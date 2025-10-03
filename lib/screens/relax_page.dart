// lib/screens/relax_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// RelaxPage: hub for relaxation tools (cards for each feature).
/// Dark theme, teal palette (team theme), roomy cards, subtle gradients.
/// Added small staggered entrance animations for cards (fade + slide).

const Color teal1 = Color(0xFF016C6C); // deep teal (primary)
const Color teal2 = Color(0xFF79C2BF); // light accent
const Color teal3 = Color(0xFF008F89); // primary accent
const Color teal4 = Color(0xFF007A78); // darker accent
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

const Color surfaceDark = Color(0xFF081015);
const Color cardDark = Color(0xFF092426);
const Color mutedText = Color(0xFFBFDCDC);
const Color dimText = Color(0xFFA3CFCB);

class RelaxPage extends StatefulWidget {
  const RelaxPage({super.key});

  @override
  State<RelaxPage> createState() => _RelaxPageState();
}

class _RelaxPageState extends State<RelaxPage> with TickerProviderStateMixin {
  late final AnimationController _controller;

  // animation timing - tweak these to get faster/slower or wider spacing
  final Duration singleDuration = const Duration(milliseconds: 450);
  final double staggerDelay = 0.08; // fraction of total: lower = more overlap

  // list of feature card data so we can easily map indexes to animation intervals
  final List<_Feature> _features = [
    _Feature(
      title: 'Breathing Exercises',
      subtitle: 'Guided inhale/exhale circle animation. Adjustable duration.',
      icon: Icons.air,
      color: teal3,
      route: '/relax/breath',
    ),
    _Feature(
      title: 'Progressive Muscle Relaxation',
      subtitle: 'Step-by-step tensing & releasing with audio & text guidance.',
      icon: Icons.self_improvement,
      color: teal5,
      route: '/relax_pmr',
    ),
    _Feature(
      title: 'Grounding (5-4-3-2-1)',
      subtitle: 'Interactive exercise to quickly ground you in the present.',
      icon: Icons.filter_5,
      color: teal4,
      route: '/grounding',
    ),
    _Feature(
      title: 'Mini Meditation Timer',
      subtitle: 'Timer with gentle background sounds. Start/stop and duration.',
      icon: Icons.timer,
      color: teal2,
      route: '/minimeditation',
    ),
    _Feature(
      title: 'Soothing Sounds',
      subtitle: 'Rain, waves, birds & white noise. Loopable playback.',
      icon: Icons.music_note,
      color: Colors.indigoAccent,
      route: '/relax/sounds',
    ),
  ];

  @override
  void initState() {
    super.initState();

    // total duration: singleDuration + stagger per item
    final int items = _features.length + 1; // +1 for the tips card
    final double totalSeconds =
        singleDuration.inMilliseconds / 1000 + (items * staggerDelay);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (totalSeconds * 1000).round()),
    );

    // play automatically
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // build a per-index animation that returns a CurvedAnimation with an Interval
  Animation<double> _buildInterval(int index, {double startOffset = 0}) {
    final int items = _features.length + 1; // +1 for tips
    final double start =
        (index * staggerDelay) /
        (singleDuration.inMilliseconds / 1000 + items * staggerDelay);
    final double durationFraction =
        singleDuration.inMilliseconds /
        1000 /
        (singleDuration.inMilliseconds / 1000 + items * staggerDelay);

    final double begin = start.clamp(0.0, 1.0);
    final double end = (start + durationFraction).clamp(0.0, 1.0);

    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceDark,
      appBar: AppBar(
        title: const Text('Relax'),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [teal4, teal1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 12),
              _searchHint(),
              const SizedBox(height: 16),

              // Feature cards with staggered animation
              ...List.generate(_features.length, (i) {
                final feature = _features[i];

                final animation = _buildInterval(i);

                // slide from slightly below + fade in
                final slideTween = Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slideTween.animate(animation),
                      child: _featureCard(
                        context,
                        title: feature.title,
                        subtitle: feature.subtitle,
                        icon: feature.icon,
                        color: feature.color,
                        route: feature.route,
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 20),

              // Tips card (animate as last item)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final index = _features.length;
                  final anim = _buildInterval(index);
                  final slideTween = Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  );

                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: slideTween.animate(anim),
                      child: child,
                    ),
                  );
                },
                child: Card(
                  color: cardDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Quick tips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Use breathing exercises for 1–5 minutes when anxious.\n'
                          '• Progressive muscle relaxation works well before sleep.\n'
                          '• Grounding helps during panic or high anxiety.\n'
                          '• Try the mini meditation daily — consistency helps.',
                          style: TextStyle(color: Color(0xFFA3CFCB)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [teal3, teal4],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8),
            ],
          ),
          child: const Icon(
            Icons.self_improvement,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Relax & Reset',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Short practices to help calm your body and mind',
                style: TextStyle(color: Color(0xFF9FCFC7)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchHint() {
    return GestureDetector(
      onTap: () {
        // placeholder: later add search or filter
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: mutedText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search exercises (coming soon)',
                style: TextStyle(color: mutedText.withOpacity(0.9)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      borderRadius: BorderRadius.circular(14),
      child: Card(
        color: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.95), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFA3CFCB),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: dimText),
            ],
          ),
        ),
      ),
    );
  }
}

// small data holder for features
class _Feature {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  _Feature({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}
