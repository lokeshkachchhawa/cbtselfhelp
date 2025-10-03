// lib/screens/safety_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

/// Improved Safety / Crisis screen — theme-consistent & accessible.
/// Requires url_launcher in pubspec.yaml.

const Color teal1 = Color(0xFFC6EDED);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

class SafetyPage extends StatelessWidget {
  const SafetyPage({super.key});

  static const Map<String, Map<String, String>> _countryNumbers = {
    'US': {
      'emergency': '911',
      'hotline': '988',
      'chat': 'https://988lifeline.org/',
    },
    'CA': {
      'emergency': '911',
      'hotline': '1-833-456-4566',
      'chat': 'https://suicideprevention.ca/get-help-now/',
    },
    'GB': {
      'emergency': '999',
      'hotline': '116123',
      'chat': 'https://www.samaritans.org/how-we-can-help/contact-samaritan/',
    },
    'AU': {
      'emergency': '000',
      'hotline': '13 11 14',
      'chat':
          'https://www.lifeline.org.au/get-help/online-services/crisis-chat/',
    },
    'IN': {
      'emergency': '112',
      'hotline': '9152987821',
      'chat': 'https://www.aitracker.org',
    },
  };

  String _formatNumber(String n) => n.replaceAll(' ', '');

  Future<void> _confirmAndDial(
    BuildContext context,
    String number, {
    String? label,
  }) async {
    final display = label ?? number;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Call $display?'),
        content: Text(
          'This will open your phone dialer to call $display. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Call'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dial(number, context);
      _trackEvent('safety_call', {'number': number});
    }
  }

