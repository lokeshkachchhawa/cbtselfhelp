import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BaselinePage extends StatefulWidget {
  const BaselinePage({super.key});

  @override
  State<BaselinePage> createState() => _BaselinePageState();
}

class _BaselinePageState extends State<BaselinePage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // PHQ-9 choices mapped to scores
  final List<String> _options = [
    'Not at all', // 0
    'Several days', // 1
    'More than half the days', // 2
    'Nearly every day', // 3
  ];

  // PHQ-9 questions (standard wording)
  final List<String> _questions = [
    '1. Little interest or pleasure in doing things',
    '2. Feeling down, depressed, or hopeless',
    '3. Trouble falling or staying asleep, or sleeping too much',
    '4. Feeling tired or having little energy',
    '5. Poor appetite or overeating',
    '6. Feeling bad about yourself — or that you are a failure or have let yourself or your family down',
    '7. Trouble concentrating on things, such as reading the newspaper or watching television',
    '8. Moving or speaking so slowly that other people could have noticed? Or the opposite — being so fidgety or restless that you have been moving a lot more than usual',
    '9. Thoughts that you would be better off dead or of hurting yourself in some way',
  ];

  // Store selected index (0..3) for each question; null = unanswered
  final List<int?> _answers = List<int?>.filled(9, null);

  bool _submitting = false;
  String? _error;

  static const int HIGH_SCORE_THRESHOLD = 20; // can tweak
  static const int Q9_RISK_MIN = 1; // any non-zero on Q9 considered risk

  int get _totalScore {
    var sum = 0;
    for (final a in _answers) {
      sum += (a ?? 0);
    }
    return sum;
  }

  String _interpretScore(int score) {
    if (score >= 20) return 'Severe';
    if (score >= 15) return 'Moderately severe';
    if (score >= 10) return 'Moderate';
    if (score >= 5) return 'Mild';
    return 'Minimal';
  }

  Future<void> _submit() async {
    // Validate all answered
    if (_answers.any((a) => a == null)) {
      setState(() => _error = 'Please answer all questions before submitting.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      final uid = user?.uid;
      if (uid == null) throw Exception('Not authenticated.');

      final score = _totalScore;
      final q9Value = _answers[8] ?? 0;

      // Save assessment doc
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('assessments')
          .doc(); // auto id

      final payload = {
        'type': 'PHQ9',
        'answers': _answers.map((e) => e ?? 0).toList(),
        'score': score,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(payload);

      // Update user doc baseline flags (merge)
      final userDocRef = _firestore.collection('users').doc(uid);
      await userDocRef.set({
        'baselineCompleted': true,
        'baselineAt': FieldValue.serverTimestamp(),
        'lastBaselineScore': score,
      }, SetOptions(merge: true));

      // Safety routing: if Q9 positive or very high score -> safety screen
      if (q9Value >= Q9_RISK_MIN || score >= HIGH_SCORE_THRESHOLD) {
        // navigate to safety screen with reason
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/safety',
          arguments: {'reason': 'phq9_risk', 'score': score},
        );
        return;
      }

      // Otherwise go to home
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e, st) {
      debugPrint('Baseline submit error: $e\n$st');
      if (mounted) setState(() => _error = 'Failed to submit. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (int i = 0; i < _options.length; i++)
              RadioListTile<int>(
                value: i,
                groupValue: _answers[index],
                onChanged: (val) {
                  setState(() {
                    _answers[index] = val;
                  });
                },
                title: Text(_options[i]),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = _totalScore;
    final interpretation = _interpretScore(score);

    return Scaffold(
      appBar: AppBar(title: const Text('Baseline Assessment (PHQ-9)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Please answer the following questions based on how you have felt over the last 2 weeks.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(9, (i) => _buildQuestionCard(i)),
                      const SizedBox(height: 12),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current score: $score',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('Interpretation: $interpretation'),
                                ],
                              ),
                              const Spacer(),
                              if (_submitting)
                                const CircularProgressIndicator(),
                            ],
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ],
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _submitting ? 'Submitting...' : 'Submit assessment',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
