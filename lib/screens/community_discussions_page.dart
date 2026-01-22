import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';

const Color _kPrimaryColor = Color.fromARGB(255, 1, 72, 65);
const Color _kBackgroundColor = Color.fromARGB(255, 20, 34, 33);
const Color _kAccentColor = Color(0xFF79C2BF);
const Color _kCardColor = Color(0xFF1A2B2A);
const Color _kBorderColor = Color(0xFF2D3F3E);

enum CommunityFeedMode { all, myLikes, myBookmarks }

class ToolLink {
  final String title;
  final String route;
  final IconData icon;
  final List<String> keywords;

  const ToolLink({
    required this.title,
    required this.route,
    required this.icon,
    required this.keywords,
  });
}

const List<ToolLink> mentalHealthTools = [
  ToolLink(
    title: 'Thought Record',
    route: '/thought',
    icon: Icons.edit_note,
    keywords: [
      'thought record',
      'negative thought',
      'automatic thought',
      'CBT',
    ],
  ),
  ToolLink(
    title: 'ABCDE Worksheet',
    route: '/abcd',
    icon: Icons.assignment,
    keywords: ['abcde', 'belief', 'dispute', 'cbt worksheet', 'CBT'],
  ),
  ToolLink(
    title: 'Breathing Exercise',
    route: '/relax/breath',
    icon: Icons.air,
    keywords: [
      'breathing',
      'breath',
      'panic',
      'hyperventilation',
      'meditation',
    ],
  ),
  ToolLink(
    title: 'PMR Relaxation',
    route: '/relax_pmr',
    icon: Icons.self_improvement,
    keywords: ['pmr', 'muscle relaxation', 'body tension', 'panic', 'anxiety'],
  ),
  ToolLink(
    title: 'Grounding Technique',
    route: '/grounding',
    icon: Icons.spa,
    keywords: ['grounding', '5-4-3-2-1', 'derealization'],
  ),
  ToolLink(
    title: 'Mini Meditation',
    route: '/minimeditation',
    icon: Icons.headphones,
    keywords: ['meditation', 'mindfulness', 'calm', 'breath'],
  ),
  ToolLink(
    title: 'Chat with Doctor',
    route: '/drktv_chat',
    icon: Icons.chat,
    keywords: ['doctor', 'consult', 'talk to expert'],
  ),
  ToolLink(
    title: 'Good Moments Diary',
    route: '/good-moments',
    icon: Icons.favorite,
    keywords: ['gratitude', 'good moments', 'positive', 'good', 'past'],
  ),
];

class CommunityDiscussionsPage extends StatefulWidget {
  const CommunityDiscussionsPage({super.key});

  @override
  State<CommunityDiscussionsPage> createState() =>
      _CommunityDiscussionsPageState();
}

