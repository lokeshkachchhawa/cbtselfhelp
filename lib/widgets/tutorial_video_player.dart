import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Reusable YouTube player with a separate visible FullscreenButton overlay.
/// - Uses youtube_player_flutter's native fullscreen feature via toggleFullScreenMode().
/// - Uses YoutubePlayerBuilder.onEnterFullScreen / onExitFullScreen to control
///   system UI + orientation.
/// - Adds a chapters drawer (bottom sheet) and "Download Notes" actions per chapter.
class TutorialYoutubePlayer extends StatefulWidget {
  final String videoUrl; // full URL or ID
  final double height;
  final bool autoPlay;
  final bool startMuted;
  final bool showControls;
  final List<Map<String, String>>?
  chapters; // optional: [{'title':..,'video':..,'duration':..,'notes':..}]

  const TutorialYoutubePlayer({
    super.key,
    required this.videoUrl,
    this.height = 220,
    this.autoPlay = false,
    this.startMuted = false,
    this.showControls = true,
    this.chapters,
    required void Function(bool isFullScreen) onFullScreenToggle,
  });

  @override
  State<TutorialYoutubePlayer> createState() => _TutorialYoutubePlayerState();
}

class _TutorialYoutubePlayerState extends State<TutorialYoutubePlayer> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  bool _isMuted = false;
  late List<Map<String, String>> _chapters;
  int _playingIndex = 0;

  // Default notes file path from upload (will be transformed by your tooling into a downloadable URL).
  static const String _uploadedNotesPath =
      'file:///mnt/data/548cd32d-58c6-449d-ba66-65fcce6233e1.png';

  @override
  void initState() {
    super.initState();
    final videoId =
        YoutubePlayer.convertUrlToId(widget.videoUrl) ?? widget.videoUrl;

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: widget.startMuted,
        controlsVisibleAtStart: widget.showControls,
        enableCaption: true,
        forceHD: true,
        useHybridComposition: false,
      ),
    )..addListener(_listener); // UPDATED: listener behaves like VideoPlayerPage

    _isMuted = widget.startMuted;

    // Setup chapters (use provided or default single chapter with uploaded notes)
    _chapters =
        widget.chapters ??
        [
          {
            'title': 'Lesson 1',
            'video': widget.videoUrl,
            'duration': '15 min',
            'notes': _uploadedNotesPath,
          },
        ];
  }

  void _listener() {
    if (!mounted) return;

    // UPDATED: same idea as VideoPlayerPage.listener()
    final isFull = _controller.value.isFullScreen;
    if (isFull) {
      // Hide status + nav bar in fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // Restore edge-to-edge UI when not fullscreen
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_listener);
    _controller.pause();
    _controller.dispose();

    // Safety: ensure UI/orientation restored if widget is disposed while fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _toggleMute() {
    if (!_isPlayerReady) return;
    if (_isMuted) {
      _controller.unMute();
    } else {
      _controller.mute();
    }
    setState(() => _isMuted = !_isMuted);
  }

  Future<void> _openChaptersSheet() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF08101A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chapters',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _chapters.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ch = _chapters[index];
                        final playing = index == _playingIndex;
                        return ListTile(
                          tileColor: playing
                              ? Colors.white10
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _playAt(index);
                          },
                          leading: CircleAvatar(
                            backgroundColor: playing
                                ? const Color(0xFF667eea)
                                : Colors.white12,
                            child: Icon(
                              playing
                                  ? Icons.play_arrow
                                  : Icons.play_circle_fill,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            ch['title'] ?? 'Untitled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            ch['duration'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          trailing: IconButton(
                            onPressed: ch['notes'] == null
                                ? null
                                : () => _downloadNotes(ch['notes']),
                            icon: Icon(
                              Icons.file_download,
                              color: ch['notes'] == null
                                  ? Colors.white24
                                  : Colors.white70,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _playAt(int index) {
    final v = _chapters[index]['video'] ?? '';
    final id = YoutubePlayer.convertUrlToId(v) ?? v;
    _controller.load(id);
    setState(() => _playingIndex = index);
  }

  Future<void> _downloadNotes(String? notesUrl) async {
    if (notesUrl == null || notesUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No notes available')));
      return;
    }

    try {
      final launched = await launchUrlString(
        notesUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open notes')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening notes: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      // UPDATED: match VideoPlayerPage – only handle orientation here
      onEnterFullScreen: () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      },
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      },
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        bottomActions: [
          const SizedBox(width: 8),
          const CurrentPosition(),
          const SizedBox(width: 8),
          const ProgressBar(isExpanded: true),
          const RemainingDuration(),
          PlaybackSpeedButton(),
          FullScreenButton(), // native fullscreen button
          const SizedBox(width: 4),
        ],
        progressIndicatorColor: Colors.red,
        progressColors: const ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.white,
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white12,
        ),
        onReady: () {
          setState(() {
            _isPlayerReady = true;
            _isMuted = widget.startMuted;
          });
        },
      ),
      builder: (context, player) {
        // This is the embedded view structure
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: widget.height,
            color: Colors.black,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: player),

                // Mute toggle (custom overlay for embedded view)
                if (_isPlayerReady)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                // Chapters button (custom overlay for embedded view)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _openChaptersSheet,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
