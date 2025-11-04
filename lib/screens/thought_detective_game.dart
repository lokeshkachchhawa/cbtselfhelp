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

// ---------------- Lightweight i18n ----------------
enum AppLang { en, hi }

class _Strings {
  final String appTitleDistortion;
  final String appTitleAsq;
  final String avgLast;
  final String howToPlay;
  final String modeDistortions;
  final String modeAttribution;
  final String noCards;
  final String retry;
  final String score;
  final String level;
  final String nextLevel;
  final String nextLevelLocked;
  final String replayLevel;
  final String close;
  final String createThought;
  final String check;
  final String correctAnswers;
  final String addToThoughtRecord;
  final String next;
  final String finish;
  final String submit;
  final String answerRecorded;
  final String atResultsTitle;
  final String summary;
  final String itemsAnswered;
  final String optimismPoints;
  final String hopeIndex;
  final String hopeExplainer;
  final String badEventsWantHigher;
  final String goodEventsWantHigher;
  final String badExplainer;
  final String goodExplainer;
  final String playAgain;
  final List<String> distortionLabels;
  final String need50Unlock;
  final String unlockedNext;

  const _Strings({
    required this.appTitleDistortion,
    required this.appTitleAsq,
    required this.avgLast,
    required this.howToPlay,
    required this.modeDistortions,
    required this.modeAttribution,
    required this.noCards,
    required this.retry,
    required this.score,
    required this.level,
    required this.nextLevel,
    required this.nextLevelLocked,
    required this.replayLevel,
    required this.close,
    required this.createThought,
    required this.check,
    required this.correctAnswers,
    required this.addToThoughtRecord,
    required this.next,
    required this.finish,
    required this.submit,
    required this.answerRecorded,
    required this.atResultsTitle,
    required this.summary,
    required this.itemsAnswered,
    required this.optimismPoints,
    required this.hopeIndex,
    required this.hopeExplainer,
    required this.badEventsWantHigher,
    required this.goodEventsWantHigher,
    required this.badExplainer,
    required this.goodExplainer,
    required this.playAgain,
    required this.distortionLabels,
    required this.need50Unlock,
    required this.unlockedNext,
  });

  static const en = _Strings(
    appTitleDistortion: 'Thought Detective',
    appTitleAsq: 'Attribution Game',
    avgLast: 'Avg (last {n})',
    howToPlay: 'How to play',
    modeDistortions: 'Distortions Mode',
    modeAttribution: 'Attribution Mode',
    noCards: 'No cards available',
    retry: 'Retry',
    score: 'Score',
    level: 'Level',
    nextLevel: 'Next Level',
    nextLevelLocked: 'Next Level (Locked)',
    replayLevel: 'Replay Level',
    close: 'Close',
    createThought: 'Create thought record',
    check: 'Check',
    correctAnswers: 'Correct answers',
    addToThoughtRecord: 'Add to thought record',
    next: 'Next',
    finish: 'Finish',
    submit: 'Submit',
    answerRecorded: 'Answer recorded',
    atResultsTitle: 'Attribution Results',
    summary: 'Summary',
    itemsAnswered: 'Items answered',
    optimismPoints: 'Optimism points (sum of 1s)',
    hopeIndex: 'Hope Index (PmB+PvB)',
    hopeExplainer:
        'Higher Hope means you tended to explain bad events as temporary (Permanence) and specific (Pervasiveness).',
    badEventsWantHigher: 'Bad Events (want higher %)',
    goodEventsWantHigher: 'Good Events (want higher %)',
    badExplainer:
        'For bad events, optimistic style = Temporary (PmB), Specific (PvB), External (PsB).',
    goodExplainer:
        'For good events, optimistic style = Permanent (PmG), Universal (PvG), Internal (PsG).',
    playAgain: 'Play again',
    distortionLabels: [
      'Mind reading',
      'Catastrophising',
      'Overgeneralisation',
      'All-or-nothing',
      'Emotional reasoning',
    ],
    need50Unlock: 'Get at least 50% correct to unlock the next level.',
    unlockedNext: 'Unlocked next level!',
  );

