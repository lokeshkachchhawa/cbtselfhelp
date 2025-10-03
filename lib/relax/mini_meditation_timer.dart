// lib/screens/mini_meditation_timer.dart
// Mini Meditation Timer — Dark teal theme, compact single-file screen
// Updated: improved background music selection & playback logic
// - Selection applies on session start (recommended behaviour)
// - Optional live-switching flag (set _applyBgImmediately = true)
// - Cross-fade helper for gentle transitions
// - Stable preview player (doesn't affect loop player)
// - Visual playing indicator and lock tooltip

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

// Teal palette (consistent with user's preference)
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
  // audio players
  final AudioPlayer _bellPlayer = AudioPlayer();
  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _previewPlayer = AudioPlayer();

  // background track registry (displayName -> asset path)
  final Map<String, String> _bgTracks = {
    'None': '',
    'Rain': 'sounds/bg_rain.mp3',
    'Ocean': 'sounds/bg_ocean.mp3',
    'OM Chant': 'sounds/bg_om_chant.mp3',
  };

  String _selectedBg = 'None';
  double _bgVolume = 0.6; // 0.0 .. 1.0

  // whether selecting background applies immediately while running
  // set this to true if you want live switching behaviour
  bool _applyBgImmediately = false;

  // background playback state
  BgState _bgState = BgState.none;
  bool _isPreviewing = false;

  // configuration
  int _minutes = 5; // session length in minutes (1..60)
  int _bellIntervalSec = 60; // 0 = off, otherwise play bell every N seconds

  // runtime state
  late AnimationController _progressController; // 0.0 -> 1.0 over session
  Timer? _cueTimer; // periodic bell timer
  Timer? _sessionTimer; // fallback, keeps safe countdown
  Timer? _previewTimer;
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _setupAudio();

    // default controller; we'll set duration on start
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSessionComplete();
      }
    });

    // Listen to background player state changes for accurate state management
    _bgPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (!mounted) return;
      setState(() {
        switch (state) {
          case PlayerState.playing:
            _bgState = BgState.playing;
            break;
          case PlayerState.paused:
            _bgState = BgState.paused;
            break;
          case PlayerState.stopped:
          case PlayerState.completed:
            _bgState = BgState.none;
            break;
          default:
            _bgState = BgState.none;
        }
      });
    });
  }

  Future<void> _setupAudio() async {
    try {
      await _bellPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _bellPlayer.setVolume(1.0);
      await _bgPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setVolume(_bgVolume);
      await _previewPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    } catch (_) {}
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _cueTimer?.cancel();
    _sessionTimer?.cancel();
    _progressController.dispose();
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

  // ------------------ audio helpers ------------------
  Future<void> _playCue() async {
    try {
      await _bellPlayer.stop();
      await _bellPlayer.setSource(AssetSource('sounds/bell_short.mp3'));
      await _bellPlayer.resume();
    } catch (_) {}

    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 36);
      }
    } catch (_) {}

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  // Simple linear fade helper (non-blocking, but awaited where used)
  Future<void> _fadeVolume(
    AudioPlayer player,
    double from,
    double to, {
    int steps = 8,
    int stepMs = 40,
  }) async {
    try {
      final diff = to - from;
      for (int i = 1; i <= steps; i++) {
        final next = (from + diff * (i / steps)).clamp(0.0, 1.0);
        await player.setVolume(next);
        await Future.delayed(Duration(milliseconds: stepMs));
      }
    } catch (_) {}
  }

  void _stopPreview({bool resumeBg = true}) async {
    try {
      await _previewPlayer.stop();
    } catch (_) {}
    final shouldResumeBg = resumeBg && _bgState == BgState.paused && _isRunning;
    if (mounted) {
      setState(() {
        _isPreviewing = false;
        if (shouldResumeBg) {
          _bgState = BgState.playing;
        }
      });
    }
    if (shouldResumeBg) {
      try {
        await _bgPlayer.setVolume(0.0);
        await _bgPlayer.resume();
        unawaited(_fadeVolume(_bgPlayer, 0.0, _bgVolume));
      } catch (_) {}
    }
    _previewTimer?.cancel();
    _previewTimer = null;
  }

  // Apply selected background when session starts (recommended behaviour)
  Future<void> _applySelectedBackground() async {
    final asset = _bgTracks[_selectedBg] ?? '';
    if (asset.isEmpty) {
      _bgState = BgState.none;
      return;
    }

    try {
      await _bgPlayer.stop();
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setSource(AssetSource(asset));
      // start muted and fade into configured volume
      await _bgPlayer.setVolume(0.0);
      await _bgPlayer.resume();
      setState(() => _bgState = BgState.playing);
      unawaited(_fadeVolume(_bgPlayer, 0.0, _bgVolume));
    } catch (e) {
      setState(() => _bgState = BgState.none);
    }
  }

  // Live switch with cross-fade (used only if _applyBgImmediately == true)
  Future<void> _switchBackgroundLive() async {
    final newAsset = _bgTracks[_selectedBg] ?? '';
    if (newAsset.isEmpty) {
      if (_bgState == BgState.playing) {
        await _fadeVolume(_bgPlayer, _bgVolume, 0.0);
        await _bgPlayer.stop();
        setState(() => _bgState = BgState.none);
      }
      return;
    }

    try {
      // fade out current
      await _fadeVolume(_bgPlayer, _bgVolume, 0.0);
      await _bgPlayer.stop();
      await _bgPlayer.setSource(AssetSource(newAsset));
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setVolume(0.0);
      await _bgPlayer.resume();
      setState(() => _bgState = BgState.playing);
      unawaited(_fadeVolume(_bgPlayer, 0.0, _bgVolume));
    } catch (_) {
      setState(() => _bgState = BgState.none);
    }
  }

  Future<void> _stopBackground({bool fade = true}) async {
    if (_bgState != BgState.playing) {
      try {
        await _bgPlayer.stop();
      } catch (_) {}
      setState(() => _bgState = BgState.none);
      return;
    }

    try {
      if (fade) await _fadeVolume(_bgPlayer, _bgVolume, 0.0);
      await _bgPlayer.stop();
    } catch (_) {}
    setState(() => _bgState = BgState.none);
  }

  // Preview uses a temporary player and never affects the loop player
  Future<void> _previewBackground() async {
    final asset = _bgTracks[_selectedBg] ?? '';
    if (asset.isEmpty) return;

    final originalState = _bgState;
    bool pausedForPreview = false;
    try {
      if (originalState == BgState.playing) {
        await _fadeVolume(_bgPlayer, _bgVolume, 0.0);
        await _bgPlayer.pause();
        pausedForPreview = true;
        setState(() => _bgState = BgState.paused);
      }

      await _previewPlayer.stop();
      await _previewPlayer.setReleaseMode(ReleaseMode.stop);
      await _previewPlayer.setVolume(_bgVolume);
      await _previewPlayer.setSource(AssetSource(asset));
      await _previewPlayer.resume();
      setState(() => _isPreviewing = true);
      _previewTimer?.cancel();
      _previewTimer = Timer(
        const Duration(seconds: 6),
        () => _stopPreview(resumeBg: true),
      );
    } catch (e) {
      if (pausedForPreview && originalState == BgState.playing) {
        try {
          setState(() => _bgState = BgState.playing);
          await _bgPlayer.setVolume(0.0);
          await _bgPlayer.resume();
          unawaited(_fadeVolume(_bgPlayer, 0.0, _bgVolume));
        } catch (_) {}
      }
      setState(() => _isPreviewing = false);
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
      // live switch
      _switchBackgroundLive();
    } else if (_isRunning && !_applyBgImmediately) {
      // inform user subtly that change will apply on next start/resume
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
      if (_bgState == BgState.playing) {
        _fadeVolume(_bgPlayer, _bgVolume, 0.0);
        _bgPlayer.pause();
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
        // if player was stopped, apply selected background
        if (_bgState == BgState.none) {
          await _applySelectedBackground();
        } else {
          await _bgPlayer.setVolume(0.0);
          await _bgPlayer.resume();
          unawaited(_fadeVolume(_bgPlayer, 0.0, _bgVolume));
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

    // final gentle cue
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
        color: const Color(0xFF031818), // subtle card surface
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
          // Label with small accent dot
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

          // Dropdown (styled to look like a single control)
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

          // Preview button
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

          // Volume control as chip that opens modal slider
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
                        // StatefulBuilder gives a local setState for the sheet
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

                                  // IMPORTANT: call both the sheet-local set and the parent setState
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

          // lock indicator when session is running
          if (_isRunning && !_applyBgImmediately)
            const Tooltip(
              message:
                  'Background locked while session is running (applies on next start)',
              child: Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Icon(Icons.lock, color: Colors.white54, size: 18),
              ),
            ),

          // playing indicator
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
            // configuration row: duration
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

            // bell interval control
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

            // background selector + preview
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

            // progress ring + label
            Expanded(
              child: Center(
                child: SizedBox(
                  width: circle,
                  height: circle,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // background ring
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

                      // animated progress
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

                      // center label
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

            // controls
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
                    // quick test cue
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
