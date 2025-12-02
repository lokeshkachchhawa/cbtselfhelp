// lib/screens/guided_meditation_player_with_list.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as fbstore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

// ================= Theme colors (Amber) =================
const Color amber1 = Color(0xFFFFA000);
const Color amber2 = Color(0xFFFFD54F);
const Color amber3 = Color(0xFFFF8F00);
const Color amber4 = Color(0xFFFF6F00);
const Color amber5 = Color(0xFFEF6C00);
const Color amber6 = Color(0xFFBF360C);

const Color surfaceDark = Color.fromARGB(255, 19, 12, 1);
const Color cardDark = Color.fromARGB(255, 27, 16, 1);

// ================ GuidedMeditationPlayer =================
class GuidedMeditationPlayer extends StatefulWidget {
  final String initialAudioAssetPath;
  final String title;
  final String subtitle;

  const GuidedMeditationPlayer({
    Key? key,
    this.initialAudioAssetPath = '',
    this.title = 'Guided Meditation',
    this.subtitle = 'Find your inner peace',
  }) : super(key: key);

  @override
  State<GuidedMeditationPlayer> createState() => _GuidedMeditationPlayerState();
}

class _GuidedMeditationPlayerState extends State<GuidedMeditationPlayer>
    with TickerProviderStateMixin {
  // players
  late final AudioPlayer _audioPlayer;

  // animations
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final AnimationController _glowController;

  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Local (asset) tracks
  final Map<String, String> _localTracks = {
    'Circle of Calm (EN)': 'assets/sounds/circle_of_calm.mp3',
    'शांति का वृत्त और श्वास (HI)': 'assets/sounds/circle_of_calm_hi.mp3',
    'समुद्र की लहर और श्वास (HI)': 'assets/sounds/bg_ocean_hi.mp3',
    'Sky Expansion Breath (EN)': 'assets/sounds/sky_expansion_breath_en.mp3',
    'आकाश विस्तार और श्वास (HI)': 'assets/sounds/sky_expansion_breath_hi.mp3',
    'Breath Meditation': 'assets/sounds/breath_meditation.mp3',
  };

  // Remote tracks fetched from Firestore (document id -> doc data)
  final Map<String, Map<String, dynamic>> _remoteTracks = {};

  // selection states
  String _selectedKey = 'None'; // friendly title
  String _selectedSource = 'none'; // 'asset' | 'remote' | 'none'

  // download state tracking for remote files:
  final Map<String, _DownloadState> _downloadStates = {};
  final Map<String, String> _downloadedLocalPath = {}; // docId -> localPath

  // Firestore listener
  StreamSubscription<QuerySnapshot>? _fsSub;

  // file storage dir
  Directory? _appDir;

  // loop toggle
  bool _isLooping = false;

  // track list tab: 0 = general, 1 = Dr. Kanhaiya
  int _trackTabIndex = 0;

  void _showDrKanhaiyaInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // handle bar
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),

              // Dr. Kanhaiya Image
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white10,
                backgroundImage: const AssetImage('images/drkanhaiya.png'),
              ),

              const SizedBox(height: 16),
              const Text(
                "Guided Meditations by Dr. Kanhaiya",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),
              Text(
                "New guided meditations are uploaded regularly by "
                "Dr. Kanhaiya to help you practice mindfulness, "
                "deep-breathing, relaxation and calmness.\n\n"
                "Downloaded audios remain available offline and "
                "you can listen anytime without internet.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: amber3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  "Got it",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _setup();
  }

  Future<void> _setup() async {
    _appDir = await getApplicationDocumentsDirectory();
    await _loadPersistedDownloads();
    _listenFirestore();
    _setupAudioListeners();

    // if initial asset provided, try to set
    if (widget.initialAudioAssetPath.isNotEmpty) {
      try {
        await _audioPlayer.setAsset(widget.initialAudioAssetPath);
        final found = _localTracks.entries.firstWhere(
          (e) => e.value == widget.initialAudioAssetPath,
          orElse: () => const MapEntry('None', ''),
        );
        setState(() {
          _selectedKey = found.key.isEmpty ? 'None' : found.key;
          _selectedSource = found.key.isEmpty ? 'none' : 'asset';
        });
      } catch (_) {}
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _setupAudioListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        _isLoading =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
    });

    _audioPlayer.durationStream.listen((d) {
      if (!mounted) return;
      if (d != null) setState(() => _duration = d);
    });

    _audioPlayer.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
  }

  Future<void> _loadPersistedDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList('downloaded_audio_keys') ?? [];
    for (final docId in keys) {
      final path = prefs.getString('downloaded_path_$docId');
      if (path != null && File(path).existsSync()) {
        _downloadedLocalPath[docId] = path;
        _downloadStates[docId] = _DownloadState(
          status: DownloadStatus.downloaded,
          progress: 1.0,
        );
      } else {
        prefs.remove('downloaded_path_$docId');
      }
    }
  }

  void _listenFirestore() {
    final coll = FirebaseFirestore.instance.collection('guided_audios');
    _fsSub = coll.snapshots().listen(
      (snap) {
        _remoteTracks.clear();
        for (final doc in snap.docs) {
          final data = doc.data();
          _remoteTracks[doc.id] = {
            'title': data['title'] ?? doc.id,
            'url': data['url'] ?? '',
            'language': data['language'] ?? '',
            'duration': data['duration'] ?? 0,
            'order': data['order'] ?? 9999,
            'description': data['description'] ?? '',
          };
          _downloadStates.putIfAbsent(
            doc.id,
            () => _downloadedLocalPath.containsKey(doc.id)
                ? _DownloadState(
                    status: DownloadStatus.downloaded,
                    progress: 1.0,
                  )
                : _DownloadState(status: DownloadStatus.notDownloaded),
          );
        }
        if (mounted) setState(() {});
      },
      onError: (e) {
        debugPrint('[fs] listen error: $e');
      },
    );
  }

  // Download a remote file (docId -> local file)
  Future<void> _downloadRemoteFile(
    String docId, {
    void Function()? progressCallback,
  }) async {
    final meta = _remoteTracks[docId];
    if (meta == null) return;
    String url = (meta['url'] as String?) ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Remote url missing')));
      return;
    }

    _downloadStates[docId] = _DownloadState(
      status: DownloadStatus.downloading,
      progress: 0.0,
    );
    progressCallback?.call();
    if (mounted) setState(() {});

    try {
      // If gs://, resolve to https URL
      if (url.startsWith('gs://')) {
        final ref = fbstore.FirebaseStorage.instance.refFromURL(url);
        url = await ref.getDownloadURL();
      }

      final uri = Uri.parse(url);
      final appDir = _appDir ?? await getApplicationDocumentsDirectory();
      final targetDir = Directory('${appDir.path}/guided_audios');
      if (!targetDir.existsSync()) targetDir.createSync(recursive: true);

      final filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : '$docId.mp3';
      final targetFile = File('${targetDir.path}/$filename');

      final client = http.Client();
      final req = http.Request("GET", uri);
      final streamed = await client
          .send(req)
          .timeout(const Duration(seconds: 60));

      if (streamed.statusCode != 200) {
        throw Exception('HTTP ${streamed.statusCode}');
      }

      final contentLength = streamed.contentLength ?? 0;
      final sink = targetFile.openWrite();
      int received = 0;

      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          final p = (received / contentLength).clamp(0.0, 1.0);
          _downloadStates[docId] = _DownloadState(
            status: DownloadStatus.downloading,
            progress: p,
          );
          progressCallback?.call();
          if (mounted) setState(() {});
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      // persist path in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getStringList('downloaded_audio_keys') ?? [];
      if (!keys.contains(docId)) {
        keys.add(docId);
        await prefs.setStringList('downloaded_audio_keys', keys);
      }
      await prefs.setString('downloaded_path_$docId', targetFile.path);

      _downloadedLocalPath[docId] = targetFile.path;
      _downloadStates[docId] = _DownloadState(
        status: DownloadStatus.downloaded,
        progress: 1.0,
      );

      progressCallback?.call();
      if (mounted) setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded: ${meta['title'] ?? docId}')),
      );
    } on TimeoutException {
      debugPrint('[download] timeout');
      _downloadStates[docId] = _DownloadState(
        status: DownloadStatus.notDownloaded,
      );
      progressCallback?.call();
      if (mounted) setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download timed out')));
    } catch (e) {
      debugPrint('[download] failed: $e');
      _downloadStates[docId] = _DownloadState(
        status: DownloadStatus.notDownloaded,
      );
      progressCallback?.call();
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: ${e.toString()}')),
      );
    }
  }

  // Select track (local asset)
  Future<void> _selectTrackByLocalAsset(String title, String assetPath) async {
    try {
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.setLoopMode(_isLooping ? LoopMode.one : LoopMode.off);
      setState(() {
        _selectedKey = title;
        _selectedSource = 'asset';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selected: $title')));
    } catch (e) {
      debugPrint('[select asset] $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to select track')));
    }
  }

  Future<void> _selectTrackByRemoteDoc(
    String docId, {
    bool playIfWasPlaying = false,
  }) async {
    final meta = _remoteTracks[docId];
    if (meta == null) return;
    final local = _downloadedLocalPath[docId];
    if (local == null || !File(local).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download file first to play offline')),
      );
      return;
    }
    try {
      await _audioPlayer.setFilePath(local);
      await _audioPlayer.setLoopMode(_isLooping ? LoopMode.one : LoopMode.off);
      setState(() {
        _selectedKey = meta['title'] as String? ?? docId;
        _selectedSource = 'remote';
      });
      if (playIfWasPlaying) await _audioPlayer.play();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selected: ${meta['title']}')));
    } catch (e) {
      debugPrint('[select remote] $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to select remote track')),
      );
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _vibrateLight();
      return;
    }

    // If nothing selected, ask user to select
    if (_selectedSource == 'none' || _selectedKey == 'None') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a track first')),
      );
      return;
    }

    // if selected is remote ensure the file exists
    if (_selectedSource == 'remote') {
      final docId = _remoteTracks.entries
          .firstWhere(
            (e) => (e.value['title'] as String?) == _selectedKey,
            orElse: () => const MapEntry('', {}),
          )
          .key;
      final local = _downloadedLocalPath[docId];
      if (local == null || !File(local).existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloaded file missing — please re-download'),
          ),
        );
        return;
      }
      try {
        await _audioPlayer.setFilePath(local);
      } catch (e) {
        debugPrint('[play remote] setFilePath error: $e');
      }
    }

    try {
      await _audioPlayer.play();
      _vibrateLight();
    } catch (e) {
      debugPrint('[play] failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Playback failed')));
    }
  }

  Future<void> _toggleLoopMode() async {
    setState(() => _isLooping = !_isLooping);
    try {
      await _audioPlayer.setLoopMode(_isLooping ? LoopMode.one : LoopMode.off);
    } catch (e) {
      debugPrint('[loop] $e');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isLooping ? 'Repeat enabled' : 'Repeat disabled'),
      ),
    );
  }

  Future<void> _vibrateLight() async {
    if (await Vibration.hasVibrator()) Vibration.vibrate(duration: 40);
  }

  Future<void> _seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (_) {}
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _fsSub?.cancel();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // helper to show selected name (friendly)
  String _selectedLabel() {
    if (_selectedSource == 'asset') return _selectedKey;
    if (_selectedSource == 'remote') return _selectedKey;
    return 'No track selected';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            if (isLandscape) {
              // Side-by-side in landscape
              return Row(
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.46,
                    child: _buildPlayerSection(padHorizontal: 24),
                  ),
                  Expanded(child: _buildTracksPanel()),
                ],
              );
            }

            // Portrait: top player, bottom tracks
            return Column(
              children: [
                SizedBox(
                  height: constraints.maxHeight * 0.46,
                  child: _buildPlayerSection(padHorizontal: 24),
                ),
                Expanded(child: _buildTracksPanel()),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===================== PLAYER UI (TOP) =====================

  Widget _buildPlayerSection({double padHorizontal = 24}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decide animation size based on available height
        final double animSize = math.min(
          constraints.maxHeight * 0.7,
          260.0,
        ); // max 260

        return Column(
          children: [
            const SizedBox(height: 8),
            // Title + selected track
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padHorizontal),
              child: Column(
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedLabel(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ---------- Row: Animation + Play Button ----------
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padHorizontal),
                child: Row(
                  children: [
                    // Animation on the left
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: SizedBox(
                          height: animSize,
                          width: animSize,
                          child: _buildAnimatedFigure(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Play button + repeat on the right
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPlayPauseButton(),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: _isLooping
                                    ? 'Repeat: On'
                                    : 'Repeat: Off',
                                icon: Icon(
                                  _isLooping ? Icons.repeat_one : Icons.repeat,
                                  color: _isLooping ? amber2 : Colors.white54,
                                  size: 26,
                                ),
                                onPressed: _toggleLoopMode,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _isLooping
                                      ? 'Repeating current track'
                                      : 'No repeat',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
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
              ),
            ),

            const SizedBox(height: 6),

            // ---------- Time + Slider at the bottom ----------
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padHorizontal + 8),
              child: Column(
                children: [
                  // time row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(
                          color: amber2,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // slider
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                      activeTrackColor: amber3,
                      inactiveTrackColor: Colors.white.withOpacity(0.1),
                      thumbColor: amber2,
                      overlayColor: amber3.withOpacity(0.3),
                    ),
                    child: Slider(
                      value: _duration.inSeconds > 0
                          ? _position.inSeconds
                                .clamp(0, _duration.inSeconds)
                                .toDouble()
                          : 0.0,
                      max: _duration.inSeconds > 0
                          ? _duration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: (value) =>
                          _seekTo(Duration(seconds: value.toInt())),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedFigure() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _rotateController,
        _glowController,
      ]),
      builder: (context, child) {
        final pulseValue = _pulseController.value;
        final rotateValue = _rotateController.value;
        final glowValue = _glowController.value;
        final scale = 1.0 + (pulseValue * 0.15);

        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotateValue * 2 * math.pi,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        amber3.withOpacity(0.05 + glowValue * 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        amber3.withOpacity(0.1 + glowValue * 0.2),
                        Colors.transparent,
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        amber2.withOpacity(0.15 + glowValue * 0.25),
                        amber3.withOpacity(0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: amber3.withOpacity(0.3 + glowValue * 0.2),
                        blurRadius: 40 + (glowValue * 20),
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    children: [
                      ...List.generate(8, (index) {
                        final angle =
                            (index * math.pi / 4) + (rotateValue * 2 * math.pi);
                        final distance = 55.0;
                        final x = math.cos(angle) * distance;
                        final y = math.sin(angle) * distance;
                        return Positioned(
                          left: 70 + x - 4,
                          top: 70 + y - 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: amber2.withOpacity(0.6 + glowValue * 0.4),
                              boxShadow: [
                                BoxShadow(
                                  color: amber2.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.15),
                                amber3.withOpacity(0.25),
                                amber4.withOpacity(0.15),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            border: Border.all(
                              color: amber2.withOpacity(0.4 + glowValue * 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: amber3.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.self_improvement_rounded,
                            size: 40,
                            color: Colors.white.withOpacity(0.9),
                            shadows: [
                              Shadow(
                                color: amber2.withOpacity(0.8),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayPauseButton() {
    return GestureDetector(
      onTapUp: (_) {
        _togglePlayPause();
      },
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [amber3.withOpacity(0.9), amber4.withOpacity(0.95)],
            center: const Alignment(-0.3, -0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: amber3.withOpacity(0.5),
              blurRadius: 25,
              spreadRadius: 3,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.32),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: amber2.withOpacity(0.32), width: 2),
        ),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 46,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.black.withOpacity(0.28), blurRadius: 8),
                ],
              ),
      ),
    );
  }

  // ===================== TRACKS PANEL (BOTTOM) =====================

  Widget _buildTracksPanel() {
    final remoteList =
        _remoteTracks.entries.map((e) => MapEntry(e.key, e.value)).toList()
          ..sort(
            (a, b) => (a.value['order'] as int? ?? 9999).compareTo(
              b.value['order'] as int? ?? 9999,
            ),
          );

    return Container(
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Row(
              children: [
                const Icon(
                  Icons.library_music,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Meditation Tracks',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Icon(
                  _selectedSource == 'remote'
                      ? Icons.cloud_done_rounded
                      : _selectedSource == 'asset'
                      ? Icons.offline_bolt_rounded
                      : Icons.music_note_outlined,
                  size: 18,
                  color: amber2,
                ),
                const SizedBox(width: 4),
                Text(
                  _selectedSource == 'remote'
                      ? 'Cloud'
                      : _selectedSource == 'asset'
                      ? 'Built-in'
                      : 'None',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // segmented tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: _buildTracksTabButton(
                    index: 0,
                    title: 'General tracks',
                    subtitle:
                        '${_localTracks.length} ${_localTracks.length == 1 ? 'track' : 'tracks'}',
                    icon: Icons.music_video_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTracksTabButton(
                    index: 1,
                    title: 'By Dr. Kanhaiya',
                    subtitle:
                        '${remoteList.length} ${remoteList.length == 1 ? 'track' : 'tracks'}',
                    icon: Icons.cloud_download_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _trackTabIndex == 0
                  ? _buildLocalTrackList()
                  : _buildRemoteTrackList(remoteList),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracksTabButton({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isActive = _trackTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _trackTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? amber3.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive ? amber3.withOpacity(0.9) : Colors.white12,
            width: 1.1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? amber2 : Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalTrackList() {
    if (_localTracks.isEmpty) {
      return const Center(
        child: Text(
          'No built-in tracks',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }

    return ListView(
      key: const ValueKey('local-list'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: _localTracks.entries.map((entry) {
        final title = entry.key;
        final asset = entry.value;
        final selected = _selectedSource == 'asset' && _selectedKey == title;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            tileColor: selected
                ? Colors.white12
                : Colors.white.withOpacity(0.02),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: selected
                  ? amber3
                  : const Color(0xFF1C1305).withOpacity(0.9),
              child: const Icon(Icons.music_note, color: Colors.white),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'On-device • Instant play',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: Icon(
              selected ? Icons.check_circle : Icons.play_arrow_rounded,
              color: selected ? amber2 : Colors.white70,
            ),
            onTap: () async {
              await _selectTrackByLocalAsset(title, asset);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRemoteTrackList(
    List<MapEntry<String, Map<String, dynamic>>> remoteList,
  ) {
    if (remoteList.isEmpty) {
      return const Center(
        child: Text(
          'New guided tracks by Dr. Kanhaiya\nwill appear here automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
      );
    }

    return ListView(
      key: const ValueKey('remote-list'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        // header row with avatar + info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _showDrKanhaiyaInfoSheet(context),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF012A2A),
                  backgroundImage: const AssetImage('images/drkanhaiya.png'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guided meditations by Dr. Kanhaiya',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap download once, then listen offline anytime.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showDrKanhaiyaInfoSheet(context),
                icon: const Icon(Icons.info_outline, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        ...remoteList.map((entry) {
          final docId = entry.key;
          final info = entry.value;
          final title = info['title'] as String? ?? docId;
          final url = info['url'] as String? ?? '';
          final downloadedPath = _downloadedLocalPath[docId];
          final dlState =
              _downloadStates[docId] ??
              _DownloadState(status: DownloadStatus.notDownloaded);
          final selected = _selectedSource == 'remote' && _selectedKey == title;

          final language = (info['language'] as String?) ?? '';
          final hasLang = language.trim().isNotEmpty;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: selected
                  ? Colors.white12
                  : Colors.white.withOpacity(0.02),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: selected
                    ? amber3
                    : const Color(0xFF012A2A).withOpacity(0.9),
                child: const Icon(Icons.cloud_download, color: Colors.white),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: hasLang
                  ? Text(
                      language,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dlState.status == DownloadStatus.downloaded &&
                      downloadedPath != null)
                    IconButton(
                      icon: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.play_arrow_rounded,
                        color: selected ? amber2 : Colors.white70,
                      ),
                      onPressed: () async {
                        await _selectTrackByRemoteDoc(docId);
                      },
                    )
                  else if (dlState.status == DownloadStatus.downloading)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: dlState.progress,
                            color: amber3,
                          ),
                          const Icon(
                            Icons.downloading,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.download_rounded),
                      color: amber3,
                      onPressed: url.isEmpty
                          ? null
                          : () async {
                              final doIt = await showDialog<bool>(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  title: Text('Download "$title"?'),
                                  content: const Text(
                                    'This will download the audio to your device for offline play.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dCtx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dCtx, true),
                                      child: const Text('Download'),
                                    ),
                                  ],
                                ),
                              );
                              if (doIt == true) {
                                await _downloadRemoteFile(
                                  docId,
                                  progressCallback: () {
                                    if (mounted) setState(() {});
                                  },
                                );
                              }
                            },
                    ),
                ],
              ),
              onTap: () async {
                if (dlState.status == DownloadStatus.downloaded &&
                    downloadedPath != null) {
                  await _selectTrackByRemoteDoc(docId);
                } else {
                  if (url.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Remote URL missing')),
                    );
                  } else {
                    final doIt = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: Text('Download "$title"?'),
                        content: const Text(
                          'This will download the audio to your device for offline play.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('Download'),
                          ),
                        ],
                      ),
                    );
                    if (doIt == true) {
                      await _downloadRemoteFile(
                        docId,
                        progressCallback: () {
                          if (mounted) setState(() {});
                        },
                      );
                    }
                  }
                }
              },
            ),
          );
        }).toList(),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ============== Download helpers & types ==============
enum DownloadStatus { notDownloaded, downloading, downloaded }

class _DownloadState {
  final DownloadStatus status;
  final double progress; // 0..1

  _DownloadState({required this.status, this.progress = 0.0});
}
