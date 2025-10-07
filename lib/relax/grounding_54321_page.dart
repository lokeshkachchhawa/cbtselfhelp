// lib/screens/relax_grounding_page.dart
// Grounding 5-4-3-2-1 exercise (dark teal theme)
// - Fixed keyboard / bottom overflow and chip deletion behavior
// - Added draggable bottom-sheet tutorial with English/Hindi toggle
// - Integrated flutter_tts for phase announcements

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';

// Reuse teal palette from project preferences
const Color teal1 = Color(0xFF016C6C);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF005E5C);

enum _GroundPhase { ready, five, four, three, two, one, finished }

class RelaxGroundingPage extends StatefulWidget {
  const RelaxGroundingPage({super.key});

  @override
  State<RelaxGroundingPage> createState() => _RelaxGroundingPageState();
}

class _RelaxGroundingPageState extends State<RelaxGroundingPage> {
  final AudioPlayer _audio = AudioPlayer();

  // NEW: TTS
  final FlutterTts _flutterTts = FlutterTts();
  bool _ttsAvailable = true;

  _GroundPhase _phase = _GroundPhase.ready;
  bool _isRunning = false;
  bool _autoAdvance = true;

  // per-phase time (seconds) - if 0 then no countdown
  int _perPhaseSeconds = 8;

  Timer? _tickTimer;
  Timer? _phaseEndTimer;
  int _phaseSecondsRemaining = 0;

  // user entries for each sense
  final List<String> _see = [];
  final List<String> _feel = [];
  final List<String> _hear = [];
  final List<String> _smell = [];
  final List<String> _taste = [];

  final TextEditingController _entryController = TextEditingController();

  // persistence keys
  static const _kSavedKey = 'grounding_saved_v1';
  static const _kSeenInfoKey = 'grounding_seen_info_v1';

  bool _loading = true;

  // NEW: tutorial language toggle (false = English, true = Hindi)
  bool _tutorialInHindi = false;

