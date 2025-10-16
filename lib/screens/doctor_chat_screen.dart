import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// DoctorChatThread — for approving & editing AI replies
/// Each message doc: { text, senderId, isDoctor, approved, timestamp }
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
  final _firestore = FirebaseFirestore.instance;
  final _scrollCtrl = ScrollController();

  Future<void> _approveMessage(
    String msgId,
    String text,
    bool alreadyApproved,
  ) async {
    try {
      if (alreadyApproved) return;
      await _firestore
          .collection('chatIndex')
          .doc(widget.chatId)
          .collection('messages')
          .doc(msgId)
          .update({'approved': true, 'text': text.trim()});

      await _firestore.collection('chatIndex').doc(widget.chatId).update({
        'lastMessage': text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message approved ✅')));
    } catch (e) {
      debugPrint('Approve failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _editAndApprove(String msgId, String oldText) async {
    final ctrl = TextEditingController(text: oldText);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF021515),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Edit AI reply',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Modify before approval...',
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008F89),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (newText != null && newText.trim().isNotEmpty) {
      await _approveMessage(msgId, newText, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgStream = _firestore
        .collection('chatIndex')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF021515),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004E4D),
        title: Text(
          widget.userName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist, color: Colors.white),
            tooltip: 'Mark all read',
            onPressed: () async {
              await _firestore
                  .collection('chatIndex')
                  .doc(widget.chatId)
                  .update({'unreadCount': 0});
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: msgStream,
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No messages yet.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              final text = (d['text'] ?? '').toString();
              final isDoctor = d['isDoctor'] ?? false;
              final approved = d['approved'] ?? false;
              final senderId = d['senderId'] ?? '';
              final timestamp = d['timestamp'];
              final timeStr = timestamp is Timestamp
                  ? _formatTime(timestamp.toDate())
                  : '';

              final bubbleColor = approved
                  ? Colors.white.withOpacity(0.05)
                  : Colors.orange.withOpacity(0.08);

              final align = isDoctor
                  ? Alignment.centerRight
                  : Alignment.centerLeft;

              return Align(
                alignment: align,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: approved
                          ? Colors.teal.withOpacity(0.4)
                          : Colors.orange.withOpacity(0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          color: approved
                              ? Colors.white
                              : Colors.orange.shade100,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            approved ? 'Approved' : 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              color: approved
                                  ? Colors.tealAccent.shade100
                                  : Colors.orangeAccent,
                            ),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (isDoctor && !approved)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _approveMessage(id, text, approved),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF008F89),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: const Size(0, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text(
                                  'Approve',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _editAndApprove(id, text),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.tealAccent.shade100,
                                  side: BorderSide(
                                    color: Colors.tealAccent.shade100
                                        .withOpacity(0.4),
                                  ),
                                ),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
