import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Reuse same colors as DoctorHome
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

  // Cached users (simple Map, JSON safe fields only)
  List<Map<String, dynamic>> _users = [];

  bool _loading = true; // initial loading
  bool _syncing = false; // when hitting server
  String _searchQuery = '';
  bool _onlyActive = false;

  // status filter driven by top chips:
  // 'all', 'active', 'inactive', 'cancel_scheduled', 'with_sub'
  String _statusFilter = 'all';

  // Pagination
  static const int _pageSize = 20;
  int _pageIndex = 0; // 0-based

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadFromCache();
    // After showing cache (if any), sync with server for latest users
    _syncFromServer();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

        // Ensure sorted by createdAt desc
        _users.sort((a, b) {
          final am = (a['createdAtMillis'] ?? 0) as int;
          final bm = (b['createdAtMillis'] ?? 0) as int;
          return bm.compareTo(am);
        });
      }
    } catch (e) {
      debugPrint('Failed to load users cache: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Always fetch full latest list from Firestore (up to 200 users)
  Future<void> _syncFromServer() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
    });

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
        final lastLogin = (data['lastLogin'] as Timestamp?)?.toDate();

        final subscription = Map<String, dynamic>.from(
          data['subscription'] ?? {},
        );
        final subStatus = (subscription['status'] ?? '').toString();
        final subId =
            (subscription['subscriptionId'] ?? data['subscriptionId'] ?? '')
                .toString();

        final user = <String, dynamic>{
          'id': doc.id,
          'name': (data['name'] ?? '').toString(),
          'email': (data['email'] ?? '').toString(),
          'isAnonymous': (data['isAnonymous'] ?? false) == true,
          'createdAtMillis': createdAt?.millisecondsSinceEpoch ?? 0,
          'lastLoginMillis': lastLogin?.millisecondsSinceEpoch ?? 0,
          'platform': (data['platform'] ?? '').toString(),
          'lastBaselineScore': (data['lastBaselineScore'] ?? '').toString(),
          'baselineCompleted': (data['baselineCompleted'] ?? false) == true,
          'consentGiven': (data['consentGiven'] ?? false) == true,
          'subStatus': subStatus,
          'subscriptionId': subId,
        };

        fresh.add(user);
      }

      // Sort latest joined first (createdAt desc)
      fresh.sort((a, b) {
        final am = (a['createdAtMillis'] ?? 0) as int;
        final bm = (b['createdAtMillis'] ?? 0) as int;
        return bm.compareTo(am);
      });

      _users = fresh;

      // Save to cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('doctor_users_cache', jsonEncode(_users));

      // On changed data, reset to first page
      _pageIndex = 0;
    } catch (e) {
      debugPrint('Error syncing users from server: $e');
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _loading = false;
        });
      }
    }
  }

  String _initialFromNameOrEmail(String? name, String? email) {
    final n = (name ?? '').trim();
    if (n.isNotEmpty) return n.characters.first.toUpperCase();
    final e = (email ?? '').trim();
    if (e.isNotEmpty) return e.characters.first.toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    // Stats from full cached list (not filtered)
    final totalUsers = _users.length;

    int activeUsers = 0;
    int withSubUsers = 0;
    int cancelScheduledUsers = 0;

    for (final u in _users) {
      final subStatus = (u['subStatus'] ?? '').toString();
      final hasSub = subStatus.isNotEmpty;
      final isActive = subStatus == 'active' || subStatus == 'cancel_scheduled';

      if (subStatus == 'cancel_scheduled') cancelScheduledUsers++;
      if (hasSub) withSubUsers++;
      if (isActive) activeUsers++;
    }
    final inactiveUsers = totalUsers - activeUsers;

    // Filtered users (search + status filter + onlyActive switch)
    List<Map<String, dynamic>> filtered = _users.where((u) {
      final name = (u['name'] ?? '').toString();
      final email = (u['email'] ?? '').toString();
      final subStatus = (u['subStatus'] ?? '').toString();
      final hasSub = subStatus.isNotEmpty;
      final isActive = subStatus == 'active' || subStatus == 'cancel_scheduled';
      final isInactive = !isActive; // includes no-subscription also

      // 1) Status chips filter
      switch (_statusFilter) {
        case 'active':
          if (!isActive) return false;
          break;
        case 'inactive':
          if (!isInactive) return false;
          break;
        case 'cancel_scheduled':
          if (subStatus != 'cancel_scheduled') return false;
          break;
        case 'with_sub':
          if (!hasSub) return false;
          break;
        case 'all':
        default:
          // no extra filter
          break;
      }

      // 2) "Show only active subscriptions" switch
      if (_onlyActive && !isActive) return false;

      // 3) Search filter
      final q = _searchQuery;
      if (q.isEmpty) return true;

      final matchesName = name.toLowerCase().contains(q);
      final matchesEmail = email.toLowerCase().contains(q);

      return matchesName || matchesEmail;
    }).toList();

    final totalFiltered = filtered.length;
    final totalPages = totalFiltered == 0
        ? 1
        : ((totalFiltered - 1) ~/ _pageSize + 1);

    // Clamp page index
    final currentPageIndex = totalFiltered == 0
        ? 0
        : min(_pageIndex, totalPages - 1);

    // Slice current page (20 users per page)
    List<Map<String, dynamic>> pageUsers = [];
    if (totalFiltered > 0) {
      final start = currentPageIndex * _pageSize;
      final end = min(start + _pageSize, totalFiltered);
      if (start < end) {
        pageUsers = filtered.sublist(start, end);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF021515),
      appBar: AppBar(
        backgroundColor: teal4,
        title: const Text('All Users'),
        actions: [
          IconButton(
            tooltip: 'Refresh from server',
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _syncing ? null : _syncFromServer,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.12),
              border: const Border(
                top: BorderSide(color: Colors.black26, width: 0.4),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _statChip(
                    label: 'Total',
                    value: totalUsers.toString(),
                    icon: Icons.person_outline,
                    selected: _statusFilter == 'all',
                    onTap: () {
                      setState(() {
                        _statusFilter = 'all';
                        _onlyActive = false;
                        _pageIndex = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    label: 'Active',
                    value: activeUsers.toString(),
                    icon: Icons.verified_user_rounded,
                    bg: Colors.greenAccent.shade400,
                    fg: Colors.black,
                    selected: _statusFilter == 'active',
                    onTap: () {
                      setState(() {
                        _statusFilter = 'active';
                        _onlyActive = false;
                        _pageIndex = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    label: 'Inactive',
                    value: inactiveUsers.toString(),
                    icon: Icons.person_off_outlined,
                    bg: Colors.redAccent.shade200,
                    fg: Colors.black,
                    selected: _statusFilter == 'inactive',
                    onTap: () {
                      setState(() {
                        _statusFilter = 'inactive';
                        _onlyActive = false;
                        _pageIndex = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    label: 'Cancel scheduled',
                    value: cancelScheduledUsers.toString(),
                    icon: Icons.schedule_send_rounded,
                    bg: Colors.amberAccent.shade700,
                    fg: Colors.black,
                    selected: _statusFilter == 'cancel_scheduled',
                    onTap: () {
                      setState(() {
                        _statusFilter = 'cancel_scheduled';
                        _onlyActive = false;
                        _pageIndex = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    label: 'With subscription',
                    value: withSubUsers.toString(),
                    icon: Icons.receipt_long_rounded,
                    bg: Colors.blueGrey.shade200,
                    fg: Colors.black,
                    selected: _statusFilter == 'with_sub',
                    onTap: () {
                      setState(() {
                        _statusFilter = 'with_sub';
                        _onlyActive = false;
                        _pageIndex = 0;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                        _pageIndex = 0; // reset page on search change
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),
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

                // Only active switch
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Switch(
                        value: _onlyActive,
                        activeColor: teal3,
                        onChanged: (v) {
                          setState(() {
                            _onlyActive = v;
                            _pageIndex = 0; // reset page
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Show only active subscriptions',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: totalFiltered == 0
                      ? const Center(
                          child: Text(
                            'No users found.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : Column(
                          children: [
                            // List of current page users
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: pageUsers.length,
                                itemBuilder: (context, index) {
                                  final u = pageUsers[index];

                                  final name = (u['name'] ?? '').toString();
                                  final email = (u['email'] ?? '').toString();
                                  final isAnonymous =
                                      (u['isAnonymous'] ?? false) == true;

                                  final createdAtMillis =
                                      (u['createdAtMillis'] ?? 0) as int;
                                  final lastLoginMillis =
                                      (u['lastLoginMillis'] ?? 0) as int;
                                  final createdAt = createdAtMillis > 0
                                      ? DateTime.fromMillisecondsSinceEpoch(
                                          createdAtMillis,
                                        )
                                      : null;
                                  final lastLogin = lastLoginMillis > 0
                                      ? DateTime.fromMillisecondsSinceEpoch(
                                          lastLoginMillis,
                                        )
                                      : null;

                                  final platform = (u['platform'] ?? '')
                                      .toString();
                                  final lastBaselineScore =
                                      (u['lastBaselineScore'] ?? '').toString();
                                  final baselineCompleted =
                                      (u['baselineCompleted'] ?? false) == true;
                                  final consentGiven =
                                      (u['consentGiven'] ?? false) == true;

                                  final subStatus = (u['subStatus'] ?? '')
                                      .toString();
                                  final subscriptionId =
                                      (u['subscriptionId'] ?? '').toString();

                                  final isActive =
                                      subStatus == 'active' ||
                                      subStatus == 'cancel_scheduled';

                                  // Status chip style
                                  Color statusBg;
                                  Color statusText;
                                  String statusLabel;

                                  if (subStatus == 'active') {
                                    statusBg = Colors.greenAccent.shade400;
                                    statusText = Colors.black;
                                    statusLabel = 'Active';
                                  } else if (subStatus == 'cancel_scheduled') {
                                    statusBg = Colors.amberAccent.shade700;
                                    statusText = Colors.black;
                                    statusLabel = 'Cancel scheduled';
                                  } else if (subStatus.isNotEmpty) {
                                    statusBg = Colors.redAccent.shade200;
                                    statusText = Colors.black;
                                    statusLabel = subStatus;
                                  } else {
                                    statusBg = Colors.grey.shade600;
                                    statusText = Colors.white;
                                    statusLabel = 'No subscription';
                                  }

                                  final initial = _initialFromNameOrEmail(
                                    name,
                                    email,
                                  );

                                  return Card(
                                    color: Colors.white.withOpacity(0.06),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isActive
                                            ? Colors.greenAccent.withOpacity(
                                                0.6,
                                              )
                                            : Colors.white10,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        10,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Avatar
                                          CircleAvatar(
                                            backgroundColor: isActive
                                                ? Colors.green.shade600
                                                : teal3,
                                            child: Text(
                                              initial,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Main content
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Name + email row
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        name.isNotEmpty
                                                            ? name
                                                            : (email.isNotEmpty
                                                                  ? email
                                                                  : 'User'),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isAnonymous)
                                                      Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              left: 6,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .deepPurple
                                                              .shade300,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        child: const Text(
                                                          'Anonymous',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),

                                                if (email.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 2,
                                                        ),
                                                    child: Text(
                                                      email,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white60,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),

                                                const SizedBox(height: 6),

                                                // Dates + platform
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          if (createdAt != null)
                                                            Text(
                                                              'Created: ${createdAt.toLocal().toString().split('.').first}',
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white54,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                            ),
                                                          if (lastLogin != null)
                                                            Text(
                                                              'Last login: ${lastLogin.toLocal().toString().split('.').first}',
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white54,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (platform.isNotEmpty)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 8,
                                                            ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .phone_iphone,
                                                              size: 14,
                                                              color: Colors
                                                                  .white60,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              platform,
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white60,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),

                                                const SizedBox(height: 6),

                                                // Baseline / consent / last score
                                                Row(
                                                  children: [
                                                    if (baselineCompleted)
                                                      _smallTag(
                                                        icon: Icons
                                                            .assessment_rounded,
                                                        label:
                                                            'Baseline ${lastBaselineScore.isNotEmpty ? lastBaselineScore : ''}',
                                                      ),
                                                    if (consentGiven)
                                                      _smallTag(
                                                        icon: Icons
                                                            .rule_folder_rounded,
                                                        label: 'Consent',
                                                      ),
                                                  ],
                                                ),

                                                if (subscriptionId.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      'Sub ID: $subscriptionId',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          // Subscription status chip
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: statusBg,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  statusLabel,
                                                  style: TextStyle(
                                                    color: statusText,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Pagination controls
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.18),
                                border: const Border(
                                  top: BorderSide(
                                    color: Colors.white10,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    totalFiltered == 0
                                        ? 'No users'
                                        : 'Page ${currentPageIndex + 1} of $totalPages   '
                                              '(${pageUsers.length} shown, $totalFiltered filtered)',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: currentPageIndex > 0
                                        ? () {
                                            setState(() {
                                              _pageIndex = currentPageIndex - 1;
                                            });
                                          }
                                        : null,
                                    child: const Text('Previous'),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton(
                                    onPressed: currentPageIndex < totalPages - 1
                                        ? () {
                                            setState(() {
                                              _pageIndex = currentPageIndex + 1;
                                            });
                                          }
                                        : null,
                                    child: const Text('Next'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _smallTag({required IconData icon, required String label}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white70),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    required IconData icon,
    bool selected = false,
    VoidCallback? onTap,
    Color? bg,
    Color? fg,
  }) {
    final backgroundBase = bg ?? Colors.white.withOpacity(0.08);
    final foreground = fg ?? Colors.white;
    final background = selected
        ? (bg ?? Colors.tealAccent.withOpacity(0.35))
        : backgroundBase;
    final borderColor = selected ? Colors.white : Colors.white24;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected ? 1.2 : 0.7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground.withOpacity(0.9)),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foreground.withOpacity(0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