  @override
  void initState() {
    super.initState();
    _init();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      // Set default TTS options
      await _flutterTts.setSpeechRate(0.45); // slower for clarity
      await _flutterTts.setPitch(1.0);
      // Don't set language here; set per utterance depending on _tutorialInHindi
      // handle completion / errors if you want
    } catch (e) {
      // If TTS fails to initialize on a platform, mark unavailable but continue gracefully
      _ttsAvailable = false;
    }
  }

  Future<void> _speak(String text, {String? lang}) async {
    if (!_ttsAvailable) return;
    try {
      if (lang != null) {
        await _flutterTts.setLanguage(lang);
      }
      await _flutterTts.speak(text);
    } catch (_) {
      // Do not crash if TTS fails
    }
  }

  Future<void> _speakPhase(_GroundPhase p) async {
    if (!_ttsAvailable) return;
    final bool hi = _tutorialInHindi;
    String utter;
    String lang;

    switch (p) {
      case _GroundPhase.five:
        utter = hi
            ? 'पाँच — जो आप देख सकते हैं।'
            : 'Five — things you can see.';
        lang = hi ? 'hi-IN' : 'en-US';
        break;
      case _GroundPhase.four:
        utter = hi
            ? 'चार — जो आप महसूस कर सकते हैं।'
            : 'Four — things you can feel.';
        lang = hi ? 'hi-IN' : 'en-US';
        break;
      case _GroundPhase.three:
        utter = hi
            ? 'तीन — जो आप सुन सकते हैं।'
            : 'Three — things you can hear.';
        lang = hi ? 'hi-IN' : 'en-US';
        break;
      case _GroundPhase.two:
        utter = hi
            ? 'दो — जो आप सूँघ सकते हैं।'
            : 'Two — things you can smell.';
        lang = hi ? 'hi-IN' : 'en-US';
        break;
      case _GroundPhase.one:
        utter = hi
            ? 'एक — जो आप स्वाद ले सकते हैं, या एक गहरी साँस लें।'
            : 'One — something you can taste, or take one deep breath.';
        lang = hi ? 'hi-IN' : 'en-US';
        break;
      case _GroundPhase.ready:
        utter = hi ? 'तैयार हों।' : 'Get ready.';
        lang = hi ? 'hi-IN' : 'en-US';
        break;
      case _GroundPhase.finished:
        utter = hi ? 'पूरा हुआ।' : 'Finished.';
        lang = hi ? 'hi-IN' : 'en-US';
        break;
    }

    await _speak(utter, lang: lang);
  }

  Future<void> _init() async {
    try {
      _audio.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {}

    await _loadSaved();

    // show tutorial bottom-sheet on first open
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kSeenInfoKey) ?? false;
    if (!seen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTutorial();
        prefs.setBool(_kSeenInfoKey, true);
      });
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSavedKey);
    if (raw == null) return;
    try {
      final Map<String, dynamic> data = jsonDecode(raw);
      setState(() {
        _see.clear();
        _feel.clear();
        _hear.clear();
        _smell.clear();
        _taste.clear();

        (_appendListFromJson(data['see']) ?? []).forEach(_see.add);
        (_appendListFromJson(data['feel']) ?? []).forEach(_feel.add);
        (_appendListFromJson(data['hear']) ?? []).forEach(_hear.add);
        (_appendListFromJson(data['smell']) ?? []).forEach(_smell.add);
        (_appendListFromJson(data['taste']) ?? []).forEach(_taste.add);

        _perPhaseSeconds = (data['perPhaseSeconds'] ?? _perPhaseSeconds) as int;
        _autoAdvance = (data['autoAdvance'] ?? _autoAdvance) as bool;
      });
    } catch (_) {}
  }

  List<String>? _appendListFromJson(dynamic v) {
    if (v == null) return null;
    return List<String>.from((v as List).map((e) => e.toString()));
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'see': _see,
      'feel': _feel,
      'hear': _hear,
      'smell': _smell,
      'taste': _taste,
      'perPhaseSeconds': _perPhaseSeconds,
      'autoAdvance': _autoAdvance,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_kSavedKey, jsonEncode(data));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Progress saved locally')));
    }
  }

  Future<void> _clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSavedKey);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _phaseEndTimer?.cancel();
    _audio.dispose();
    _entryController.dispose();
    try {
      _flutterTts.stop();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _playCue() async {
    try {
      await _audio.stop();
      await _audio.setSource(AssetSource('sounds/bell_short.mp3'));
      await _audio.resume();
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

  void _startSequence() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });
    _enterPhase(_GroundPhase.five);
    _playCue();
  }

  void _pauseSequence() {
    _tickTimer?.cancel();
    _phaseEndTimer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _confirmAndStop(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dctx) {
        return AlertDialog(
          title: const Text('Stop & Reset'),
          content: const Text(
            'Are you sure you want to stop and reset the exercise? This will keep your saved progress unless you choose "Reset & Clear".',
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

  void _stopSequence() {
    _tickTimer?.cancel();
    _phaseEndTimer?.cancel();
    try {
      _audio.stop();
    } catch (_) {}
    setState(() {
      _isRunning = false;
      _phase = _GroundPhase.ready;
      _phaseSecondsRemaining = 0;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Grounding exercise stopped')));
  }

  void _enterPhase(_GroundPhase p) {
    _tickTimer?.cancel();
    _phaseEndTimer?.cancel();

    setState(() {
      _phase = p;
      _phaseSecondsRemaining = _perPhaseSeconds;
    });

    // Speak the phase instruction (respects _tutorialInHindi)
    _speakPhase(p);

    _playCue();

    if (_perPhaseSeconds > 0) {
      _startTick();
      _phaseEndTimer = Timer(Duration(seconds: _perPhaseSeconds), () {
        _tickTimer?.cancel();
        _onPhaseComplete(p);
      });
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

  void _onPhaseComplete(_GroundPhase completed) {
    if (!mounted) return;
    switch (completed) {
      case _GroundPhase.five:
        _playCue();
        if (_autoAdvance) {
          _enterPhase(_GroundPhase.four);
        } else {
          setState(() => _isRunning = false);
        }
        break;
      case _GroundPhase.four:
        _playCue();
        if (_autoAdvance) {
          _enterPhase(_GroundPhase.three);
        } else {
          setState(() => _isRunning = false);
        }
        break;
      case _GroundPhase.three:
        _playCue();
        if (_autoAdvance) {
          _enterPhase(_GroundPhase.two);
        } else {
          setState(() => _isRunning = false);
        }
        break;
      case _GroundPhase.two:
        _playCue();
        if (_autoAdvance) {
          _enterPhase(_GroundPhase.one);
        } else {
          setState(() => _isRunning = false);
        }
        break;
      case _GroundPhase.one:
        _playCue();
        setState(() {
          _phase = _GroundPhase.finished;
          _isRunning = false;
          _phaseSecondsRemaining = 0;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Grounding complete')));
        break;
      case _GroundPhase.ready:
      case _GroundPhase.finished:
        break;
    }
  }

  String _phaseTitle(_GroundPhase p) {
    switch (p) {
      case _GroundPhase.five:
        return '5 — Things you CAN SEE';
      case _GroundPhase.four:
        return '4 — Things you CAN FEEL (touch)';
      case _GroundPhase.three:
        return '3 — Things you CAN HEAR';
      case _GroundPhase.two:
        return '2 — Things you CAN SMELL';
      case _GroundPhase.one:
        return '1 — Thing you CAN TASTE (or one deep breath)';
      case _GroundPhase.ready:
        return 'Get ready';
      case _GroundPhase.finished:
        return 'Finished';
    }
  }

  List<String> _listForPhase(_GroundPhase p) {
    switch (p) {
      case _GroundPhase.five:
        return _see;
      case _GroundPhase.four:
        return _feel;
      case _GroundPhase.three:
        return _hear;
      case _GroundPhase.two:
        return _smell;
      case _GroundPhase.one:
        return _taste;
      default:
        return [];
    }
  }

  int _targetCountForPhase(_GroundPhase p) {
    switch (p) {
      case _GroundPhase.five:
        return 5;
      case _GroundPhase.four:
        return 4;
      case _GroundPhase.three:
        return 3;
      case _GroundPhase.two:
        return 2;
      case _GroundPhase.one:
        return 1;
      default:
        return 0;
    }
  }

  void _addEntry(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      final p = _phase;
      final list = _listForPhase(p);
      if (list.length >= _targetCountForPhase(p)) return;
      list.add(text.trim());
      _entryController.clear();

      // If we've filled the phase, optionally auto-advance a little after cue
      if (list.length >= _targetCountForPhase(p)) {
        _playCue();
        if (_autoAdvance) {
          Future.delayed(const Duration(milliseconds: 700), () {
            if (!mounted) return;
            // move to next phase
            switch (p) {
              case _GroundPhase.five:
                _enterPhase(_GroundPhase.four);
                break;
              case _GroundPhase.four:
                _enterPhase(_GroundPhase.three);
                break;
              case _GroundPhase.three:
                _enterPhase(_GroundPhase.two);
                break;
              case _GroundPhase.two:
                _enterPhase(_GroundPhase.one);
                break;
              case _GroundPhase.one:
                _onPhaseComplete(_GroundPhase.one);
                break;
              default:
                break;
            }
          });
        }
      }
    });
  }

  void _removeEntryFromList(List<String> list, int idx) {
    if (idx < 0 || idx >= list.length) return;
    setState(() => list.removeAt(idx));
  }

  Widget _buildChips(List<String> items, {void Function(int)? onDelete}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .asMap()
          .entries
          .map(
            (e) => InputChip(
              label: Text(e.value),
              onDeleted: onDelete == null ? null : () => onDelete(e.key),
              deleteIconColor: Colors.white70,
              backgroundColor: teal4.withOpacity(0.9),
              labelStyle: const TextStyle(color: Colors.white),
            ),
          )
          .toList(),
    );
  }

  /// Draggable bottom-sheet tutorial with English/Hindi toggle
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
                color: Colors.black.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16.0),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.02)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: StatefulBuilder(
                // local setState for sheet + we still update parent _tutorialInHindi
                builder: (sheetCtx, sheetSetState) {
                  String t(String en, String hi) => _tutorialInHindi ? hi : en;

                  Widget headerToggle() {
                    return Row(
                      children: [
                        // Language toggle label
                        Text(
                          _tutorialInHindi
                              ? 'Switch to EN'
                              : 'Switch to हिंदी ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _tutorialInHindi,
                          activeColor: teal3,
                          onChanged: (v) {
                            // update both sheet state and parent state
                            sheetSetState(() => _tutorialInHindi = v);
                            setState(() => _tutorialInHindi = v);
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close, color: Colors.white70),
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
                                  'Grounding — 5-4-3-2-1 (Tutorial)',
                                  'ग्राउंडिंग — 5-4-3-2-1 (ट्यूटोरियल)',
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
                          t('What is grounding?', 'ग्राउंडिंग क्या है?'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'The 5-4-3-2-1 grounding technique helps reduce anxiety by bringing attention to your five senses. It is quick, portable, and effective at interrupting worry loops.',
                            '5-4-3-2-1 ग्राउंडिंग तकनीक आपकी पाँच इन्द्रियों पर ध्यान केंद्रित कर के चिंता घटाने में मदद करती है। यह तेज़, कहीं भी करने योग्य और चिंतामुक्ति में प्रभावी है।',
                          ),
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('How to do it', 'इसे कैसे करें'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '1. Look around and name 5 things you can SEE (notice colors, shapes, details).\n'
                                '2. Identify 4 things you can FEEL (texture, temperature, contact points).\n'
                                '3. Listen for 3 things you can HEAR (near or far).\n'
                                '4. Notice 2 things you can SMELL (or imagine scents).\n'
                                '5. Find 1 taste — or take 1 slow intentional breath and notice it.\n\n'
                                'You can write each item if it helps focus (this screen supports quick entry).',
                            '1. चारों ओर देखें और 5 चीजें बताइए जिन्हें आप देख सकते हैं (रंग, आकार, विवरण देखें)।\n'
                                '2. 4 चीजें बताइए जिन्हें आप महसूस कर सकते हैं (बनावट, तापमान)।\n'
                                '3. 3 आवाज़ें सुनिए जो आप सुन सकते हैं (पास या दूर)।\n'
                                '4. 2 सुंघने योग्य चीजें नोट कीजिए (वास्तविक या कल्पित)।\n'
                                '5. 1 स्वाद ढूँढिए — या एक धीमी और इरादतन साँस लें और उस पर ध्यान दें।\n\n'
                                'यदि लिखना मदद करता है तो आप प्रत्येक आइटम लिख सकते हैं (यह स्क्रीन यह सुविधा देती है)।',
                          ),
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('Timing & options', 'समय एवं विकल्प'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            '• Use the per-step seconds slider to allow automatic countdowns. Set to 0 to add items manually.\n'
                                '• Toggle Auto-advance to move to the next sense automatically after the timer or after you add required items.\n'
                                '• If you prefer, do this exercise moving physically (touch objects, smell something pleasant).',
                            '• प्रति-स्टेप सेकंड स्लाइडर का उपयोग स्वचालित काउंटडाउन के लिए करें। मैन्युअल जोड़ने के लिए 0 सेट करें।\n'
                                '• ऑटो-एडवांस चालू करें ताकि टाइमर या आवश्यक आइटम जोड़ने के बाद अगला चरण स्वतः चले।\n'
                                '• चाहें तो वास्तविक वस्तुओं को छूकर या खुशबू लेकर भी यह अभ्यास कर सकते हैं।',
                          ),
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t(
                            'Why it helps & safety',
                            'यह क्यों मदद करता है एवं सुरक्षा',
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
                            '• It anchors attention to the present and reduces rumination.\n'
                                '• Move slowly and describe items to yourself — naming details improves focus.\n'
                                '• If you feel dizzy or unwell, stop and breathe normally. For severe symptoms, seek help.',
                            '• यह ध्यान को वर्तमान में केंद्रित करता है और चिन्तन चक्र को तोड़ता है।\n'
                                '• धीरे-धीरे करें और वस्तुओं का वर्णन खुद से करें — विवरण बताने से ध्यान बढ़ता है।\n'
                                '• चक्कर आएँ या अस्वस्थ महसूस हो तो रुकें और सामान्य साँस लें। गंभीर लक्षणों के लिए मदद लें।',
                          ),
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('Quick step reference', 'त्वरित चरण सार'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _tutorialStepRow(
                          1,
                          t('See', 'देखें'),
                          t(
                            '5 things you can see — describe details.',
                            'आप जो 5 चीजें देख रहे हैं — विवरण बताइए।',
                          ),
                        ),
                        const SizedBox(height: 6),
                        _tutorialStepRow(
                          2,
                          t('Feel', 'महसूस करें'),
                          t(
                            '4 things you can feel — textures/pressure.',
                            'आप जो 4 चीजें महसूस कर सकते हैं — बनावट/दबाव।',
                          ),
                        ),
                        const SizedBox(height: 6),
                        _tutorialStepRow(
                          3,
                          t('Hear', 'सुनें'),
                          t(
                            '3 things you can hear — near or far.',
                            'आप जो 3 आवाज़ें सुन सकते हैं — पास या दूर।',
                          ),
                        ),
                        const SizedBox(height: 6),
                        _tutorialStepRow(
                          4,
                          t('Smell', 'सूंघें'),
                          t(
                            '2 scents — real or imagined.',
                            '2 सुगंध — वास्तविक या कल्पित।',
                          ),
                        ),
                        const SizedBox(height: 6),
                        _tutorialStepRow(
                          5,
                          t('Taste', 'स्वाद'),
                          t(
                            '1 thing you can taste, or take one slow breath.',
                            '1 चीज़ का स्वाद, या एक धीमी साँस लें।',
                          ),
                        ),
                        const SizedBox(height: 16),

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
                            '• Tap Start to begin the exercise.\n'
                                '• Use the entry field to type items and press + or Enter to add.\n'
                                '• Tap any chip to delete an entry if you made a mistake.\n'
                                '• Use Save to persist current progress locally.\n',
                            '• अभ्यास शुरू करने के लिए Start पर टैप करें।\n'
                                '• आइटम टाइप करने के लिए एंट्री फील्ड का उपयोग करें और + या Enter दबाएँ।\n'
                                '• गलती होने पर किसी भी चिप को टैप कर हटाएँ।\n'
                                '• Save से प्रगति लोकली सेव होती है।\n',
                          ),
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  // reset to initial phase and start
                                  setState(() {
                                    _see.clear();
                                    _feel.clear();
                                    _hear.clear();
                                    _smell.clear();
                                    _taste.clear();
                                    _phase = _GroundPhase.ready;
                                    _isRunning = false;
                                    _phaseSecondsRemaining = 0;
                                  });
                                  _startSequence();
                                },
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  t(
                                    'Start grounding exercise',
                                    'ग्राउंडिंग अभ्यास शुरू करें',
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
                                style: TextStyle(color: Colors.white70),
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

  Widget _tutorialStepRow(int num, String title, String subtitle) {
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
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActivePhase =
        _phase != _GroundPhase.ready && _phase != _GroundPhase.finished;
    final currentList = _listForPhase(_phase);
    final target = _targetCountForPhase(_phase);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Grounding — 5-4-3-2-1'),
        backgroundColor: teal4,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Show how this works',
            onPressed:
                _showTutorial, // opens the multilingual bottom-sheet tutorial
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: 'Save progress locally',
            onPressed: _saveToDisk,
            icon: const Icon(Icons.save_outlined),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            tooltip: 'More',
            // menu background color
            color: const Color(0xFF0B0B0B),
            offset: const Offset(0, 44), // push menu below the appbar if needed
            onSelected: (value) async {
              if (value == 'reset') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: const Text('Reset & Clear'),
                    content: const Text(
                      'Reset all fields and clear saved progress? This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dctx).pop(true),
                        child: const Text('Reset & Clear'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  setState(() {
                    _see.clear();
                    _feel.clear();
                    _hear.clear();
                    _smell.clear();
                    _taste.clear();
                    _phase = _GroundPhase.ready;
                    _isRunning = false;
                    _phaseSecondsRemaining = 0;
                  });
                  await _clearSaved();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reset & cleared saved progress'),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'reset',
                child: Row(
                  children: const [
                    Icon(
                      Icons.restore_outlined,
                      size: 18,
                      color: Colors.white70,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Reset & Clear saved',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      // allow scaffold to resize for keyboard by default
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF021919), Color(0xFF043434)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        // ensure scroll when keyboard opens
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _phaseTitle(_phase),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),

                                    // per-phase timer control explanation
                                    IconButton(
                                      onPressed: () {
                                        showDialog<void>(
                                          context: context,
                                          builder: (dctx) => AlertDialog(
                                            title: const Text('Per-step timer'),
                                            content: const Text(
                                              'Use the slider below to set how many seconds each step should allow. Set to 0 for no automatic countdown; then add entries manually. The small number beside the slider shows the current value.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(dctx).pop(),
                                                child: const Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.timer_outlined,
                                        color: Colors.white70,
                                      ),
                                      tooltip: 'What does the slider do?',
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                Card(
                                  color: Colors.black.withOpacity(0.24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              isActivePhase
                                                  ? '${currentList.length} / $target'
                                                  : 'Ready',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (isActivePhase &&
                                                _perPhaseSeconds > 0)
                                              Text(
                                                '${_phaseSecondsRemaining}s',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        if (currentList.isEmpty)
                                          Text(
                                            isActivePhase
                                                ? 'Add items for this step — type and press Enter or the + button.'
                                                : 'Tap Start to begin the grounding exercise.',
                                            style: const TextStyle(
                                              color: Colors.white60,
                                            ),
                                          )
                                        else
                                          // pass onDelete specific to the active list
                                          _buildChips(
                                            currentList,
                                            onDelete: (i) =>
                                                _removeEntryFromList(
                                                  currentList,
                                                  i,
                                                ),
                                          ),

                                        const SizedBox(height: 12),

                                        // entry field only when active phase
                                        if (isActivePhase)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: _entryController,
                                                  decoration: InputDecoration(
                                                    hintText: 'Add an item',
                                                    hintStyle: const TextStyle(
                                                      color: Colors.white38,
                                                    ),
                                                    filled: true,
                                                    fillColor: Colors.white
                                                        .withOpacity(0.03),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      borderSide:
                                                          BorderSide.none,
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  onSubmitted: (v) =>
                                                      _addEntry(v),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () => _addEntry(
                                                  _entryController.text,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: teal3,
                                                ),
                                                child: const Icon(Icons.add),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // controls
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _perPhaseSeconds =
                                              (_perPhaseSeconds - 2).clamp(
                                                0,
                                                120,
                                              );
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                      color: Colors.white70,
                                      tooltip: 'Decrease per-step timer',
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Slider(
                                            min: 0,
                                            max: 30,
                                            divisions: 30,
                                            value: _perPhaseSeconds.toDouble(),
                                            activeColor: teal2,
                                            inactiveColor: Colors.white12,
                                            onChanged: _isRunning
                                                ? null
                                                : (v) => setState(
                                                    () => _perPhaseSeconds = v
                                                        .toInt(),
                                                  ),
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Per-step seconds',
                                                style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                '$_perPhaseSeconds s',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _perPhaseSeconds =
                                              (_perPhaseSeconds + 2).clamp(
                                                0,
                                                120,
                                              );
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      color: Colors.white70,
                                      tooltip: 'Increase per-step timer',
                                    ),
                                    const SizedBox(width: 8),

                                    ElevatedButton(
                                      onPressed: _isRunning
                                          ? _stopSequence
                                          : _startSequence,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isRunning
                                            ? Colors.redAccent
                                            : teal3,
                                      ),
                                      child: Text(
                                        _isRunning ? 'Stop' : 'Start',
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // quick navigation (manual) and status
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Auto-advance: ${_autoAdvance ? 'On' : 'Off'}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            // back one phase
                                            if (_phase == _GroundPhase.five)
                                              return;
                                            _tickTimer?.cancel();
                                            _phaseEndTimer?.cancel();
                                            setState(() {
                                              _isRunning = false;
                                              _phase =
                                                  _GroundPhase
                                                      .values[(_phase.index - 1)
                                                      .clamp(
                                                        0,
                                                        _GroundPhase
                                                                .values
                                                                .length -
                                                            1,
                                                      )];
                                              _phaseSecondsRemaining = 0;
                                            });
                                          },
                                          icon: const Icon(Icons.chevron_left),
                                          color: Colors.white70,
                                        ),

                                        IconButton(
                                          onPressed: () {
                                            // forward one phase
                                            if (_phase == _GroundPhase.one ||
                                                _phase == _GroundPhase.finished)
                                              return;
                                            _tickTimer?.cancel();
                                            _phaseEndTimer?.cancel();
                                            setState(() {
                                              _isRunning = false;
                                              _phase =
                                                  _GroundPhase
                                                      .values[(_phase.index + 1)
                                                      .clamp(
                                                        0,
                                                        _GroundPhase
                                                                .values
                                                                .length -
                                                            1,
                                                      )];
                                              _phaseSecondsRemaining = 0;
                                            });
                                          },
                                          icon: const Icon(Icons.chevron_right),
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // review summary (compact)
                                Expanded(
                                  child: Card(
                                    color: Colors.transparent,
                                    elevation: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Your entries',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'See (5):',
                                              style: TextStyle(
                                                color: Colors.white60,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            _buildChips(
                                              _see,
                                              onDelete: (i) =>
                                                  _removeEntryFromList(_see, i),
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'Feel (4):',
                                              style: TextStyle(
                                                color: Colors.white60,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            _buildChips(
                                              _feel,
                                              onDelete: (i) =>
                                                  _removeEntryFromList(
                                                    _feel,
                                                    i,
                                                  ),
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'Hear (3):',
                                              style: TextStyle(
                                                color: Colors.white60,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            _buildChips(
                                              _hear,
                                              onDelete: (i) =>
                                                  _removeEntryFromList(
                                                    _hear,
                                                    i,
                                                  ),
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'Smell (2):',
                                              style: TextStyle(
                                                color: Colors.white60,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            _buildChips(
                                              _smell,
                                              onDelete: (i) =>
                                                  _removeEntryFromList(
                                                    _smell,
                                                    i,
                                                  ),
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'Taste (1):',
                                              style: TextStyle(
                                                color: Colors.white60,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            _buildChips(
                                              _taste,
                                              onDelete: (i) =>
                                                  _removeEntryFromList(
                                                    _taste,
                                                    i,
                                                  ),
                                            ),
                                            const SizedBox(height: 16),

                                            // save & reset quick buttons
                                            Row(
                                              children: [
                                                // Save button
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: _saveToDisk,
                                                    icon: const Icon(
                                                      Icons.save,
                                                      color: Colors.white,
                                                    ),
                                                    label: const Text(
                                                      'Save',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 14,
                                                          ),
                                                      backgroundColor: teal3,
                                                      foregroundColor:
                                                          Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      elevation: 6,
                                                      shadowColor:
                                                          Colors.black54,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 14),

                                                // Clear button
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      final ok = await showDialog<bool>(
                                                        context: context,
                                                        builder: (dctx) => AlertDialog(
                                                          title: const Text(
                                                            'Reset entries',
                                                          ),
                                                          content: const Text(
                                                            'Clear current entries but keep saved progress?',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    dctx,
                                                                  ).pop(false),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    dctx,
                                                                  ).pop(true),
                                                              child: const Text(
                                                                'Clear',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (ok == true) {
                                                        setState(() {
                                                          _see.clear();
                                                          _feel.clear();
                                                          _hear.clear();
                                                          _smell.clear();
                                                          _taste.clear();
                                                          _phase = _GroundPhase
                                                              .ready;
                                                          _isRunning = false;
                                                          _phaseSecondsRemaining =
                                                              0;
                                                        });
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Entries cleared (saved progress retained)',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    icon: const Icon(
                                                      Icons.clear,
                                                      color: Colors.white70,
                                                    ),
                                                    label: const Text(
                                                      'Clear',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 14,
                                                          ),
                                                      backgroundColor:
                                                          Colors.white12,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      elevation: 4,
                                                      shadowColor:
                                                          Colors.black45,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
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
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
