// lib/screens/course_detail_page.dart
// Local-only course detail / player (SharedPreferences + asset fallback)

import 'dart:convert';

import 'package:cbt_drktv/widgets/tutorial_video_player.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

const Color amber1 = Color(0xFF8C5200); // Dark Amber Primary
const Color amber3 = Color(0xFFFFB300); // Bright Amber Accent
const Color amber4 = Color(0xFFCC8A00); // Deep Amber Accent

const Color darkBg = Color(0xFF1A1200); // Warm dark background
const Color cardBg = Color(0xFF2A1F00); // Card background with amber warmth

class CourseDetailPage extends StatefulWidget {
  final String? courseId;
  const CourseDetailPage({super.key, this.courseId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  late final String courseId;
  String courseTitle = 'Course';
  String? courseDescription;
  Map<String, dynamic>? _selectedSession;

  // Local sessions loaded from prefs or assets
  List<Map<String, dynamic>> _sessions = [];

  // Two controllers: one for overall page (if needed later) and separate for list
  final ScrollController _pageController = ScrollController();
  final ScrollController _listController = ScrollController();

  // Progress tracking
  Set<String> _completedSessions = {};
  String? _lastWatchedSessionId;
  bool _isLoading = true;

  // Course stats
  int _totalSessions = 0;
  int _completedCount = 0;
  double _overallProgress = 0.0;

  // Key for forcing video player rebuild
  Key _videoPlayerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    courseId = widget.courseId ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (courseId.isEmpty) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map && args['courseId'] is String) {
          setState(() {
            courseId = args['courseId'];
          });
        }
      }
      if (courseId.isNotEmpty) {
        _loadCourseMeta();
        _loadProgress();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _listController.dispose();
    super.dispose();
  }

  /// Loads course meta & sessions:
  /// 1) Try SharedPreferences key `course_$courseId` (JSON string)
  /// 2) Else fallback to asset `assets/courses.json` (structure described above)
  Future<void> _loadCourseMeta() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('course_$courseId');

      Map<String, dynamic>? courseObj;

      if (saved != null && saved.isNotEmpty) {
        final parsed = jsonDecode(saved);
        if (parsed is Map<String, dynamic>) {
          courseObj = parsed;
        }
      }

      if (courseObj == null) {
        // Fallback: load from an asset JSON which contains many courses
        try {
          final raw = await rootBundle.loadString('assets/courses.json');
          final parsed = jsonDecode(raw) as Map<String, dynamic>;
          final courses = parsed['courses'] as Map<String, dynamic>?;

          if (courses != null && courses.containsKey(courseId)) {
            final candidate = courses[courseId];
            if (candidate is Map<String, dynamic>) {
              courseObj = candidate;
            }
          }
        } catch (e) {
          debugPrint('Failed to load asset courses.json: $e');
        }
      }

      // If still null, leave placeholders and empty sessions
      if (courseObj == null) {
        setState(() {
          courseTitle = 'Course';
          courseDescription = null;
          _sessions = [];
          _totalSessions = 0;
          _isLoading = false;
        });
        return;
      }

      // Normalize sessions list
      final sessionsRaw = courseObj['sessions'];
      List<Map<String, dynamic>> sessions = [];
      if (sessionsRaw is List) {
        for (var s in sessionsRaw) {
          if (s is Map<String, dynamic>) {
            final m = Map<String, dynamic>.from(s);
            // Ensure an id exists
            if (m['id'] == null) {
              m['id'] = UniqueKey().toString();
            } else {
              m['id'] = m['id'].toString();
            }
            sessions.add(m);
          }
        }
      }

      // Sort by 'order' if available
      sessions.sort((a, b) {
        final ao = a['order'];
        final bo = b['order'];
        if (ao is num && bo is num) return ao.compareTo(bo);
        return 0;
      });

      setState(() {
        courseTitle = (courseObj!['title'] as String?) ?? courseTitle;
        courseDescription =
            (courseObj['description'] as String?) ?? courseDescription;
        _sessions = sessions;
        _totalSessions = _sessions.length;
        _isLoading = false;
      });

