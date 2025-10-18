// lib/screens/doctor_home.dart
import 'package:cbt_drktv/screens/doctor_chat_screen.dart';
import 'package:cbt_drktv/screens/thought_record_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// your teal color constants (teal3, teal4 etc)

class DoctorHome extends StatefulWidget {
  const DoctorHome({super.key});

  @override
  State<DoctorHome> createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  void _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/signin');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatStream() {
    return _firestore
        .collection('chatIndex')
        .orderBy('lastUpdated', descending: true)
        .limit(100)
        .snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021515),
      appBar: AppBar(
        backgroundColor: teal4,
        title: const Text('Doctor Dashboard — Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search patient name or email...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white12,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Chat list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error loading chats: ${snap.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No patient chats yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                // Filter search
                final filtered = docs.where((d) {
                  final data = d.data();
                  final name = (data['userName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (data['userEmail'] ?? '')
                      .toString()
                      .toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  if (query.isEmpty) return true;
                  return name.contains(query) || email.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No results match your search.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final doc = filtered[i];
                    final data = doc.data();
                    final chatId = doc.id;
                    final userName = (data['userName'] ?? 'User').toString();
                    final lastMessage = (data['lastMessage'] ?? '').toString();
                    final unread = (data['unreadCount'] ?? 0) as int;
                    final pending = (data['pendingCount'] ?? 0) as int;
                    final ts = (data['lastUpdated'] as Timestamp?)?.toDate();
                    final time = ts != null
                        ? '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                        : '';

                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: teal3,
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (pending > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orangeAccent.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Pending $pending',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (unread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (time.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  time,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () async {
                          // reset unreadCount on open (best-effort)
                          try {
                            await _firestore
                                .collection('chatIndex')
                                .doc(chatId)
                                .update({'unreadCount': 0});
                          } catch (e) {
                            debugPrint('Failed to reset unread: $e');
                          }

                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DoctorChatThread(
                                chatId: chatId,
                                userName: userName,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: teal3,
        child: const Icon(Icons.refresh),
        onPressed: () => setState(() {}),
        tooltip: 'Refresh list',
      ),
    );
  }
}
