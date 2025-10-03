// lib/screens/relax_breath_page.dart
// Guided breathing exercise page — improved sphere animation synchronized with phases.
// Requires:
//   audioplayers: ^6.5.1
//   vibration: ^3.1.4
// And an asset registered in pubspec.yaml:
// flutter:
//   assets:
//     - assets/sounds/bell_short.mp3

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

// Primary teal palette (kept from original)
const Color teal1 = Color(0xFFC6EDED);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);

enum BreathPhase { inhale, hold, exhale, finished }

class RelaxBreathPage extends StatefulWidget {
  const RelaxBreathPage({super.key});

  @override
  State<RelaxBreathPage> createState() => _RelaxBreathPageState();
}

class _RelaxBreathPageState extends State<RelaxBreathPage>
    with TickerProviderStateMixin {
  // Two controllers:
  //  - _phaseController animates shape scale from 0..1 for inhale/exhale
  //  - _breathPulseController drives a gentle continuous micro-pulse (subtle)
  late AnimationController _phaseController;
  late Animation<double> _phaseScaleAnim; // maps 0..1 -> scale
  late AnimationController _breathPulseController;
  late Animation<double> _breathPulseAnim;

  // Audio & haptics
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Configurable durations
  int _inhaleSec = 5;
  int _holdSec = 5;
  int _exhaleSec = 8;

  // Session length (minutes)
  int _sessionMinutes = 2;

  // Runtime state
  bool _isRunning = false;
  BreathPhase _phase = BreathPhase.finished;

  // timers & counters
  Timer? _sessionTimer;
  Timer? _phaseTickTimer;
  Timer? _phaseEndTimer;
  int _sessionSecondsRemaining = 0;
  int _phaseSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();

    // phase controller starts duration 1s (we will set per-phase when entering)
    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // phaseScaleAnim uses an eased curve for smooth grow/shrink
    _phaseScaleAnim = CurvedAnimation(
      parent: _phaseController,
      curve: Curves.easeInOut,
    );

    // subtle pulse (very gentle, continuous) to make the circle feel alive
    _breathPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
    _breathPulseAnim = Tween<double>(begin: 0.0, end: 0.04).animate(
      CurvedAnimation(parent: _breathPulseController, curve: Curves.easeInOut),
    );

    // Try to set audio player to low latency for quick cue playback
    try {
      _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopSession();
    _phaseController.dispose();
    _breathPulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playCue() async {
    try {
      await _audioPlayer.stop();
      // Use AssetSource path relative to assets/ registration:
      // if pubspec.yaml has assets/sounds/bell_short.mp3 then use 'sounds/bell_short.mp3'
      await _audioPlayer.setSource(AssetSource('sounds/bell_short.mp3'));
      await _audioPlayer.resume();
    } catch (e) {
      // ignore audio errors in release; useful during dev:
      // debugPrint('Audio play error: $e');
    }

    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 28);
      }
    } catch (_) {}

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  int _phaseDuration(BreathPhase p) {
    switch (p) {
      case BreathPhase.inhale:
        return _inhaleSec;
      case BreathPhase.hold:
        return _holdSec;
      case BreathPhase.exhale:
        return _exhaleSec;
      case BreathPhase.finished:
      default:
        return 0;
    }
  }

  void _startSession() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _sessionSecondsRemaining = _sessionMinutes * 60;
    });

    // session countdown timer
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _sessionSecondsRemaining--;
      });
      if (_sessionSecondsRemaining <= 0) {
        _endSession();
      }
    });

    // immediately start inhale phase
    _enterPhase(BreathPhase.inhale);
    _playCue();
  }

  void _stopSession() {
    _sessionTimer?.cancel();
    _phaseTickTimer?.cancel();
    _phaseEndTimer?.cancel();
    _isRunning = false;
    _phase = BreathPhase.finished;
    try {
      _phaseController.stop();
      _phaseController.reset();
    } catch (_) {}
  }

  void _endSession() {
    _stopSession();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Breathing session complete')),
      );
    }
  }

  void _enterPhase(BreathPhase p) {
    // cancel previous timers
    _phaseTickTimer?.cancel();
    _phaseEndTimer?.cancel();

    setState(() {
      _phase = p;
      _phaseSecondsRemaining = _phaseDuration(p);
    });

    // Configure animation depending on phase:
    if (p == BreathPhase.inhale) {
      // scale from 0..1 (we map later to visual range)
      _phaseController.duration = Duration(
        seconds: _inhaleSec.clamp(1, 600) as int,
      );
      // animate to 1.0 (grow)
      _phaseController.animateTo(1.0, curve: Curves.easeOut);
    } else if (p == BreathPhase.hold) {
      // hold: keep controller at 1.0 (peak)
      _phaseController.stop(canceled: false);
      _phaseController.value = 1.0;
    } else if (p == BreathPhase.exhale) {
      _phaseController.duration = Duration(
        seconds: _exhaleSec.clamp(1, 600) as int,
      );
      // animate back to 0.0 (shrink)
      _phaseController.animateTo(0.0, curve: Curves.easeIn);
    }

    // per-second tick for UI countdown
    _phaseTickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _phaseSecondsRemaining--;
      });
    });

    // schedule end-of-phase
    final dur = Duration(seconds: _phaseDuration(p));
    _phaseEndTimer = Timer(dur, () {
      _phaseTickTimer?.cancel();
      if (!mounted) return;
      switch (p) {
        case BreathPhase.inhale:
          _playCue();
          _enterPhase(BreathPhase.hold);
          break;
        case BreathPhase.hold:
          _playCue();
          _enterPhase(BreathPhase.exhale);
          break;
        case BreathPhase.exhale:
          _playCue();
          // continue if session left
          if (_sessionSecondsRemaining > 0) {
            _enterPhase(BreathPhase.inhale);
          } else {
            _endSession();
          }
          break;
        case BreathPhase.finished:
        default:
          _endSession();
          break;
      }
    });
  }

  void _pauseOrResume() {
    if (!_isRunning) return;
    // Pause timers & animation. For simplicity resume starts fresh.
    _sessionTimer?.cancel();
    _phaseTickTimer?.cancel();
    _phaseEndTimer?.cancel();
    _phaseController.stop();
    setState(() => _isRunning = false);
  }

  String _phaseLabel() {
    switch (_phase) {
      case BreathPhase.inhale:
        return 'Inhale';
      case BreathPhase.hold:
        return 'Hold';
      case BreathPhase.exhale:
        return 'Exhale';
      case BreathPhase.finished:
      default:
        return '';
    }
  }

  String _formatSessionTime() {
    final s = _sessionSecondsRemaining;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // Map controller value (0..1) to visual scale (0.7 .. 1.35) and glow intensity
  double _visualScale(double t) {
    const min = 0.68;
    const max = 1.35;
    return min + (max - min) * t;
  }

  double _glowAlphaFromScale(double scale) {
    // returns 0..1 alpha for glow; larger when scale near peak
    final normal = (scale - 0.68) / (1.35 - 0.68);
    return (0.25 + normal * 0.65).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final baseCircle = screenW * 0.46;

    // Dark teal background gradient (kept subtle)
    const darkBgTop = Color(0xFF012B2B);
    const darkBgBottom = Color(0xFF003737);

    // Text colors for dark theme
    const primaryText = Colors.white;
    final secondaryText = Colors.white.withOpacity(0.78);
    final subtleText = Colors.white.withOpacity(0.56);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breathing Exercise'),
        backgroundColor: teal4, // keep teal appbar
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [darkBgTop, darkBgBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // header: session slider & start/stop
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Session length',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  min: 1,
                                  max: 20,
                                  divisions: 19,
                                  value: _sessionMinutes.toDouble(),
                                  activeColor: teal2,
                                  inactiveColor: Colors.white24,
                                  onChanged: _isRunning
                                      ? null
                                      : (v) => setState(
                                          () => _sessionMinutes = v.toInt(),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_sessionMinutes}m',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRunning
                            ? Colors.red.shade400
                            : teal3,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black45,
                      ),
                      onPressed: _isRunning ? _endSession : _startSession,
                      child: Text(_isRunning ? 'Stop' : 'Start'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Animated breathing sphere + overlay text
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _phaseController,
                        _breathPulseController,
                      ]),
                      builder: (context, _) {
                        final t = _phaseController.value.clamp(0.0, 1.0);
                        final pulse = _breathPulseAnim.value;
                        final scale = _visualScale(t) * (1.0 + pulse * 0.015);
                        final glowAlpha = _glowAlphaFromScale(_visualScale(t));

                        final currentPhaseSeconds = _phaseSecondsRemaining;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // soft outer glow (darker, teal-tinted)
                            Container(
                              width: baseCircle * scale * 1.45,
                              height: baseCircle * scale * 1.45,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                      0.28 * glowAlpha,
                                    ),
                                    blurRadius: 36 * (0.8 + glowAlpha),
                                    spreadRadius: 2 * glowAlpha,
                                  ),
                                  BoxShadow(
                                    color: teal2.withOpacity(0.14 * glowAlpha),
                                    blurRadius: 22 * glowAlpha,
                                    spreadRadius: 2 * glowAlpha,
                                  ),
                                ],
                              ),
                            ),

                            // main circle (darker teal radial gradient)
                            Container(
                              width: baseCircle * scale,
                              height: baseCircle * scale,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    teal3.withOpacity(0.98),
                                    teal2.withOpacity(0.88),
                                    Colors.black.withOpacity(0.08),
                                  ],
                                  center: const Alignment(-0.2, -0.2),
                                  radius: 0.95,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.34),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.04),
                                  width: 1,
                                ),
                              ),
                            ),

                            // inner luminous ring (muted for dark theme)
                            Container(
                              width: baseCircle * scale * 0.78,
                              height: baseCircle * scale * 0.78,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  stops: const [0.0, 0.55, 1.0],
                                  colors: [
                                    Colors.white.withOpacity(
                                      0.06 + 0.04 * glowAlpha,
                                    ),
                                    Colors.white.withOpacity(0.02),
                                    Colors.white.withOpacity(0.01),
                                  ],
                                ),
                              ),
                            ),

                            // overlay: phase label and big seconds counter with low opacity
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Opacity(
                                  opacity: 0.96,
                                  child: Text(
                                    _phaseLabel(),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: primaryText,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Opacity(
                                  opacity: 0.16,
                                  child: Text(
                                    _isRunning
                                        ? '${currentPhaseSeconds}s'
                                        : '--',
                                    style: TextStyle(
                                      fontSize: 88,
                                      fontWeight: FontWeight.w900,
                                      color: primaryText,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_isRunning)
                                  Opacity(
                                    opacity: 0.95,
                                    child: Text(
                                      'Session: ${_formatSessionTime()}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Duration controls for inhale/hold/exhale
                Column(
                  children: [
                    _buildDurationRow('Inhale', _inhaleSec, (v) {
                      if (!_isRunning) setState(() => _inhaleSec = v);
                    }, activeColor: teal2),
                    _buildDurationRow('Hold', _holdSec, (v) {
                      if (!_isRunning) setState(() => _holdSec = v);
                    }, activeColor: teal4),
                    _buildDurationRow('Exhale', _exhaleSec, (v) {
                      if (!_isRunning) setState(() => _exhaleSec = v);
                    }, activeColor: Colors.orange.shade700),
                  ],
                ),

                const SizedBox(height: 8),
                const Text(
                  'Inhale → Hold → Exhale\nHaptic & bell cues mark phase transitions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationRow(
    String label,
    int seconds,
    ValueChanged<int> onChanged, {
    Color? activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: seconds.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              activeColor: activeColor,
              inactiveColor: Colors.white24,
              onChanged: _isRunning ? null : (v) => onChanged(v.toInt()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            child: Text(
              '$seconds s',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
