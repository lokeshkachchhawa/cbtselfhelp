// lib/screens/mini_meditation_timer.dart
// Mini Meditation Timer — Dark teal theme, compact single-file screen
// Updated: switched from audioplayers -> just_audio
// - background loop player (just_audio) with fade in/out
// - preview player separate from loop player
// - bell player (short cue) played independently
// - cross-fade helper using Timer
// Requires in pubspec.yaml:
//   just_audio: ^0.9.35
//   vibration: ^3.1.4

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

const Color teal1 = Color(0xFF016C6C);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF005E5C);

class MiniMeditationTimer extends StatefulWidget {
  const MiniMeditationTimer({super.key});

  @override
  State<MiniMeditationTimer> createState() => _MiniMeditationTimerState();
}

enum BgState { none, playing, paused, previewing }

class _MiniMeditationTimerState extends State<MiniMeditationTimer>
    with TickerProviderStateMixin {
  // just_audio players
  final AudioPlayer _bellPlayer = AudioPlayer();
  final AudioPlayer _bgPlayer = AudioPlayer(); // loop player
  final AudioPlayer _previewPlayer = AudioPlayer(); // temporary preview

  // background track registry (displayName -> asset path)
  final Map<String, String> _bgTracks = {
    'None': '',
    'Rain': 'assets/sounds/bg_rain.mp3',
    'Ocean': 'assets/sounds/bg_ocean.mp3',
    'OM Chant': 'assets/sounds/om_chant_loop.mp3',
  };

  String _selectedBg = 'None';
  double _bgVolume = 0.6; // 0.0 .. 1.0

  bool _applyBgImmediately = false; // live switching only if true

  BgState _bgState = BgState.none;
  bool _isPreviewing = false;

  // UI / session config
  int _minutes = 5;
  int _bellIntervalSec = 60;

  // session runtime state
  late AnimationController _progressController;
  Timer? _cueTimer;
  Timer? _sessionTimer;
  Timer? _previewTimer;
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  bool _isRunning = false;

  // fade timers to avoid concurrent fades
  Timer? _bgFadeTimer;
  Timer? _previewFadeTimer;
  Timer? _bellFadeTimer;

  // NEW: tutorial language toggle (false = English, true = Hindi)
  bool _tutorialInHindi = false;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayers();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSessionComplete();
      }
    });

    // monitor bg player playing state to update UI indicator
    _bgPlayer.playingStream.listen((playing) {
      if (!mounted) return;
      setState(() {
        if (playing) {
          _bgState = BgState.playing;
        } else if (_isPreviewing) {
          _bgState = BgState.previewing;
        } else if (_bgPlayer.processingState == ProcessingState.idle ||
            _bgPlayer.processingState == ProcessingState.completed) {
          _bgState = BgState.none;
        } else {
          _bgState = BgState.paused;
        }
      });
    });
  }

  Future<void> _setupAudioPlayers() async {
    try {
      // bell player - keep short and ready
      await _bellPlayer.setVolume(1.0);
      // bg player - loop mode; volume managed by fades
      await _bgPlayer.setVolume(0.0);
      await _bgPlayer.setLoopMode(LoopMode.one);
      // preview player - no loop
      await _previewPlayer.setVolume(_bgVolume);
      await _previewPlayer.setLoopMode(LoopMode.off);
    } catch (_) {}
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _cueTimer?.cancel();
    _sessionTimer?.cancel();
    _progressController.dispose();

    _bgFadeTimer?.cancel();
    _previewFadeTimer?.cancel();
    _bellFadeTimer?.cancel();

    try {
      _bellPlayer.dispose();
    } catch (_) {}
    try {
      _bgPlayer.dispose();
    } catch (_) {}
    try {
      _previewPlayer.dispose();
    } catch (_) {}

    super.dispose();
  }

  // -------------------- fade helpers --------------------
  // fade player volume from current (or from param) to target over duration using steps
  Timer? _startFade(
    AudioPlayer player,
    double from,
    double to, {
    int steps = 12,
    int totalMs = 480,
    required void Function() onComplete,
    required void Function(Timer) registerTimer,
  }) {
    final stepMs = (totalMs / steps).round();
    int step = 0;
    final diff = to - from;
    player.setVolume(from.clamp(0.0, 1.0));
    final t = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      step++;
      final v = (from + diff * (step / steps)).clamp(0.0, 1.0);
      try {
        player.setVolume(v);
      } catch (_) {}
      if (step >= steps) {
        timer.cancel();
        onComplete();
      }
    });
    registerTimer(t);
    return t;
  }

  Future<void> _fadeInBg(double target) async {
    _bgFadeTimer?.cancel();
    final current = await _bgPlayer.volume;
    _bgFadeTimer = _startFade(
      _bgPlayer,
      current,
      target,
      steps: 14,
      totalMs: 700,
      onComplete: () {
        _bgFadeTimer = null;
      },
      registerTimer: (t) => _bgFadeTimer = t,
    );
  }

  Future<void> _fadeOutBgAndPause() async {
    _bgFadeTimer?.cancel();
    final current = await _bgPlayer.volume;
    _bgFadeTimer = _startFade(
      _bgPlayer,
      current,
      0.0,
      steps: 10,
      totalMs: 500,
      onComplete: () async {
        _bgFadeTimer = null;
        try {
          await _bgPlayer.pause();
        } catch (_) {}
      },
      registerTimer: (t) => _bgFadeTimer = t,
    );
  }

  // -------------------- bell --------------------
  Future<void> _playCue() async {
    try {
      // stop previous if running
      await _bellPlayer.stop();
      await _bellPlayer.setAsset('assets/sounds/bell_short.mp3');
      await _bellPlayer.setVolume(1.0);
      await _bellPlayer.play();
    } catch (_) {}

    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 36);
      }
    } catch (_) {}

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  // -------------------- background / preview --------------------
  Future<void> _applySelectedBackground() async {
    final asset = _bgTracks[_selectedBg] ?? '';
    if (asset.isEmpty) {
      // stop existing bg
      await _stopBackground();
      return;
    }

    try {
      // stop existing and set new asset
      await _bgPlayer.stop();
      await _bgPlayer.setLoopMode(LoopMode.one);
      await _bgPlayer.setAsset(asset);
      // start muted and fade into configured volume
      await _bgPlayer.setVolume(0.0);
      await _bgPlayer.play();
      setState(() => _bgState = BgState.playing);
      _fadeInBg(_bgVolume);
    } catch (e) {
      debugPrint('[mini_timer] applySelectedBackground failed: $e');
      setState(() => _bgState = BgState.none);
    }
  }

  Future<void> _stopBackground({bool fade = true}) async {
    try {
      if (fade && _bgPlayer.playing) {
        await _fadeOutBgAndPause();
        setState(() => _bgState = BgState.none);
      } else {
        await _bgPlayer.stop();
        setState(() => _bgState = BgState.none);
      }
    } catch (_) {
      setState(() => _bgState = BgState.none);
    }
  }

  // Live switch behaviour (only if _applyBgImmediately == true)
  Future<void> _switchBackgroundLive() async {
    final newAsset = _bgTracks[_selectedBg] ?? '';
    if (newAsset.isEmpty) {
      // stopping background
      await _stopBackground(fade: true);
      return;
    }

    try {
      // cross-fade: fade current to 0, stop, then start new and fade in
      await _fadeOutBgAndPause();
      await _bgPlayer.stop();
      await _bgPlayer.setAsset(newAsset);
      await _bgPlayer.setLoopMode(LoopMode.one);
      await _bgPlayer.setVolume(0.0);
      await _bgPlayer.play();
      setState(() => _bgState = BgState.playing);
      _fadeInBg(_bgVolume);
    } catch (e) {
      debugPrint('[mini_timer] live switch failed: $e');
      setState(() => _bgState = BgState.none);
    }
  }

  // Preview uses previewPlayer and never affects loop player permanently.
  Future<void> _previewBackground() async {
    final asset = _bgTracks[_selectedBg] ?? '';
    if (asset.isEmpty) return;

    final originalState = _bgState;
    bool pausedForPreview = false;

    try {
      if (originalState == BgState.playing) {
        // fade bg down and pause it while preview plays
        await _fadeOutBgAndPause();
        pausedForPreview = true;
        setState(() => _bgState = BgState.paused);
      }

      // prepare & play preview
      await _previewPlayer.stop();
      await _previewPlayer.setAsset(asset);
      await _previewPlayer.setVolume(_bgVolume);
      await _previewPlayer.play();
      setState(() {
        _isPreviewing = true;
        _bgState = BgState.previewing;
      });

      _previewTimer?.cancel();
      _previewTimer = Timer(const Duration(seconds: 6), () {
        _stopPreview(resumeBg: true);
      });
    } catch (e) {
      debugPrint('[mini_timer] preview failed: $e');
      // attempt to resume bg if we paused it
      if (pausedForPreview && originalState == BgState.playing) {
        try {
          await _bgPlayer.setVolume(0.0);
          await _bgPlayer.play();
          _fadeInBg(_bgVolume);
          setState(() => _bgState = BgState.playing);
        } catch (_) {}
      }
      setState(() => _isPreviewing = false);
    }
  }

  Future<void> _stopPreview({bool resumeBg = true}) async {
    _previewTimer?.cancel();
    try {
      await _previewPlayer.stop();
    } catch (_) {}

    final shouldResumeBg = resumeBg && _bgPlayer.playing == false && _isRunning;
    if (mounted) {
      setState(() {
        _isPreviewing = false;
        if (shouldResumeBg) {
          _bgState = BgState.playing;
        } else if (!shouldResumeBg && _bgPlayer.playing == false) {
          _bgState = BgState.none;
        }
      });
    }

    if (shouldResumeBg) {
      try {
        // resume bg and fade back to configured volume
        await _bgPlayer.setVolume(0.0);
        await _bgPlayer.play();
        _fadeInBg(_bgVolume);
      } catch (_) {}
    }
  }

  // Called when user changes dropdown selection
  void _onSelectedBgChanged(String? v) {
    if (v == null) return;
    setState(() => _selectedBg = v);

    if (_isPreviewing) {
      _stopPreview(resumeBg: true);
    }

    if (_isRunning && _applyBgImmediately) {
      _switchBackgroundLive();
    } else if (_isRunning && !_applyBgImmediately) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Background will apply when session (re)starts'),
        ),
      );
    }
  }

  // ------------------ session control ------------------
  void _startSession() async {
    if (_isRunning) return;

    _stopPreview(resumeBg: false);

    _totalSeconds = (_minutes.clamp(1, 60)) * 60;
    _remainingSeconds = _totalSeconds;

    _progressController.duration = Duration(seconds: _totalSeconds);
    _progressController.forward(from: 0.0);

    // start background audio loop (if selected)
    await _applySelectedBackground();

    // session timer to keep remainingSeconds in sync
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds = (_totalSeconds * (1.0 - _progressController.value))
            .ceil();
        if (_remainingSeconds <= 0) {
          _remainingSeconds = 0;
        }
      });
    });

    // cue timer
    _cueTimer?.cancel();
    if (_bellIntervalSec > 0 && _bellIntervalSec < _totalSeconds) {
      // play first cue immediately then every interval
      _playCue();
      _cueTimer = Timer.periodic(Duration(seconds: _bellIntervalSec), (_) {
        _playCue();
      });
    }

    setState(() {
      _isRunning = true;
    });
  }

  void _pauseSession() {
    if (!_isRunning) return;

    _stopPreview(resumeBg: false);

    _progressController.stop();
    _cueTimer?.cancel();
    _sessionTimer?.cancel();

    // gentle pause background player (keep state so resume can continue loop)
    try {
      if (_bgPlayer.playing) {
        _fadeOutBgAndPause();
      }
    } catch (_) {}

    setState(() {
      _isRunning = false;
    });
  }

  void _resumeSession() async {
    if (_isRunning) return;

    _stopPreview(resumeBg: false);

    final progressed = _progressController.value;
    final secondsLeft = (_totalSeconds * (1.0 - progressed)).ceil();
    _remainingSeconds = secondsLeft;

    final remainingDuration = Duration(seconds: secondsLeft);
    _progressController.duration = remainingDuration;
    _progressController.forward(from: progressed);

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remainingSeconds = (_totalSeconds * (1.0 - _progressController.value))
            .ceil();
        if (_remainingSeconds <= 0) _remainingSeconds = 0;
      });
    });

    _cueTimer?.cancel();
    if (_bellIntervalSec > 0 && _bellIntervalSec < _totalSeconds) {
      _cueTimer = Timer.periodic(Duration(seconds: _bellIntervalSec), (_) {
        _playCue();
      });
    }

    // gentle resume background if selected
    try {
      if ((_bgTracks[_selectedBg] ?? '').isNotEmpty) {
        if (_bgState == BgState.none) {
          await _applySelectedBackground();
        } else {
          // ensure player resumes and fade into volume
          await _bgPlayer.setVolume(0.0);
          await _bgPlayer.play();
          _fadeInBg(_bgVolume);
        }
      }
    } catch (_) {}

    setState(() => _isRunning = true);
  }

  void _stopSession({bool showSnack = true}) async {
    _stopPreview(resumeBg: false);

    _progressController.stop();
    _progressController.reset();
    _cueTimer?.cancel();
    _sessionTimer?.cancel();

    await _stopBackground();

    setState(() {
      _isRunning = false;
      _remainingSeconds = 0;
      _totalSeconds = 0;
    });

    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meditation session stopped')),
      );
    }
  }

  void _onSessionComplete() async {
    _stopPreview(resumeBg: false);

    _cueTimer?.cancel();
    _sessionTimer?.cancel();

    await _stopBackground();

    setState(() {
      _isRunning = false;
      _remainingSeconds = 0;
    });

    // gentle cue
    _playCue();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session complete')));
    }
  }

  // ------------------ UI ------------------
  String _formatTime(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _buildBackgroundSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF031818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: teal2,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: teal2.withOpacity(0.25), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Background',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 160,
              maxWidth: MediaQuery.of(context).size.width * 0.45,
            ),
            child: InputDecorator(
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                filled: true,
                fillColor: const Color(0xFF042A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBg,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF042A2A),
                  iconEnabledColor: Colors.white70,
                  items: _bgTracks.keys.map((k) {
                    return DropdownMenuItem(
                      value: k,
                      child: Row(
                        children: [
                          Icon(
                            k == 'Rain'
                                ? Icons.cloud
                                : (k == 'Ocean'
                                      ? Icons.waves
                                      : (k == 'OM Chant'
                                            ? Icons.music_note
                                            : Icons.not_interested)),
                            size: 18,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(k, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: _isRunning && !_applyBgImmediately
                      ? null
                      : (v) => _onSelectedBgChanged(v),
                ),
              ),
            ),
          ),

          Tooltip(
            message: _selectedBg == 'None'
                ? 'No background selected'
                : 'Preview selected background',
            child: IconButton(
              onPressed: (_selectedBg == 'None' || _isRunning)
                  ? null
                  : () {
                      if (_isPreviewing) {
                        _stopPreview(resumeBg: true);
                      } else {
                        _previewBackground();
                      }
                    },
              icon: Icon(_isPreviewing ? Icons.stop : Icons.play_circle_fill),
              color: teal2,
              iconSize: 28,
            ),
          ),

          GestureDetector(
            onTap: _isRunning
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF021515),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      builder: (ctx) {
                        return StatefulBuilder(
                          builder: (ctx2, setSheetState) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.volume_up,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Background volume',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${(_bgVolume * 100).round()}%',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Slider(
                                    value: _bgVolume,
                                    min: 0.0,
                                    max: 1.0,
                                    divisions: 20,
                                    activeColor: teal2,
                                    inactiveColor: Colors.white12,
                                    onChanged: (v) {
                                      setSheetState(() {
                                        _bgVolume = v;
                                      });
                                      setState(() {
                                        _bgVolume = v;
                                      });
                                      try {
                                        _bgPlayer.setVolume(v);
                                        if (_isPreviewing) {
                                          _previewPlayer.setVolume(v);
                                        }
                                      } catch (_) {}
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
            child: Chip(
              backgroundColor: const Color(0xFF023232),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _bgVolume == 0 ? Icons.volume_off : Icons.volume_up,
                    size: 18,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(_bgVolume * 100).round()}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          if (_isRunning && !_applyBgImmediately)
            const Tooltip(
              message:
                  'Background locked while session is running (applies on next start)',
              child: Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Icon(Icons.lock, color: Colors.white54, size: 18),
              ),
            ),

          if (_bgState == BgState.playing || _isPreviewing)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.graphic_eq, color: teal2, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Draggable tutorial bottom sheet with English/Hindi toggle
  void _showTutorial() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.92),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16.0),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.02)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: StatefulBuilder(
                builder: (sheetCtx, sheetSetState) {
                  String t(String en, String hi) => _tutorialInHindi ? hi : en;

                  Widget headerToggle() {
                    return Row(
                      children: [
                        Text(
                          _tutorialInHindi ? 'Switch to EN' : 'Switch to हिंदी',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _tutorialInHindi,
                          activeColor: teal3,
                          onChanged: (v) {
                            sheetSetState(() => _tutorialInHindi = v);
                            setState(() => _tutorialInHindi = v);
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 6,
                          width: 60,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t(
                                  'Mini Meditation Timer — Tutorial',
                                  'मिनी मेडिटेशन टाइमर — ट्यूटोरियल',
                                ),
                                style: const TextStyle(
                                  color: teal2,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // language toggle + close
                        headerToggle(),
                        const SizedBox(height: 8),

                        Text(
                          t('What is this?', 'यह क्या है?'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'A compact meditation timer with optional background loops and periodic bell cues. Use it for short focused sessions or as a quick reset.',
                            'एक कॉम्पैक्ट मेडिटेशन टाइमर जिसमें पृष्ठभूमि लूप और आवधिक घंटी संकेत विकल्प हैं। इसे छोटे सत्रों या त्वरित पुनरारंभ के लिए उपयोग करें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('How to use (quick)', 'कैसे उपयोग करें (संक्षेप)'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '1. Choose duration using the Duration slider.\n'
                                '2. Optionally select a background loop (Rain/Ocean/OM Chant) and preview it.\n'
                                '3. Set bell interval or turn off.\n'
                                '4. Press Start — background will fade in and bell cues play at intervals.',
                            '1. Duration स्लाइडर से अवधि चुनें।\n'
                                '2. वैकल्पिक रूप से पृष्ठभूमि लूप (Rain/Ocean/OM Chant) चुनें और पूर्वावलोकन करें।\n'
                                '3. घंटी अंतराल सेट करें या बंद करें।\n'
                                '4. Start दबाएँ — पृष्ठभूमि धीरे से फेड इन होगी और घंटी संकेत निर्धारित अंतराल पर बजेगी।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('Background & preview', 'पृष्ठभूमि और पूर्वावलोकन'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'Preview plays a short snippet without affecting your active loop. Use the volume chip to adjust background volume. Live switching only applies if "apply immediately" is enabled.',
                            'पूर्वावलोकन सक्रिय लूप को प्रभावित किए बिना छोटी क्लिप चलाता है। पृष्ठभूमि की मात्रा समायोजित करने के लिए वॉल्यूम चिप का उपयोग करें। यदि "apply immediately" सक्षम है तो ही लाइव स्विच लागू होगा।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('Tips & safety', 'टिप्स और सुरक्षा'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '• Use gentle background volume so cues remain audible.\n'
                                '• Test the bell using the Test bell button.\n'
                                '• If you experience discomfort from continuous background sound, stop the loop.',
                            '• संकेत सुनाई देने के लिए पृष्ठभूमि की मात्रा हल्की रखें।\n'
                                '• Test bell बटन से घंटी का परीक्षण करें।\n'
                                '• यदि निरंतर पृष्ठभूमि ध्वनि असुविधा दे तो लूप बंद करें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('Quick controls', 'त्वरित नियंत्रण'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _tutorialRow(
                          t('Duration', 'अवधि'),
                          t(
                            'Set session length in minutes',
                            'सत्र की लंबाई मिनट में सेट करें',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _tutorialRow(
                          t('Bell interval', 'घंटी अंतराल'),
                          t(
                            'Set periodic bell cues (or turn off)',
                            'आवधिक घंटी संकेत सेट करें (या बंद करें)',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _tutorialRow(
                          t('Background', 'पृष्ठभूमि'),
                          t(
                            'Choose loop, preview, and adjust volume',
                            'लूप चुनें, पूर्वावलोकन करें, और वॉल्यूम समायोजित करें',
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _startSession();
                                },
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  t('Start session', 'सत्र शुरू करें'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teal3,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                              ),
                              child: Text(
                                t('Close', 'बंद करें'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _tutorialRow(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: teal3, shape: BoxShape.circle),
          child: Center(
            child: Icon(Icons.info_outline, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final circle = (screenW * 0.56).clamp(100.0, 360.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini Meditation Timer'),
        backgroundColor: teal4,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Tutorial',
            onPressed: _showTutorial,
            icon: const Icon(Icons.help_outline, color: Colors.white70),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF012B2B), Color(0xFF003737)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Duration',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _minutes.toDouble(),
                              min: 1,
                              max: 60,
                              divisions: 59,
                              activeColor: teal2,
                              inactiveColor: Colors.white12,
                              onChanged: _isRunning
                                  ? null
                                  : (v) => setState(() => _minutes = v.toInt()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_minutes m',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const SizedBox(width: 8),
                const Text(
                  'Bell every',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _bellIntervalSec.toDouble(),
                    min: 0,
                    max: 300,
                    divisions: 12,
                    label: _bellIntervalSec == 0
                        ? 'Off'
                        : '$_bellIntervalSec s',
                    activeColor: teal2,
                    inactiveColor: Colors.white12,
                    onChanged: _isRunning
                        ? null
                        : (v) => setState(() => _bellIntervalSec = v.toInt()),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: Text(
                    _bellIntervalSec == 0 ? 'Off' : '${_bellIntervalSec}s',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Card(
              color: Colors.transparent,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6.0,
                  horizontal: 8.0,
                ),
                child: _buildBackgroundSelector(),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: Center(
                child: SizedBox(
                  width: circle,
                  height: circle,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: circle,
                        height: circle,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 12,
                          valueColor: AlwaysStoppedAnimation(
                            teal4.withOpacity(0.24),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, _) {
                          final value = _progressController.value.clamp(
                            0.0,
                            1.0,
                          );
                          return SizedBox(
                            width: circle,
                            height: circle,
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 12,
                              valueColor: AlwaysStoppedAnimation(teal2),
                              backgroundColor: Colors.transparent,
                            ),
                          );
                        },
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _remainingSeconds > 0
                                ? _formatTime(_remainingSeconds)
                                : _minutes == 0
                                ? '00:00'
                                : _formatTime(_minutes * 60),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isRunning ? 'In session' : 'Ready',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_isRunning) {
                        _pauseSession();
                      } else {
                        if (_progressController.isDismissed ||
                            _remainingSeconds == 0) {
                          _startSession();
                        } else {
                          _resumeSession();
                        }
                      }
                    },
                    icon: Icon(
                      _isRunning
                          ? Icons.pause
                          : (_progressController.isDismissed
                                ? Icons.play_arrow
                                : Icons.play_arrow),
                    ),
                    label: Text(
                      _isRunning
                          ? 'Pause'
                          : (_progressController.isDismissed
                                ? 'Start'
                                : 'Resume'),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: teal3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _stopSession(),
                  icon: const Icon(Icons.stop),
                  color: Colors.redAccent,
                  tooltip: 'Stop',
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () async {
                    await _playCue();
                  },
                  icon: const Icon(Icons.notifications_active),
                  color: teal2,
                  tooltip: 'Test bell',
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
