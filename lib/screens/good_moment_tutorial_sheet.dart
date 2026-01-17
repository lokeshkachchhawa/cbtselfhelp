import 'package:flutter/material.dart';
import 'good_moments_diary.dart'; // for AppTheme

class GoodMomentTutorialSheet extends StatelessWidget {
  const GoodMomentTutorialSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.teal3.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.teal1,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'How Good Moments Works',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Scrollable tutorial steps
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: const [
                    _TutorialStep(
                      icon: Icons.add_circle_outline,
                      title: 'Capture a Moment',
                      description:
                          'Whenever something small or meaningful makes you feel calm, happy, or grateful, tap "Add Moment" and write it down.',
                    ),
                    _TutorialStep(
                      icon: Icons.image_outlined,
                      title: 'Add Photos (Optional)',
                      description:
                          'You can attach one or more photos from your gallery or camera to make the memory stronger.',
                    ),
                    _TutorialStep(
                      icon: Icons.favorite_outline,
                      title: 'Choose Your Feeling',
                      description:
                          'Select the feeling that best matches the moment, like Calm, Happy, Loved, or Peaceful.',
                    ),
                    _TutorialStep(
                      icon: Icons.view_carousel_outlined,
                      title: 'View & Scroll Memories',
                      description:
                          'Your saved moments appear as cards. Scroll through images, read text previews, and open them anytime.',
                    ),
                    _TutorialStep(
                      icon: Icons.psychology_outlined,
                      title: 'Use During Difficult Times',
                      description:
                          'When anxiety or negative thoughts appear, open Good Moments and read these memories to ground yourself.',
                    ),
                    _TutorialStep(
                      icon: Icons.lock_outline,
                      title: 'Private & Safe',
                      description:
                          'All your moments are saved locally on your device. Nothing is shared or uploaded.',
                    ),
                  ],
                ),
              ),
            ),

            // Footer button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teal4,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------- STEP WIDGET --------------------

class _TutorialStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(icon, color: AppTheme.teal2, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.dimText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