class _CommunityDiscussionsPageState extends State<CommunityDiscussionsPage> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  CommunityFeedMode _feedMode = CommunityFeedMode.all;
  final ScrollController _categoryScrollCtrl = ScrollController();
  final int _pageSize = 10;
  DocumentSnapshot? _lastDoc;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  final ScrollController _feedScrollCtrl = ScrollController();

  List<Map<String, dynamic>> _posts = [];
  late Box _cacheBox;

  @override
  void initState() {
    super.initState();
    _cacheBox = Hive.box('community_posts');
    _loadInitialPosts();

    _feedScrollCtrl.addListener(() {
      if (_feedScrollCtrl.position.pixels >=
              _feedScrollCtrl.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMorePosts();
      }
    });
  }

  String _cacheKey() {
    return 'posts_${_feedMode.name}_$_selectedCategory';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    setState(() {
      _posts.clear();
      _lastDoc = null;
      _hasMore = true;
    });

    // 🟢 1. LOAD FROM HIVE (instant UI)
    final cached = _cacheBox.get(_cacheKey());

    if (cached != null && cached is List) {
      setState(() {
        _posts = cached.map((e) {
          return {'id': e['id'], 'data': Map<String, dynamic>.from(e['data'])};
        }).toList();
      });
    }

    // 🟢 2. FETCH FROM FIRESTORE (fresh data)
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('public_discussions')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (_selectedCategory != 'All') {
      query = query.where('category.primary', isEqualTo: _selectedCategory);
    }

    final snap = await query.get();

    if (snap.docs.isNotEmpty) {
      _lastDoc = snap.docs.last;
      _posts = snap.docs.map((d) {
        return {'id': d.id, 'data': d.data()};
      }).toList();
    }

    if (snap.docs.length < _pageSize) {
      _hasMore = false;
    }

    // 🟢 3. SAVE TO HIVE
    await _cacheBox.put(_cacheKey(), _posts);

    setState(() {});
  }

  Future<void> _loadMorePosts() async {
    if (_lastDoc == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('public_discussions')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(_lastDoc!)
        .limit(_pageSize);

    if (_selectedCategory != 'All') {
      query = query.where('category.primary', isEqualTo: _selectedCategory);
    }

    final snap = await query.get();

    if (snap.docs.isNotEmpty) {
      _lastDoc = snap.docs.last;

      _posts.addAll(
        snap.docs.map((d) {
          return {'id': d.id, 'data': d.data()};
        }),
      );
    }

    if (snap.docs.length < _pageSize) {
      _hasMore = false;
    }

    // Update cache with combined list
    await _cacheBox.put(_cacheKey(), _posts);

    setState(() {
      _isLoadingMore = false;
    });
  }

  Future<void> _onRefresh() async {
    await _cacheBox.delete(_cacheKey());
    await _loadInitialPosts();
  }

  Widget _buildPaginatedFeed() {
    if (_posts.isEmpty && _isLoadingMore) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_kAccentColor),
        ),
      );
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: _kAccentColor,
      backgroundColor: _kCardColor,
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _feedScrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_kAccentColor),
                ),
              ),
            );
          }

          final post = _posts[index];
          final data = post['data'] as Map<String, dynamic>;
          final docId = post['id'] as String;

          // 🔍 search filter
          final question = (data['question']?['text'] ?? '')
              .toString()
              .toLowerCase();
          final answer = (data['answer']?['text'] ?? '')
              .toString()
              .toLowerCase();
          final category = (data['category']?['primary'] ?? '')
              .toString()
              .toLowerCase();

          if (_searchQuery.isNotEmpty &&
              !question.contains(_searchQuery) &&
              !answer.contains(_searchQuery) &&
              !category.contains(_searchQuery)) {
            return const SizedBox.shrink();
          }

          return _DiscussionCard(
            data: data,
            docId: docId,
            onTap: () => _openDiscussionDetail(context, data, docId),
          );
        },
      ),
    );
  }

  Widget _buildDiscussionFeed() {
    final userId = 'TEMP_USER_ID'; // replace with FirebaseAuth uid

    // -------- ALL DISCUSSIONS --------
    if (_feedMode == CommunityFeedMode.all) {
      return _buildPaginatedFeed();
    }

    // -------- MY LIKES --------
    if (_feedMode == CommunityFeedMode.myLikes) {
      return _buildUserIndexedFeed(
        collectionPath: 'users/$userId/liked_discussions',
        selectedCategory: _selectedCategory,
      );
    }

    // -------- MY BOOKMARKS --------
    return _buildUserIndexedFeed(
      collectionPath: 'users/$userId/bookmarked_discussions',
      selectedCategory: _selectedCategory,
    );
  }

  Widget _buildUserIndexedFeed({
    required String collectionPath,
    required String selectedCategory,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionPath)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // ⏳ loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_kAccentColor),
            ),
          );
        }

        // ❌ error
        if (snapshot.hasError) {
          return _buildErrorState();
        }

        final ids = snapshot.data?.docs.map((d) => d.id).toList() ?? [];

        if (ids.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ids.length,
          itemBuilder: (context, index) {
            final docId = ids[index];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('public_discussions')
                  .doc(docId)
                  .get(),
              builder: (context, snap) {
                // ❌ error on single document
                if (snap.hasError) {
                  return _buildErrorState();
                }

                if (!snap.hasData || !snap.data!.exists) {
                  return const SizedBox.shrink();
                }

                final data = snap.data!.data() as Map<String, dynamic>;

                final question = (data['question']?['text'] ?? '')
                    .toString()
                    .toLowerCase();
                final answer = (data['answer']?['text'] ?? '')
                    .toString()
                    .toLowerCase();
                final category = (data['category']?['primary'] ?? 'General')
                    .toString()
                    .toLowerCase();

                // 🔍 SEARCH FILTER
                if (_searchQuery.isNotEmpty &&
                    !question.contains(_searchQuery) &&
                    !answer.contains(_searchQuery) &&
                    !category.contains(_searchQuery)) {
                  return const SizedBox.shrink();
                }

                // 🏷 CATEGORY FILTER
                if (selectedCategory != 'All' &&
                    category != selectedCategory.toLowerCase()) {
                  return const SizedBox.shrink();
                }

                return _DiscussionCard(
                  data: data,
                  docId: docId,
                  onTap: () => _openDiscussionDetail(context, data, docId),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Community Discussions',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: _kPrimaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showFilterOptions(context),
            tooltip: 'More options',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                    _loadInitialPosts(); // 🔥 REQUIRED
                  },

                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search discussions...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: _kAccentColor),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _kBorderColor, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: _kAccentColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Category Filter
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('categories')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(height: 36);
                    }

                    final categories = snapshot.data!.docs;

                    final all = [
                      {'name': 'All', 'count': null},
                      ...categories.map(
                        (d) => {'name': d.id, 'count': d['postCount'] ?? 0},
                      ),
                    ];

                    return _buildCategoryFilter(all);
                  },
                ),
              ],
            ),
          ),

          // Discussions List
          Expanded(child: _buildDiscussionFeed()),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(List<Map<String, dynamic>> categories) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        controller: _categoryScrollCtrl,
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final name = categories[index]['name'] as String;
          final count = categories[index]['count'] as int?;
          final isSelected = _selectedCategory == name;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                count == null ? name : '$name ($count)',
                style: TextStyle(
                  color: isSelected ? _kPrimaryColor : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => _onCategorySelected(name, index),
              backgroundColor: const Color.fromARGB(255, 34, 74, 74),
              selectedColor: _kAccentColor,
              side: BorderSide(
                color: isSelected ? _kAccentColor : _kBorderColor,
              ),
            ),
          );
        },
      ),
    );
  }

  void _onCategorySelected(String category, int index) {
    setState(() {
      _selectedCategory = category;
    });
    _loadInitialPosts(); // 🔥 VERY IMPORTANT

    // 🎯 Smooth scroll so selected chip stays visible
    _categoryScrollCtrl.animateTo(
      index * 90.0 - MediaQuery.of(context).size.width / 2 + 45,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No discussions found'
                : 'No discussions yet',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'Be the first to start a discussion!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error loading discussions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentColor,
              foregroundColor: _kPrimaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort & Filter',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // -------- Normal feeds --------
            ListTile(
              leading: const Icon(Icons.access_time, color: _kAccentColor),
              title: const Text(
                'All Discussions',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                setState(() {
                  _feedMode = CommunityFeedMode.all;
                  _selectedCategory = 'All'; // ✅ IMPORTANT
                });
                Navigator.pop(context);
              },
            ),

            const Divider(color: Colors.white12),

            // -------- My activity --------
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.redAccent),
              title: const Text(
                'My Likes',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                setState(() {
                  _feedMode = CommunityFeedMode.myLikes;
                  _selectedCategory = 'All';
                });

                _loadInitialPosts();

                _selectedCategory = 'All';
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark, color: _kAccentColor),
              title: const Text(
                'My Bookmarks',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                setState(() => _feedMode = CommunityFeedMode.myBookmarks);
                _selectedCategory = 'All';
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openDiscussionDetail(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    FirebaseFirestore.instance.collection('public_discussions').doc(docId).set({
      'stats': {'views': FieldValue.increment(1)},
    }, SetOptions(merge: true));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiscussionDetailPage(data: data, docId: docId),
      ),
    );
  }
}

