// lib/screens/safety_page.dart
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Safety / Crisis (India-first) — dark teal theme, bilingual (EN/हिं),
/// multiple helplines & actions (Call/Chat/Copy/SMS).
/// Requires: url_launcher in pubspec.yaml.

const Color teal1 = Color(0xFFC6EDED);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key});
  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  /// Basic i18n (English / Hindi).
  String _lang = 'en'; // 'en' | 'hi'
  bool get isHi => _lang == 'hi';

  /// Region resources — India-first.
  /// You can add more countries below if you want to expand later.
  static const _regional = <String, List<_Resource>>{
    'IN': [
      _Resource(
        titleEn: 'Emergency Services',
        titleHi: 'आपातकालीन सेवाएँ',
        subtitleEn: 'Dial 112 (all emergencies in India)',
        subtitleHi: '112 डायल करें (भारत में सभी आपात स्थितियाँ)',
        color: Colors.redAccent,
        icon: Icons.sos_rounded,
        phone: '112',
      ),
      _Resource(
        titleEn: 'Tele-MANAS (24x7)',
        titleHi: 'टेली-मैनस (24x7)',
        subtitleEn: 'Mental health support (toll-free)',
        subtitleHi: 'मानसिक स्वास्थ्य सहायता (टोल-फ्री)',
        color: Colors.deepOrange,
        icon: Icons.support_agent,
        phone: '14416',
        // Govt info site changes — keep URL configurable:
        chatUrl: 'https://www.mohfw.gov.in', // update if you have a better link
      ),
      _Resource(
        titleEn: 'KIRAN Helpline (MoSJE)',
        titleHi: 'किरण हेल्पलाइन (MoSJE)',
        subtitleEn: 'National mental health helpline (toll-free)',
        subtitleHi: 'राष्ट्रीय मानसिक स्वास्थ्य हेल्पलाइन (टोल-फ्री)',
        color: Colors.orange,
        icon: Icons.health_and_safety,
        phone: '18005990019', // optional; keep if you use it
      ),
    ],
  };

  /// Fallback if device locale doesn’t map.
  String _inferCountryCode() {
    final cc = (ui.PlatformDispatcher.instance.locale.countryCode ?? '')
        .toUpperCase();
    if (cc.isEmpty) return 'IN';
    return _regional.containsKey(cc) ? cc : 'IN';
  }

  @override
  void initState() {
    super.initState();
    // Guess language from device
    final code = ui.PlatformDispatcher.instance.locale.languageCode
        .toLowerCase();
    _lang = code.startsWith('hi') ? 'hi' : 'en';
  }

  @override
  Widget build(BuildContext context) {
    final reasonArg =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final country = _inferCountryCode();
    final items = _regional[country] ?? const <_Resource>[];

    return Scaffold(
      backgroundColor: const Color(0xFF021515),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(reasonArg),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                children: [
                  for (final r in items) _ResourceCard(r, isHi: isHi),
                  const SizedBox(height: 12),
                  _TrustedContactCard(isHi: isHi),
                  const SizedBox(height: 12),
                  _GroundingCard(isHi: isHi),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic>? reasonArg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [teal6, teal4, teal3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  isHi ? 'आप अकेले नहीं हैं' : 'You are not alone',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isHi
                      ? 'यदि तत्काल खतरा है, अभी आपातकालीन सेवाओं पर कॉल करें।'
                      : 'If you are in immediate danger, call emergency services now.',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (reasonArg != null && reasonArg['reason'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    (isHi ? 'कारण: ' : 'Reason: ') + '${reasonArg['reason']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          // Language toggle
          Container(
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _langChip(
                  'EN',
                  active: !isHi,
                  onTap: () => setState(() => _lang = 'en'),
                ),
                _langChip(
                  'हि',
                  active: isHi,
                  onTap: () => setState(() => _lang = 'hi'),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isHi ? 'जानकारी साझा करें' : 'Share safety info',
            onPressed: () {
              final text = isHi
                  ? 'यदि आप खतरे में हैं, 112 पर कॉल करें।'
                  : 'If you are in danger, call 112.';
              _share(context, text);
            },
            icon: const Icon(Icons.share, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _langChip(
    String label, {
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? teal3 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // --- helpers (share/copy/dial/open) ---

  void _share(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isHi ? 'क्लिपबोर्ड पर कॉपी किया गया' : 'Copied to clipboard',
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard(this.r, {required this.isHi});

  final _Resource r;
  final bool isHi;

  String _formatNumber(String n) => n.replaceAll(' ', '');

  Future<void> _dial(BuildContext ctx, String number) async {
    final uri = Uri(scheme: 'tel', path: _formatNumber(number));
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _toast(
          ctx,
          isHi ? 'इस डिवाइस पर कॉल नहीं कर सकते' : 'Cannot open phone dialer',
        );
      }
    } catch (_) {
      _toast(
        ctx,
        isHi ? 'इस डिवाइस पर कॉल नहीं कर सकते' : 'Cannot open phone dialer',
      );
    }
  }

  Future<void> _openChat(BuildContext ctx, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _toast(ctx, isHi ? 'ब्राउज़र नहीं खुल सका' : 'Cannot open browser');
      }
    } catch (_) {
      _toast(ctx, isHi ? 'ब्राउज़र नहीं खुल सका' : 'Cannot open browser');
    }
  }

  Future<void> _sms(BuildContext ctx, String number, String body) async {
    final uri = Uri(
      scheme: 'sms',
      path: _formatNumber(number),
      queryParameters: {'body': body},
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _toast(ctx, isHi ? 'SMS ऐप नहीं खुल सका' : 'Cannot open SMS app');
      }
    } catch (_) {
      _toast(ctx, isHi ? 'SMS ऐप नहीं खुल सका' : 'Cannot open SMS app');
    }
  }

  void _copy(BuildContext ctx, String text) {
    Clipboard.setData(ClipboardData(text: text));
    _toast(ctx, isHi ? 'नंबर कॉपी किया गया' : 'Number copied');
  }

  static void _toast(BuildContext ctx, String m) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final hasCall = (r.phone ?? '').isNotEmpty;
    final hasChat = (r.chatUrl ?? '').isNotEmpty;

    final smsText = isHi
        ? 'मुझे सहायता चाहिए। कृपया संपर्क करें।'
        : 'I need support. Please contact me.';

    return Card(
      color: const Color(0xFF011F1F),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: r.color,
                  child: Icon(r.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHi ? r.titleHi : r.titleEn,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isHi ? r.subtitleHi : r.subtitleEn,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (hasCall)
                  IconButton(
                    tooltip: isHi ? 'कॉपी' : 'Copy',
                    onPressed: () => _copy(context, r.phone!),
                    icon: const Icon(Icons.copy, color: Colors.white70),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasCall ? () => _dial(context, r.phone!) : null,
                    icon: const Icon(Icons.call),
                    label: Text(
                      hasCall
                          ? (isHi ? 'कॉल करें ' : 'Call ') + (r.phone ?? '')
                          : (isHi ? 'उपलब्ध नहीं' : 'Unavailable'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasCall ? r.color : Colors.white12,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasChat
                        ? () => _openChat(context, r.chatUrl!)
                        : null,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(isHi ? 'चैट/वेब' : 'Chat/Web'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white24,
                      side: BorderSide(color: Colors.white.withOpacity(0.18)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (hasCall)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sms(context, r.phone!, smsText),
                      icon: const Icon(Icons.sms_outlined),
                      label: Text(isHi ? 'SMS भेजें' : 'Send SMS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _copy(context, r.phone!),
                      icon: const Icon(
                        Icons.content_copy,
                        color: Colors.white54,
                      ),
                      label: Text(
                        isHi ? 'नंबर कॉपी' : 'Copy number',
                        style: const TextStyle(color: Colors.white70),
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

class _TrustedContactCard extends StatefulWidget {
  const _TrustedContactCard({required this.isHi});
  final bool isHi;

  @override
  State<_TrustedContactCard> createState() => _TrustedContactCardState();
}

class _TrustedContactCardState extends State<_TrustedContactCard> {
  static const _storeKey = 'trusted_contacts_v1';
  final _maxContacts = 3;
  List<_TC> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---- storage ----
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storeKey) ?? [];
    setState(() => _contacts = raw.map((s) => _TC.fromJson(s)).toList());
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storeKey,
      _contacts.map((c) => c.toJson()).toList(),
    );
  }

  // Put this inside your State class (e.g., _TrustedContactCardState)
  Widget _chip(String label, {required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF033333),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      onPressed: onTap,
    );
  }

  InputBorder _border({bool active = false}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(
      color: active ? teal2 : Colors.white24,
      width: active ? 1.3 : 1.0,
    ),
  );

  InputDecoration _dec({
    required String label,
    String? hint,
    IconData? icon,
    String? error,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF033333), // <<< DARK INPUT BG
      prefixIcon: icon != null ? Icon(icon, color: Colors.white54) : null,
      suffixIcon: suffix,
      enabledBorder: _border(),
      focusedBorder: _border(active: true),
    );
  }

  // ---- add / edit / delete ----
  Future<void> _addOrEdit({_TC? existing, int? index}) async {
    final isHi = widget.isHi;
    final name = TextEditingController(text: existing?.name ?? '');
    final code = TextEditingController(
      text: existing?.code ?? '+91',
    ); // India default
    final phone = TextEditingController(text: existing?.phone ?? '');

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        const isDarkBg = Color(0xFF021515);

        String? errName, errPhone;

        return StatefulBuilder(
          builder: (ctx, setState) {
            String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

            String? validate() {
              errName = (name.text.trim().isEmpty)
                  ? (isHi ? 'कृपया नाम लिखें' : 'Please enter a name')
                  : null;

              final phoneDigits = digitsOnly(phone.text);
              errPhone = phoneDigits.length < 7
                  ? (isHi
                        ? 'मान्य फ़ोन नंबर लिखें'
                        : 'Enter a valid phone number')
                  : null;

              setState(() {}); // update errors
              return (errName == null && errPhone == null) ? null : 'x';
            }

            void save() {
              if (validate() == null) {
                Navigator.pop(ctx, true);
              }
            }

            return AlertDialog(
              backgroundColor: isDarkBg,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              titlePadding: const EdgeInsets.fromLTRB(18, 16, 12, 0),
              contentPadding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),

              title: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: teal4,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isHi ? 'विश्वसनीय संपर्क' : 'Trusted contact',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isHi ? 'बंद करें' : 'Close',
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // NAME
                    TextField(
                      controller: name,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec(
                        label: isHi ? 'नाम' : 'Name',
                        icon: Icons.badge,
                        error: errName,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // CODE + PHONE
                    Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: TextField(
                            controller: code,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+\-]'),
                              ),
                            ],
                            style: const TextStyle(color: Colors.white),
                            decoration: _dec(
                              label: "Code",
                              hint: "+91",
                              icon: Icons.flag_circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: TextField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => save(),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(15),
                            ],
                            style: const TextStyle(color: Colors.white),
                            decoration: _dec(
                              label: isHi ? 'फोन' : 'Phone',
                              hint: isHi
                                  ? 'उदा: 9876543210'
                                  : 'e.g. 9876543210',
                              icon: Icons.phone_iphone,
                              error: errPhone,
                              suffix: IconButton(
                                tooltip: isHi ? 'पेस्ट' : 'Paste',
                                icon: const Icon(
                                  Icons.content_paste,
                                  color: Colors.white54,
                                ),
                                onPressed: () async {
                                  final d = (await Clipboard.getData(
                                    'text/plain',
                                  ))?.text;
                                  if (d != null) {
                                    final m = RegExp(
                                      r'^\s*(\+\d{1,4})?[\s\-]*([\d\s\-]{6,})\s*$',
                                    ).firstMatch(d);

                                    if (m != null) {
                                      if ((m.group(1) ?? '').isNotEmpty) {
                                        code.text = m.group(1)!;
                                      }
                                      phone.text = digitsOnly(m.group(2)!);
                                    } else {
                                      phone.text = digitsOnly(d);
                                    }
                                    setState(() {});
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // QUICK REGION CHIPS
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        children: [
                          _chip("+91", onTap: () => code.text = "+91"),
                          _chip("+1", onTap: () => code.text = "+1"),
                          _chip("+44", onTap: () => code.text = "+44"),
                          _chip("+61", onTap: () => code.text = "+61"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isHi
                                ? 'ध्यान दें: कॉल / SMS / WhatsApp के लिए मान्य नंबर जोड़ें।'
                                : 'Note: Provide a valid number for Call / SMS / WhatsApp.',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(isHi ? 'रद्द' : 'Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teal3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: save,
                  icon: const Icon(Icons.check),
                  label: Text(isHi ? 'सेव' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      final c = _TC(
        name: (name.text.trim().isEmpty
            ? (widget.isHi ? 'संपर्क' : 'Contact')
            : name.text.trim()),
        code: code.text.trim().isEmpty ? '+91' : code.text.trim(),
        phone: phone.text.trim(),
      );
      setState(() {
        if (index != null) {
          _contacts[index] = c;
        } else {
          if (_contacts.length < _maxContacts) _contacts.add(c);
        }
      });
      await _save();
    }
  }

  Future<void> _delete(int i) async {
    final isHi = widget.isHi;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isHi ? 'हटाएँ?' : 'Remove?'),
        content: Text(
          isHi
              ? 'क्या आप इस संपर्क को हटाना चाहते हैं?'
              : 'Remove this trusted contact?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isHi ? 'नहीं' : 'No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHi ? 'हाँ' : 'Yes'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _contacts.removeAt(i));
      await _save();
    }
  }

  // ---- actions ----
  String _msg(_TC c) => widget.isHi
      ? 'हैलो ${c.name}, मुझे तुरंत सहयोग चाहिए। क्या आप बात कर सकते हैं?'
      : 'Hi ${c.name}, I need support right now. Can you talk?';

  Future<void> _call(_TC c) async {
    final uri = Uri(scheme: 'tel', path: c.e164);
    await _launch(uri);
  }

  Future<void> _sms(_TC c) async {
    final uri = Uri(
      scheme: 'sms',
      path: c.e164,
      queryParameters: {'body': _msg(c)},
    );
    await _launch(uri);
  }

  Future<void> _wa(_TC c) async {
    final phoneIntl = c.e164.replaceAll(RegExp(r'[^\d+]'), '');
    final text = Uri.encodeComponent(_msg(c));
    final native = Uri.parse('whatsapp://send?phone=$phoneIntl&text=$text');
    final web = Uri.parse('https://wa.me/$phoneIntl?text=$text');
    if (await canLaunchUrl(native)) {
      await launchUrl(native, mode: LaunchMode.externalApplication);
    } else {
      await _launch(web);
    }
  }

  Future<void> _copy(_TC c) async {
    await Clipboard.setData(ClipboardData(text: '${c.name} • ${c.pretty}'));
    _toast(widget.isHi ? 'कॉपी किया गया' : 'Copied');
  }

  Future<void> _launch(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _toast(widget.isHi ? 'ऐप नहीं खुला' : 'Could not open app');
      }
    } catch (_) {
      _toast(widget.isHi ? 'त्रुटि: ऐप नहीं खुला' : 'Error: app did not open');
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Widget _roundAction({
    required Widget icon,
    required String tooltip,
    required VoidCallback onTap,
    Color bg = Colors.white12,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white12),
          ),
          alignment: Alignment.center,
          child: icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHi = widget.isHi;

    return Card(
      color: const Color(0xFF011F1F),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Header: icon + title + add ----
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [teal6.withOpacity(0.55), teal4.withOpacity(0.55)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: teal4,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHi ? 'विश्वसनीय संपर्क' : 'Trusted contacts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isHi
                              ? '1–3 लोग जिन्हें आप तुरंत कॉल/मैसेज कर सकें'
                              : '1–3 people you can contact quickly',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: isHi ? 'नया जोड़ें' : 'Add',
                    child: ElevatedButton.icon(
                      onPressed: _contacts.length >= _maxContacts
                          ? null
                          : () => _addOrEdit(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal3,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: Text(isHi ? 'जोड़ें' : 'Add'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ---- Empty state ----
            if (_contacts.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.035),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white70),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isHi
                            ? 'यहाँ अपने 1–3 विश्वसनीय लोगों को जोड़ें — कॉल/SMS/WhatsApp एक टैप में।'
                            : 'Add 1–3 trusted people — one-tap Call/SMS/WhatsApp.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _addOrEdit(),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(isHi ? 'जोड़ें' : 'Add'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              // ---- Contacts list ----
              Column(
                children: List.generate(_contacts.length, (i) {
                  final c = _contacts[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF021A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ---------------- ROW 1 (Avatar + Name) ----------------
                          Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: teal3,
                                    child: Text(
                                      c.initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Color(0xFF021515),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ---------------- ROW 2 (Contact number) ----------------
                          const SizedBox(height: 10),
                          Text(
                            c.pretty,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 18,
                            ),
                          ),

                          // ---------------- ROW 3 (Actions) ----------------
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _roundAction(
                                tooltip: isHi ? 'कॉल' : 'Call',
                                bg: Colors.white12,
                                icon: const Icon(
                                  Icons.call,
                                  color: Colors.white,
                                ),
                                onTap: () => _call(c),
                              ),
                              const SizedBox(width: 6),
                              _roundAction(
                                tooltip: 'SMS',
                                bg: Colors.white12,
                                icon: const Icon(
                                  Icons.sms,
                                  color: Colors.white,
                                ),
                                onTap: () => _sms(c),
                              ),
                              const SizedBox(width: 6),
                              _roundAction(
                                tooltip: 'WhatsApp',
                                bg: Colors.white12,
                                icon: Image.asset(
                                  'images/whatsapp.png',
                                  width: 20,
                                  height: 20,
                                ),
                                onTap: () => _wa(c),
                              ),
                              const Spacer(),
                              PopupMenuButton<String>(
                                color: const Color(0xFF021515),
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white70,
                                ),
                                onSelected: (v) {
                                  switch (v) {
                                    case 'copy':
                                      _copy(c);
                                      break;
                                    case 'edit':
                                      _addOrEdit(existing: c, index: i);
                                      break;
                                    case 'del':
                                      _delete(i);
                                      break;
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'copy',
                                    child: Text(
                                      isHi ? 'कॉपी' : 'Copy',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(
                                      isHi ? 'संपादित' : 'Edit',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'del',
                                    child: Text(
                                      isHi ? 'हटाएँ' : 'Delete',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),

            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white38, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isHi
                        ? 'टिप: संकट में पहले 112 पर कॉल करें।'
                        : 'Tip: In a crisis, call 112 first.',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
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

// Mini data model
class _TC {
  final String name;
  final String code; // +91
  final String phone; // 9876543210

  _TC({required this.name, required this.code, required this.phone});

  String get e164 => '$code$phone';
  String get pretty => '$code ${_group(phone)}';
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'T';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  static String _group(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    if (d.length == 10)
      return '${d.substring(0, 3)}-${d.substring(3, 6)}-${d.substring(6)}';
    return d;
  }

  String toJson() => jsonEncode({'n': name, 'c': code, 'p': phone});
  factory _TC.fromJson(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return _TC(
      name: (m['n'] ?? 'Contact') as String,
      code: (m['c'] ?? '+91') as String,
      phone: (m['p'] ?? '') as String,
    );
  }
}

class _GroundingCard extends StatefulWidget {
  const _GroundingCard({required this.isHi});
  final bool isHi;
  @override
  State<_GroundingCard> createState() => _GroundingCardState();
}

class _GroundingCardState extends State<_GroundingCard> {
  bool _expanded = false;

  void _go(String route) {
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF011F1F),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isHi
                        ? 'तुरंत कॉपिंग स्टेप्स'
                        : 'Immediate coping steps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                  tooltip: widget.isHi
                      ? (_expanded ? 'छिपाएँ' : 'खोलें')
                      : (_expanded ? 'Collapse' : 'Expand'),
                ),
              ],
            ),

            if (_expanded) ...[
              const SizedBox(height: 8),
              _bullet(
                widget.isHi
                    ? '5-4-3-2-1 ग्राउंडिंग: 5 चीजें देखें, 4 छूएँ, 3 सुनें, 2 सूँघें, 1 स्वाद।'
                    : '5-4-3-2-1 grounding: 5 you see, 4 touch, 3 hear, 2 smell, 1 taste.',
              ),
              const SizedBox(height: 8),
              _bullet(
                widget.isHi
                    ? 'धीमी साँस: 4 सेकंड अंदर, 4 रोके, 6 बाहर।'
                    : 'Slow breathing: inhale 4s, hold 4s, exhale 6s.',
              ),
              const SizedBox(height: 8),
              _bullet(
                widget.isHi
                    ? 'ठंडी पट्टी लगाएँ, सुरक्षित जगह जाएँ, पास के व्यक्ति को बताएं।'
                    : 'Use a cool cloth, move to a safe place, tell someone nearby.',
              ),
              const SizedBox(height: 14),

              // NEW: Relaxation tools (buttons)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _toolBtn(
                    icon: Icons.self_improvement,
                    label: widget.isHi ? 'रिलैक्स हब' : 'Relax Hub',
                    onTap: () => _go('/relax'),
                  ),
                  _toolBtn(
                    icon: Icons.air,
                    label: widget.isHi ? 'श्वास अभ्यास' : 'Breathing',
                    onTap: () => _go('/relax/breath'),
                  ),
                  _toolBtn(
                    icon: Icons.spa_rounded,
                    label: widget.isHi ? 'पीएमआर' : 'PMR',
                    onTap: () => _go('/relax_pmr'),
                  ),
                  _toolBtn(
                    icon: Icons.sensors,
                    label: widget.isHi ? 'ग्राउंडिंग' : 'Grounding',
                    onTap: () => _go('/grounding'),
                  ),
                  _toolBtn(
                    icon: Icons.timer,
                    label: widget.isHi ? 'मिनी मेडिटेशन' : 'Mini Meditation',
                    onTap: () => _go('/minimeditation'),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _go('/relax/breath'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal4,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.isHi
                      ? 'गाइडेड ग्राउंडिंग/सांस शुरू करें'
                      : 'Start guided grounding/breath',
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                widget.isHi
                    ? 'सरल स्टेप्स और त्वरित रिलैक्सेशन टूल्स देखने के लिए विस्तार करें।'
                    : 'Expand to see simple steps and quick relaxation tools.',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width:
          (MediaQuery.of(context).size.width - 14 - 14 - 8) /
          2, // two per row on most phones
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('•  ', style: TextStyle(color: Colors.white70, fontSize: 18)),
      ],
    ).childrenPlus(
      Expanded(
        child: Text(text, style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

// Small extension to add widgets after a Row’s leading
extension _ChildrenPlus on Row {
  Row childrenPlus(Widget w) => Row(children: [...children, w]);
}

class _Resource {
  final String titleEn;
  final String titleHi;
  final String subtitleEn;
  final String subtitleHi;
  final Color color;
  final IconData icon;
  final String? phone;
  final String? chatUrl;

  const _Resource({
    required this.titleEn,
    required this.titleHi,
    required this.subtitleEn,
    required this.subtitleHi,
    required this.color,
    required this.icon,
    this.phone,
    this.chatUrl,
  });
}
