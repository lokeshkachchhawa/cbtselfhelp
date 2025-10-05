// lib/screens/relax_pmr_page.dart
// Progressive Muscle Relaxation page (PMR) - DARK THEME (teal palette)
// - step-by-step tense-hold-release exercises
// - per-step timers, autoplay option, haptic/audio cues
// Keep functionality identical to original; only styling adjusted for a dark, teal-themed UI.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

// Teal palette (user preference) - darker teal primary tones
const Color teal1 = Color(0xFF016C6C); // deep teal
const Color teal2 = Color(0xFF79C2BF); // light accent
const Color teal3 = Color(0xFF008F89); // primary accent
const Color teal4 = Color(0xFF005E5C); // darker accent
const Color surfaceDark = Color(0xFF081015); // near-black background for depth
const Color cardDark = Color(0xFF092426); // deep card surface
const Color mutedText = Color(0xFFBFDCDC);
const Color dimText = Color(0xFFA3CFCB);

class PmrStep {
  final String title;
  final String instruction;
  final int tensionSeconds;
  final int relaxSeconds;

  const PmrStep({
    required this.title,
    required this.instruction,
    this.tensionSeconds = 5,
    this.relaxSeconds = 8,
  });
}

class RelaxPmrPage extends StatefulWidget {
  const RelaxPmrPage({super.key});

  @override
  State<RelaxPmrPage> createState() => _RelaxPmrPageState();
}

enum _PmrPhase { ready, tension, hold, relax, finished }

class _RelaxPmrPageState extends State<RelaxPmrPage> {
  final List<PmrStep> _defaultSteps = const [
    PmrStep(
      title: 'Hands & Fingers',
      instruction: 'Clench fists and curl fingers.',
    ),
    PmrStep(
      title: 'Wrists & Forearms',
      instruction: 'Bend backwards then tense the forearm.',
    ),
    PmrStep(
      title: 'Upper Arms / Biceps',
      instruction: 'Tighten your upper arms.',
    ),
    PmrStep(
      title: 'Shoulders',
      instruction: 'Lift shoulders toward ears and hold.',
    ),
    PmrStep(
      title: 'Neck',
      instruction: 'Gently press chin to chest and tense neck.',
    ),
    PmrStep(
      title: 'Face (Jaw, Eyes)',
      instruction: 'Clench jaw, squeeze eyes shut.',
    ),
    PmrStep(
      title: 'Chest & Back',
      instruction: 'Take a deep breath and tense chest/back.',
    ),
    PmrStep(title: 'Stomach', instruction: 'Tighten stomach muscles.'),
    PmrStep(title: 'Thighs', instruction: 'Squeeze thigh muscles hard.'),
    PmrStep(
      title: 'Calves & Feet',
      instruction: 'Point toes and tighten calves, then relax.',
    ),
  ];

  final AudioPlayer _audio = AudioPlayer();

  late List<PmrStep> _steps;
  int _index = 0;
  _PmrPhase _phase = _PmrPhase.ready;
  bool _isRunning = false;
  bool _autoAdvance = true;
  Timer? _tickTimer;
  Timer? _phaseEndTimer;
  int _phaseSecondsRemaining = 0;

  // NEW: tutorial language toggle (false = English, true = Hindi)
  bool _tutorialInHindi = false;

  @override
  void initState() {
    super.initState();
    _steps = List<PmrStep>.from(_defaultSteps);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _phaseEndTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _confirmAndStop(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dctx) {
        return AlertDialog(
          title: const Text('Stop & Reset'),
          content: const Text(
            'Are you sure you want to stop and reset the session?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('Stop'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _stopSequence();
    }
  }

  Future<void> _playCue() async {
    try {
      await _audio.stop();
      await _audio.play(AssetSource('sounds/bell_short.mp3'));
    } catch (_) {}

    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 40);
      }
    } catch (_) {}
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void _startSequence({bool restartCurrent = false}) {
    if (_isRunning) return;

    // if we are mid-session and user didn't ask to restart current phase,
    // resume the phase (restore timers based on remaining seconds)
    if (!restartCurrent &&
        _phase != _PmrPhase.ready &&
        _phase != _PmrPhase.finished) {
      _resumePhase();
      return;
    }

    // otherwise start fresh from tension phase (or restart current if requested)
    setState(() {
      _isRunning = true;
    });

    // start from the tension phase of the current step
    _enterPhase(_PmrPhase.tension);
  }

