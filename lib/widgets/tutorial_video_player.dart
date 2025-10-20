import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Clean, reliable YouTube Player (works with v9.1.3)
/// - Supports play/pause, mute toggle, fullscreen
/// - No iframe / embed issues (uses native YouTube APIs)
class TutorialYoutubePlayer extends StatefulWidget {
  final String videoUrl; // can be full URL or ID
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

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: widget.startMuted,
        controlsVisibleAtStart: widget.showControls,
        enableCaption: true,
      ),
    )..addListener(_playerListener);
  }

  void _playerListener() {
    if (_isPlayerReady && mounted && !_controller.value.isFullScreen) {
      // You can read position, duration, etc. from _controller.value
    }
  }

  @override
  void deactivate() {
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.removeListener(_playerListener);
    _controller.dispose();
    super.dispose();
  }

  void _toggleMute() async {
    if (!_isPlayerReady) return;
    if (_isMuted) {
      _controller.unMute();
    } else {
      _controller.mute();
    }
    setState(() => _isMuted = !_isMuted);
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF016C6C),
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
              alignment: Alignment.center,
              children: [
                player,

                // --- Mute button (top-right) ---
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
              ],
            ),
          ),
        );
      },
    );
  }
}
