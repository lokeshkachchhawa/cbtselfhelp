import 'package:flutter/material.dart';
import '../data/community_loader.dart';
import '../models/community_post.dart';
import '../widgets/post_card.dart';
import '../widgets/category_chips.dart';
import 'ask_community_page.dart';

/// Reuse Home theme colors
const Color teal1 = Color.fromARGB(255, 1, 108, 108);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color pageBg = Color(0xFF021515);

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String _selectedCategory = 'all';
  late Future<List<CommunityPost>> _postsFuture;

  final ScrollController _scrollController = ScrollController();
  bool _showNewPostsBanner = false;

  @override
  void initState() {
    super.initState();
    _postsFuture = CommunityLoader.loadPosts();
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _postsFuture = CommunityLoader.loadPosts();
      _showNewPostsBanner = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              teal1,
              Color.fromARGB(255, 3, 3, 3),
              Color.fromARGB(255, 9, 36, 29),
              teal4,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),

              const _CommunitySafetyBanner(),

              CategoryChips(
                selected: _selectedCategory,
                onSelected: (id) {
                  setState(() => _selectedCategory = id);
                },
              ),

              _buildNewPostsBanner(),

              Expanded(
                child: RefreshIndicator(
                  color: teal3,
                  onRefresh: _refresh,
                  child: FutureBuilder<List<CommunityPost>>(
                    future: _postsFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: teal3),
                        );
                      }

                      final posts = snapshot.data!
                          .where(
                            (p) =>
                                _selectedCategory == 'all' ||
                                p.category == _selectedCategory,
                          )
                          .toList();

                      if (posts.isEmpty) {
                        return const Center(
                          child: Text(
                            'No posts yet.\nBe the first to share 🌱',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: posts.length,
                        itemBuilder: (_, i) => PostCard(post: posts[i]),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: teal3,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text(
          'Ask Community',
          style: TextStyle(color: Colors.white),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AskCommunityPage()),
          );
        },
      ),
    );
  }

  // ---------------- UI PARTS ----------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.forum, color: Colors.white),
          const SizedBox(width: 10),
          const Text(
            'Community',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            onPressed: _showCommunityInfo,
          ),
        ],
      ),
    );
  }

  Widget _buildNewPostsBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      child: _showNewPostsBanner
          ? GestureDetector(
              key: const ValueKey('new_posts'),
              onTap: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
                setState(() => _showNewPostsBanner = false);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: teal3,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'New posts available · Tap to refresh',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  void _showCommunityInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'About Community',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'This space is for sharing experiences and support.\n\n'
                '⚠️ This is not a substitute for professional mental health care.\n'
                'If you feel unsafe or in crisis, please use the Get Help option.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ---------------- SAFETY BANNER ----------------

class _CommunitySafetyBanner extends StatelessWidget {
  const _CommunitySafetyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Text(
        'This community offers peer support only. '
        'Please avoid medical advice. In emergencies, seek professional help.',
        style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}