      // Auto-select last watched or first session (after build)
      if (_sessions.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_selectedSession == null) {
            Map<String, dynamic> sessionToPlay;
            if (_lastWatchedSessionId != null) {
              final found = _sessions.firstWhere(
                (s) => s['id'] == _lastWatchedSessionId,
                orElse: () => _sessions.first,
              );
              sessionToPlay = found;
            } else {
              sessionToPlay = _sessions.first;
            }
            _selectSession(sessionToPlay);
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load course meta: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getStringList('completed_$courseId') ?? [];
      final lastWatched = prefs.getString('lastWatched_$courseId');

      setState(() {
        _completedSessions = completed.toSet();
        _lastWatchedSessionId = lastWatched;
        _calculateProgress();
      });
    } catch (e) {
      debugPrint('Failed to load progress: $e');
    }
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'completed_$courseId',
        _completedSessions.toList(),
      );
      if (_lastWatchedSessionId != null) {
        await prefs.setString('lastWatched_$courseId', _lastWatchedSessionId!);
      }
    } catch (e) {
      debugPrint('Failed to save progress: $e');
    }
  }

  void _markSessionWatched(String sessionId) {
    setState(() {
      _completedSessions.add(sessionId);
      _calculateProgress();
    });
    _saveProgress();
  }

  void _calculateProgress() {
    if (_totalSessions > 0) {
      _completedCount = _completedSessions.length;
      _overallProgress = _completedCount / _totalSessions;
    } else {
      _completedCount = 0;
      _overallProgress = 0.0;
    }
  }

  void _selectSession(Map<String, dynamic> session) {
    setState(() {
      _selectedSession = session;
      _lastWatchedSessionId = session['id']?.toString();
      // Mark as watched when selected
      _markSessionWatched(session['id']?.toString() ?? '');
      // Force video player to rebuild with new video
      _videoPlayerKey = UniqueKey();
    });
    _saveProgress();

    // Optional: keep list scroll position stable — do NOT call _listController.jumpTo here
  }

  void _playNextSession() {
    if (_selectedSession == null || _sessions.isEmpty) return;

    final currentIndex = _sessions.indexWhere(
      (s) => s['id'] == _selectedSession!['id'],
    );
    if (currentIndex >= 0 && currentIndex < _sessions.length - 1) {
      final next = _sessions[currentIndex + 1];
      _selectSession(next);
      _ensureVisibleIndex(currentIndex + 1);
    }
  }

  void _playPreviousSession() {
    if (_selectedSession == null || _sessions.isEmpty) return;

    final currentIndex = _sessions.indexWhere(
      (s) => s['id'] == _selectedSession!['id'],
    );
    if (currentIndex > 0) {
      final prev = _sessions[currentIndex - 1];
      _selectSession(prev);
      _ensureVisibleIndex(currentIndex - 1);
    }
  }

  // ensure the list scrolls so the item at index is visible (smooth)
  void _ensureVisibleIndex(int index) {
    // estimate item height (approx). If your item height changes, adjust this.
    const itemHeight = 82.0; // thumbnail row approx height + spacing
    final target = (index * (itemHeight + 10)) - 60.0;
    if (_listController.hasClients) {
      _listController.animateTo(
        target.clamp(0.0, _listController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if ((courseId.isEmpty) &&
        routeArgs is Map &&
        routeArgs['courseId'] is String) {
      final id = routeArgs['courseId'] as String;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          courseId = id;
        });
        _loadCourseMeta();
        _loadProgress();
      });
    }

    return Scaffold(
      backgroundColor: darkBg,
      body: courseId.isEmpty
          ? const Center(
              child: Text(
                'Course not specified',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator(color: amber3))
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    // _totalSessions may be updated already
    _totalSessions = _sessions.length;
    _calculateProgress();

    return Column(
      children: [
        _buildAppBarWithProgress(),

        if (_selectedSession != null) _buildFixedVideoPlayer(),

        Expanded(child: _buildSessionsList()),
      ],
    );
  }

  Widget _buildAppBarWithProgress() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [amber1, amber4],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courseTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_completedCount of $_totalSessions watched',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Circular progress indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          value: _overallProgress,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                      Text(
                        '${(_overallProgress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // Compact linear progress
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _overallProgress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedVideoPlayer() {
    final currentIndex = _sessions.indexWhere(
      (s) => s['id'] == _selectedSession!['id'],
    );
    final isFirstSession = currentIndex == 0;
    final isLastSession = currentIndex == _sessions.length - 1;
    final isWatched = _completedSessions.contains(_selectedSession!['id']);

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Video player - with unique key to force rebuild
          SizedBox(
            key: _videoPlayerKey,
            height: 220,
            child: TutorialYoutubePlayer(
              videoUrl: _selectedSession!['youtubeUrl'] ?? '',
              height: 220,
              autoPlay: true,
              startMuted: false,
              showControls: true,
            ),
          ),

          // Video info and controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isWatched ? amber3 : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isWatched
                                ? Icons.check_circle
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isWatched ? 'WATCHED' : 'WATCHING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Session ${currentIndex + 1} of $_totalSessions',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedSession!['title'] ?? 'Playing...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Navigation buttons
                Row(
                  children: [
                    // Previous button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isFirstSession ? null : _playPreviousSession,
                        icon: const Icon(Icons.skip_previous, size: 18),
                        label: const Text('Previous'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          disabledForegroundColor: Colors.white24,
                          side: BorderSide(
                            color: isFirstSession
                                ? Colors.white12
                                : Colors.white30,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Next button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLastSession ? null : _playNextSession,
                        icon: const Icon(Icons.skip_next, size: 18),
                        label: const Text('Next'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLastSession
                              ? Colors.white12
                              : amber3,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white12,
                          disabledForegroundColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No sessions available',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: amber3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Course Sessions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: _listController,
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _sessions.length,
              cacheExtent: 800, // cache items ahead to reduce jank
              addAutomaticKeepAlives: true,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final data = _sessions[i];
                final title = (data['title'] as String?) ?? 'Session ${i + 1}';
                final thumb = (data['thumb'] as String?) ?? '';
                final id = data['id']?.toString() ?? '';
                final isSelected =
                    _selectedSession != null && (_selectedSession!['id'] == id);
                final isWatched = _completedSessions.contains(id);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final sessionMap = Map<String, dynamic>.from(data);
                      // some data may use videoId -> youtubeUrl
                      if ((sessionMap['youtubeUrl'] as String?)?.isEmpty ??
                          true && sessionMap['videoId'] != null) {
                        sessionMap['youtubeUrl'] = sessionMap['videoId'];
                      }
                      _selectSession(sessionMap);

                      // ensure selected item visible smoothly
                      _ensureVisibleIndex(i);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? amber3.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? amber3
                              : Colors.white.withOpacity(0.08),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            // Status icon
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isWatched
                                    ? amber3
                                    : isSelected
                                    ? amber3.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  isWatched
                                      ? Icons.check_circle
                                      : isSelected
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: thumb.isNotEmpty
                                  ? Image.network(
                                      thumb,
                                      width: 80,
                                      height: 45,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, chunk) {
                                        if (chunk == null) return child;
                                        return Container(
                                          width: 80,
                                          height: 45,
                                          color: Colors.white10,
                                          child: const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) =>
                                          _thumbFallback(),
                                    )
                                  : _thumbFallback(),
                            ),
                            const SizedBox(width: 12),

                            // Title
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    '${i + 1}.',
                                    style: TextStyle(
                                      color: isSelected
                                          ? amber3
                                          : Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Right indicator
                            if (isSelected)
                              Container(
                                width: 3,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: amber3,
                                  borderRadius: BorderRadius.circular(2),
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
        ],
      ),
    );
  }

  Widget _thumbFallback() => Container(
    width: 80,
    height: 45,
    color: Colors.white12,
    child: Icon(
      Icons.play_circle_outline,
      color: amber3.withOpacity(0.5),
      size: 24,
    ),
  );
}
