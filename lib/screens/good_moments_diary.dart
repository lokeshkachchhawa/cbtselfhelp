// good_moments_diary.dart
import 'dart:convert';
import 'package:cbt_drktv/screens/good_moment_tutorial_sheet.dart';
import 'package:cbt_drktv/screens/thought_record_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// -------------------- THEME --------------------

class AppTheme {
  static const Color teal1 = Color(0xFFC6EDED);
  static const Color teal2 = Color(0xFF79C2BF);
  static const Color teal3 = Color(0xFF008F89);
  static const Color teal4 = Color(0xFF007A78);
  static const Color teal5 = Color(0xFF005E5C);
  static const Color teal6 = Color(0xFF004E4D);

  static const Color surfaceDark = Color(0xFF071617);
  static const Color cardDark = Color(0xFF072726);
  static const Color mutedText = Color(0xFFBFDCDC);
  static const Color dimText = Color(0xFFA3CFCB);

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: surfaceDark,
    colorScheme: const ColorScheme.dark(
      primary: teal3,
      secondary: teal4,
      surface: cardDark,
    ),
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      elevation: 0,
    ),
  );
}

/// -------------------- CONSTANTS --------------------

const _kStorageKey = 'good_moments_v2';
const _kOnboardingKey = 'onboarding_complete_v1';
final _uuid = const Uuid();
final _picker = ImagePicker();

/// -------------------- DOMAIN MODEL --------------------

class GoodMoment {
  final String id;
  final String feeling;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> tags;
  final List<String> imagePaths;

  GoodMoment({
    required this.id,
    required this.feeling,
    required this.text,
    required this.createdAt,
    this.updatedAt,
    this.tags = const [],
    this.imagePaths = const [],
  });

  GoodMoment copyWith({
    String? feeling,
    String? text,
    DateTime? updatedAt,
    List<String>? tags,
    List<String>? imagePaths,
  }) {
    return GoodMoment(
      id: id,
      feeling: feeling ?? this.feeling,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      imagePaths: imagePaths ?? this.imagePaths, // ✅ FIX
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'feeling': feeling,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'tags': tags,
    'imagePaths': imagePaths,
  };

  static GoodMoment fromMap(Map<String, dynamic> m) {
    return GoodMoment(
      id: m['id'],
      feeling: m['feeling'],
      text: m['text'],
      createdAt: DateTime.parse(m['createdAt']),
      updatedAt: m['updatedAt'] != null ? DateTime.parse(m['updatedAt']) : null,
      tags: List<String>.from(m['tags'] ?? []),
      imagePaths: List<String>.from(m['imagePaths'] ?? []),
    );
  }
}

/// -------------------- REPOSITORY --------------------

class GoodMomentsRepository {
  static final GoodMomentsRepository _instance = GoodMomentsRepository._();
  factory GoodMomentsRepository() => _instance;
  GoodMomentsRepository._();

  SharedPreferences? _prefs;
  List<GoodMoment>? _cache;

  Future<void> _ensureInit() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<GoodMoment>> loadAll() async {
    if (_cache != null) return List.from(_cache!);

    await _ensureInit();
    final raw = _prefs!.getString(_kStorageKey);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      return [];
    }

    try {
      final list = json.decode(raw) as List;
      _cache = list
          .map((e) => GoodMoment.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      return List.from(_cache!);
    } catch (e) {
      debugPrint('Error loading moments: $e');
      _cache = [];
      return [];
    }
  }

  Future<void> saveAll(List<GoodMoment> items) async {
    await _ensureInit();
    _cache = List.from(items);
    await _prefs!.setString(
      _kStorageKey,
      json.encode(items.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> add(GoodMoment item) async {
    final all = await loadAll();
    all.insert(0, item);
    await saveAll(all);
  }

  Future<void> update(GoodMoment item) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == item.id);
    if (idx != -1) {
      all[idx] = item;
      await saveAll(all);
    }
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await saveAll(all);
  }

  Future<bool> hasCompletedOnboarding() async {
    await _ensureInit();
    return _prefs!.getBool(_kOnboardingKey) ?? false;
  }

  Future<void> setOnboardingComplete() async {
    await _ensureInit();
    await _prefs!.setBool(_kOnboardingKey, true);
  }

  void clearCache() {
    _cache = null;
  }
}

/// -------------------- ONBOARDING --------------------

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;

