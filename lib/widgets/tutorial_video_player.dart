// lib/widgets/tutorial_youtube_player.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Reusable YouTube player with a separate visible FullscreenButton overlay.
/// - Ensures overlays (buttons) render above the native player by using texture mode.
/// - Reuses same controller when opening fullscreen so playback continues seamlessly.
class TutorialYoutubePlayer extends StatefulWidget {
  final String videoUrl; // full URL or ID
  final double height;
  final bool autoPlay;
  final bool startMuted;
  final bool showControls;

  const TutorialYoutubePlayer({
    super.key,
    required this.videoUrl,
    this.height = 220,
    this.autoPlay = false,
    this.startMuted = false,
    this.showControls = true,
  });

  @override
  State<TutorialYoutubePlayer> createState() => _TutorialYoutubePlayerState();
}

class _TutorialYoutubePlayerState extends State<TutorialYoutubePlayer> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    final videoId =
        YoutubePlayer.convertUrlToId(widget.videoUrl) ?? widget.videoUrl;

    // NOTE: useHybridComposition: false -> texture mode.
    // This typically allows Flutter overlays to render above the player on Android.
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: widget.startMuted,
        controlsVisibleAtStart: widget.showControls,
        enableCaption: true,
        forceHD: true,
        useHybridComposition:
            false, // IMPORTANT: texture mode so overlays show above player
      ),
    )..addListener(_listener);

    _isMuted = widget.startMuted;
  }

  void _listener() {
    if (!mounted) return;
    // placeholder for future state sync
  }

  @override
  void dispose() {
    _controller.removeListener(_listener);
    _controller.dispose();

    // restore system UI/orientation as a safety
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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

  Future<void> _openFullScreen() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) =>
            _FullScreenPlayerPage(controller: _controller),
      ),
    );
    // Safeguard restore (page dispose also restores)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        // custom bottom actions: keep speed button, remove package fullscreen button
        bottomActions: [
          const SizedBox(width: 8),
          CurrentPosition(),
          const SizedBox(width: 8),
          ProgressBar(isExpanded: true),
          const SizedBox(width: 8),
          RemainingDuration(),
          const SizedBox(width: 8),
          PlaybackSpeedButton(), // keep speed options
          const SizedBox(width: 8),
        ],
        progressIndicatorColor: const Color.fromARGB(255, 255, 242, 0),
        progressColors: const ProgressBarColors(
          playedColor: Color.fromARGB(255, 211, 255, 255),
          handleColor: Color.fromARGB(255, 249, 229, 3),
        ),
        onReady: () {
          setState(() {
            _isPlayerReady = true;
            _isMuted = widget.startMuted;
          });
        },
      ),
      builder: (context, player) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: widget.height,
            color: Colors.black,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Player must be first child so overlays paint above it
                Positioned.fill(child: player),

                // Optional: debug border to ensure overlay zone (remove in prod)
                // Positioned.fill(
                //   child: Container(
                //     decoration: BoxDecoration(border: Border.all(color: Colors.transparent)),
                //   ),
                // ),

                // Mute toggle (top-right)
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

                // Custom separate Fullscreen button (bottom-right)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _openFullScreen,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 22,
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

/// Fullscreen page that reuses the controller.
/// Provides a visible close (X) button and hides system UI while present.
class _FullScreenPlayerPage extends StatefulWidget {
  final YoutubePlayerController controller;

  const _FullScreenPlayerPage({required this.controller});

  @override
  State<_FullScreenPlayerPage> createState() => _FullScreenPlayerPageState();
}

class _FullScreenPlayerPageState extends State<_FullScreenPlayerPage> {
  @override
  void initState() {
    super.initState();
    // hide system UI and force landscape
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // restore UI / orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // restore before popping to avoid UI flash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
          top: false,
          child: Stack(
            children: [
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    double targetHeight = width * 9 / 16;
                    double targetWidth = width;
                    if (targetHeight > height) {
                      targetHeight = height;
                      targetWidth = height * 16 / 9;
                    }
                    return SizedBox(
                      width: targetWidth,
                      height: targetHeight,
                      child: YoutubePlayer(
                        controller: widget.controller,
                        showVideoProgressIndicator: true,
                        bottomActions: [
                          const SizedBox(width: 8),
                          CurrentPosition(),
                          const SizedBox(width: 8),
                          ProgressBar(isExpanded: true),
                          const SizedBox(width: 8),
                          RemainingDuration(),
                          const SizedBox(width: 8),
                          PlaybackSpeedButton(),
                        ],
                        progressIndicatorColor: const Color.fromARGB(
                          255,
                          255,
                          242,
                          0,
                        ),
                        progressColors: const ProgressBarColors(
                          playedColor: Color.fromARGB(255, 211, 255, 255),
                          handleColor: Color.fromARGB(255, 249, 229, 3),
                        ),
                        onReady: () {
                          // nothing extra
                        },
                      ),
                    );
                  },
                ),
              ),

              // Close button (top-left)
              Positioned(
                top: 16,
                left: 16,
                child: SafeArea(
                  child: Material(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.edgeToEdge,
                        );
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown,
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ]);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
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
}