  Future<void> _dial(String number, BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: _formatNumber(number));
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showCantOpen(context, 'phone dialer');
      }
    } catch (_) {
      _showCantOpen(context, 'phone dialer');
    }
  }

  Future<void> _openChat(String url, BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _trackEvent('safety_open_chat', {'url': url});
      } else {
        _showCantOpen(context, 'browser');
      }
    } catch (_) {
      _showCantOpen(context, 'browser');
    }
  }

  Future<void> _sendSms(
    String number,
    String body,
    BuildContext context,
  ) async {
    final uri = Uri(
      scheme: 'sms',
      path: _formatNumber(number),
      queryParameters: {'body': body},
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _trackEvent('safety_sms', {'number': number});
      } else {
        _showCantOpen(context, 'SMS app');
      }
    } catch (_) {
      _showCantOpen(context, 'SMS app');
    }
  }

  Future<void> _sendEmail(
    String to,
    String subject,
    String body,
    BuildContext context,
  ) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: {'subject': subject, 'body': body},
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _trackEvent('safety_email', {'to': to});
      } else {
        _showCantOpen(context, 'email client');
      }
    } catch (_) {
      _showCantOpen(context, 'email client');
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    _trackEvent('safety_copy', {'text': text});
  }

  void _share(BuildContext context, String text) {
    // Simple fallback: copy to clipboard. Replace with share_plus for real share sheet.
    _copyToClipboard(context, text);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ready to share (copied)')));
    _trackEvent('safety_share', {'text': text});
  }

  void _showCantOpen(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to open $what on this device.')),
    );
  }

  Map<String, String> _numbersForLocale(BuildContext context) {
    final locale = ui.PlatformDispatcher.instance.locale;
    final country = (locale.countryCode ?? '').toUpperCase();
    if (country.isEmpty) return {};
    return _countryNumbers[country] ?? {};
  }

  void _trackEvent(String name, Map<String, dynamic> props) {
    // Replace with analytics (GA4/Amplitude/etc.). For now: debug print.
    // ignore: avoid_print
    print('TRACK: $name -> $props');
  }

  @override
  Widget build(BuildContext context) {
    final numbers = _numbersForLocale(context);
    final emergency = numbers['emergency'];
    final hotline = numbers['hotline'];
    final chat = numbers['chat'];
    final reasonArg =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // HERO HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [teal3, teal4],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volunteer_activism,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You are not alone',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'If you are in immediate danger, call emergency services now.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        if (reasonArg != null &&
                            reasonArg['reason'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Reason: ${reasonArg['reason']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // quick share of safety info
                      final text =
                          'If you are in danger call ${emergency ?? 'your local emergency number'}';
                      _share(context, text);
                    },
                    icon: const Icon(Icons.share, color: Colors.white),
                    tooltip: 'Share safety info',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // EMERGENCY CARD (prominent)
                      _bigActionCard(
                        context,
                        title: 'Emergency Services',
                        subtitle: emergency != null
                            ? 'Dial $emergency immediately'
                            : 'Emergency number not detected',
                        accent: Colors.redAccent,
                        icon: Icons.call,
                        primaryLabel: emergency != null
                            ? 'Call $emergency'
                            : 'No number',
                        primaryEnabled: emergency != null,
                        onPrimary: emergency != null
                            ? () => _confirmAndDial(
                                context,
                                emergency,
                                label: emergency,
                              )
                            : null,
                        secondaryIcon: Icons.copy,
                        onSecondary: emergency != null
                            ? () => _copyToClipboard(context, emergency)
                            : null,
                        tertiaryIcon: Icons.person,
                        onTertiary: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Contact a trusted person'),
                              ),
                            ),
                      ),

                      const SizedBox(height: 12),

                      // HOTLINE / CHAT CARD
                      _bigActionCard(
                        context,
                        title: 'Crisis & Hotline',
                        subtitle: hotline != null
                            ? 'Free, confidential support'
                            : 'Hotline not found for your region',
                        accent: Colors.deepOrange,
                        icon: Icons.support_agent,
                        primaryLabel: hotline != null
                            ? 'Call $hotline'
                            : 'Unavailable',
                        primaryEnabled: hotline != null,
                        onPrimary: hotline != null
                            ? () => _confirmAndDial(
                                context,
                                hotline,
                                label: hotline,
                              )
                            : null,
                        secondaryLabel: 'Open chat',
                        secondaryEnabled: chat != null,
                        onSecondary: chat != null
                            ? () => _openChat(chat, context)
                            : null,
                        tertiaryIcon: Icons.copy,
                        onTertiary: hotline != null
                            ? () => _copyToClipboard(context, hotline)
                            : null,
                      ),

                      const SizedBox(height: 12),

                      // OTHER SUPPORTS
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: teal4,
                                  child: const Icon(
                                    Icons.message,
                                    color: Colors.white,
                                  ),
                                ),
                                title: const Text(
                                  'Other ways to get support',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: const Text(
                                  'Send a message, email, or contact someone you trust.',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: (hotline ?? emergency) != null
                                        ? () => _sendSms(
                                            (hotline ?? emergency)!,
                                            'I need support. Please contact me.',
                                            context,
                                          )
                                        : null,
                                    icon: const Icon(Icons.message),
                                    label: const Text('Send SMS to hotline'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: teal3,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _sendEmail(
                                      'support@example.com',
                                      'I need support',
                                      'I would like to speak with someone.',
                                      context,
                                    ),
                                    icon: const Icon(Icons.email),
                                    label: const Text('Email support'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      final text =
                                          'If you are in danger call ${emergency ?? 'your local emergency number'}';
                                      _share(context, text);
                                    },
                                    icon: const Icon(Icons.share),
                                    label: const Text('Share'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // GROUNDED / COPING (collapsible)
                      _GroundingCard(),

                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color accent,
    required IconData icon,
    String? primaryLabel,
    bool primaryEnabled = true,
    VoidCallback? onPrimary,
    String? secondaryLabel,
    bool secondaryEnabled = true,
    VoidCallback? onSecondary,
    IconData? secondaryIcon,
    IconData? tertiaryIcon,
    VoidCallback? onTertiary,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent,
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                if (tertiaryIcon != null)
                  IconButton(
                    onPressed: onTertiary,
                    icon: Icon(tertiaryIcon),
                    tooltip: 'More',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: primaryEnabled ? onPrimary : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryEnabled
                          ? accent
                          : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      primaryLabel ?? 'Action',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (secondaryLabel != null || secondaryIcon != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: secondaryEnabled ? onSecondary : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (secondaryIcon != null) ...[
                            Icon(secondaryIcon),
                            const SizedBox(width: 8),
                          ],
                          Text(secondaryLabel ?? 'Open'),
                        ],
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
}

class _GroundingCard extends StatefulWidget {
  @override
  State<_GroundingCard> createState() => _GroundingCardState();
}

class _GroundingCardState extends State<_GroundingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Immediate coping steps',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              _bulleted(
                '5-4-3-2-1 grounding: name 5 things you see, 4 you can touch, 3 you hear, 2 you smell, 1 you taste.',
              ),
              const SizedBox(height: 8),
              _bulleted(
                'Slow breathing: inhale 4s, hold 4s, exhale 6s — repeat several times.',
              ),
              const SizedBox(height: 8),
              _bulleted(
                'Use a cool cloth, move to a safe place, and tell someone nearby.',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Grounding exercise started')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal4,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Start guided grounding'),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Expand for simple grounding steps and a quick guided exercise.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bulleted(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(fontSize: 18)),
        Expanded(child: Text(text)),
      ],
    );
  }
}
