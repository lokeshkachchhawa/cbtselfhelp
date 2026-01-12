// lib/screens/relax_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enhanced RelaxPage with improved UI/UX:
/// - Vibrant per-feature colors with glowing effects
/// - Smooth press animations on cards
/// - Better visual hierarchy and spacing
/// - Enhanced typography and shadows
/// - Improved accessibility with better touch targets

const Color teal1 = Color(0xFF016C6C);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

const Color surfaceDark = Color(0xFF081015);
const Color cardDark = Color(0xFF092426);
const Color mutedText = Color(0xFFBFDCDC);
const Color dimText = Color(0xFFA3CFCB);

// Vibrant colors for each feature
const Color breathBlue = Color(0xFF3B82F6); // bright blue
const Color muscleViolet = Color(0xFF8B5CF6); // purple
const Color groundGreen = Color(0xFF10B981); // emerald
const Color meditationAmber = Color(0xFFF59E0B); // warm amber

class RelaxPage extends StatefulWidget {
  const RelaxPage({super.key});

  @override
  State<RelaxPage> createState() => _RelaxPageState();
}

class _RelaxPageState extends State<RelaxPage> with TickerProviderStateMixin {
  late final AnimationController _controller;

  final Duration singleDuration = const Duration(milliseconds: 450);
  final double staggerDelay = 0.08;

  final List<_Feature> _features = [
    _Feature(
      title: 'Guided Audios by Dr. Kanhaiya',
      subtitle: 'Calming guided audios for anxiety, OCD and relaxation',
      icon: Icons.timer_rounded,
      color: meditationAmber,
      route: '/minimeditation',
    ),
    _Feature(
      title: 'Breathing Exercises',
      subtitle: 'Guided inhale/exhale with calming circle animation',
      icon: Icons.air_rounded,
      color: breathBlue,
      route: '/relax/breath',
    ),
    _Feature(
      title: 'Progressive Muscle Relaxation',
      subtitle: 'Release tension step-by-step with audio guidance',
      icon: Icons.self_improvement_rounded,
      color: muscleViolet,
      route: '/relax_pmr',
    ),
    _Feature(
      title: 'Grounding (5-4-3-2-1)',
      subtitle: 'Ground yourself in the present moment instantly',
      icon: Icons.spa_rounded,
      color: groundGreen,
      route: '/grounding',
    ),
  ];

  @override
  void initState() {
    super.initState();

    final int items = _features.length + 1;
    final double totalSeconds =
        singleDuration.inMilliseconds / 1000 + (items * staggerDelay);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (totalSeconds * 1000).round()),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _buildInterval(int index) {
    final int items = _features.length + 1;
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

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 24),

              // Feature cards with staggered animation
              ...List.generate(_features.length, (i) {
                final feature = _features[i];
                final animation = _buildInterval(i);
                final slideTween = Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slideTween.animate(animation),
                      child: _EnhancedFeatureCard(
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

              // Tips card
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
                child: _TipsCard(),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF020617), // deep black
            teal6.withOpacity(0.55),
            teal4.withOpacity(0.35),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 🧑‍⚕️ Doctor image with cinematic fade
          _buildDoctorImage(),

          // 🌑 Dark overlay for text readability
          _buildOverlay(),

          // 🎬 Text content
          _buildTextContent(),
          // ⬅️ Floating Back Button (AppBar-like)
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorImage() {
    return Positioned(
      left: -10,
      bottom: 0,
      top: 0,
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.6, 1.0], // Added stops for better control
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          'images/drkanhaiya.png',
          fit: BoxFit.cover,
          width: 160,
          filterQuality: FilterQuality.medium, // Performance optimization
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.55), Colors.transparent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 0.7], // More control over gradient
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Positioned(
      left: 180,
      right: 20,
      top: 28,
      bottom: 28, // Increased from 26 to fix overflow
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Tag badge
          _buildTagBadge(),

          const SizedBox(height: 8), // Reduced from 14
          // Title
          const Text(
            'Relax',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.4,
              height: 1.1,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black26,
                ),
              ],
            ),
          ),

          const SizedBox(height: 6), // Reduced from 8
          // Description
          Flexible(
            // Added Flexible to prevent overflow
            child: Text(
              'Guided audios and calming tools by Dr. Kanhaiya for anxiety, OCD and stress',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: mutedText.withOpacity(0.95),
                shadows: const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black38,
                  ),
                ],
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: const Text(
        'DOCTOR GUIDED',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// Enhanced feature card with press animation
class _EnhancedFeatureCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _EnhancedFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });

  @override
  State<_EnhancedFeatureCard> createState() => _EnhancedFeatureCardState();
}

class _EnhancedFeatureCardState extends State<_EnhancedFeatureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _pressController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _pressController.reverse();

        Future.delayed(const Duration(milliseconds: 120), () {
          Navigator.pushNamed(context, widget.route);
        });
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _pressController.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cardDark, cardDark.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isPressed
                  ? widget.color.withOpacity(0.5)
                  : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? widget.color.withOpacity(0.2)
                    : Colors.black.withOpacity(0.3),
                blurRadius: _isPressed ? 16 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Glowing icon container
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withOpacity(0.35),
                      widget.color.withOpacity(0.15),
                      Colors.transparent,
                    ],
                    center: const Alignment(-0.3, -0.3),
                    radius: 1.0,
                  ),
                  boxShadow: [
                    // Primary colored glow
                    BoxShadow(
                      color: widget.color.withOpacity(0.45),
                      blurRadius: 32,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                    // Secondary glow layer
                    BoxShadow(
                      color: widget.color.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                    // Inner highlight
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: const Offset(0, -2),
                    ),
                  ],
                  border: Border.all(
                    color: widget.color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withOpacity(0.2),
                        widget.color.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 32,
                    shadows: [
                      Shadow(
                        color: widget.color,
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                      Shadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: mutedText.withOpacity(0.9),
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Chevron with subtle glow
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: widget.color.withOpacity(0.8),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced tips card
class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [teal6.withOpacity(0.4), teal5.withOpacity(0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: teal4.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: teal3.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: teal3.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: teal2,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Tips',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TipItem(
            text: 'Use breathing exercises for 1–5 minutes when anxious',
            icon: Icons.circle,
          ),
          _TipItem(
            text: 'Progressive muscle relaxation works well before sleep',
            icon: Icons.circle,
          ),
          _TipItem(
            text: 'Grounding helps during panic or high anxiety',
            icon: Icons.circle,
          ),
          _TipItem(
            text: 'Try meditation daily — consistency builds calm',
            icon: Icons.circle,
          ),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;
  final IconData icon;

  const _TipItem({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(icon, size: 6, color: teal2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: mutedText.withOpacity(0.95),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
