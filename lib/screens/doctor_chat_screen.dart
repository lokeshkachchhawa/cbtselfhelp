import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
        if (data['sender'] == 'assistant') {
          final inReplyTo = data['inReplyTo'] as String?;
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
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
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
    // Fallback for older messages stored as int or null
    return (timestampValue ?? DateTime.now().millisecondsSinceEpoch) as int;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Approved & published')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error approving: $e')));
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

    // 🚨 FIX: Correctly extract and convert Timestamp to int (millisecondsSinceEpoch)
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
      final sender = d['sender'];
      final inReplyTo = d['inReplyTo'] as String?;

      if (sender == 'user') {
        final text = (d['text'] ?? '').toString();

        // 🚨 FIX: Correctly extract and convert Timestamp for user messages
        final ts = _extractTimestamp(d['timestamp']);

        children.add(_buildUserBubble(text, ts));

        // Display replies linked to this user message
        final replies = _replies[doc.id] ?? [];
        for (final r in replies) {
          children.add(_assistantCard(doc: r));
        }
      } else if (sender == 'assistant' &&
          (inReplyTo == null || inReplyTo.isEmpty)) {
        // Display independent assistant messages
        children.add(_assistantCard(doc: doc));
      }
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
