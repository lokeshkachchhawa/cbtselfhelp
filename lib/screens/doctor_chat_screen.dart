import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- CONSTANTS FOR DESIGN (Updated to user's Teal palette) ---
// Palette (from user's home_page.dart):
// teal1: #016C6C
// teal2: #79C2BF
// teal3: #008F89
// teal4: #007A78
// teal5: #005E5C
// teal6: #004E4D

const Color _kPrimaryColor = Color.fromARGB(255, 1, 72, 65); // teal3 - primary
const Color _kAccentColor = Color(0xFF79C2BF); // teal2 - accent
const Color _kUserBubbleColor = Color(
  0xFF004E4D,
); // teal6 - user/patient bubble
const Color _kBackgroundColor = Color.fromARGB(
  255,
  20,
  34,
  33,
); // very light teal background
const Color _kApprovedColor = Color(0xFF007A78); // teal4 - approved
const Color _kPendingColor = Color(0xFF79C2BF); // teal2 - pending (subtle)

class DoctorChatThread extends StatefulWidget {
  final String chatId;
  final String userName;

  const DoctorChatThread({
    super.key,
    required this.chatId,
    required this.userName,
  });

  @override
  State<DoctorChatThread> createState() => _DoctorChatThreadState();
}

class _DoctorChatThreadState extends State<DoctorChatThread> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _assistantCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _sub;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> _replies = {};

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final ref = _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false);

    _sub = ref.snapshots().listen((snap) {
      final docs = snap.docs;
      final replies =
          <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
      for (final d in docs) {
        final data = d.data();
        if ((data['sender'] ?? '') == 'assistant') {
          // support either `inReplyTo` or `parentId`
          final inReplyTo = (data['inReplyTo'] ?? data['parentId']) as String?;
          if (inReplyTo != null && inReplyTo.isNotEmpty) {
            replies.putIfAbsent(inReplyTo, () => []).add(d);
          }
        }
      }
      setState(() {
        _docs = docs;
        _replies = replies;
      });

      // Automatically scroll to the bottom when new messages arrive
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll_controller_has_clients()) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  bool _scroll_controller_has_clients() {
    // defensive guard to avoid exceptions in tests/rare states
    try {
      return _scrollController.hasClients;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _assistantCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Helper function to correctly extract timestamp (The Fix)
  int _extractTimestamp(dynamic timestampValue) {
    if (timestampValue is Timestamp) {
      return timestampValue.millisecondsSinceEpoch;
    }
    if (timestampValue is int) return timestampValue;
    // Fallback for missing value
    return DateTime.now().millisecondsSinceEpoch;
  }

  TextSpan _parseBoldSpans(
    String text,
    TextStyle defaultStyle,
    TextStyle boldStyle,
  ) {
    // Splits on **bold** occurrences and builds TextSpans.
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }
      final boldText = match.group(1) ?? '';
      spans.add(TextSpan(text: boldText, style: boldStyle));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: defaultStyle));
    }

    return TextSpan(children: spans, style: defaultStyle);
  }

  /// Save ONLY the edited text (do NOT mark approved).
  /// Keeps approval workflow separate and auditable.
  Future<void> _saveAssistantDraft(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String updatedText,
  }) async {
    final msgRef = doc.reference;

    // Basic guard: ensure the document still exists
    final current = await msgRef.get();
    if (!current.exists) {
      throw StateError('Message no longer exists.');
    }

    // Use set(..., merge: true) to be forgiving if fields are missing
    await msgRef.set({
      'text': updatedText,
      'editedByDoctor': true,
      'editedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _approveAssistant(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String updatedText,
  }) async {
    final msgRef = doc.reference;
    final chatIndexRef = _firestore.collection('chatIndex').doc(widget.chatId);
    try {
      await _firestore.runTransaction((tx) async {
        tx.update(msgRef, {
          'text': updatedText,
          'approved': true,
          'editedByDoctor': true,
          'approvedAt': FieldValue.serverTimestamp(),
        });
        tx.set(chatIndexRef, {
          'lastMessage': updatedText,
          'lastUpdated': FieldValue.serverTimestamp(),
          'pendingCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Approved & published')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error approving: $e')));
      }
    } finally {}
  }

  Future<void> _editAssistantDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final controller = TextEditingController(
      text: (data['text'] ?? '') as String,
    );
    final formKey = GlobalKey<FormState>();

    // Show dialog and handle saving inside the dialog's StatefulBuilder.
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          bool isSaving = false;

          return StatefulBuilder(
            builder: (ctx, setState) {
              Future<void> _onSave() async {
                // Validate form
                if (!(formKey.currentState?.validate() ?? false)) return;

                final updatedText = controller.text.trim();
                if (updatedText.isEmpty) {
                  // Defensive: should be caught by validator, but double-check.
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reply cannot be empty')),
                    );
                  }
                  return;
                }

                // Start save state
                setState(() => isSaving = true);

                try {
                  // Remove focus so IME stops sending events to the TextField
                  // before we close the dialog / dispose the controller.
                  FocusScope.of(ctx).unfocus();

                  // perform the Firestore write
                  await _saveAssistantDraft(doc, updatedText: updatedText);

                  // Give the platform a small moment to settle IME/focus events.
                  await Future.delayed(const Duration(milliseconds: 150));

                  // Close dialog (do NOT call setState after this - builder will be disposed)
                  if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop(true);
                } on FirebaseException catch (fe) {
                  // Firestore error - allow retry
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save draft: ${fe.message}'),
                      ),
                    );
                  }
                  // revert saving state only while dialog is still visible
                  try {
                    setState(() => isSaving = false);
                  } catch (_) {}
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save draft: $e')),
                    );
                  }
                  try {
                    setState(() => isSaving = false);
                  } catch (_) {}
                }
              }

              return AlertDialog(
                title: const Text('Edit Reply (Save Draft)'),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: TextFormField(
                        controller: controller,
                        autofocus: true,
                        textInputAction: TextInputAction.newline,
                        minLines: 4,
                        maxLines: 12,
                        maxLength: 2000,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Reply cannot be empty';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Edit the AI suggested reply...',
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: _kPrimaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            // Unfocus first to make IME events stop, then pop.
                            FocusScope.of(ctx).unfocus();
                            if (Navigator.of(ctx).canPop())
                              Navigator.of(ctx).pop(false);
                          },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSaving ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimaryColor,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 8.0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Draft'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
      // (optional) you can react to didSave here if needed
    } finally {
      // Give the platform/IME a small moment to finish sending events before disposing.
      // This avoids "TextEditingController used after being disposed" errors.
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        controller.dispose();
      } catch (e) {
        // swallow - disposal errors are non-fatal here
      }
    }
  }

  Future<void> _approveDirect(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final text = (doc['text'] ?? '').toString();
    await _approveAssistant(doc, updatedText: text);
  }

  Widget _buildUserBubble(String text, int ts) {
    final time = DateTime.fromMillisecondsSinceEpoch(ts);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(top: 8, bottom: 8, right: 60),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kUserBubbleColor,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            topLeft: Radius.circular(4),
            bottomLeft: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: _parseBoldSpans(
                text,
                const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 4),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assistantCard({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data();
    final text = (data['text'] ?? '').toString();
    final approved = (data['approved'] ?? false) as bool;
    final edited = (data['editedByDoctor'] ?? false) as bool;
    final suggestedBy = (data['suggestedBy'] ?? 'AI') as String;

    // support either `timestamp` types
    final ts = _extractTimestamp(data['timestamp']);
    final time = DateTime.fromMillisecondsSinceEpoch(ts);

    final cardColor = approved ? _kApprovedColor : _kPendingColor;

    return Container(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.only(right: 0, top: 6, bottom: 6, left: 40),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(-1, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: _parseBoldSpans(
                text,
                const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),
            // Status and Actions
            if (!approved) ...[
              const Divider(color: Colors.white38, height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Suggested by: ${suggestedBy.toUpperCase()}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => _editAssistantDialog(doc),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _approveDirect(doc),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: cardColor,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text(
                          'Approve',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (edited)
                      const Icon(Icons.edit, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      'Published • ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------ NEW: worksheet summary card & detail dialog for doctor ------------------

  Widget _worksheetSummaryCardForDoctor(
    Map<String, dynamic> ws, {
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    // Colors reused from earlier palette variables
    final titleText =
        (ws['activatingEvent'] as String?)?.trim().isNotEmpty == true
        ? ws['activatingEvent'] as String
        : 'ABCDE worksheet';
    final belief = (ws['belief'] ?? '') as String;
    final firstLine = belief.trim().split(RegExp(r'\r?\n')).first;
    final dateStr = MaterialLocalizations.of(context).formatFullDate(
      // createdAt may be server timestamp - try to extract
      ws['createdAt'] is Timestamp
          ? (ws['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(
              _extractTimestamp(doc['timestamp']),
            ),
    );

    return Card(
      color: _kBackgroundColor.withOpacity(0.02),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white10, width: 0.7),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showWorksheetDetailDialog(ws),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 64,
                decoration: BoxDecoration(
                  color: _kApprovedColor.withOpacity(0.95),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (firstLine.isNotEmpty)
                      Text(
                        firstLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'B — ${belief.isEmpty ? "—" : (belief.length > 40 ? belief.substring(0, 40) + '…' : belief)}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWorksheetDetailDialog(Map<String, dynamic> item) async {
    // A compact detail dialog for doctors to inspect worksheet fields quickly
    await showDialog<void>(
      context: context,
      builder: (dctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _kBackgroundColor.withOpacity(0.98),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                // header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.02),
                        const Color(0xFF003E3D).withOpacity(0.06),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              _kAccentColor.withOpacity(0.12),
                              _kApprovedColor.withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.psychology_alt,
                            color: Colors.tealAccent,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Worksheet Detail',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (item['activatingEvent'] as String?) ??
                                  'ABCDE worksheet',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(dctx).pop(),
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white10, height: 1),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _detailSection(
                          'A — Activating Event',
                          item['activatingEvent'] as String? ?? '',
                        ),
                        const SizedBox(height: 8),
                        _detailSection(
                          'B — Belief',
                          item['belief'] as String? ?? '',
                        ),
                        const SizedBox(height: 8),
                        _detailGroup('C — Consequences', [
                          {
                            'label': 'Emotional',
                            'value': item['consequencesEmotional'] ?? '',
                          },
                          {
                            'label': 'Psychological',
                            'value': item['consequencesPsychological'] ?? '',
                          },
                          {
                            'label': 'Physical',
                            'value': item['consequencesPhysical'] ?? '',
                          },
                          {
                            'label': 'Behavioural',
                            'value': item['consequencesBehavioural'] ?? '',
                          },
                        ]),
                        const SizedBox(height: 8),
                        _detailSection('D — Dispute', item['dispute'] ?? ''),
                        const SizedBox(height: 8),
                        _detailGroup('E — Effects', [
                          {
                            'label': 'Emotional',
                            'value': item['emotionalEffect'] ?? '',
                          },
                          {
                            'label': 'Psychological',
                            'value': item['psychologicalEffect'] ?? '',
                          },
                          {
                            'label': 'Physical',
                            'value': item['physicalEffect'] ?? '',
                          },
                          {
                            'label': 'Behavioural',
                            'value': item['behaviouralEffect'] ?? '',
                          },
                        ]),
                        if ((item['note'] as String?)?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Note',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item['note'] as String,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // footer actions
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14),
                    ),
                    border: const Border(
                      top: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // For doctors: quick action could be to copy to clipboard or comment — keep simple.
                            final sbText = StringBuffer();
                            sbText.writeln('ABCDE Worksheet — quick copy:');
                            sbText.writeln();
                            sbText.writeln(
                              'A: ${item['activatingEvent'] ?? ''}',
                            );
                            sbText.writeln('B: ${item['belief'] ?? ''}');
                            sbText.writeln('D: ${item['dispute'] ?? ''}');
                            sbText.writeln('Note: ${item['note'] ?? ''}');
                            Clipboard.setData(
                              ClipboardData(text: sbText.toString()),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied worksheet summary'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.copy,
                            color: Colors.tealAccent,
                          ),
                          label: const Text(
                            'Copy summary',
                            style: TextStyle(color: Colors.tealAccent),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.tealAccent),
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Optionally open a full editor (app-specific) — left as a placeholder
                        },
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'Close',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailSection(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _detailGroup(String label, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: items.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['label'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (m['value'] ?? '').isEmpty ? '—' : (m['value'] ?? ''),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ------------------ END worksheet helpers ------------------

  Widget _buildThread() {
    if (_docs.isEmpty) {
      return const Center(
        child: Text(
          'Start the conversation.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final children = <Widget>[];
    for (final doc in _docs) {
      final d = doc.data();
      final sender = d['sender'] ?? '';

      // support either parent field names for replies created by different code paths
      final inReplyTo = (d['inReplyTo'] ?? d['parentId']) as String?;

      if (sender == 'user') {
        final text = (d['text'] ?? '').toString();

        // 🚨 FIX: Correctly extract and convert Timestamp for user messages
        final ts = _extractTimestamp(d['timestamp']);

        // If this user message is a worksheet (structured), render special summary card
        final type = (d['type'] ?? '') as String;
        final ws = d['worksheet'] != null
            ? Map<String, dynamic>.from(d['worksheet'] as Map)
            : null;

        if (type == 'worksheet' || ws != null) {
          // use structured worksheet if present, else attempt to parse text (fallback)
          final wsMap =
              ws ??
              <String, dynamic>{
                'activatingEvent': text.split('\n').first,
                'belief': text, // fallback
              };
          children.add(_worksheetSummaryCardForDoctor(wsMap, doc: doc));
        } else {
          children.add(_buildUserBubble(text, ts));
        }

        // Display replies linked to this user message
        final replies = _replies[doc.id] ?? [];
        // Also consider replies keyed by doc.id string (some code writes parentId as doc.id string).
        for (final r in replies) {
          children.add(_assistantCard(doc: r));
        }
      } else if (sender == 'assistant') {
        // show top-level assistant messages (that aren't replies) directly
        final parent = (d['inReplyTo'] ?? d['parentId']) as String?;
        if (parent == null || parent.isEmpty) {
          children.add(_assistantCard(doc: doc));
        }
        // otherwise the assistant reply will be shown nested under its parent user msg above
      } else {
        // unknown sender - render as plain bubble
        final ts = _extractTimestamp(d['timestamp']);
        children.add(_buildUserBubble((d['text'] ?? '').toString(), ts));
      }
      // small spacing handled by each widget's margin
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF004E4D),
        foregroundColor: Colors.white,
        elevation: 4,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _kAccentColor,
              child: Text(
                widget.userName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.userName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      _docs.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _kPrimaryColor,
                        ),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snap.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  return _buildThread();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
