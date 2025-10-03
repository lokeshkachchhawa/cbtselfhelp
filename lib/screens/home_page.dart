// lib/screens/home_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Palette derived from the provided image (left -> right)
const Color teal1 = Color.fromARGB(255, 1, 108, 108); // very light
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

final List<Color> tealPalette = [teal1, teal2, teal3, teal4, teal5, teal6];

class _HomePageState extends State<HomePage> {
  int mood = 5;
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient background using palette
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              teal1,
              const Color.fromARGB(255, 3, 3, 3),
              const Color.fromARGB(255, 9, 36, 29),
              teal4,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar / header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // small circular logo placeholder
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(Icons.self_improvement, color: teal6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good ${_timeOfDayGreeting()}, ${user?.displayName ?? 'there'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Small daily practices help — 5–10 mins a day',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // open settings or profile
                      },
                      icon: Icon(Icons.settings, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mood quick entry card
                      _buildMoodCard(),

                      const SizedBox(height: 12),

                      // Today's task card (now has ABCD option)
                      _buildTaskCard(),

                      const SizedBox(height: 12),

                      // Quick tools row (includes ABCD)
                      _buildQuickTools(),

                      const SizedBox(height: 16),

                      // Programs carousel (simple horizontal list)
                      const Text(
                        'Programs',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildProgramsCarousel(),

                      const SizedBox(height: 16),

                      // Progress card
                      _buildProgressCard(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Persistent bottom bar with Get Help CTA
              Container(
                color: Colors.white.withOpacity(0.06),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/safety');
                        },
                        icon: const Icon(Icons.volunteer_activism),
                        label: const Text('Get Help'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            172,
                            69,
                            0,
                          ),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      onPressed:
                          _openQuickCreateSheet, // now opens sheet with choices
                      backgroundColor: teal3,
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New: bottom sheet letting user quickly create Thought or ABCD
  void _openQuickCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quick create',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: teal4,
                    child: const Icon(Icons.note_alt, color: Colors.white),
                  ),
                  title: const Text('New thought record'),
                  subtitle: const Text('Capture an automatic thought quickly'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.pushNamed(context, '/thought');
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: teal4,
                    child: const Icon(Icons.rule, color: Colors.white),
                  ),
                  title: const Text('New ABCD worksheet'),
                  subtitle: const Text(
                    'Open the ABCD worksheet (Activating event → Belief → Consequence → Dispute)',
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.pushNamed(context, '/abcd');
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoodCard() {
    return Card(
      color: Colors.white.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How are you feeling right now?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: teal3,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: teal4,
                      overlayColor: teal4.withOpacity(0.2),
                      valueIndicatorColor: teal4,
                    ),
                    child: Slider(
                      value: mood.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: '$mood',
                      onChanged: (v) => setState(() => mood = v.toInt()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    moodLabel(mood),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _saveMood,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.12)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard() {
    return Card(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Today\'s task',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'Complete a short thought record or try an ABCD worksheet',
            style: TextStyle(color: Colors.white70),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/thought'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/abcd'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('ABCD'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTools() {
    final tools = [
      {'icon': Icons.note_alt, 'label': 'Thought', 'route': '/thought'},
      {
        'icon': Icons.rule,
        'label': 'ABCD',
        'route': '/abcd',
      }, // <-- added ABCD here
      {
        'icon': Icons.access_time,
        'label': 'Activities',
        'route': '/activities',
      },
      {'icon': Icons.self_improvement, 'label': 'Relax', 'route': '/relax'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: tools.map((t) {
        return Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, t['route'] as String),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: teal4,
                    child: Icon(t['icon'] as IconData, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t['label'] as String,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProgramsCarousel() {
    // Example program cards - replace with dynamic data later
    final programs = [
      {
        'title': '7-Day Mood Boost',
        'days': '7 days',
        'color': const Color.fromARGB(255, 1, 73, 69),
      },
      {'title': 'Managing Worry', 'days': '4 weeks', 'color': teal4},
      {'title': 'Sleep Better', 'days': '2 weeks', 'color': teal5},
    ];

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: programs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = programs[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/programs'),
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    p['color'] as Color,
                    (p['color'] as Color).withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p['days'] as String,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/programs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Start',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressCard() {
    // Placeholder progress UI
    return Card(
      color: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Circular progress placeholder
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [teal3, teal4]),
                  ),
                  child: Center(
                    child: Text(
                      '42%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Lessons completed: 5/12',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Average mood this week: 6.2',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  String moodLabel(int m) {
    if (m <= 2) return 'Low';
    if (m <= 4) return 'Down';
    if (m <= 6) return 'Okay';
    if (m <= 8) return 'Good';
    return 'Great';
  }

  void _saveMood() {
    // Save mood to Firestore (simple example)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save your mood')),
      );
      return;
    }
    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('moodLogs')
        .doc();
    doc.set({
      'score': mood,
      'note': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mood saved')));
  }
}