class _DiscussionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onTap;

  const _DiscussionCard({
    required this.data,
    required this.docId,
    required this.onTap,
  });
  Future<void> toggleLike(String docId, String userId) async {
    final discussionRef = FirebaseFirestore.instance
        .collection('public_discussions')
        .doc(docId);

    final likeRef = discussionRef.collection('likes').doc(userId);
    final userLikeRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('liked_discussions')
        .doc(docId);

    final snap = await likeRef.get();

    if (snap.exists) {
      // Unlike
      await likeRef.delete();
      await userLikeRef.delete();
      await discussionRef.set({
        'stats': {'likes': FieldValue.increment(-1)},
      }, SetOptions(merge: true));
    } else {
      // Like
      await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      await userLikeRef.set({'createdAt': FieldValue.serverTimestamp()});
      await discussionRef.set({
        'stats': {'likes': FieldValue.increment(1)},
      }, SetOptions(merge: true));
    }
  }

  Future<void> toggleBookmark(String docId, String userId) async {
    final bookmarkRef = FirebaseFirestore.instance
        .collection('public_discussions')
        .doc(docId)
        .collection('bookmarks')
        .doc(userId);

    final userBookmarkRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bookmarked_discussions')
        .doc(docId);

    final snap = await bookmarkRef.get();

    if (snap.exists) {
      await bookmarkRef.delete();
      await userBookmarkRef.delete();
    } else {
      await bookmarkRef.set({'savedAt': FieldValue.serverTimestamp()});
      await userBookmarkRef.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }

  void shareDiscussion(Map<String, dynamic> data) {
    final question = data['question']?['text'] ?? '';
    final answer = data['answer']?['text'] ?? '';

    final text =
        '''
Q: $question

Doctor’s Answer:
${answer.length > 300 ? answer.substring(0, 300) + '...' : answer}

Read more in DRKTV CBT App
''';

    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final question = (data['question']?['text'] ?? '').toString();
    final answer = (data['answer']?['text'] ?? '').toString();
    final category = (data['category']?['primary'] ?? 'General').toString();
    final views = (data['stats']?['views'] ?? 0) as int;

    final timestamp = data['createdAt'] as Timestamp?;
    final userId = 'TEMP_USER_ID'; // replace with FirebaseAuth uid

    return Hero(
      tag: 'discussion_$docId',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with category and time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _kAccentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _kAccentColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: _kAccentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (timestamp != null)
                      Text(
                        timeago.format(timestamp.toDate()),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Question
                Text(
                  question,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                // Answer preview
                Text(
                  answer,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 14),

                // Footer with engagement metrics
                Row(
                  children: [
                    _buildMetric(Icons.visibility_outlined, views),
                    const SizedBox(width: 16),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('public_discussions')
                          .doc(docId)
                          .snapshots(),
                      builder: (context, discussionSnap) {
                        if (!discussionSnap.hasData) {
                          return const SizedBox.shrink();
                        }

                        final data = discussionSnap.data!.data();
                        final likes = (data?['stats']?['likes'] ?? 0) as int;

                        return _LikeButton(
                          docId: docId,
                          userId: userId,
                          likes: likes,
                          onToggle: toggleLike,
                        );
                      },
                    ),

                    const SizedBox(width: 16),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('public_discussions')
                          .doc(docId)
                          .collection('bookmarks')
                          .doc(userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final saved = snapshot.data?.exists ?? false;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => toggleBookmark(docId, userId),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: saved
                                    ? _kAccentColor.withOpacity(0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: saved
                                    ? Border.all(
                                        color: _kAccentColor.withOpacity(0.3),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Icon(
                                saved ? Icons.bookmark : Icons.bookmark_border,
                                color: saved ? _kAccentColor : Colors.white60,
                                size: 24,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Share button with enhanced design
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => shareDiscussion(data),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.share_outlined,
                            size: 24,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.5)),
        const SizedBox(width: 6),
        Text(
          _formatCount(count),
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

// Placeholder for detail page
class DiscussionDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const DiscussionDetailPage({
    super.key,
    required this.data,
    required this.docId,
  });

  Future<void> toggleLike(String docId, String userId) async {
    final discussionRef = FirebaseFirestore.instance
        .collection('public_discussions')
        .doc(docId);

    final likeRef = discussionRef.collection('likes').doc(userId);
    final userLikeRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('liked_discussions')
        .doc(docId);

    final snap = await likeRef.get();

    if (snap.exists) {
      // Unlike
      await likeRef.delete();
      await userLikeRef.delete();
      await discussionRef.set({
        'stats': {'likes': FieldValue.increment(-1)},
      }, SetOptions(merge: true));
    } else {
      // Like
      await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      await userLikeRef.set({'createdAt': FieldValue.serverTimestamp()});
      await discussionRef.set({
        'stats': {'likes': FieldValue.increment(1)},
      }, SetOptions(merge: true));
    }
  }

  Future<void> toggleBookmark(String docId, String userId) async {
    final bookmarkRef = FirebaseFirestore.instance
        .collection('public_discussions')
        .doc(docId)
        .collection('bookmarks')
        .doc(userId);

    final userBookmarkRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('bookmarked_discussions')
        .doc(docId);

    final snap = await bookmarkRef.get();

    if (snap.exists) {
      await bookmarkRef.delete();
      await userBookmarkRef.delete();
    } else {
      await bookmarkRef.set({'savedAt': FieldValue.serverTimestamp()});
      await userBookmarkRef.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }

  void shareDiscussion(Map<String, dynamic> data) {
    final question = data['question']?['text'] ?? '';
    final answer = data['answer']?['text'] ?? '';

    final text =
        '''
Q: $question

Doctor’s Answer:
${answer.length > 300 ? answer.substring(0, 300) + '...' : answer}

Read more in DRKTV CBT App
''';

    Share.share(text);
  }

  List<TextSpan> buildHighlightedText({
    required String text,
    required TextStyle normalStyle,
    required TextStyle highlightStyle,
  }) {
    final List<TextSpan> spans = [];
    final regex = RegExp(r'\*\*(.*?)\*\*');

    int currentIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: normalStyle,
          ),
        );
      }

      spans.add(TextSpan(text: match.group(1), style: highlightStyle));

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(text: text.substring(currentIndex), style: normalStyle),
      );
    }

    return spans;
  }

  List<ToolLink> detectRelevantTools(String answer) {
    final lowerText = answer.toLowerCase();

    return mentalHealthTools.where((tool) {
      return tool.keywords.any((k) => lowerText.contains(k.toLowerCase()));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final question = (data['question']?['text'] ?? '').toString();
    final answer = (data['answer']?['text'] ?? '').toString();
    final category = (data['category']?['primary'] ?? 'General').toString();
    final createdAt = data['createdAt'] as Timestamp?;
    final userId = 'TEMP_USER_ID'; // replace with FirebaseAuth uid
    final views = (data['stats']?['views'] ?? 0) as int;
    final relevantTools = detectRelevantTools(answer);

    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        backgroundColor: _kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Community Q&A',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge with enhanced styling
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _kAccentColor.withOpacity(0.2),
                            _kAccentColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _kAccentColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label, size: 14, color: _kAccentColor),
                          const SizedBox(width: 6),
                          Text(
                            category,
                            style: const TextStyle(
                              color: _kAccentColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (createdAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeago.format(createdAt.toDate()),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // Question Section with enhanced design
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color.fromARGB(255, 0, 24, 23),
                        _kCardColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _kAccentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.help_outline,
                              color: _kAccentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Question',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        question,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Answer Section with enhanced design
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color.fromARGB(255, 0, 20, 18),
                        const Color.fromARGB(255, 0, 20, 18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _kAccentColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kAccentColor.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _kAccentColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _kAccentColor.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.medical_services,
                              color: _kAccentColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Doctor Answer',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _kAccentColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Dr. Kanhaiya',
                              style: TextStyle(
                                color: _kAccentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      RichText(
                        text: TextSpan(
                          children: buildHighlightedText(
                            text: answer,
                            normalStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.7,
                              letterSpacing: 0.2,
                            ),
                            highlightStyle: const TextStyle(
                              color: _kAccentColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ),
                      if (relevantTools.isNotEmpty) ...[
                        const SizedBox(height: 16),

                        Text(
                          'Recommended Tools',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: relevantTools.map((tool) {
                            return InkWell(
                              onTap: () {
                                Navigator.pushNamed(context, tool.route);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _kAccentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _kAccentColor.withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      tool.icon,
                                      size: 18,
                                      color: _kAccentColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      tool.title,
                                      style: const TextStyle(
                                        color: _kAccentColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // View count card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorderColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$views people viewed this discussion',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating action bar at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _kBackgroundColor.withOpacity(0),
                    _kBackgroundColor.withOpacity(0.95),
                    _kBackgroundColor,
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: _kCardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kBorderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Like toggle with enhanced design
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('public_discussions')
                          .doc(docId)
                          .snapshots(),
                      builder: (context, discussionSnap) {
                        if (!discussionSnap.hasData) {
                          return const SizedBox.shrink();
                        }

                        final data = discussionSnap.data!.data();
                        final likes = (data?['stats']?['likes'] ?? 0) as int;

                        return _LikeButton(
                          docId: docId,
                          userId: userId,
                          likes: likes,
                          onToggle: toggleLike,
                        );
                      },
                    ),

                    // Bookmark toggle with enhanced design
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('public_discussions')
                          .doc(docId)
                          .collection('bookmarks')
                          .doc(userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final saved = snapshot.data?.exists ?? false;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => toggleBookmark(docId, userId),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: saved
                                    ? _kAccentColor.withOpacity(0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: saved
                                    ? Border.all(
                                        color: _kAccentColor.withOpacity(0.3),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Icon(
                                saved ? Icons.bookmark : Icons.bookmark_border,
                                color: saved ? _kAccentColor : Colors.white60,
                                size: 24,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Share button with enhanced design
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => shareDiscussion(data),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.share_outlined,
                            size: 24,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final String docId;
  final String userId;
  final int likes;
  final Function(String, String) onToggle;

  const _LikeButton({
    required this.docId,
    required this.userId,
    required this.likes,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('public_discussions')
          .doc(docId)
          .collection('likes')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final liked = snapshot.data?.exists ?? false;

        return InkWell(
          onTap: () => onToggle(docId, userId),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: liked
                  ? Colors.redAccent.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: liked
                  ? Border.all(
                      color: Colors.redAccent.withOpacity(0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? Colors.redAccent : Colors.white60,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatCount(likes),
                  style: TextStyle(
                    color: liked ? Colors.redAccent : Colors.white60,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
