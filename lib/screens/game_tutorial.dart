// lib/screens/game_tutorial.dart
import 'package:flutter/material.dart';

const Color teal1 = Color.fromARGB(255, 1, 108, 108);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);

class GameTutorialPage extends StatelessWidget {
  const GameTutorialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF021515),
        appBar: AppBar(
          backgroundColor: teal1,
          title: const Text('How to play'),
          bottom: const TabBar(
            labelColor: Colors.white, // selected tab text
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white, // underline color
            tabs: [
              Tab(text: 'Distortions'),
              Tab(text: 'Attribution'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DistortionsHelp(), _AttributionHelp()],
        ),
      ),
    );
  }
}

class _DistortionsHelp extends StatelessWidget {
  const _DistortionsHelp();

  @override
  Widget build(BuildContext context) {
    return _ScrollPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _H1('Thought Detective (Cognitive Distortions)'),
          _P(
            'Read the thought. Pick which labels fit. Some thoughts can have more than one label.',
          ),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _H2('Common labels'),
                _Bullet('Mind reading — assuming you know what others think.'),
                _Bullet('Catastrophising — jumping to worst-case scenarios.'),
                _Bullet(
                  'Overgeneralisation — “always/never” after a few events.',
                ),
                _Bullet(
                  'All-or-nothing — only perfect or failure, nothing between.',
                ),
                _Bullet(
                  'Emotional reasoning — “I feel it, so it must be true.”',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _H2('Example'),
                _Code('Thought: “They didn’t reply — they must be angry.”'),
                _P(
                  'Best labels: Mind reading (guessing feelings without evidence).',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _H2('Scoring'),
                _P(
                  'Each correct label = +10 points. Each wrong label = –2 points. '
                  'Score ≥ 50% correct to unlock the next level.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Tip(
            'Pro tip: If you are unsure, pick fewer labels you feel confident about.',
          ),
        ],
      ),
    );
  }
}

class _AttributionHelp extends StatelessWidget {
  const _AttributionHelp();

  @override
  Widget build(BuildContext context) {
    return _ScrollPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _H1('Attribution Style (Learned Optimism)'),
          _P(
            'For each situation, choose A or B. Some choices earn 1 point (more optimistic), others 0.',
          ),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _H2('What is “optimistic style”?'),
                _Bullet(
                  'Bad events → Temporary (PmB), Specific (PvB), External (PsB).',
                ),
                _Bullet(
                  'Good events → Permanent (PmG), Universal (PvG), Internal (PsG).',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _H2('Example (Bad event)'),
                _Code('Prompt: “You made an error in an email.”'),
                _Code('A. “I always mess up communications.”  (0)'),
                _Code('B. “I was rushed today.”                (1)'),
                _P('Why? “Today” is temporary (PmB=1).'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _H2('Example (Good event)'),
                _Code('Prompt: “Your boss praises your presentation.”'),
                _Code('A. “I usually present well.”  (1)  → Permanent'),
                _Code('B. “This topic was easy.”     (0)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _H2('Scoring & Levels'),
                _P(
                  'Each optimistic pick = 1 point. '
                  'Score ≥ 50% on a level (5 items) to unlock the next one. '
                  'Your results page shows your percentages for each dimension.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Tip(
            'Pro tip: Think “Could this be temporary or specific?” for setbacks. '
            'For wins, ask “What did I do right that I can repeat?”.',
          ),
        ],
      ),
    );
  }
}

class _ScrollPad extends StatelessWidget {
  final Widget child;
  const _ScrollPad({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _H1 extends StatelessWidget {
  final String text;
  const _H1(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _H2 extends StatelessWidget {
  final String text;
  const _H2(this.text);
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

class _P extends StatelessWidget {
  final String text;
  const _P(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, height: 1.35),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.white70)),
          Expanded(child: _P(text)),
        ],
      ),
    );
  }
}

class _Code extends StatelessWidget {
  final String text;
  const _Code(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2020),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.lightbulb_outline, color: teal2),
        const SizedBox(width: 8),
        Expanded(child: _P(text)),
      ],
    );
  }
}
