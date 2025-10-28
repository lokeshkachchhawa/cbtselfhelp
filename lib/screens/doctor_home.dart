import 'package:cbt_drktv/screens/doctor_chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:characters/characters.dart';

// Remove these if you already define them in a shared theme and import instead:
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);

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

  // cache to avoid repeated profile reads
  final Map<String, String> _nameCache = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  /// Resolve display name:
  /// 1) chatIndex.userName (if denormalized)
  /// 2) users/{uid}.name (if we can find uid in chatIndex.userId/uid/ownerUid)
  /// 3) users by email
  /// 4) email local part
  /// 5) "User"
  Future<String> _resolveDisplayName(Map<String, dynamic> chatIdx) async {
    final existing = (chatIdx['userName'] ?? '').toString().trim();
    if (existing.isNotEmpty) return existing;

    final uid =
        (chatIdx['userId'] ?? chatIdx['uid'] ?? chatIdx['ownerUid'] ?? '')
            .toString()
            .trim();

    if (uid.isNotEmpty) {
      if (_nameCache.containsKey(uid)) return _nameCache[uid]!;
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final udata = userDoc.data();
        if (udata != null) {
          final n = (udata['name'] ?? '').toString().trim();
          if (n.isNotEmpty) {
            _nameCache[uid] = n;
            return n;
          }
          final em = (udata['email'] ?? '').toString();
          if (em.isNotEmpty) {
            final local = em.split('@').first;
            _nameCache[uid] = local;
            return local;
          }
        }
      } catch (_) {}
    }

    final email = (chatIdx['userEmail'] ?? '').toString().trim();
    if (email.isNotEmpty) {
      final cacheKey = 'email:$email';
      if (_nameCache.containsKey(cacheKey)) return _nameCache[cacheKey]!;
      try {
        final q = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final name = (q.docs.first.data()['name'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            _nameCache[cacheKey] = name;
            return name;
          }
        }
      } catch (_) {}
      final local = email.split('@').first;
      _nameCache[cacheKey] = local;
      return local;
    }

    return 'User';
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

                // We filter after resolving names. To keep UI smooth, we still
                // render each tile with a FutureBuilder and hide when it doesn’t match.
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final chatId = doc.id;

                    final lastMessage = (data['lastMessage'] ?? '').toString();
                    final unread = (data['unreadCount'] ?? 0) as int;
                    final pending = (data['pendingCount'] ?? 0) as int;
                    final ts = (data['lastUpdated'] as Timestamp?)?.toDate();
                    final time = ts != null
                        ? '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                        : '';

                    return FutureBuilder<String>(
                      future: _resolveDisplayName(data),
                      builder: (ctx, nameSnap) {
                        final userName = (nameSnap.data ?? '').trim();
                        final displayName = userName.isEmpty
                            ? 'User'
                            : userName;

                        // search filtering uses resolved name
                        final q = _searchQuery.toLowerCase();
                        if (q.isNotEmpty) {
                          final email = (data['userEmail'] ?? '')
                              .toString()
                              .toLowerCase();
                          final matches =
                              displayName.toLowerCase().contains(q) ||
                              email.contains(q);
                          if (!matches) return const SizedBox.shrink();
                        }

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
                                _initial(displayName),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              displayName,
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
                                    userName: displayName, // pass resolved
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
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