  static const hi = _Strings(
    appTitleDistortion: 'विचार जासूस',
    appTitleAsq: 'आरोपण खेल',
    avgLast: 'औसत (आख़िरी {n})',
    howToPlay: 'कैसे खेलें',
    modeDistortions: 'डिस्टॉर्शन मोड',
    modeAttribution: 'आरोपण मोड',
    noCards: 'कार्ड उपलब्ध नहीं',
    retry: 'फिर कोशिश करें',
    score: 'स्कोर',
    level: 'स्तर',
    nextLevel: 'अगला स्तर',
    nextLevelLocked: 'अगला स्तर (लॉक)',
    replayLevel: 'स्तर दोबारा खेलें',
    close: 'बंद करें',
    createThought: 'थॉट रिकॉर्ड बनाएं',
    check: 'जांचें',
    correctAnswers: 'सही उत्तर',
    addToThoughtRecord: 'थॉट रिकॉर्ड में जोड़ें',
    next: 'आगे',
    finish: 'समाप्त',
    submit: 'सबमिट',
    answerRecorded: 'उत्तर दर्ज हुआ',
    atResultsTitle: 'आरोपण के परिणाम',
    summary: 'सारांश',
    itemsAnswered: 'दिये गए उत्तर',
    optimismPoints: 'आशावाद अंक (1 का योग)',
    hopeIndex: 'होप इंडेक्स (PmB+PvB)',
    hopeExplainer:
        'उच्च होप का अर्थ है कि आप बुरी घटनाओं को अस्थायी (Permanence) और विशिष्ट (Pervasiveness) मानते हैं।',
    badEventsWantHigher: 'बुरी घटनाएँ (ऊँचा % बेहतर)',
    goodEventsWantHigher: 'अच्छी घटनाएँ (ऊँचा % बेहतर)',
    badExplainer:
        'बुरी घटनाओं में, आशावादी शैली = अस्थायी (PmB), विशिष्ट (PvB), बाहरी (PsB)।',
    goodExplainer:
        'अच्छी घटनाओं में, आशावादी शैली = स्थायी (PmG), सार्वभौमिक (PvG), आंतरिक (PsG)।',
    playAgain: 'फिर खेलें',
    distortionLabels: [
      'दिमाग़ पढ़ना',
      'विनाशकारी निष्कर्ष',
      'अतिसामान्यीकरण',
      'सब-या-कुछ नहीं',
      'भावनात्मक तर्क',
    ],
    need50Unlock: 'अगला स्तर अनलॉक करने के लिए कम से कम 50% सही करें।',
    unlockedNext: 'अगला स्तर अनलॉक हुआ!',
  );
}

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
  final int scoreA; // 0/1
  final String optionB;
  final int scoreB; // 0/1
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
  static const String _prefsLevelsKey = 'td_levels_unlocked';

  // Levels config (Attribution)
  static const int _asqLevelsCount = 6;
  static const int _asqCardsPerLevel = 5;
  static const String _prefsAsqLevelsKey = 'asq_levels_unlocked';

  // Language persistence
  static const String _prefsLangKey = 'td_lang';

  // Mode & Language
  GameMode _mode = GameMode.distortions;
  AppLang _lang = AppLang.en;
  _Strings get t => _lang == AppLang.hi ? _Strings.hi : _Strings.en;

  /// JSON-loaded content
  final List<CardItem> _cardBank = []; // distortions chips
  final List<AttributionItem> _asqBank = []; // attribution A/B

  // Distortion labels (chips) — derived from t.distortionLabels
  List<String> get _labels => t.distortionLabels;

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

  // Attribution tallies
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

  // UI animation controller
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

    _initAll();
  }

  Future<void> _initAll() async {
    await _loadHistory();
    await _loadLevelsProgress();
    await _loadSavedLang();
    await _loadCardsFromJson(); // language-aware
    await _loadAttributionFromJson(); // language-aware
    _buildThoughtDetectiveLevels();
    _buildAsqLevels();
    _selectedLevel = _selectedLevel.clamp(1, _highestUnlocked);
    _selectedAsqLevel = _selectedAsqLevel.clamp(1, _highestUnlockedAsq);
    _startRound();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ---------- Language ----------
  Future<void> _loadSavedLang() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_prefsLangKey);
    setState(() {
      _lang = (val == 'hi') ? AppLang.hi : AppLang.en;
    });
  }

  Future<void> _saveLang(AppLang lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLangKey, lang == AppLang.hi ? 'hi' : 'en');
  }

  Future<void> _switchLang(AppLang lang) async {
    if (_lang == lang) return;
    setState(() {
      _lang = lang;
    });
    await _saveLang(lang);
    await _loadCardsFromJson();
    await _loadAttributionFromJson();
    _buildThoughtDetectiveLevels();
    _buildAsqLevels();
    _startRound();
  }

  String get _langSuffix => _lang == AppLang.hi ? '_hi' : '';

  // ---------- Loaders ----------
  Future<void> _loadCardsFromJson() async {
    // Try language file first; if missing, fall back to EN
    final candidates = [
      'assets/data/thought_detective_questions$_langSuffix.json',
      'assets/data/thought_detective_questions.json',
    ];
    for (final path in candidates) {
      try {
        final raw = await rootBundle.loadString(path);
        final List decoded = json.decode(raw) as List;
        final loaded = decoded
            .map((m) => CardItem.fromMap(m as Map<String, dynamic>))
            .toList();
        setState(() {
          _cardBank
            ..clear()
            ..addAll(loaded);
        });
        return;
      } catch (_) {
        // try next
      }
    }
    debugPrint("Failed to load distortions JSON in any language.");
    setState(() {
      _cardBank.clear();
    });
  }

  Future<void> _loadAttributionFromJson() async {
    final candidates = [
      'assets/data/asq_items$_langSuffix.json',
      'assets/data/asq_items.json',
    ];
    for (final path in candidates) {
      try {
        final raw = await rootBundle.loadString(path);
        final List decoded = json.decode(raw) as List;
        final loaded = decoded
            .map((m) => AttributionItem.fromMap(m as Map<String, dynamic>))
            .toList();
        setState(() {
          _asqBank
            ..clear()
            ..addAll(loaded);
        });
        return;
      } catch (_) {
        // try next
      }
    }
    debugPrint("Failed to load ASQ JSON in any language.");
    setState(() {
      _asqBank.clear();
    });
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
      _highestUnlocked = prefs.getInt(_prefsLevelsKey) ?? 1;
      _selectedLevel = _highestUnlocked;
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

  // --------- UPDATED: Partial scoring, no penalty for wrong picks ---------
  void _submitAnswer() {
    if (_selected.isEmpty) return;

    final card = _cardsThisRound[_index];
    final correct = card.answers;
    final int totalCorrect = correct.length;

    // Count only correct picks (no penalty for wrong)
    int correctPicked = 0;
    for (final s in _selected) {
      if (correct.contains(s)) correctPicked++;
    }

    // Each question is out of 10 points → split equally among correct answers
    // Example: 2 correct → each worth 5. Pick 1 correct → 5. Pick both (+wrong) → 10.
    final earned = totalCorrect == 0
        ? 0
        : ((10.0 * correctPicked) / totalCorrect).round();

    _score += earned;
    _correctThisRound +=
        correctPicked; // kept for legacy stats (not used for unlock)

    _animController.forward().then((_) => _animController.reverse());
    setState(() => _showFeedback = true);
  }

  void _submitAttribution() {
    if (_asqSelection == null) return;
    final item = _asqThisRound[_index];
    final selectedScore = (_asqSelection == 0) ? item.scoreA : item.scoreB;

    _score += selectedScore; // ASQ questions are 0/1 each
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
              strings: t, // pass localized strings
            ),
          ),
        );
      } else {
        _maybeUnlockNextLevel(session);
        _showSummary(session);
      }
    }
  }

  // --------- UPDATED: Unlock by total score % (>= 50%) ---------
  void _maybeUnlockNextLevel(GameSession s) {
    // Max score differs by mode
    final int maxScore = (_mode == GameMode.attribution)
        ? s.cardsSeen
        : (s.cardsSeen * 10);
    final double pct = maxScore == 0 ? 0.0 : s.score / maxScore;
    final bool passed = pct >= 0.50;

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

  // --------- UPDATED: Summary shows score/max and % (no 7/5 bug) ---------
  void _showSummary(GameSession session) {
    final int maxScore = (_mode == GameMode.attribution)
        ? session.cardsSeen
        : (session.cardsSeen * 10);
    final double pct = maxScore == 0 ? 0.0 : session.score / maxScore;
    final bool passed = pct >= 0.5;
    final String pctStr = (pct * 100).toStringAsFixed(0);

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
                '${t.level} $_selectedLevel ${t.close == 'Close' ? 'complete' : 'पूरा'}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              // Score line (e.g., 37/50 (74%))
              Text(
                '${t.score}: ${session.score}/$maxScore  ($pctStr%)',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              // Items answered is just a count now (prevents 7/5 issue)
              Text(
                '${t.itemsAnswered}: ${session.cardsSeen}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (passed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_open, color: Colors.tealAccent),
                    const SizedBox(width: 8),
                    Text(
                      t.unlockedNext,
                      style: const TextStyle(color: Colors.tealAccent),
                    ),
                  ],
                )
              else
                Text(
                  t.need50Unlock,
                  style: const TextStyle(color: Colors.white70),
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
                    child: Text(t.replayLevel),
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
                      nextLockedDist ? t.nextLevelLocked : t.nextLevel,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(t.close, style: TextStyle(color: teal4)),
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
                child: Text(t.createThought),
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
        elevation: 0,
        title: Text(
          "CBT games",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<AppLang>(
            tooltip: 'Language',
            icon: const Icon(Icons.language),
            initialValue: _lang,
            onSelected: _switchLang,
            itemBuilder: (ctx) => [
              CheckedPopupMenuItem(
                value: AppLang.en,
                checked: _lang == AppLang.en,
                child: const Text('English'),
              ),
              CheckedPopupMenuItem(
                value: AppLang.hi,
                checked: _lang == AppLang.hi,
                child: const Text('हिंदी'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: t.howToPlay,
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
            Text(t.noCards, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => setState(() => _startRound()),
              style: ElevatedButton.styleFrom(backgroundColor: teal3),
              child: Text(t.retry),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          Text(
            isASQ ? t.appTitleAsq : t.appTitleDistortion,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0, bottom: 8.0),
              child: Text(
                '${t.avgLast.replaceFirst('{n}', min(7, _history.length).toString())}: ${_avgScoreLast7.toStringAsFixed(0)} pts',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const SizedBox(height: 8),

          _levelHeader(isAsq: isASQ),

          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(teal4),
            minHeight: 6,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              color: Colors.white10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: isASQ ? _asqCard() : _distortionCard(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${t.score}: $_score',
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
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: GameMode.distortions,
          child: Text(t.modeDistortions),
        ),
        PopupMenuItem(
          value: GameMode.attribution,
          child: Text(t.modeAttribution),
        ),
      ],
    );
  }

  Widget _levelHeader({required bool isAsq}) {
    final current = isAsq ? _selectedAsqLevel : _selectedLevel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showLevelPicker(isAsq: isAsq),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                "Level $current",
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 16, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  void _showLevelPicker({required bool isAsq}) {
    final total = isAsq ? _asqLevelsCount : _levelsCount;
    final highest = isAsq ? _highestUnlockedAsq : _highestUnlocked;
    final selected = isAsq ? _selectedAsqLevel : _selectedLevel;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF021515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: total,
          itemBuilder: (_, i) {
            final level = i + 1;
            final locked = level > highest;

            return ListTile(
              enabled: !locked,
              onTap: locked
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      setState(() {
                        if (isAsq) {
                          _selectedAsqLevel = level;
                        } else {
                          _selectedLevel = level;
                        }
                      });
                      _startRound();
                    },
              leading: Icon(
                locked ? Icons.lock : Icons.flag,
                color: locked ? Colors.white24 : Colors.tealAccent,
              ),
              title: Text(
                "Level $level",
                style: TextStyle(
                  color: locked
                      ? Colors.white24
                      : (selected == level ? Colors.tealAccent : Colors.white),
                  fontWeight: selected == level
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              trailing: selected == level
                  ? const Icon(Icons.check, color: Colors.tealAccent)
                  : null,
            );
          },
        );
      },
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
                    child: Text(t.check),
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
                                '${t.correctAnswers}: ${correctAnswers.join(', ')}',
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
                                    ? t.next
                                    : t.finish,
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
                              child: Text(t.addToThoughtRecord),
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
                    child: Text(t.submit),
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
                          children: [
                            const Icon(
                              Icons.assessment_outlined,
                              color: Colors.tealAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              t.answerRecorded,
                              style: const TextStyle(color: Colors.tealAccent),
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
                                    ? t.next
                                    : t.finish,
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
  final _Strings strings;

  const AsqResultsPage({
    super.key,
    required this.session,
    required this.totals,
    required this.counts,
    required this.onPlayAgain,
    required this.strings,
  });

  double _pct(String k) {
    final t = totals[k] ?? 0;
    final c = counts[k] ?? 0;
    if (c == 0) return 0.0;
    return t / c;
  }

  // Hope Index = PmB + PvB
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
        title: Text(strings.atResultsTitle),
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
                  _TitleText(strings.summary),
                  const SizedBox(height: 8),
                  _line(strings.itemsAnswered, '${session.cardsSeen}'),
                  _line(strings.optimismPoints, '${session.score}'),
                  _line(
                    strings.hopeIndex,
                    '${hope['t']}/${hope['c']}  (${(hope['pct'] * 100).toStringAsFixed(0)}%)',
                  ),
                  const SizedBox(height: 12),
                  _band(strings.hopeIndex, hope['pct'] as double),
                  const SizedBox(height: 8),
                  Text(
                    strings.hopeExplainer,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TitleText(strings.badEventsWantHigher),
                  const SizedBox(height: 10),
                  _metricRow('Permanence (PmB)', _pct('PmB')),
                  _metricRow('Pervasiveness (PvB)', _pct('PvB')),
                  _metricRow('Personalization (PsB)', _pct('PsB')),
                  const SizedBox(height: 8),
                  Text(
                    strings.badExplainer,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TitleText(strings.goodEventsWantHigher),
                  const SizedBox(height: 10),
                  _metricRow('Permanence (PmG)', _pct('PmG')),
                  _metricRow('Pervasiveness (PvG)', _pct('PvG')),
                  _metricRow('Personalization (PsG)', _pct('PsG')),
                  const SizedBox(height: 8),
                  Text(
                    strings.goodExplainer,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                    label: Text(strings.playAgain),
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
