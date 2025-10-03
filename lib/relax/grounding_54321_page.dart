// lib/screens/relax_grounding_page.dart
// Grounding 5-4-3-2-1 exercise (dark teal theme)
// - Fixed keyboard / bottom overflow and chip deletion behavior

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _audio.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {}

    await _loadSaved();

    // show info dialog on first open
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kSeenInfoKey) ?? false;
    if (!seen && mounted) {
      // show after frame so context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInfoDialog();
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

  Future<void> _showInfoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: teal3,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'How the 5-4-3-2-1 grounding technique helps',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The 5-4-3-2-1 grounding technique is a simple mindfulness exercise '
                  'that helps manage anxiety and stress by using your five senses '
                  'to anchor you to the present moment.\n\n'
                  'You can do this exercise with real movements or by imaginative focus.\n',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const Text(
                  'Note: Writing input inreasses focus',
                  style: TextStyle(
                    color: Colors.yellow,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Steps:',
                  style: TextStyle(
                    color: teal2,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),

                _bulletItem(
                  Icons.remove_red_eye,
                  '5 — Notice five things you can SEE. Focus on details and name them.',
                ),
                _bulletItem(
                  Icons.touch_app,
                  '4 — Notice four things you can FEEL. Pay attention to textures and contact points.',
                ),
                _bulletItem(
                  Icons.hearing,
                  '3 — Notice three things you can HEAR. Listen to distinct sounds.',
                ),
                _bulletItem(
                  Icons.local_florist,
                  '2 — Notice two things you can SMELL. Inhale and identify scents.',
                ),
                _bulletItem(
                  Icons.restaurant,
                  '1 — Notice one thing you can TASTE, or take one deep intentional breath.',
                ),

                const SizedBox(height: 16),
                const Text(
                  'Why it works:',
                  style: TextStyle(
                    color: teal2,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),

                _bulletItem(
                  Icons.sensors,
                  'It engages the senses and interrupts the worry loop.',
                ),
                _bulletItem(
                  Icons.self_improvement,
                  'It activates your calming nervous system by shifting attention to the present.',
                ),
                _bulletItem(
                  Icons.flash_on,
                  'It’s quick, portable, and can be used anywhere.',
                ),

                const SizedBox(height: 16),
                const Text(
                  '💡 Tip: Move slowly and describe each item to yourself — naming details increases focus.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it', style: TextStyle(color: teal2)),
            ),
          ],
        );
      },
    );
  }

  // helper widget for bullet items with icon
  Widget _bulletItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: teal2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
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
        title: const Text('Grounding — 5‑4‑3‑2‑1'),
        backgroundColor: teal4,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Show how this works',
            onPressed: _showInfoDialog,
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
