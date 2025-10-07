// lib/screens/relax_breath_page.dart
// Guided breathing exercise page — improved sphere animation synchronized with phases.
// Integrated flutter_tts for spoken guidance (EN/HI) + small TTS on/off toggle.
// Requires in pubspec.yaml:
//   audioplayers: ^6.5.1
//   vibration: ^3.1.4
//   flutter_tts: ^3.6.0
// And an asset registered in pubspec.yaml:
// flutter:
//   assets:
//     - assets/sounds/bell_short.mp3

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';

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

  // TTS
  late FlutterTts _tts;
  bool _ttsEnabled = true; // small toggle in appbar

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

  // NEW: tutorial language toggle (false = English, true = Hindi)
  bool _tutorialInHindi = false;

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

    // Initialize TTS
    _tts = FlutterTts();
    _configureTts();
  }

  Future<void> _configureTts() async {
    try {
      // Default settings — adjust if you like
      await _tts.setSpeechRate(0.48); // slower, calm guidance
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Optionally set a fallback language; we'll change language before each speak
      // await _tts.setLanguage('en-US');

      // Some platforms require this call to avoid multiple overlapping utterances
      _tts.setCompletionHandler(() {
        // Nothing for now; kept so we don't leave dangling listeners
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopSession();
    _phaseController.dispose();
    _breathPulseController.dispose();
    _audioPlayer.dispose();
    try {
      _tts.stop();
    } catch (_) {}
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
    try {
      _tts.stop();
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

  Future<void> _enterPhase(BreathPhase p) async {
    // cancel previous timers
    _phaseTickTimer?.cancel();
    _phaseEndTimer?.cancel();

    setState(() {
      _phase = p;
      _phaseSecondsRemaining = _phaseDuration(p);
    });

    // speak the phase if enabled
    if (_ttsEnabled) {
      _speakPhase(p);
    }

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

  /// Speak helper that sets language depending on _tutorialInHindi and uses
  /// a calm phrase for the user. Uses short phrases (avoid long TTS utterances).
  Future<void> _speakPhase(BreathPhase p) async {
    if (!_ttsEnabled) return;
    try {
      final isHindi = _tutorialInHindi;
      String text;
      switch (p) {
        case BreathPhase.inhale:
          text = isHindi
              ? 'साँस अंदर लें, ${_inhaleSec} सेकंड'
              : 'Inhale for ${_inhaleSec} seconds';
          break;
        case BreathPhase.hold:
          text = isHindi
              ? 'रोकें, ${_holdSec} सेकंड'
              : 'Hold for ${_holdSec} seconds';
          break;
        case BreathPhase.exhale:
          text = isHindi
              ? 'साँस छोड़ें, ${_exhaleSec} सेकंड'
              : 'Exhale for ${_exhaleSec} seconds';
          break;
        case BreathPhase.finished:
        default:
          text = isHindi ? 'सत्र समाप्त' : 'Session finished';
          break;
      }

      // set language before speaking
      await _tts.setLanguage(isHindi ? 'hi-IN' : 'en-US');

      // short speak. do not await long operations to avoid blocking UI updates
      await _tts.speak(text);
    } catch (_) {}
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
                                  'Guided Breathing — Tutorial',
                                  'निर्देशित श्वसन — ट्यूटोरियल',
                                ),
                                style: TextStyle(
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
                        const SizedBox(height: 6),

                        Text(
                          t('What is this exercise?', 'यह अभ्यास क्या है?'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'A guided breathing exercise helps regulate your breath and calm the nervous system by following a simple inhale → hold → exhale pattern. Use the sliders to adjust inhale/hold/exhale durations to your comfort.',
                            'निर्देशित श्वसन अभ्यास आपकी साँस को नियमित करने और स्नायविक तंत्र को शांत करने में मदद करता है। यह inhale → hold → exhale पैटर्न का पालन करता है। अपनी सुविधा के अनुसार अवधि समायोजित करने के लिए स्लाइडर का उपयोग करें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('How to use (quick)', 'कैसे उपयोग करें (संकलित)'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '1. Choose session length (minutes) using the slider.\n'
                                '2. Adjust inhale, hold and exhale seconds using the sliders below.\n'
                                '3. Press Start to begin; the bell and a gentle vibration will mark phase changes.\n'
                                '4. Follow the expanding/contracting sphere to pace your breath.',
                            '1. सेशन की लम्बाई (मिनट) स्लाइडर से चुनें।\n'
                                '2. नीचे दिए गए स्लाइडर्स से inhale, hold और exhale सेकंड समायोजित करें।\n'
                                '3. शुरू करने के लिए Start दबाएँ; चरण परिवर्तन के लिए घन्टी और हल्का वाइब्रेशन होगा।\n'
                                '4. अपनी साँस की गति के लिए बढ़ते/संकुचित होते गोले का पालन करें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('Timing guidance', 'समय संबंधी मार्गदर्शन'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'Common patterns: 4-4-6, 5-5-8, or 4-2-6 (inhale-hold-exhale). Start gently and do not strain. Adjust times to what feels comfortable.',
                            'सामान्य पैटर्न: 4-4-6, 5-5-8, या 4-2-6 (inhale-hold-exhale)। धीरे शुरू करें और ज़ोर न लगाएँ। समय अपनी सहूलियत अनुसार समायोजित करें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('Safety & tips', 'सुरक्षा और सुझाव'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '• Sit comfortably with straight spine or lie down.\n'
                                '• Do not force breath; if you feel dizzy, stop and breathe normally.\n'
                                '• For medical conditions (recent surgery, severe respiratory or cardiovascular issues, pregnancy), consult a professional before trying intense breathwork.',
                            '• सीधे रीढ़ के साथ आराम से बैठें या लेटें।\n'
                                '• साँस को बलपूर्वक न लें; यदि चक्कर आएँ तो रुकें और सामान्य साँस लें।\n'
                                '• यदि चिकित्सा स्थिति हो (हाल की सर्जरी, श्वसन/हृदय संबंधी गंभीर समस्याएँ, गर्भावस्था), तो पहले विशेषज्ञ से सलाह लें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('Quick step reference', 'त्वरित चरण सार'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _tutorialRow(
                          1,
                          t('Inhale', 'साँस अंदर लें'),
                          t(
                            'Grow the sphere slowly for the inhale duration.',
                            'इनहेल अवधि के दौरान गोला धीरे-धीरे बढ़ाएँ।',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _tutorialRow(
                          2,
                          t('Hold', 'रोकें'),
                          t(
                            'Hold gently at the peak — do not strain.',
                            'पीक पर हल्के से रोकें — ज़ोर न लगाएँ।',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _tutorialRow(
                          3,
                          t('Exhale', 'साँस बाहर छोड़ें'),
                          t(
                            'Slowly let the sphere contract for the exhale duration.',
                            'एक्सहेल अवधि में गोला धीरे-धीरे सिकुड़े।',
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  // start session fresh
                                  _startSession();
                                },
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  t(
                                    'Start breathing session',
                                    'श्वसन सत्र शुरू करें',
                                  ),
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

  Widget _tutorialRow(int num, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: teal3, shape: BoxShape.circle),
          child: Center(
            child: Text(
              '$num',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
        actions: [
          IconButton(
            tooltip: 'Tutorial',
            onPressed: _showTutorial,
            icon: const Icon(Icons.help_outline, color: Colors.white70),
          ),
          // small TTS enable/disable toggle
          IconButton(
            tooltip: _ttsEnabled ? 'TTS: On' : 'TTS: Off',
            onPressed: () {
              setState(() => _ttsEnabled = !_ttsEnabled);
            },
            icon: Icon(
              _ttsEnabled ? Icons.volume_up : Icons.volume_off,
              color: Colors.white70,
            ),
          ),
        ],
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
