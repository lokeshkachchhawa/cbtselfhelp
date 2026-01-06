import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Brand Colors
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);

class DoctorUsersScreen extends StatefulWidget {
  const DoctorUsersScreen({super.key});

  @override
  State<DoctorUsersScreen> createState() => _DoctorUsersScreenState();
}

class _DoctorUsersScreenState extends State<DoctorUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchCtrl = TextEditingController();

  // Data State
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _syncing = false;
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'cancel_scheduled', 'no_sub'

  // Global Counts (Aggregated from entire DB)
  int _globalTotal = 0;
  int _globalActiveSub = 0; // Subscribed & Not Cancelled
  int _globalCancelScheduled = 0; // Cancelled but Access Active
  int _globalNoSub = 0; // No active subscription record

  // Pagination
  static const int _pageSize = 20;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _fetchGlobalStats();
    await _loadFromCache();
    _syncFromServer();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showEnrollConfirmDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF021515),
        title: const Text("Enroll User", style: TextStyle(color: Colors.white)),
        content: Text(
          "Enroll $email in the CBT Course?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: teal3),
            onPressed: () {
              Navigator.pop(context);
              _enrollInCBT(email);
            },
            child: const Text("Confirm Enrollment"),
          ),
        ],
      ),
    );
  }

  Future<void> _enrollInCBT(String email) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _firestore.collection('enrollments').add({
        'courseId': 'cbt_course',
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $email enrolled successfully!')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Enrollment error: $e');
    }
  }

  /// Fetches real-time counts from the entire Firestore collection
  Future<void> _fetchGlobalStats() async {
    try {
      final usersCol = _firestore.collection('users');

      // Run aggregation queries in parallel
      final results = await Future.wait([
        usersCol.count().get(), // Total
        usersCol
            .where('subscription.status', isEqualTo: 'active')
            .count()
            .get(),
        usersCol
            .where('subscription.status', isEqualTo: 'cancel_scheduled')
            .count()
            .get(),
      ]);

      if (mounted) {
        setState(() {
          _globalTotal = results[0].count ?? 0;
          _globalActiveSub = results[1].count ?? 0;
          _globalCancelScheduled = results[2].count ?? 0;
          _globalNoSub =
              _globalTotal - (_globalActiveSub + _globalCancelScheduled);
        });
      }
    } catch (e) {
      debugPrint('Error fetching global stats: $e');
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('doctor_users_cache');

      if (jsonString != null) {
        final list = jsonDecode(jsonString) as List;
        _users = list
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
        _users.sort(
          (a, b) =>
              (b['createdAtMillis'] ?? 0).compareTo(a['createdAtMillis'] ?? 0),
        );
      }
    } catch (e) {
      debugPrint('Cache error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncFromServer() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    _fetchGlobalStats();

    try {
      final snap = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      final List<Map<String, dynamic>> fresh = [];

      for (final doc in snap.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final subscription = Map<String, dynamic>.from(
          data['subscription'] ?? {},
        );

        fresh.add({
          'id': doc.id,
          'name': (data['name'] ?? '').toString(),
          'email': (data['email'] ?? '').toString(),
          'createdAtMillis': createdAt?.millisecondsSinceEpoch ?? 0,
          'subStatus': (subscription['status'] ?? '').toString(),
          'platform': (data['platform'] ?? '').toString(),
        });
      }

      _users = fresh;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('doctor_users_cache', jsonEncode(_users));
      _pageIndex = 0;
    } catch (e) {
      debugPrint('Sync error: $e');
    } finally {
      if (mounted)
        setState(() {
          _syncing = false;
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filtered = _users.where((u) {
      final status = (u['subStatus'] ?? '').toString();

      if (_statusFilter == 'active' && status != 'active') return false;
      if (_statusFilter == 'cancel_scheduled' && status != 'cancel_scheduled')
        return false;
      if (_statusFilter == 'no_sub' && status.isNotEmpty) return false;

      final q = _searchQuery;
      if (q.isEmpty) return true;
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    final totalFiltered = filtered.length;
    final totalPages = (totalFiltered / _pageSize).ceil().clamp(1, 999);
    final currentPageIndex = min(_pageIndex, totalPages - 1);

    List<Map<String, dynamic>> pageUsers = [];
    if (totalFiltered > 0) {
      final start = currentPageIndex * _pageSize;
      final end = min(start + _pageSize, totalFiltered);
      pageUsers = filtered.sublist(start, end);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF021515),
      appBar: AppBar(
        backgroundColor: teal4,
        elevation: 0,
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _syncing ? null : _syncFromServer,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(65),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _statChip(
                    'Total',
                    _globalTotal.toString(),
                    Icons.groups,
                    'all',
                    Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    'Subscribed',
                    _globalActiveSub.toString(),
                    Icons.verified,
                    'active',
                    Colors.greenAccent.shade700,
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    'Cancelling',
                    _globalCancelScheduled.toString(),
                    Icons.pending_actions,
                    'cancel_scheduled',
                    Colors.orangeAccent.shade400,
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    'No Sub',
                    _globalNoSub.toString(),
                    Icons.person_outline,
                    'no_sub',
                    Colors.redAccent.shade200,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: teal3))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() {
                      _searchQuery = val.trim().toLowerCase();
                      _pageIndex = 0;
                    }),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search recent 200 by name or email...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: Colors.white12,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: pageUsers.isEmpty
                      ? const Center(
                          child: Text(
                            'No users found in this category.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: pageUsers.length,
                          itemBuilder: (context, index) =>
                              _buildUserCard(pageUsers[index]),
                        ),
                ),
                _buildPagination(totalPages),
              ],
            ),
    );
  }

  Widget _statChip(
    String label,
    String value,
    IconData icon,
    String filterKey,
    Color activeColor,
  ) {
    bool isSelected = _statusFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() {
        _statusFilter = filterKey;
        _pageIndex = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white38 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final String name = u['name'].toString();
    final String email = u['email'].toString();
    final String status = u['subStatus'].toString();

    Color statusColor = Colors.grey;
    String statusText = 'No Subscription';

    if (status == 'active') {
      statusColor = Colors.greenAccent;
      statusText = 'Active Subscriber';
    } else if (status == 'cancel_scheduled') {
      statusColor = Colors.orangeAccent;
      statusText = 'Access ends soon';
    }

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: status == 'active'
              ? Colors.greenAccent.withOpacity(0.2)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: status == 'active' ? Colors.green.shade800 : teal3,
            child: Text(
              (name.isNotEmpty ? name[0] : (email.isNotEmpty ? email[0] : '?'))
                  .toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            name.isNotEmpty
                ? name
                : (email.isNotEmpty ? email : 'Unknown User'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty && email.isNotEmpty)
                Text(
                  email,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Inside _buildUserCard
          trailing: IconButton(
            icon: const Icon(Icons.school_outlined, color: Colors.tealAccent),
            tooltip: 'Enroll in CBT',
            onPressed: () {
              _showEnrollConfirmDialog(u['email']);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 18,
            ),
            onPressed: _pageIndex > 0
                ? () => setState(() => _pageIndex--)
                : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Page ${_pageIndex + 1} of $totalPages',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 18,
            ),
            onPressed: _pageIndex < totalPages - 1
                ? () => setState(() => _pageIndex++)
                : null,
          ),
        ],
      ),
    );
  }
}