  final _pages = const [
    OnboardingContent(
      icon: Icons.self_improvement,
      title: 'Capture Good Moments',
      description:
          'Write down the small moments that make you feel calm, safe, and happy.',
    ),
    OnboardingContent(
      icon: Icons.favorite,
      title: 'Build Your Collection',
      description:
          'Create a personal library of positive memories to revisit anytime.',
    ),
    OnboardingContent(
      icon: Icons.psychology,
      title: 'Find Peace When Needed',
      description:
          'During anxious times, read your moments to ground yourself in whats good.',
    ),
  ];

  void _complete() async {
    await GoodMomentsRepository().setOnboardingComplete();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GoodMomentsDiaryPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppTheme.teal3
                              : AppTheme.teal6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _currentPage == _pages.length - 1
                        ? _complete
                        : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.teal4,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_currentPage < _pages.length - 1)
                    TextButton(onPressed: _complete, child: const Text('Skip')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const OnboardingContent({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.teal3.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(icon, size: 80, color: AppTheme.teal2),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.mutedText,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// -------------------- MAIN PAGE --------------------

class GoodMomentsDiaryPage extends StatefulWidget {
  const GoodMomentsDiaryPage({super.key});

  @override
  State<GoodMomentsDiaryPage> createState() => _GoodMomentsDiaryPageState();
}

class _GoodMomentsDiaryPageState extends State<GoodMomentsDiaryPage> {
  final _repo = GoodMomentsRepository();
  bool _loading = true;
  List<GoodMoment> _items = [];
  String _filter = 'All';

  final _feelings = const [
    '😌 Calm',
    '🛡️ Safe',
    '😌 Relaxed',
    '😊 Happy',
    '🕊️ Peaceful',
    '🙏 Grateful',
    '❤️ Loved',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.loadAll();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  List<GoodMoment> get _filteredItems {
    if (_filter == 'All') return _items;
    return _items.where((m) => m.feeling == _filter).toList();
  }

  void _openAddSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddMomentSheet(),
    );
    if (result == true) _load();
  }

  void _openDetailSheet(GoodMoment moment) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MomentDetailSheet(moment: moment),
    );
    if (result == true) _load();
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: const Border(top: BorderSide(color: Colors.white10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Drag handle
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.teal3.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.filter_alt_rounded,
                            color: AppTheme.teal1,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Filter by Feeling',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: Colors.white10, height: 1),
                  ),

                  const SizedBox(height: 12),

                  /// 🔑 FILTER LIST WITH COUNTS
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          ...['All', ..._feelings].map((f) {
                            final selected = _filter == f;

                            // ✅ COUNT LOGIC
                            final int count = f == 'All'
                                ? _items.length
                                : _items.where((m) => m.feeling == f).length;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() => _filter = f);
                                  Navigator.pop(ctx);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppTheme.teal3.withOpacity(0.18)
                                        : AppTheme.cardDark,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? AppTheme.teal3
                                          : Colors.white10,
                                      width: selected ? 1.5 : 1,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.teal3.withOpacity(
                                                0.25,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      // Check icon
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppTheme.teal3
                                              : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selected
                                                ? AppTheme.teal3
                                                : Colors.white38,
                                          ),
                                        ),
                                        child: selected
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.black,
                                              )
                                            : null,
                                      ),

                                      const SizedBox(width: 14),

                                      // Feeling text
                                      Expanded(
                                        child: Text(
                                          f,
                                          style: TextStyle(
                                            color: selected
                                                ? AppTheme.teal1
                                                : Colors.white70,
                                            fontSize: 15,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),

                                      // 🔢 COUNT BADGE
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppTheme.teal3.withOpacity(0.25)
                                              : Colors.black26,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? AppTheme.teal3
                                                : Colors.white12,
                                          ),
                                        ),
                                        child: Text(
                                          count.toString(),
                                          style: TextStyle(
                                            color: selected
                                                ? AppTheme.teal1
                                                : Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      appBar: AppBar(
        title: const Text(
          'Good Moments',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.teal6, AppTheme.teal4],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // HELP / TUTORIAL ICON (always visible)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: const Icon(Icons.help_outline_rounded, size: 22),
              tooltip: 'How this works',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const GoodMomentTutorialSheet(),
                );
              },
            ),
          ),

