// lib/screens/thought_detective_game.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color teal1 = Color.fromARGB(255, 1, 108, 108);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);

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

class _ThoughtDetectiveGameState extends State<ThoughtDetectiveGame>
    with SingleTickerProviderStateMixin {
  // Config
  static const int _cardsPerRound = 5;
  static const String _prefsKey = 'td_game_history';
  // Content (replace/extend with your asset JSON)
  final List<CardItem> _cardBank = [
    CardItem(
      id: 'td_001',
      text: 'If I speak up I will look foolish.',
      answers: ['Mind reading', 'Catastrophising'],
      explanation:
          'Assuming others judge you negatively is mind reading; it often exaggerates outcomes.',
    ),
    CardItem(
      id: 'td_002',
      text: 'I always mess things up.',
      answers: ['Overgeneralisation'],
      explanation:
          'Using “always” is overgeneralisation — one or few events do not mean always.',
    ),
    CardItem(
      id: 'td_003',
      text: 'They didn’t reply — they must be angry with me.',
      answers: ['Mind reading'],
      explanation:
          'This assumes knowledge of others’ thoughts. Consider alternate reasons for delay.',
    ),
    // Add more cards here...
  ];

  // Distortion labels
  final List<String> _labels = [
    'Mind reading',
    'Catastrophising',
    'Overgeneralisation',
    'All-or-nothing',
    'Emotional reasoning',
  ];

  // Round state
  late List<CardItem> _cardsThisRound;
  int _index = 0;
  final Set<String> _selected = <String>{};
  int _score = 0;
  bool _showFeedback = false;
  int _correctThisRound = 0;

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
    _loadHistory().then((_) => _startRound());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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

  void _startRound() {
    if (_cardBank.isEmpty) {
      // safety fallback
      _cardsThisRound = [];
      return;
    }
    final rnd = Random();
    final shuffled = List<CardItem>.from(_cardBank)..shuffle(rnd);
    // ensure we don't request more cards than available
    _cardsThisRound = shuffled
        .take(min(_cardsPerRound, shuffled.length))
        .toList();
    _index = 0;
    _selected.clear();
    _score = 0;
    _showFeedback = false;
    _correctThisRound = 0;
    setState(() {});
  }

  void _submitAnswer() {
    if (_selected.isEmpty) return;
    final card = _cardsThisRound[_index];
    final correct = card.answers;
    int correctCount = 0;
    int wrongCount = 0;

    for (final s in _selected) {
      if (correct.contains(s))
        correctCount++;
      else
        wrongCount++;
    }

    final earned = max(0, correctCount * 10 - wrongCount * 2);
    _score += earned;
    _correctThisRound += correctCount;

    // animate feedback
    _animController.forward().then((_) => _animController.reverse());
    setState(() => _showFeedback = true);
  }

  void _nextCard() {
    if (_index < _cardsThisRound.length - 1) {
      setState(() {
        _index++;
        _selected.clear();
        _showFeedback = false;
      });
    } else {
      // finish round -> persist session
      final session = GameSession(
        score: _score,
        createdAt: DateTime.now().toUtc(),
        cardsSeen: _cardsThisRound.length,
        correctCount: _correctThisRound,
      );
      _saveSession(session);
      _showSummary(session);
    }
  }

  void _showSummary(GameSession session) {
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
                'Round complete',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Score: ${session.score}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                'Correct tags: ${session.correctCount}/${session.cardsSeen}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _startRound());
                },
                style: ElevatedButton.styleFrom(backgroundColor: teal3),
                child: const Text('Play again'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.pushNamed(context, '/thought');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white12),
                ),
                child: const Text('Create thought record'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Close', style: TextStyle(color: teal4)),
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
    // Safe empty handling
    if (_cardsThisRound.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Thought Detective'),
          backgroundColor: teal1,
        ),
        backgroundColor: const Color(0xFF021515),
        body: Center(
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
                  onPressed: () {
                    // reload or navigate back
                    setState(() => _startRound());
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: teal3),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final card = _cardsThisRound[_index];
    final correctAnswers = card.answers;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: teal1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thought Detective'),
            if (_history.isNotEmpty)
              Text(
                'Avg (last ${min(7, _history.length)}): ${_avgScoreLast7.toStringAsFixed(0)} pts',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF021515),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / _cardsThisRound.length,
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
                child: Column(
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
                        // inside the Wrap mapping
                        return ChoiceChip(
                          label: Text(
                            label,
                            semanticsLabel: 'Distortion: $label',
                          ),
                          selected: isSelected,
                          onSelected: (sel) {
                            if (_showFeedback) return;
                            setState(() {
                              if (sel)
                                _selected.add(label);
                              else
                                _selected.remove(label);
                            });
                          },
                          selectedColor: teal3,
                          backgroundColor:
                              Colors.white12, // keep subtle light chip
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.black, // <-- stronger contrast
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                                onPressed: _selected.isEmpty
                                    ? null
                                    : _submitAnswer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teal3,
                                ),
                                child: const Text('Submit'),
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
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
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
                                            side: BorderSide(
                                              color: Colors.white12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Add to thought record',
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
                ),
              ),
            ),
            const SizedBox(height: 12),
            // small footer: current score / progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Score: $_score',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  '${_index + 1}/${_cardsThisRound.length}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