  void _pauseSequence() {
    _tickTimer?.cancel();
    _phaseEndTimer?.cancel();
    setState(() {
      _isRunning = false;
      // _phaseSecondsRemaining intentionally kept so resume picks up the remaining time
    });
  }

  void _stopSequence() {
    // cancel timers and audio/haptics
    _tickTimer?.cancel();
    _phaseEndTimer?.cancel();
    try {
      _audio.stop();
    } catch (_) {}
    // reset to initial session state (step 0, ready)
    setState(() {
      _isRunning = false;
      _index =
          0; // reset to first step — change to keep current step if you prefer
      _phase = _PmrPhase.ready;
      _phaseSecondsRemaining = 0;
    });

    // optional feedback
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Session reset')));
  }

  void _resumePhase() {
    // If we are already running, nothing to do
    if (_isRunning) return;

    // If no remaining seconds (maybe paused right after completion), re-enter to reset durations
    if (_phaseSecondsRemaining <= 0) {
      // Re-enter the current phase to set a proper duration (or transition if it's a terminal phase).
      _enterPhase(_phase == _PmrPhase.ready ? _PmrPhase.tension : _phase);
      return;
    }

    setState(() {
      _isRunning = true;
    });

    // restart visible tick
    _startTick();

    // restart phase end timer using the remaining seconds and capture the phase at start
    final currentPhase = _phase;
    _phaseEndTimer = Timer(Duration(seconds: _phaseSecondsRemaining), () {
      // cancel tick and call completion handler for the phase that was running
      _tickTimer?.cancel();
      _onPhaseComplete(currentPhase);
    });
  }

  void _enterPhase(_PmrPhase p) {
    _tickTimer?.cancel();
    _phaseEndTimer?.cancel();

    final currentStep = _steps[_index];
    int dur = 0;
    switch (p) {
      case _PmrPhase.tension:
        dur = (currentStep.tensionSeconds).clamp(1, 600);
        break;
      case _PmrPhase.hold:
        dur = 4;
        break;
      case _PmrPhase.relax:
        dur = (currentStep.relaxSeconds).clamp(1, 600);
        break;
      case _PmrPhase.ready:
      case _PmrPhase.finished:
        dur = 0;
        break;
    }

    setState(() {
      _phase = p;
      _phaseSecondsRemaining = dur;
    });

    _playCue();

    if (dur > 0) {
      _startTick();
      _phaseEndTimer = Timer(Duration(seconds: dur), () {
        _tickTimer?.cancel();
        _onPhaseComplete(p);
      });
    } else {
      _onPhaseComplete(p);
    }
  }

