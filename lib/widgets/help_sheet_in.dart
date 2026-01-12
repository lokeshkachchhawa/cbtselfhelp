// lib/widgets/help_sheet.dart
import 'package:cbt_drktv/widgets/tutorial_video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 📞 Support Contact
const _supportPhone = '+917976171908';
const _supportPhonePlain = '917976171908'; // used for wa.me links
const _supportEmail = 'drktvtech@gmail.com';

/// 💬 Pre-filled WhatsApp message
const _preMsg = 'Hello, I need help with my active CBT subscription.';

/// ✅ Open WhatsApp
Future<void> _openWhatsApp(BuildContext ctx) async {
  final url =
      "https://wa.me/$_supportPhonePlain?text=${Uri.encodeComponent(_preMsg)}";
  final uri = Uri.parse(url);

  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    _toast(ctx, "Could not open WhatsApp");
  }
}

/// ✅ Make phone call
Future<void> _callSupport(BuildContext ctx) async {
  final uri = Uri.parse("tel:$_supportPhone");
  if (!await launchUrl(uri)) {
    _toast(ctx, "No phone app installed");
  }
}

/// ✅ Send email
Future<void> _emailSupport(BuildContext ctx) async {
  final uri = Uri(
    scheme: 'mailto',
    path: _supportEmail,
    queryParameters: {
      'subject': 'CBT Self-Guided • Support Request',
      'body': 'Hi Team,\n\n$_preMsg\n\nThanks.',
    },
  );

  if (!await launchUrl(uri)) {
    _toast(ctx, "No email app installed");
  }
}

Future<Map<String, String>?> _loadTutorialConfig() async {
  try {
    final snap = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('help')
        .get();

    if (!snap.exists) return null;

    final data = snap.data()!;
    final url = data['tutorialVideoUrl'] as String?;
    final title = data['tutorialTitle'] as String? ?? 'App Tutorial';

    if (url == null || url.isEmpty) return null;

    return {'url': url, 'title': title};
  } catch (e) {
    debugPrint('Tutorial config load failed: $e');
    return null;
  }
}

/// ✅ Show support sheet
void showHelpSheetIn(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return FutureBuilder<Map<String, String>?>(
        future: _loadTutorialConfig(),
        builder: (ctx, snap) {
          final tutorial = snap.data;

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ---------- VIDEO SECTION ----------
                    if (tutorial != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          tutorial['title']!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      TutorialYoutubePlayer(
                        videoUrl: tutorial['url']!,
                        height: 210,
                        autoPlay: false,
                        startMuted: false,
                        showControls: true,
                        onFullScreenToggle: (_) {},
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                    ],

                    // ---------- HEADER ----------
                    Row(
                      children: [
                        Icon(Icons.support_agent, color: Colors.teal.shade700),
                        const SizedBox(width: 8),
                        Text(
                          "Need help?",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: const Text(
                            "9 AM – 8 PM",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // WhatsApp
                    _SupportTile(
                      customIcon: Image.asset(
                        "images/whatsapp.png",
                        width: 24,
                        height: 24,
                      ),
                      title: "WhatsApp",
                      subtitle: "Chat with us",
                      onTap: () => _openWhatsApp(ctx),
                    ),

                    _SupportTile(
                      icon: Icons.call_rounded,
                      iconColor: Colors.teal,
                      title: "Call Support",
                      subtitle: _supportPhone,
                      onTap: () => _callSupport(ctx),
                    ),

                    _SupportTile(
                      icon: Icons.email_rounded,
                      iconColor: Colors.orange,
                      title: "Email",
                      subtitle: _supportEmail,
                      onTap: () => _emailSupport(ctx),
                    ),

                    const SizedBox(height: 8),
                    Opacity(
                      opacity: 0.75,
                      child: Text(
                        "We usually reply within a few minutes.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// ✅ List tile template
class _SupportTile extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportTile({
    this.icon,
    this.customIcon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : assert(
         icon != null || customIcon != null,
         "Either icon or customIcon must be supplied",
       );

  @override
  Widget build(BuildContext context) {
    final Color color = iconColor ?? Colors.teal;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Center(
            child: customIcon ?? Icon(icon, color: color, size: 22),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.teal.shade800,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.teal.shade400,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// ✅ Snack
void _toast(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
  );
}
