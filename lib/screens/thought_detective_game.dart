// lib/screens/thought_detective_game.dart
import 'dart:convert';
import 'dart:math';

import 'package:cbt_drktv/screens/game_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

const Color teal1 = Color.fromARGB(255, 1, 108, 108);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal6 = Color(0xFF004E4D);

// ---------------- Models ----------------
class CardItem {
  final String id;
  final String text;
  final List<String> answers;
  final String explanation;

  CardItem({
    required this.id,
    required this.text,
    required this.answers,
    required this.explanation,
  });

  factory CardItem.fromMap(Map<String, dynamic> m) => CardItem(
    id: m['id'] as String,
    text: m['text'] as String,
    answers: List<String>.from(m['answers'] as List<dynamic>),
    explanation: m['explanation'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'answers': answers,
    'explanation': explanation,
  };
}

class AttributionItem {
  final String id;
  final String prompt;
  final String optionA;
  final int scoreA; // 0/1 (1 = more optimistic for that dimension)
  final String optionB;
  final int scoreB; // 0/1
  /// Dimension code:
  /// PmB / PmG  (Permanence Bad/Good)
  /// PvB / PvG  (Pervasiveness Bad/Good)
  /// PsB / PsG  (Personalization Bad/Good)
  final String dimension;
  final String note;

  AttributionItem({
    required this.id,
    required this.prompt,
    required this.optionA,
    required this.scoreA,
    required this.optionB,
    required this.scoreB,
    required this.dimension,
    this.note = '',
  });

  factory AttributionItem.fromMap(Map<String, dynamic> m) => AttributionItem(
    id: m['id'] as String,
    prompt: m['prompt'] as String,
    optionA: m['optionA'] as String,
    scoreA: (m['scoreA'] as num).toInt(),
    optionB: m['optionB'] as String,
    scoreB: (m['scoreB'] as num).toInt(),
    dimension: m['dimension'] as String,
    note: (m['note'] ?? '') as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'prompt': prompt,
    'optionA': optionA,
    'scoreA': scoreA,
    'optionB': optionB,
    'scoreB': scoreB,
    'dimension': dimension,
    'note': note,
  };
}

class GameSession {
  final int score;
  final DateTime createdAt;
  final int cardsSeen;
  final int correctCount;

  GameSession({
    required this.score,
    required this.createdAt,
    required this.cardsSeen,
    required this.correctCount,
  });

  factory GameSession.fromMap(Map<String, dynamic> m) => GameSession(
    score: (m['score'] as num).toInt(),
    createdAt: DateTime.parse(m['createdAt'] as String),
    cardsSeen: (m['cardsSeen'] as num).toInt(),
    correctCount: (m['correctCount'] as num).toInt(),
  );

  Map<String, dynamic> toMap() => {
    'score': score,
    'createdAt': createdAt.toIso8601String(),
    'cardsSeen': cardsSeen,
    'correctCount': correctCount,
  };
}

// ---------------- Screen ----------------
class ThoughtDetectiveGame extends StatefulWidget {
  const ThoughtDetectiveGame({super.key});

  @override
  State<ThoughtDetectiveGame> createState() => _ThoughtDetectiveGameState();
}

enum GameMode { distortions, attribution }

class _ThoughtDetectiveGameState extends State<ThoughtDetectiveGame>
    with SingleTickerProviderStateMixin {
  // Config
  static const int _cardsPerRound = 5;
  static const String _prefsKey = 'td_game_history';

  // Levels config (Distortions)
  static const int _levelsCount = 6;
  static const int _cardsPerLevel = 5;
  static const String _prefsLevelsKey =
      'td_levels_unlocked'; // highest unlocked distortions (1..6)

  // Levels config (Attribution)
  static const int _asqLevelsCount = 6;
  static const int _asqCardsPerLevel = 5;
  static const String _prefsAsqLevelsKey =
      'asq_levels_unlocked'; // highest unlocked ASQ (1..6)

  // Mode
  GameMode _mode = GameMode.distortions;

  /// JSON-loaded content
  final List<CardItem> _cardBank = []; // distortions chips
  final List<AttributionItem> _asqBank = []; // attribution A/B

  // Distortion labels (chips)
  final List<String> _labels = const [
    'Mind reading',
    'Catastrophising',
    'Overgeneralisation',
    'All-or-nothing',
    'Emotional reasoning',
  ];

  // ---- Levels state (Distortions) ----
  List<List<CardItem>> _tdLevels = [];
  int _selectedLevel = 1;
  int _highestUnlocked = 1;

  // ---- Levels state (Attribution) ----
  List<List<AttributionItem>> _asqLevels = [];
  int _selectedAsqLevel = 1;
  int _highestUnlockedAsq = 1;

  // Round state
  late List<CardItem> _cardsThisRound; // distortions
  late List<AttributionItem> _asqThisRound; // attribution
  int _index = 0;

  // distortions selection
  final Set<String> _selected = <String>{};

  // attribution selection (A=0, B=1)
  int? _asqSelection;

  int _score = 0;
  bool _showFeedback = false;
  int _correctThisRound = 0;

  // Attribution tallies (optimism points = sum of 1s)
  final Map<String, int> _dimensionTotals = {
    'PmB': 0,
    'PvB': 0,
    'PsB': 0,
    'PmG': 0,
    'PvG': 0,
    'PsG': 0,
  };
  final Map<String, int> _dimensionCounts = {
    'PmB': 0,
    'PvB': 0,
    'PsB': 0,
    'PmG': 0,
    'PvG': 0,
    'PsG': 0,
  };

  // History
  List<GameSession> _history = [];

  // UI animation controller for feedback area
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      lowerBound: 0.9,
      upperBound: 1.02,
    );

