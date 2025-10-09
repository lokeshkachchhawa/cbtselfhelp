// lib/screens/drktv_chat_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';

/// DrKtv Chat Screen — polished UI with wide script support (Noto Sans).
class DrKtvChatScreen extends StatefulWidget {
  const DrKtvChatScreen({super.key});

  @override
  State<DrKtvChatScreen> createState() => _DrktvChatScreenState();
}

class _DrktvChatScreenState extends State<DrKtvChatScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _loading = false; // AI is generating
  bool _consentAccepted = false;
  SharedPreferences? _prefs;
  final _uuid = const Uuid();

  static const _prefsKey = 'drktv_chat_history';
  static const _prefsConsentKey = 'drktv_consent';

  // UI state

  @override
  void initState() {
    super.initState();
    _initPrefsAndHistory();
  }

  Future<void> _initPrefsAndHistory() async {
    _prefs = await SharedPreferences.getInstance();
    final consent = _prefs?.getBool(_prefsConsentKey) ?? false;
    if (consent && mounted) setState(() => _consentAccepted = true);
    await _loadMessagesFromPrefs();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ---------------- Persistence helpers ----------------
  Future<void> _saveMessagesToPrefs() async {
    try {
      final list = _messages.map((m) => m.toMap()).toList();
      final jsonStr = jsonEncode(list);
      await _prefs?.setString(_prefsKey, jsonStr);
    } catch (e) {
      debugPrint('Failed to save chat history: $e');
    }
  }

  Future<void> _loadMessagesFromPrefs() async {
    try {
      final jsonStr = _prefs?.getString(_prefsKey);
      if (jsonStr == null || jsonStr.isEmpty) return;
      final data = jsonDecode(jsonStr) as List<dynamic>;
      _messages.clear();
      for (final item in data) {
        if (item is Map) {
          _messages.add(_ChatMessage.fromMap(Map<String, dynamic>.from(item)));
        }
      }
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 150));
      _scrollToBottom();
    } catch (e) {
      debugPrint('Failed to load saved chat history: $e');
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    Future.microtask(
      () => _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  // --- API key resolution (dart-define first, then dotenv) ---
  Future<String?> _getApiKey() async {
    // 1) compile-time define (recommended)
    const compileTimeApiKey = String.fromEnvironment(
      'OPENAI_API_KEY',
      defaultValue: '',
    );
    if (compileTimeApiKey.isNotEmpty) return compileTimeApiKey;

    // 2) runtime dotenv (if loaded)
    try {
      final dot = dotenv.env['OPENAI_API_KEY'];
      if (dot != null && dot.trim().isNotEmpty) return dot.trim();
    } catch (e) {
      debugPrint('dotenv lookup failed: $e');
    }

    // not found
    return null;
  }

  // --- Build the system instruction (not shown in UI) ---
  String _systemPromptForCBT() {
    return '''
You are Dr. Kanhaiya (DrKtv), an empathetic AI psychiatrist specializing in Cognitive Behavioral Therapy (CBT). 
Respond to patient questions using CBT fundamentals: 
- Identify automatic thoughts and cognitive distortions (e.g., all-or-nothing thinking, catastrophizing).
- Help challenge unhelpful beliefs with evidence-based questioning.
- Suggest behavioral activation, relaxation techniques, or homework like thought records.
- Be supportive, non-judgmental, and culturally sensitive for Indian contexts.
- Always remind that you provide informational support, not diagnosis or treatment—advise seeking professional help for serious issues.
- Keep responses concise (2-4 paragraphs), warm, and actionable.
- Use the same language the user used for their question. If you cannot, ask politely before switching.
''';
  }

  // --- OpenAI call (UTF-8 safe + defensive API key) ---
  Future<String> _queryOpenAI(
    String prompt,
    List<Map<String, String>> history,
  ) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception(
        'OpenAI API key not set. Provide via --dart-define=OPENAI_API_KEY=sk-... or set dotenv in main().',
      );
    }

    final systemInstruction = _systemPromptForCBT();

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemInstruction},
      {
        'role': 'assistant',
        'content':
            'Hello — I am Dr. Kanhaiya (DrKtv). I respond with CBT-based suggestions and practical steps. I do not provide diagnosis. If you are in crisis call local emergency services.',
      },
      ...history,
      {'role': 'user', 'content': prompt},
    ];

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': messages,
      'temperature': 0.2,
      'max_tokens': 800,
    });

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (resp.statusCode >= 400) {
      final safe = utf8.decode(resp.bodyBytes);
      throw Exception('OpenAI error ${resp.statusCode}: $safe');
    }

    // decode bytes as UTF-8 to avoid mojibake for non-ASCII languages
    final utf8Body = utf8.decode(resp.bodyBytes);
    final data = jsonDecode(utf8Body) as Map<String, dynamic>;

    final choice = (data['choices'] as List).first;
    final text = ((choice['message'] ?? {})['content'] ?? '') as String;
    return text.trim();
  }

  // Build history for OpenAI: convert our _messages to [{role:, content:},...]
  List<Map<String, String>> _buildHistoryForOpenAI() {
    final out = <Map<String, String>>[];
    for (final m in _messages) {
      out.add({'role': m.isUser ? 'user' : 'assistant', 'content': m.text});
    }
    return out;
  }

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    if (!_consentAccepted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF021515),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Consent', style: TextStyle(color: Colors.white)),
          content: const Text(
            'By using this AI chat you acknowledge this assistant provides informational CBT-style guidance and is not a substitute for clinical care. If you are in immediate danger, use emergency services or the Get Help button.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008F89),
              ),
              child: const Text('Accept'),
            ),
          ],
        ),
      );

      if (ok != true) return;
      setState(() {
        _consentAccepted = true;
      });
      await _prefs?.setBool(_prefsConsentKey, true);
    }

    // Add user message locally and save
    final userMsg = _ChatMessage.user(text);
    setState(() {
      _messages.add(userMsg);
      _ctrl.clear();
      _loading = true; // show typing indicator & disable send
    });
    await _saveMessagesToPrefs();
    _scrollToBottom();

    try {
      final history = _buildHistoryForOpenAI();
      final reply = await _queryOpenAI(text, history);

      final assistantMsg = _ChatMessage.assistant(reply);
      setState(() {
        _messages.add(assistantMsg);
      });
      await _saveMessagesToPrefs();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Chat send error: $e');
      final errMsg = _ChatMessage.assistant(
        'Sorry — failed to get a reply. (${e})',
      );
      setState(() {
        _messages.add(errMsg);
      });
      await _saveMessagesToPrefs();
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Build a consistent text style using Noto (good Indic coverage)
  TextStyle _textStyle({
    double size = 15,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.notoSans(
      textStyle: TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: weight,
        height: 1.38,
      ),
    ).copyWith(
      fontFamilyFallback: const [
        'Noto Sans Devanagari',
        'Noto Sans',
        'Roboto',
        'sans-serif',
      ],
    );
  }

  // ---------------- UI pieces ----------------
  Widget _buildDisclaimerCard() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Card(
        elevation: 3,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.06),
                const Color(0xFF007A78).withOpacity(0.1),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular icon badge
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF008F89).withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disclaimer',
                      style: _textStyle(
                        size: 14,
                        weight: FontWeight.w600,
                      ).copyWith(color: Colors.tealAccent.shade100),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'DrKtv offers CBT-style mental wellness guidance. '
                      'It is not a substitute for professional or emergency care. '
                      'If you feel unsafe or in crisis, please use the “Get Help” button.',
                      style: _textStyle(
                        size: 13,
                      ).copyWith(color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ),
              ),

              // More button
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF79C2BF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
                onPressed: _showMoreInfo,
                child: Text(
                  'More',
                  style: _textStyle(
                    size: 13,
                    weight: FontWeight.w600,
                  ).copyWith(color: Colors.tealAccent.shade100),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF021515),
        title: Text('About DrKtv', style: _textStyle(weight: FontWeight.w700)),
        content: Text(
          'This AI provides CBT-informed suggestions. It is not a substitute for professional medical, psychiatric or emergency care. If you are at risk, call local emergency services.',
          style: _textStyle(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: _textStyle()),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text('DrKtv is typing...', style: _textStyle(size: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021515),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004E4D),
        elevation: 0,
        titleSpacing: 8,
        title: Row(
          children: [
            // Circular Dr. Kanhaiya photo
            CircleAvatar(
              radius: 18,
              backgroundImage: const AssetImage('images/drkanhaiya.png'),
              backgroundColor:
                  Colors.teal.shade200, // fallback tint if image fails
            ),
            const SizedBox(width: 10),
            // Title text
            Text(
              'Dr. Kanhaiya (AI)',
              style: _textStyle(weight: FontWeight.w700, size: 13),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _confirmClear,
          ),
          IconButton(
            tooltip: 'Save chat (local)',
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            onPressed: () async {
              await _saveMessagesToPrefs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat saved locally')),
              );
            },
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // header with language & speak toggle

            // disclaimer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: _buildDisclaimerCard(),
            ),

            const SizedBox(height: 8),

            // messages
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    return _buildMessageTile(m);
                  },
                ),
              ),
            ),

            // typing
            if (_loading) _buildTypingIndicator(),

            // input bar
            // --- Replace your existing "input bar" SafeArea/Padding/Row block with this ---
            // Input bar (clean, single background; no stray white boxes)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Quick templates / actions
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        tooltip: 'Quick templates',
                        icon: const Icon(
                          Icons.bolt_outlined,
                          color: Colors.white,
                        ),
                        onPressed: _showTemplatesMenu,
                      ),
                    ),

                    // Main input container (single background surface)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            0.03,
                          ), // single subtle background
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          children: [
                            // Text field - transparent, no filled box
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                textInputAction: TextInputAction.send,
                                minLines: 1,
                                maxLines: 6,
                                style: _textStyle(),
                                cursorColor: const Color(0xFF008F89),
                                decoration: InputDecoration(
                                  hintText: 'Ask Dr. Kanhaiya a question...',
                                  hintStyle: _textStyle(
                                    size: 14,
                                  ).copyWith(color: Colors.white54),
                                  border: InputBorder.none,
                                  isDense: true,
                                  // ensure there is no filled box
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                ),
                                onSubmitted: (_) {
                                  if (!_loading) _sendMessage();
                                },
                              ),
                            ),

                            // Send button - circular, no extra white Material surface
                            const SizedBox(width: 8),
                            Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: _loading
                                    ? Colors.grey
                                    : const Color(0xFF008F89),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color:
                                    Colors.transparent, // avoid white material
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: _loading ? null : _sendMessage,
                                  child: Center(
                                    child: _loading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quick templates menu (pre-fill input)
  void _showTemplatesMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF021515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Quick templates',
                  style: _textStyle(weight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.nights_stay),
                  title: Text(
                    'I feel low and can’t sleep',
                    style: _textStyle(),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(
                      () => _ctrl.text =
                          'I feel low and I can’t sleep. What can I try tonight?',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.psychology),
                  title: Text(
                    'I keep worrying about the future',
                    style: _textStyle(),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(
                      () => _ctrl.text =
                          'I keep worrying about the future and it stops me from concentrating. What can I do?',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lightbulb_outline),
                  title: Text(
                    'Help me challenge a thought',
                    style: _textStyle(),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(
                      () => _ctrl.text =
                          'I think "I will fail at everything." Help me challenge this thought.',
                    );
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

  void _openGetHelp() {
    // simple dialog — replace with a route to your safety page if you have one
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF021515),
        title: Text('Get Help', style: _textStyle(weight: FontWeight.w700)),
        content: Text(
          'If you are in immediate danger or experiencing a crisis, please contact local emergency services or your nearest helpline.',
          style: _textStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: _textStyle()),
          ),
        ],
      ),
    );
  }

  void _confirmClear() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF021515),
        title: Text('Clear chat?', style: _textStyle(weight: FontWeight.w700)),
        content: Text(
          'This will remove the conversation from local storage.',
          style: _textStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: _textStyle()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
            child: Text('Clear', style: _textStyle()),
          ),
        ],
      ),
    ).then((val) {
      if (val == true) {
        setState(() {
          _messages.clear();
        });
        _prefs?.remove(_prefsKey);
      }
    });
  }

  // Message bubble builder
  Widget _buildMessageTile(_ChatMessage m) {
    final isUser = m.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isUser
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.04);
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isUser ? 14 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 14),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: alignment,
        child: GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: m.text));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Copied message')));
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(m.text, style: _textStyle()),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatTimestamp(m.timestamp),
                        style: _textStyle(
                          size: 11,
                        ).copyWith(color: Colors.white38),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

// ---------------- Local message model ----------------
class _ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final bool isSystem;
  final int timestamp;

  _ChatMessage._({
    required this.id,
    required this.text,
    this.isUser = false,
    this.isSystem = false,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory _ChatMessage.user(String t) =>
      _ChatMessage._(id: const Uuid().v4(), text: t, isUser: true);

  factory _ChatMessage.assistant(String t) =>
      _ChatMessage._(id: const Uuid().v4(), text: t, isUser: false);

  factory _ChatMessage.system(String t) =>
      _ChatMessage._(id: const Uuid().v4(), text: t, isSystem: true);

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'isSystem': isSystem,
    'timestamp': timestamp,
  };

  factory _ChatMessage.fromMap(Map<String, dynamic> m) => _ChatMessage._(
    id: m['id'] as String? ?? const Uuid().v4(),
    text: m['text'] as String? ?? '',
    isUser: m['isUser'] as bool? ?? false,
    isSystem: m['isSystem'] as bool? ?? false,
    timestamp: m['timestamp'] is int ? m['timestamp'] as int : null,
  );
}