  void _startTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_phaseSecondsRemaining > 0) _phaseSecondsRemaining--;
      });
    });
  }

  void _onPhaseComplete(_PmrPhase completed) {
    if (!mounted) return;
    switch (completed) {
      case _PmrPhase.tension:
        _playCue();
        _enterPhase(_PmrPhase.hold);
        break;
      case _PmrPhase.hold:
        _playCue();
        _enterPhase(_PmrPhase.relax);
        break;
      case _PmrPhase.relax:
        _playCue();
        if (_autoAdvance) {
          if (_index >= _steps.length - 1) {
            setState(() {
              _phase = _PmrPhase.finished;
              _isRunning = false;
              _phaseSecondsRemaining = 0;
            });
            _showCompletedSnack();
          } else {
            setState(() {
              _index++;
            });
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              _enterPhase(_PmrPhase.tension);
            });
          }
        } else {
          setState(() {
            _phase = _PmrPhase.ready;
            _isRunning = false;
            _phaseSecondsRemaining = 0;
          });
        }
        break;
      case _PmrPhase.ready:
      case _PmrPhase.finished:
        break;
    }
  }

  void _showCompletedSnack() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PMR session complete')));
  }

  void _prevStep() {
    if (_index > 0) {
      _tickTimer?.cancel();
      _phaseEndTimer?.cancel();
      setState(() {
        _index--;
        _phase = _PmrPhase.ready;
        _isRunning = false;
        _phaseSecondsRemaining = 0;
      });
    }
  }

  void _nextStep() {
    if (_index < _steps.length - 1) {
      _tickTimer?.cancel();
      _phaseEndTimer?.cancel();
      setState(() {
        _index++;
        _phase = _PmrPhase.ready;
        _isRunning = false;
        _phaseSecondsRemaining = 0;
      });
    } else {
      _tickTimer?.cancel();
      _phaseEndTimer?.cancel();
      setState(() {
        _phase = _PmrPhase.finished;
        _isRunning = false;
        _phaseSecondsRemaining = 0;
      });
      _showCompletedSnack();
    }
  }

  void _jumpToStep(int i) {
    if (i < 0 || i >= _steps.length) return;
    _tickTimer?.cancel();
    _phaseEndTimer?.cancel();
    setState(() {
      _index = i;
      _phase = _PmrPhase.ready;
      _isRunning = false;
      _phaseSecondsRemaining = 0;
    });
  }

  String _phaseLabel() {
    switch (_phase) {
      case _PmrPhase.tension:
        return 'Tense';
      case _PmrPhase.hold:
        return 'Hold';
      case _PmrPhase.relax:
        return 'Relax';
      case _PmrPhase.ready:
        return 'Ready';
      case _PmrPhase.finished:
        return 'Done';
    }
  }

  /// UPDATED: show tutorial modal with English/Hindi toggle
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
                color: cardDark,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16.0),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.02)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: StatefulBuilder(
                builder: (sheetCtx, sheetSetState) {
                  String t(String en, String hi) => _tutorialInHindi ? hi : en;

                  Widget headerToggle() {
                    return Row(
                      children: [
                        Text(
                          _tutorialInHindi ? 'Switch to EN' : 'Switch to हिंदी',
                          style: TextStyle(
                            color: mutedText,
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
                          icon: Icon(Icons.close, color: dimText),
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
                          margin: const EdgeInsets.only(bottom: 12),
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
                                  'Progressive Muscle Relaxation — Tutorial',
                                  'प्रोग्रेसिव मसल रिलैक्सेशन — ट्यूटोरियल',
                                ),
                                style: TextStyle(
                                  color: mutedText,
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

                        // Intro
                        Text(
                          t('What is PMR?', 'PMR क्या है?'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'Progressive Muscle Relaxation (PMR) is a guided exercise that helps '
                                'you release physical tension by systematically tensing and relaxing '
                                'muscle groups. It can reduce anxiety, improve sleep, and increase body awareness.',
                            'प्रोग्रेसिव मसल रिलैक्सेशन (PMR) एक मार्गदर्शित अभ्यास है जो मांसपेशियों को क्रमिक रूप से तनाव देकर और छोड़कर शारीरिक तनाव कम करने में मदद करता है। यह चिंता घटाने, नींद सुधारने और शरीर की जागरूकता बढ़ाने में सहायक है।',
                          ),
                          style: TextStyle(color: dimText),
                        ),
                        const SizedBox(height: 12),

                        // How to perform
                        Text(
                          t(
                            'How to perform (step-by-step)',
                            'कैसे करें (चरण-दर-चरण)',
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '1. Find a quiet, comfortable place and sit or lie down.\n'
                                '2. Breathe normally. For each step: breathe in, firmly tense the target muscles for the tense seconds, hold for the hold seconds, then release fully and relax for the relax seconds.\n'
                                '3. Move through the body from hands/fingers → forearms → upper arms → shoulders → neck → face → chest/back → stomach → thighs → calves/feet.\n'
                                '4. Focus on the sensation of relaxation after each release (don’t rush).',
                            '1. एक शांत और आरामदायक जगह चुनें और बैठ जाएँ या लेट जाएँ।\n'
                                '2. सामान्य रूप से साँस लें। प्रत्येक चरण में: साँस लेते समय लक्षित मांसपेशियों को दृढ़ता से तनाव दें (tense सेकंड), थोड़ी देर रोकें (hold सेकंड), फिर पूरी तरह छोड़ें और relax सेकंड के लिए शांत रहें।\n'
                                '3. शरीर के हिस्सों की श्रेणी पालन करें: हाथ/ऊँगलियाँ → कलाई/पूर्व-बाह → ऊपरी बांह/बाइसेप्स → कंधे → गर्दन → चेहरा → छाती/पीठ → पेट → जांघें → पिंडलियां/पैर।\n'
                                '4. प्रत्येक रिलीज़ के बाद विश्राम की भावना पर ध्यान दें (जल्दी न करें)।',
                          ),
                          style: TextStyle(color: dimText),
                        ),
                        const SizedBox(height: 12),

                        // Timing guidance
                        Text(
                          t('Timing & cues', 'समय और संकेत'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '• Tension: 4–8 seconds (we default to 5s for most steps).\n'
                                '• Hold: about 3–5 seconds (we use 4s).\n'
                                '• Relax: 8–12 seconds — notice the contrast between tightness and release.\n'
                                '• Use the bell and gentle vibration/haptic cue to mark phase transitions.',
                            '• Tension: 4–8 सेकंड (हम अधिकांश चरणों के लिए 5s डिफ़ॉल्ट करते हैं)।\n'
                                '• Hold: लगभग 3–5 सेकंड (हम 4s उपयोग करते हैं)।\n'
                                '• Relax: 8–12 सेकंड — तनाव और रिलीज़ के बीच के अंतर पर ध्यान दें।\n'
                                '• चरण परिवर्तन के लिए घन्टी और हल्का वाइब्रेशन/हैप्टिक संकेत उपयोग करें।',
                          ),
                          style: TextStyle(color: dimText),
                        ),
                        const SizedBox(height: 12),

                        // Safety + common mistakes
                        Text(
                          t('Safety & common tips', 'सुरक्षा और सामान्य सुझाव'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '• Do not force a painful contraction — tension should be firm but safe.\n'
                                '• Stop if you feel sharp pain, dizziness, or unusual breathlessness.\n'
                                '• If you have recent injuries, cardiovascular conditions, or pregnancy, consult a healthcare professional first.\n'
                                '• If you feel light-headed, stop, breathe normally, and rest.',
                            '• दर्दनाक संकुचन न करें — तनाव कड़ा पर सुरक्षित होना चाहिए।\n'
                                '• तेज़ दर्द, चक्कर या असामान्य साँस फूलने पर रुक जाएँ।\n'
                                '• हाल की चोट, हृदय संबंधी स्थितियाँ या गर्भावस्था होने पर पहले चिकित्सक से सलाह लें।\n'
                                '• चक्कर आएँ तो रुकें, सामान्य साँस लें और आराम करें।',
                          ),
                          style: TextStyle(color: dimText),
                        ),
                        const SizedBox(height: 12),

                        // Using the app tips
                        Text(
                          t('Using this screen', 'इस स्क्रीन का उपयोग'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '• Toggle Auto-advance (top-right) to let the app move automatically to the next step.\n'
                                '• Use the large play button to Start / Pause the guided sequence.\n'
                                '• Tap any list item to jump to that step.\n'
                                '• Use "Stop / Reset" to return to the first step.',
                            '• Auto-advance (ऊपर-दाएँ) को टॉगल करें ताकि ऐप स्वतः अगला चरण चलाए।\n'
                                '• Start / Pause के लिए बड़े प्ले बटन का उपयोग करें।\n'
                                '• किसी भी सूची आइटम पर टैप करके उस चरण पर जाएँ।\n'
                                '• प्रारंभिक चरण पर लौटने के लिए "Stop / Reset" का उपयोग करें।',
                          ),
                          style: TextStyle(color: dimText),
                        ),
                        const SizedBox(height: 18),

                        // Step quick reference (compact)
                        Text(
                          t('Quick step reference', 'त्वरित चरण सार'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int i = 0; i < _steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: teal3,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _tutorialInHindi
                                            ? _translateStepTitleToHindi(
                                                _steps[i].title,
                                              )
                                            : _steps[i].title,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        _tutorialInHindi
                                            ? _translateStepInstructionToHindi(
                                                _steps[i].instruction,
                                              )
                                            : _steps[i].instruction,
                                        style: TextStyle(
                                          color: dimText,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 18),

                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Start guided session from step 0
                                  Navigator.of(ctx).pop();
                                  _jumpToStep(0);
                                  // restartCurrent true to ensure we begin fresh
                                  _startSequence(restartCurrent: true);
                                },
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  t(
                                    'Start guided session',
                                    'दर्शित सत्र शुरू करें',
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
                                style: TextStyle(color: dimText),
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

  // Simple step title translations (concise)
  static String _translateStepTitleToHindi(String title) {
    switch (title) {
      case 'Hands & Fingers':
        return 'हाथ और उँगलियाँ';
      case 'Wrists & Forearms':
        return 'कलाई और अग्र-बाह';
      case 'Upper Arms / Biceps':
        return 'ऊपरी बांह / बाइसेप्स';
      case 'Shoulders':
        return 'कंधे';
      case 'Neck':
        return 'गर्दन';
      case 'Face (Jaw, Eyes)':
        return 'चेहरा (जॉ, आँखें)';
      case 'Chest & Back':
        return 'छाती और पीठ';
      case 'Stomach':
        return 'पेट';
      case 'Thighs':
        return 'जाँघें';
      case 'Calves & Feet':
        return 'पिंडलियां और पैर';
      default:
        return title;
    }
  }

  // Simple instruction translations (concise)
  static String _translateStepInstructionToHindi(String instr) {
    if (instr.contains('Clench fists')) {
      return 'मुट्ठियाँ कसें और उँगलियाँ मोड़ें।';
    } else if (instr.contains('Bend backwards')) {
      return 'पीछे की ओर मोड़ें और अग्र-बाह को तना दें।';
    } else if (instr.contains('Tighten your upper arms')) {
      return 'ऊपरी बांह को कस कर तना दें।';
    } else if (instr.contains('Lift shoulders')) {
      return 'कंधों को कानों की तरफ उठाएँ और रोकें।';
    } else if (instr.contains('press chin to chest')) {
      return 'ठोड़ी को धीरे से छाती की ओर दबाएँ और गर्दन तनाएँ।';
    } else if (instr.contains('Clench jaw')) {
      return 'जबड़ा कसें, आँखें बंद कर के निचोड़ें।';
    } else if (instr.contains('deep breath')) {
      return 'गहरी साँस लें और छाती/पीठ को तनाएँ।';
    } else if (instr.contains('Tighten stomach')) {
      return 'पेट की मांसपेशियाँ कसें।';
    } else if (instr.contains('Squeeze thigh')) {
      return 'जाँघ की मांसपेशियाँ ज़ोर से संकुचित करें।';
    } else if (instr.contains('Point toes')) {
      return 'पोइंट टो और पिंडलियां को कसें, फिर छोड़ें।';
    } else {
      return instr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];
    final screenW = MediaQuery.of(context).size.width;
    final circleSize = (screenW * 0.45).clamp(120.0, 360.0);

    return Scaffold(
      backgroundColor: surfaceDark,
      appBar: AppBar(
        title: const Text('Progressive Muscle Relaxation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [teal4, teal1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // NEW: Tutorial button (top-right)
          IconButton(
            onPressed: _showTutorial,
            icon: Icon(Icons.help_outline, color: mutedText),
            tooltip: 'PMR tutorial',
          ),

          // existing auto-advance toggle
          IconButton(
            onPressed: () {
              setState(() => _autoAdvance = !_autoAdvance);
            },
            icon: Icon(
              _autoAdvance ? Icons.play_arrow : Icons.playlist_play,
              color: mutedText,
            ),
            tooltip: _autoAdvance ? 'Auto-advance on' : 'Auto-advance off',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF031718), Color(0xFF072626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Step ${_index + 1} of ${_steps.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFBFDCDC),
                        ),
                      ),
                    ),
                    Text(
                      _phaseLabel(),
                      style: TextStyle(
                        fontSize: 14,
                        color: _phase == _PmrPhase.relax
                            ? teal2
                            : (_phase == _PmrPhase.tension
                                  ? Colors.deepOrangeAccent
                                  : dimText),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Card(
                  color: cardDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: teal3,
                              child: Text(
                                '${_index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                step.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step.instruction,
                          style: const TextStyle(fontSize: 14, color: dimText),
                        ),
                        const SizedBox(height: 18),

                        SizedBox(
                          height: circleSize + 40,
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 450),
                                  width: _phase == _PmrPhase.tension
                                      ? circleSize * 1.08
                                      : (_phase == _PmrPhase.relax
                                            ? circleSize
                                            : circleSize * 0.9),
                                  height: _phase == _PmrPhase.tension
                                      ? circleSize * 1.08
                                      : (_phase == _PmrPhase.relax
                                            ? circleSize
                                            : circleSize * 0.9),
                                  curve: Curves.easeInOut,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: _phase == _PmrPhase.relax
                                          ? [
                                              teal2.withOpacity(0.95),
                                              teal3.withOpacity(0.95),
                                            ]
                                          : [
                                              Colors.deepOrange.shade400
                                                  .withOpacity(0.95),
                                              Colors.deepOrange.shade200
                                                  .withOpacity(0.7),
                                            ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.6),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                ),

                                // surrounding sphere decoration (pulsing rings + subtle orbiting dots)
                                Positioned(
                                  child: _SphereSurround(
                                    size: circleSize * 1.06,
                                    phase: _phase,
                                  ),
                                ),

                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _phaseLabel(),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withOpacity(0.95),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Opacity(
                                      opacity: 0.18,
                                      child: Text(
                                        '${_phaseSecondsRemaining}s',
                                        style: const TextStyle(
                                          fontSize: 72,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tense ${step.tensionSeconds}s • Relax ${step.relaxSeconds}s',
                              style: const TextStyle(color: dimText),
                            ),
                            Text(
                              _isRunning ? 'Running' : 'Paused',
                              style: TextStyle(
                                color: _isRunning ? teal2 : dimText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    // Previous step
                    IconButton(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.chevron_left),
                      color: dimText,
                      tooltip: 'Previous',
                    ),

                    // Play / Pause (expanded)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_isRunning) {
                            _pauseSequence();
                          } else {
                            _startSequence();
                          }
                        },
                        icon: Icon(
                          _isRunning ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        label: Text(
                          _isRunning
                              ? 'Pause'
                              : (_phase == _PmrPhase.ready
                                    ? 'Start'
                                    : 'Resume'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teal3,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Stop / Reset
                    // Stop / Reset (with confirmation)
                    IconButton(
                      onPressed: () => _confirmAndStop(context),
                      icon: const Icon(Icons.stop),
                      color: Colors.redAccent,
                      tooltip: 'Stop / Reset',
                    ),

                    // Next step
                    IconButton(
                      onPressed: _nextStep,
                      icon: const Icon(Icons.chevron_right),
                      color: dimText,
                      tooltip: 'Next',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: Card(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(8.0),
                      child: ListView.separated(
                        itemCount: _steps.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 8, color: Colors.transparent),
                        itemBuilder: (ctx, i) {
                          final s = _steps[i];
                          final selected = i == _index;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: selected
                                  ? teal3
                                  : Colors.grey.shade800,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: selected ? Colors.white : dimText,
                                ),
                              ),
                            ),
                            title: Text(
                              s.title,
                              style: selected
                                  ? const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    )
                                  : const TextStyle(color: mutedText),
                            ),
                            subtitle: Text(
                              s.instruction,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: dimText),
                            ),
                            trailing: selected
                                ? Icon(Icons.play_circle_fill, color: teal2)
                                : null,
                            onTap: () => _jumpToStep(i),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SphereSurround extends StatefulWidget {
  final double size;
  final _PmrPhase phase;
  const _SphereSurround({required this.size, required this.phase});

  @override
  State<_SphereSurround> createState() => _SphereSurroundState();
}

class _SphereSurroundState extends State<_SphereSurround>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.size;
    // pulse scale depending on phase
    final pulseScale = widget.phase == _PmrPhase.tension
        ? 1.06
        : (widget.phase == _PmrPhase.relax ? 1.0 : 0.98);

    return SizedBox(
      width: base,
      height: base,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, _) {
          final t = _ctrl.value;
          // three rings with slight phase offsets
          final ring1Scale = pulseScale + 0.03 * sin(2 * pi * t);
          final ring2Scale = pulseScale + 0.06 * sin(2 * pi * (t + 0.25));
          final ring3Scale = pulseScale + 0.09 * sin(2 * pi * (t + 0.5));

          // subtle orbiting dots
          final dots = 6;

          return Stack(
            alignment: Alignment.center,
            children: [
              // soft ambient glow
              Container(
                width: base * 1.02,
                height: base * 1.02,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [teal3.withOpacity(0.12), Colors.transparent],
                    stops: const [0.0, 0.9],
                  ),
                ),
              ),

              // ring 1
              Transform.scale(
                scale: ring1Scale,
                child: Container(
                  width: base * 0.9,
                  height: base * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: teal2.withOpacity(0.22),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: teal2.withOpacity(0.02),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

              // ring 2
              Transform.scale(
                scale: ring2Scale,
                child: Container(
                  width: base * 0.98,
                  height: base * 0.98,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: teal3.withOpacity(0.14),
                      width: 1.6,
                    ),
                  ),
                ),
              ),

              // ring 3 (subtle dotted ring)
              Transform.scale(
                scale: ring3Scale,
                child: CustomPaint(
                  size: Size(base * 1.02, base * 1.02),
                  painter: _DottedRingPainter(color: teal2.withOpacity(0.14)),
                ),
              ),

              // orbiting dots
              for (int i = 0; i < dots; i++)
                Transform.translate(
                  offset: Offset(
                    cos(2 * pi * (i / dots) + t * 2 * pi) *
                        (base * 0.45 + 4 * sin(t * 2 * pi + i)),
                    sin(2 * pi * (i / dots) + t * 2 * pi) *
                        (base * 0.45 + 4 * cos(t * 2 * pi + i)),
                  ),
                  child: Opacity(
                    opacity: (0.6 - (i / dots) * 0.08).clamp(0.2, 0.9),
                    child: Container(
                      width: 4.0 + (i % 3).toDouble(),
                      height: 4.0 + (i % 3).toDouble(),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9 - i * 0.06),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: teal2.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DottedRingPainter extends CustomPainter {
  final Color color;
  _DottedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(cx, cy) * 0.95;

    // draw dotted ring by drawing many short arcs
    final segments = 40;
    final gap = (2 * pi) / segments;
    for (int i = 0; i < segments; i++) {
      final start = i * gap;
      final sweep = gap * 0.55; // dot length
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