    _loadHistory()
        .then((_) => _loadLevelsProgress())
        .then((_) => _loadCardsFromJson())
        .then((_) => _loadAttributionFromJson())
        .then((_) {
          _buildThoughtDetectiveLevels();
          _buildAsqLevels();
          _selectedLevel = _selectedLevel.clamp(1, _highestUnlocked);
          _selectedAsqLevel = _selectedAsqLevel.clamp(1, _highestUnlockedAsq);
          _startRound();
        });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ---------- Loaders ----------
  Future<void> _loadCardsFromJson() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/thought_detective_questions.json',
      );
      final List decoded = json.decode(raw) as List;
      final loaded = decoded
          .map((m) => CardItem.fromMap(m as Map<String, dynamic>))
          .toList();
      setState(() {
        _cardBank
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      debugPrint("Failed to load distortions JSON: $e");
    }
  }

  Future<void> _loadAttributionFromJson() async {
    try {
      final raw = await rootBundle.loadString('assets/data/asq_items.json');
      final List decoded = json.decode(raw) as List;
      final loaded = decoded
          .map((m) => AttributionItem.fromMap(m as Map<String, dynamic>))
          .toList();
      setState(() {
        _asqBank
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      debugPrint("Failed to load attribution JSON: $e");
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? <String>[];
      _history = raw
          .map(
            (s) => GameSession.fromMap(json.decode(s) as Map<String, dynamic>),
          )
          .toList();
      setState(() {});
    } catch (e) {
      debugPrint('Failed to load history: $e');
      _history = [];
    }
  }

  Future<void> _loadLevelsProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Distortions progress
      _highestUnlocked = prefs.getInt(_prefsLevelsKey) ?? 1;
      _selectedLevel = _highestUnlocked;

      // ASQ progress
      _highestUnlockedAsq = prefs.getInt(_prefsAsqLevelsKey) ?? 1;
      _selectedAsqLevel = _highestUnlockedAsq;

      setState(() {});
    } catch (e) {
      debugPrint('Failed to load levels progress: $e');
      _highestUnlocked = 1;
      _selectedLevel = 1;
      _highestUnlockedAsq = 1;
      _selectedAsqLevel = 1;
    }
  }

  Future<void> _saveLevelsProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsLevelsKey, _highestUnlocked);
      await prefs.setInt(_prefsAsqLevelsKey, _highestUnlockedAsq);
    } catch (e) {
      debugPrint('Failed to save levels progress: $e');
    }
  }

  Future<void> _saveSession(GameSession s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _history.insert(0, s);
      final encoded = _history.map((x) => json.encode(x.toMap())).toList();
      await prefs.setStringList(_prefsKey, encoded);
      setState(() {});
    } catch (e) {
      debugPrint('Failed to save session: $e');
    }
  }

  // ---------- Level builders ----------
  void _buildThoughtDetectiveLevels() {
    final items = List<CardItem>.from(_cardBank)
      ..sort((a, b) => a.id.compareTo(b.id));
    final List<List<CardItem>> chunks = [];
    for (int i = 0; i < items.length; i += _cardsPerLevel) {
      final end = (i + _cardsPerLevel) > items.length
          ? items.length
          : (i + _cardsPerLevel);
      chunks.add(items.sublist(i, end));
    }
    _tdLevels =
        chunks.length >= _levelsCount
              ? chunks.take(_levelsCount).toList()
              : chunks
          ..addAll(
            List.generate(
              (_levelsCount - chunks.length).clamp(0, 999),
              (_) => <CardItem>[],
            ),
          );
  }

  void _buildAsqLevels() {
    final items = List<AttributionItem>.from(_asqBank)
      ..sort((a, b) => a.id.compareTo(b.id));
    final List<List<AttributionItem>> chunks = [];
    for (int i = 0; i < items.length; i += _asqCardsPerLevel) {
      final end = (i + _asqCardsPerLevel) > items.length
          ? items.length
          : (i + _asqCardsPerLevel);
      chunks.add(items.sublist(i, end));
    }
    _asqLevels =
        chunks.length >= _asqLevelsCount
              ? chunks.take(_asqLevelsCount).toList()
              : chunks
          ..addAll(
            List.generate(
              (_asqLevelsCount - chunks.length).clamp(0, 999),
              (_) => <AttributionItem>[],
            ),
          );
  }

  // ---------- Game flow ----------
  void _resetTallies() {
    for (final k in _dimensionTotals.keys) {
      _dimensionTotals[k] = 0;
      _dimensionCounts[k] = 0;
    }
  }

  void _startRound() {
    // Reset round state
    _index = 0;
    _selected.clear();
    _asqSelection = null;
    _score = 0;
    _showFeedback = false;
    _correctThisRound = 0;
    _resetTallies();

    final rnd = Random();

    if (_mode == GameMode.distortions) {
      final levelIdx = _selectedLevel - 1;
      if (levelIdx < 0 || levelIdx >= _tdLevels.length) {
        _cardsThisRound = [];
      } else {
        final levelCards = List<CardItem>.from(_tdLevels[levelIdx]);
        if (levelCards.isEmpty) {
          _cardsThisRound = [];
        } else {
          levelCards.shuffle(rnd);
          _cardsThisRound = levelCards
              .take(min(_cardsPerRound, levelCards.length))
              .toList();
        }
      }
    } else {
      final levelIdx = _selectedAsqLevel - 1;
      if (levelIdx < 0 || levelIdx >= _asqLevels.length) {
        _asqThisRound = [];
      } else {
        final levelItems = List<AttributionItem>.from(_asqLevels[levelIdx]);
        if (levelItems.isEmpty) {
          _asqThisRound = [];
        } else {
          levelItems.shuffle(rnd);
          _asqThisRound = levelItems
              .take(min(_cardsPerRound, levelItems.length))
              .toList();

          // Pre-count dimensions for results denominators
          for (final it in _asqThisRound) {
            if (_dimensionCounts.containsKey(it.dimension)) {
              _dimensionCounts[it.dimension] =
                  (_dimensionCounts[it.dimension] ?? 0) + 1;
            }
          }
        }
      }
    }

    setState(() {});
  }

  void _submitAnswer() {
    if (_selected.isEmpty) return;
    final card = _cardsThisRound[_index];
    final correct = card.answers;
    int correctCount = 0;
    int wrongCount = 0;

    for (final s in _selected) {
      if (correct.contains(s)) {
        correctCount++;
      } else {
        wrongCount++;
      }
    }

    final earned = max(0, correctCount * 10 - wrongCount * 2);
    _score += earned;
    _correctThisRound += correctCount;

    _animController.forward().then((_) => _animController.reverse());
    setState(() => _showFeedback = true);
  }

  void _submitAttribution() {
    if (_asqSelection == null) return;
    final item = _asqThisRound[_index];
    final selectedScore = (_asqSelection == 0) ? item.scoreA : item.scoreB;

    _score += selectedScore; // sum of 1s as "optimism points"
    _correctThisRound += selectedScore;

    if (_dimensionTotals.containsKey(item.dimension)) {
      _dimensionTotals[item.dimension] =
          (_dimensionTotals[item.dimension] ?? 0) + selectedScore;
    }

    _animController.forward().then((_) => _animController.reverse());
    setState(() => _showFeedback = true);
  }

  void _nextCard() {
    final lastIndex = (_mode == GameMode.distortions)
        ? _cardsThisRound.length - 1
        : _asqThisRound.length - 1;

    if (_index < lastIndex) {
      setState(() {
        _index++;
        _selected.clear();
        _asqSelection = null;
        _showFeedback = false;
      });
    } else {
      final seen = (_mode == GameMode.distortions)
          ? _cardsThisRound.length
          : _asqThisRound.length;

      final session = GameSession(
        score: _score,
        createdAt: DateTime.now().toUtc(),
        cardsSeen: seen,
        correctCount: _correctThisRound,
      );
      _saveSession(session);

      if (_mode == GameMode.attribution) {
        // Unlock ASQ level if passed before showing results
        _maybeUnlockNextLevel(session);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AsqResultsPage(
              session: session,
              totals: Map<String, int>.from(_dimensionTotals),
              counts: Map<String, int>.from(_dimensionCounts),
              onPlayAgain: () {
                Navigator.of(context).pop();
                _startRound();
              },
            ),
          ),
        );
      } else {
        // Distortions mode -> show summary + maybe unlock
        _maybeUnlockNextLevel(session);
        _showSummary(session);
      }
    }
  }

  void _maybeUnlockNextLevel(GameSession s) {
    final accuracy = (s.cardsSeen == 0) ? 0.0 : s.correctCount / s.cardsSeen;
    final passed = accuracy >= 0.5;

    if (!passed) return;

    if (_mode == GameMode.distortions) {
      if (_selectedLevel == _highestUnlocked &&
          _highestUnlocked < _levelsCount) {
        setState(() => _highestUnlocked += 1);
        _saveLevelsProgress();
      }
    } else {
      if (_selectedAsqLevel == _highestUnlockedAsq &&
          _highestUnlockedAsq < _asqLevelsCount) {
        setState(() => _highestUnlockedAsq += 1);
        _saveLevelsProgress();
      }
    }
  }

  void _showSummary(GameSession session) {
    final accuracy = (session.cardsSeen == 0)
        ? 0.0
        : session.correctCount / session.cardsSeen;
    final passed = accuracy >= 0.5;

    final nextLockedDist = _highestUnlocked < _levelsCount
        ? (_selectedLevel + 1) > _highestUnlocked
        : false;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF021515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Level ${_selectedLevel} complete',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Score: ${session.score}   •   Correct tags: ${session.correctCount}/${session.cardsSeen} (${(accuracy * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              if (passed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_open, color: Colors.tealAccent),
                    SizedBox(width: 8),
                    Text(
                      'Unlocked next level!',
                      style: TextStyle(color: Colors.tealAccent),
                    ),
                  ],
                )
              else
                const Text(
                  'Get at least 50% correct to unlock the next level.',
                  style: TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _startRound(); // replay same level
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: teal3),
                    child: const Text('Replay Level'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      final next = (_selectedLevel < _highestUnlocked)
                          ? _selectedLevel + 1
                          : _selectedLevel;
                      setState(() => _selectedLevel = next);
                      _startRound();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white12),
                    ),
                    child: Text(
                      nextLockedDist ? 'Next Level (Locked)' : 'Next Level',
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Close', style: TextStyle(color: teal4)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushNamed(context, '/thought');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white12),
                ),
                child: const Text('Create thought record'),
              ),
            ],
          ),
        );
      },
    );
  }

  double get _avgScoreLast7 {
    if (_history.isEmpty) return 0.0;
    final last7 = _history.take(7).toList();
    final sum = last7.fold<int>(0, (p, e) => p + e.score);
    return sum / last7.length;
  }

  @override
  Widget build(BuildContext context) {
    final isASQ = _mode == GameMode.attribution;

    final hasCards = isASQ
        ? (_asqThisRound.isNotEmpty)
        : (_cardsThisRound.isNotEmpty);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: teal1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isASQ ? 'Attribution Game' : 'Thought Detective'),
            if (_history.isNotEmpty)
              Text(
                'Avg (last ${min(7, _history.length)}): ${_avgScoreLast7.toStringAsFixed(0)} pts',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          _levelToggle(isAsq: isASQ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'How to play',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GameTutorialPage()),
              );
            },
          ),
          _modeToggle(),
        ],
      ),
      backgroundColor: const Color(0xFF021515),
      body: hasCards ? _gameBody(isASQ) : _emptyBody(),
    );
  }

  Widget _emptyBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No cards available',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => setState(() => _startRound()),
              style: ElevatedButton.styleFrom(backgroundColor: teal3),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameBody(bool isASQ) {
    final total = isASQ ? _asqThisRound.length : _cardsThisRound.length;
    final progress = total == 0 ? 0.0 : (_index + 1) / total;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _levelHeader(isAsq: isASQ),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(teal4),
            minHeight: 6,
          ),
          const SizedBox(height: 14),
          Card(
            color: Colors.white10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: isASQ ? _asqCard() : _distortionCard(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Score: $_score',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                '${_index + 1}/$total',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- UI parts ----------
  Widget _modeToggle() {
    return PopupMenuButton<GameMode>(
      icon: const Icon(Icons.swap_horiz),
      onSelected: (m) => setState(() {
        _mode = m;
        _startRound();
      }),
      itemBuilder: (ctx) => const [
        PopupMenuItem(
          value: GameMode.distortions,
          child: Text('Distortions Mode'),
        ),
        PopupMenuItem(
          value: GameMode.attribution,
          child: Text('Attribution Mode'),
        ),
      ],
    );
  }

  Widget _levelToggle({required bool isAsq}) {
    // Unified level menu that adapts to mode
    return PopupMenuButton<int>(
      icon: const Icon(Icons.flag),
      onSelected: (lvl) {
        if (!isAsq) {
          if (lvl <= _highestUnlocked) {
            setState(() => _selectedLevel = lvl);
            _startRound();
          }
        } else {
          if (lvl <= _highestUnlockedAsq) {
            setState(() => _selectedAsqLevel = lvl);
            _startRound();
          }
        }
      },
      itemBuilder: (ctx) {
        final count = isAsq ? _asqLevelsCount : _levelsCount;
        final highest = isAsq ? _highestUnlockedAsq : _highestUnlocked;
        final current = isAsq ? _selectedAsqLevel : _selectedLevel;

        return List<PopupMenuEntry<int>>.generate(count, (i) {
          final lvl = i + 1;
          final locked = lvl > highest;
          return PopupMenuItem<int>(
            value: lvl,
            enabled: !locked,
            child: Row(
              children: [
                Text('Level $lvl'),
                const SizedBox(width: 8),
                if (locked)
                  const Icon(Icons.lock, size: 16, color: Colors.white54),
                if (!locked && lvl == current)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.tealAccent,
                    ),
                  ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _levelHeader({required bool isAsq}) {
    final current = isAsq ? _selectedAsqLevel : _selectedLevel;
    final highest = isAsq ? _highestUnlockedAsq : _highestUnlocked;
    final totalLevels = isAsq ? _asqLevelsCount : _levelsCount;
    final lockedNext = current >= highest && highest < totalLevels;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  'Level $current',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (lockedNext)
            Row(
              children: const [
                Icon(Icons.lock, size: 16, color: Colors.white54),
                SizedBox(width: 6),
                Text(
                  'Next level locked (≥ 50% to unlock)',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _distortionCard() {
    final card = _cardsThisRound[_index];
    final correctAnswers = card.answers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          card.text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _labels.map((label) {
            final isSelected = _selected.contains(label);
            return ChoiceChip(
              label: Text(label, semanticsLabel: 'Distortion: $label'),
              selected: isSelected,
              onSelected: (sel) {
                if (_showFeedback) return;
                setState(() {
                  if (sel) {
                    _selected.add(label);
                  } else {
                    _selected.remove(label);
                  }
                });
              },
              selectedColor: teal3,
              backgroundColor: Colors.white12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          child: !_showFeedback
              ? SizedBox(
                  key: const ValueKey('submit'),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selected.isEmpty ? null : _submitAnswer,
                    style: ElevatedButton.styleFrom(backgroundColor: teal3),
                    child: const Text('Check'),
                  ),
                )
              : ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.96,
                    end: 1.0,
                  ).animate(_animController),
                  child: Container(
                    key: const ValueKey('feedback'),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: Colors.white12),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.tealAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Correct answers: ${correctAnswers.join(', ')}',
                                style: const TextStyle(
                                  color: Colors.tealAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          card.explanation,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _nextCard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: teal4,
                              ),
                              child: Text(
                                _index < _cardsThisRound.length - 1
                                    ? 'Next'
                                    : 'Finish',
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/thought',
                                  arguments: {'prefill': card.text},
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white12),
                              ),
                              child: const Text('Add to thought record'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _asqCard() {
    final item = _asqThisRound[_index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.prompt,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 12),
        RadioListTile<int>(
          value: 0,
          groupValue: _asqSelection,
          onChanged: _showFeedback
              ? null
              : (v) => setState(() => _asqSelection = v),
          title: Text(
            'A. ${item.optionA}',
            style: const TextStyle(color: Colors.white),
          ),
          activeColor: teal3,
        ),
        RadioListTile<int>(
          value: 1,
          groupValue: _asqSelection,
          onChanged: _showFeedback
              ? null
              : (v) => setState(() => _asqSelection = v),
          title: Text(
            'B. ${item.optionB}',
            style: const TextStyle(color: Colors.white),
          ),
          activeColor: teal3,
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          child: !_showFeedback
              ? SizedBox(
                  key: const ValueKey('submit_asq'),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _asqSelection == null
                        ? null
                        : _submitAttribution,
                    style: ElevatedButton.styleFrom(backgroundColor: teal3),
                    child: const Text('Submit'),
                  ),
                )
              : ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.96,
                    end: 1.0,
                  ).animate(_animController),
                  child: Container(
                    key: const ValueKey('feedback_asq'),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: Colors.white12),
                        Row(
                          children: const [
                            Icon(
                              Icons.assessment_outlined,
                              color: Colors.tealAccent,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Answer recorded',
                              style: TextStyle(color: Colors.tealAccent),
                            ),
                          ],
                        ),
                        if (item.note.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.note,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _nextCard,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: teal4,
                              ),
                              child: Text(
                                _index < _asqThisRound.length - 1
                                    ? 'Next'
                                    : 'Finish',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------- Results Page (Attribution) ----------------

class AsqResultsPage extends StatelessWidget {
  final GameSession session;
  final Map<String, int> totals; // sum of 1s for each dimension
  final Map<String, int> counts; // number of items seen for each dimension
  final VoidCallback onPlayAgain;

  const AsqResultsPage({
    super.key,
    required this.session,
    required this.totals,
    required this.counts,
    required this.onPlayAgain,
  });

  double _pct(String k) {
    final t = totals[k] ?? 0;
    final c = counts[k] ?? 0;
    if (c == 0) return 0.0;
    return t / c;
  }

  // Hope Index = PmB + PvB (optimism points)
  Map<String, dynamic> _hope() {
    final t = (totals['PmB'] ?? 0) + (totals['PvB'] ?? 0);
    final c = (counts['PmB'] ?? 0) + (counts['PvB'] ?? 0);
    final pct = (c == 0) ? 0.0 : t / c;
    return {'t': t, 'c': c, 'pct': pct};
  }

  @override
  Widget build(BuildContext context) {
    final hope = _hope();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: teal1,
        title: const Text('Attribution Results'),
      ),
      backgroundColor: const Color(0xFF021515),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TitleText('Summary'),
                  const SizedBox(height: 8),
                  _line('Items answered', '${session.cardsSeen}'),
                  _line('Optimism points (sum of 1s)', '${session.score}'),
                  _line(
                    'Hope Index (PmB+PvB)',
                    '${hope['t']}/${hope['c']}  (${(hope['pct'] * 100).toStringAsFixed(0)}%)',
                  ),
                  const SizedBox(height: 12),
                  _band('Hope Index', hope['pct'] as double),
                  const SizedBox(height: 8),
                  const Text(
                    'Higher Hope means you tended to explain bad events as temporary (Permanence) and specific (Pervasiveness).',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TitleText('Bad Events (want higher %)'),
                  const SizedBox(height: 10),
                  _metricRow('Permanence (PmB)', _pct('PmB')),
                  _metricRow('Pervasiveness (PvB)', _pct('PvB')),
                  _metricRow('Personalization (PsB)', _pct('PsB')),
                  const SizedBox(height: 8),
                  const Text(
                    'For bad events, optimistic style = Temporary (PmB), Specific (PvB), External (PsB).',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TitleText('Good Events (want higher %)'),
                  const SizedBox(height: 10),
                  _metricRow('Permanence (PmG)', _pct('PmG')),
                  _metricRow('Pervasiveness (PvG)', _pct('PvG')),
                  _metricRow('Personalization (PsG)', _pct('PsG')),
                  const SizedBox(height: 8),
                  const Text(
                    'For good events, optimistic style = Permanent (PmG), Universal (PvG), Internal (PsG).',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPlayAgain,
                    icon: const Icon(Icons.replay),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal3,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    label: const Text('Play again'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: teal2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }

  Widget _line(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: const TextStyle(color: Colors.white70)),
          ),
          Text(v, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _metricRow(String label, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _band(label, pct),
        ],
      ),
    );
  }

  Widget _band(String label, double pct) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Container(height: 12, color: Colors.white12),
          FractionallySizedBox(
            widthFactor: pct.clamp(0.0, 1.0),
            child: Container(height: 12, color: teal4),
          ),
        ],
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  final String text;
  const _TitleText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