          // FILTER ICON (only when items exist)
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 22),
                    if (_filter != 'All')
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: 'Filter moments',
                onPressed: _showFilterOptions,
              ),
            ),
        ],
      ),
      floatingActionButton: GlowPulse(
        color: AppTheme.teal2, // soft calming glow
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.teal3, AppTheme.teal2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppTheme.teal2.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Moment',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                if (_filter != 'All')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppTheme.cardDark,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.filter_alt,
                          size: 16,
                          color: AppTheme.teal2,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Showing $_filter moments',
                          style: const TextStyle(
                            color: AppTheme.teal2,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _filter = 'All'),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.search_off,
                                size: 48,
                                color: AppTheme.dimText,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No $_filter moments yet',
                                style: const TextStyle(
                                  color: AppTheme.mutedText,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildMomentCard(filtered[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.teal3.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.self_improvement,
                size: 64,
                color: AppTheme.teal2,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your moment collection awaits',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Capture the small moments that make you feel good. Build your personal library of calm.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.dimText,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _openAddSheet,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Your First Moment'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.teal2,
                side: const BorderSide(color: AppTheme.teal3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMomentCard(GoodMoment m) {
    final now = DateTime.now();
    final diff = now.difference(m.createdAt);

    String timeAgo;
    if (diff.inDays > 0) {
      timeAgo = '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      timeAgo = '${diff.inHours}h ago';
    } else {
      timeAgo = 'Just now';
    }
    String _formatDate(DateTime d) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    }

    return Card(
      color: AppTheme.cardDark,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetailSheet(m),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🟢 HEADER (FEELING + TIME)
              Row(
                children: [
                  buildGlowingCategoryPill(m.feeling),

                  const Spacer(),
                  const Icon(
                    Icons.favorite,
                    color: Colors.pinkAccent,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      color: AppTheme.dimText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              /// 🖼️ IMAGE STRIP (ONLY IF EXISTS)
              if (m.imagePaths.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: m.imagePaths.length,
                    itemBuilder: (_, i) {
                      return Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(m.imagePaths[i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 12),

              /// 📝 TEXT PREVIEW (2 LINES)
              Text(
                m.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 8),

              /// 📅 DATE
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: AppTheme.dimText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(m.createdAt),
                    style: const TextStyle(
                      color: AppTheme.dimText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------- ADD MOMENT SHEET --------------------

class AddMomentSheet extends StatefulWidget {
  const AddMomentSheet({super.key});

  @override
  State<AddMomentSheet> createState() => _AddMomentSheetState();
}

class _AddMomentSheetState extends State<AddMomentSheet> {
  final _repo = GoodMomentsRepository();
  final _textCtrl = TextEditingController();
  String _selectedFeeling = 'Calm';
  bool _saving = false;
  List<File> _selectedImages = [];

  final _feelings = const [
    '😌 Calm',
    '🛡️ Safe',
    '😌 Relaxed',
    '😊 Happy',
    '🕊️ Peaceful',
    '🙏 Grateful',
    '❤️ Loved',
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please write something')));
      return;
    }

    setState(() => _saving = true);

    try {
      await _repo.add(
        GoodMoment(
          id: _uuid.v4(),
          feeling: _selectedFeeling,
          text: text,
          createdAt: DateTime.now(),
          imagePaths: _selectedImages.map((e) => e.path).toList(),
        ),
      );
      _selectedImages.clear(); // reset for next entry
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moment saved ✨'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pickFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked == null) return;

    await _savePickedImages([picked]);
  }

  Future<void> _pickFromGalleryMulti() async {
    final pickedImages = await _picker.pickMultiImage(imageQuality: 80);
    if (pickedImages.isEmpty) return;

    await _savePickedImages(pickedImages);
  }

  Future<void> _savePickedImages(List<XFile> pickedImages) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/good_moments');

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    for (final picked in pickedImages) {
      final fileName =
          'img_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';

      final saved = await File(picked.path).copy('${imagesDir.path}/$fileName');

      setState(() => _selectedImages.add(saved));
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      color: AppTheme.teal1,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Add Photos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Camera Option
                    _ImageSourceOption(
                      icon: Icons.photo_camera_rounded,
                      iconColor: AppTheme.teal2,
                      backgroundColor: AppTheme.teal3.withOpacity(0.15),
                      title: 'Take Photo',
                      subtitle: 'Use your camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromCamera();
                      },
                    ),

                    const SizedBox(height: 12),

                    // Gallery Option
                    _ImageSourceOption(
                      icon: Icons.photo_library_rounded,
                      iconColor: const Color(0xFF9C27B0),
                      backgroundColor: const Color(
                        0xFF9C27B0,
                      ).withOpacity(0.15),
                      title: 'Choose from Gallery',
                      subtitle: 'Select multiple photos',
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromGalleryMulti();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Cancel Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom Option Widget

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: const Border(top: BorderSide(color: Colors.white10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Drag Handle
            Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            // Header Section
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.teal3.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Capture a Good Moment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'What made you feel good today?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.dimText,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// ================= FEELING SECTION =================
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.sentiment_satisfied_alt,
                                  size: 16,
                                  color: AppTheme.teal1,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'How are you feeling?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: _feelings.map((f) {
                                final active = _selectedFeeling == f;
                                return ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_getFeelingEmoji(f)),
                                      const SizedBox(width: 4),
                                      Text(f),
                                    ],
                                  ),
                                  selected: active,
                                  selectedColor: AppTheme.teal3,
                                  backgroundColor: AppTheme.cardDark,
                                  side: BorderSide(
                                    color: active
                                        ? AppTheme.teal3
                                        : Colors.white10,
                                    width: active ? 1.5 : 1,
                                  ),
                                  labelStyle: TextStyle(
                                    color: active
                                        ? Colors.black
                                        : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _selectedFeeling = f),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// ================= IMAGE SECTION =================
                    // ================= IMAGE SECTION =================
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: AppTheme.teal1,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Add photos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          Text(
                            'Optional',
                            style: TextStyle(
                              color: AppTheme.dimText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      height: 110,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // ➕ ADD IMAGE BUTTON
                          GestureDetector(
                            onTap: _showImageSourcePicker,
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.cardDark,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.teal3.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.teal3.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add_a_photo_rounded,
                                      color: AppTheme.teal1,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Add Photo',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 🖼️ SELECTED IMAGES WITH NUMBERING
                          ..._selectedImages.asMap().entries.map((entry) {
                            final index = entry.key;
                            final file = entry.value;

                            return Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 10),
                              child: Stack(
                                children: [
                                  // IMAGE
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppTheme.teal3.withOpacity(
                                            0.3,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Image.file(
                                        file,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    ),
                                  ),

                                  // ❌ REMOVE BUTTON
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setState(
                                            () =>
                                                _selectedImages.removeAt(index),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white24,
                                              width: 1,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 🔢 NUMBER BADGE
                                  Positioned(
                                    bottom: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // =================================================

                    /// ================= TEXT SECTION =================
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 16,
                                  color: AppTheme.teal1,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Describe your moment',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _textCtrl,
                              minLines: 4,
                              maxLines: null,
                              maxLength: 500,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'What happened? How did it make you feel?\n\nDescribe the details that made this moment special...',
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                  height: 1.4,
                                ),
                                filled: true,
                                fillColor: AppTheme.cardDark,
                                counterStyle: const TextStyle(
                                  color: AppTheme.dimText,
                                  fontSize: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Colors.white10,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Colors.white10,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppTheme.teal3,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Save Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 0.5),
                ),
              ),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teal4,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor: AppTheme.teal6,
                  elevation: 0,
                  shadowColor: AppTheme.teal3.withOpacity(0.3),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Save Moment',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get feeling emoji
  String _getFeelingEmoji(String feeling) {
    switch (feeling.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'excited':
        return '🎉';
      case 'grateful':
        return '🙏';
      case 'proud':
        return '💪';
      case 'calm':
        return '😌';
      case 'loved':
        return '❤️';
      case 'peaceful':
        return '🕊️';
      case 'joyful':
        return '😄';
      default:
        return '✨';
    }
  }
}

/// -------------------- MOMENT DETAIL SHEET --------------------

class MomentDetailSheet extends StatelessWidget {
  final GoodMoment moment;

  const MomentDetailSheet({super.key, required this.moment});

  Future<void> _delete(BuildContext context) async {
    await GoodMomentsRepository().delete(moment.id);

    if (context.mounted) {
      Navigator.pop(context, true); // ✅ closes bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Moment deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: moment.text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header with Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Feeling Badge
                    buildGlowingCategoryPill(moment.feeling),
                    const Spacer(),

                    // Action Buttons with Tooltips
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _copy(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.copy_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showDeleteConfirmation(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Content Area with Better Spacing
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Gallery with Page Indicator
                      if (moment.imagePaths.isNotEmpty) ...[
                        _buildImageGallery(context),
                        const SizedBox(height: 20),
                      ],

                      // Text Content with Better Typography
                      SelectableText(
                        moment.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.6,
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Enhanced Footer
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white10, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.pinkAccent,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDate(moment.createdAt),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatTime(moment.createdAt),
                            style: const TextStyle(
                              color: AppTheme.dimText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.teal1,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
    );
  }

  // Enhanced Image Gallery with Page Indicator
  Widget _buildImageGallery(BuildContext context) {
    final pageController = PageController();
    final currentPage = ValueNotifier<int>(0);

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: pageController,
            onPageChanged: (index) => currentPage.value = index,
            itemCount: moment.imagePaths.length,
            itemBuilder: (_, i) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullscreenImageViewer(
                        images: moment.imagePaths,
                        initialIndex: i,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Hero(
                    tag: 'moment_image_$i',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(moment.imagePaths[i]),
                            fit: BoxFit.cover,
                          ),
                          // Gradient Overlay for Better Readability
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Tap to Expand Indicator
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Page Indicator
        if (moment.imagePaths.length > 1) ...[
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: currentPage,
            builder: (context, page, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  moment.imagePaths.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: page == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: page == index ? AppTheme.teal1 : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // Delete Confirmation Dialog
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Moment?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This action cannot be undone. Are you sure you want to delete this moment?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _delete(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Helper method to get feeling icon

  // Format time separately
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class FullscreenImageViewer extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: images.length,
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              child: Center(child: Image.file(File(images[i]))),
            ),
          );
        },
      ),
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImageSourceOption({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.dimText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white24,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildGlowingCategoryPill(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),

      // 🌈 Gradient background
      gradient: const LinearGradient(
        colors: [
          Color(0xFFFF5F6D), // soft pink-red
          Color(0xFFFF2E63), // deep rose
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),

      // ✨ Glow effect
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF5F6D).withOpacity(0.55),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // optional small dot
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),

        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );
}
