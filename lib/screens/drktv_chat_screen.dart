// lib/screens/drktv_chat_screen.dart
// Updated DrKtv chat screen with doctor-approval flow backed by Firestore.
// - User sends message -> AI generates reply (written to Firestore as approved:false).
// - Doctor UI (separate) can edit/approve assistant reply -> when approved:true, user sees message.
// - Uses FirebaseAuth.currentUser.uid as chatId and displayName.
// UI kept the same as your original; message threading added.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
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

enum _AiProvider { openai, gemini }

class _DrktvChatScreenState extends State<DrKtvChatScreen>
    with SingleTickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<TapGestureRecognizer> _linkRecognizers = [];
  late final AnimationController _ringController;

  bool _loading = false; // AI is generating
  bool _consentAccepted = false;
  SharedPreferences? _prefs;

  static const _prefsKey = 'drktv_chat_history';
  static const _prefsConsentKey = 'drktv_consent';

  // Provider state (OpenAI by default)
  _AiProvider _provider = _AiProvider.openai;

  // Firestore & Auth
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Chat identifiers
  String? _chatId; // will be currentUser.uid
  String? _userName;

  // Firestore listener subscription
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _initPrefsAndHistory();
    _initChatIdentifiersAndListeners();
  }

  Future<void> _initChatIdentifiersAndListeners() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('DrKtvChat: no signed-in user, chat will be local-only.');
      return;
    }
    _chatId = user.uid;
    _userName = user.displayName ?? (user.email?.split('@').first ?? 'User');

    // Subscribe to all messages for this chat. We'll filter and thread client-side.
    try {
      final ref = _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snap, _) =>
                Map<String, dynamic>.from(snap.data() ?? {}),
            toFirestore: (map, _) => map,
          );

      _messagesSub = ref.snapshots().listen(
        (snap) {
          _processMessagesSnapshot(snap);
        },
        onError: (e) {
          debugPrint('Messages listener error: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to start messages listener: $e');
    }
  }

  Future<void> _processMessagesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    // Build separate lists for user messages and approved assistant messages
    final List<_ChatMessage> userMsgs = [];
    final List<_ChatMessageWithMeta> assistantMsgs = [];

    for (final doc in snap.docs) {
      final data = doc.data();
      final id = doc.id;
      final sender = (data['sender'] ?? '') as String;
      final text = (data['text'] ?? '') as String;
      final ts = data['timestamp'] is int
          ? data['timestamp'] as int
          : (data['timestamp'] is Timestamp
                ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch);

      if (sender == 'user') {
        userMsgs.add(
          _ChatMessage._withId(id, text, isUser: true, timestamp: ts),
        );
      } else if (sender == 'assistant') {
        // Only show assistant messages if approved == true
        final approved = data['approved'] == true;
        final parentId = data['parentId'] as String?;
        final editedByDoctor = data['editedByDoctor'] == true;
        if (approved) {
          assistantMsgs.add(
            _ChatMessageWithMeta(
              id: id,
              text: text,
              timestamp: ts,
              parentId: parentId,
              editedByDoctor: editedByDoctor,
            ),
          );
        }
      } else {
        // ignore other senders
      }
    }

    // Sort both lists (should already be sorted by timestamp but ensure)
    userMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    assistantMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Map parentId -> list of assistant messages
    final Map<String, List<_ChatMessageWithMeta>> assistantByParent = {};
    final List<_ChatMessageWithMeta> orphanAssistant = [];

    for (final a in assistantMsgs) {
      if (a.parentId != null && a.parentId!.isNotEmpty) {
        assistantByParent.putIfAbsent(a.parentId!, () => []).add(a);
      } else {
        orphanAssistant.add(a);
      }
    }

    // Build final threaded list:
    final List<_ChatMessage> finalList = [];

    // Keep track of IDs added to avoid duplicates
    final Set<String> added = {};

    for (final u in userMsgs) {
      if (added.contains(u.id)) continue;
      finalList.add(u);
      added.add(u.id);

      final assistants = assistantByParent[u.id];
      if (assistants != null && assistants.isNotEmpty) {
        assistants.sort((x, y) => x.timestamp.compareTo(y.timestamp));
        for (final a in assistants) {
          if (added.contains(a.id)) continue;
          finalList.add(
            _ChatMessage._withId(
              a.id,
              a.text,
              isUser: false,
              timestamp: a.timestamp,
            ),
          );
          added.add(a.id);
        }
      }
    }

    // Now append orphan assistant messages (those without parent or parent missing)
    for (final a in orphanAssistant) {
      if (added.contains(a.id)) continue;
      finalList.add(
        _ChatMessage._withId(
          a.id,
          a.text,
          isUser: false,
          timestamp: a.timestamp,
        ),
      );
      added.add(a.id);
    }

    // In case there are assistant messages whose parent existed but user list didn't
    // (e.g., if doctor created assistant without parent), ensure no missed messages by also checking
    // any assistant messages that are not yet added (edge-case):
    for (final a in assistantMsgs) {
      if (added.contains(a.id)) continue;
      finalList.add(
        _ChatMessage._withId(
          a.id,
          a.text,
          isUser: false,
          timestamp: a.timestamp,
        ),
      );
      added.add(a.id);
    }

    // Update local messages and persist
    setState(() {
      _messages
        ..clear()
        ..addAll(finalList);
    });
    await _saveMessagesToPrefs();
    _scrollToBottom();
  }

  @override
  void dispose() {
    for (final r in _linkRecognizers) {
      try {
        r.dispose();
      } catch (_) {}
    }
    _ringController.dispose();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _messagesSub?.cancel();
    super.dispose();
  }

  /// Defensive extractor for Gemini generateContent responses.
  String _extractGeminiText(Map<String, dynamic> data) {
    try {
      // 1) candidates -> content -> parts -> text
      if (data.containsKey('candidates')) {
        final candidates = data['candidates'] as List<dynamic>;
        if (candidates.isNotEmpty) {
          final first = candidates.first;
          if (first is Map<String, dynamic>) {
            final content = first['content'];
            if (content is Map<String, dynamic>) {
              final parts = content['parts'];
              if (parts is List && parts.isNotEmpty) {
                final p0 = parts.first;
                if (p0 is Map<String, dynamic> && p0['text'] is String) {
                  return (p0['text'] as String).trim();
                }
              }
              if (content['text'] is String)
                return (content['text'] as String).trim();
              if (content['output'] is String)
                return (content['output'] as String).trim();
            }
          }
          // fallback older shapes
          if (first is Map<String, dynamic>) {
            if (first['output'] is String)
              return (first['output'] as String).trim();
            if (first['content'] is String)
              return (first['content'] as String).trim();
            if (first['text'] is String)
              return (first['text'] as String).trim();
          }
        }
      }

      // 2) top-level 'output' object
      if (data.containsKey('output')) {
        final out = data['output'];
        if (out is Map<String, dynamic>) {
          if (out['text'] is String) return (out['text'] as String).trim();
          if (out['content'] is String)
            return (out['content'] as String).trim();
        }
      }

      // 3) fallback: stringify something useful
      if (data['candidates'] != null) return jsonEncode(data['candidates']);
      return jsonEncode(data);
    } catch (e) {
      return 'Error extracting Gemini text: $e';
    }
  }

  Future<void> _initPrefsAndHistory() async {
    _prefs = await SharedPreferences.getInstance();
    final consent = _prefs?.getBool(_prefsConsentKey) ?? false;
    if (consent && mounted) setState(() => _consentAccepted = true);
    await _loadMessagesFromPrefs();
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

  Future<void> _saveMessagesToPrefs() async {
    try {
      final list = _messages.map((m) => m.toMap()).toList();
      final jsonStr = jsonEncode(list);
      await _prefs?.setString(_prefsKey, jsonStr);
    } catch (e) {
      debugPrint('Failed to save chat history: $e');
    }
  }

  void _setLoading(bool on) {
    if (!mounted) return;
    setState(() => _loading = on);
    if (on) {
      _ringController.repeat();
    } else {
      _ringController.stop();
      _ringController.reset();
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

  TextSpan _parseMarkdownToTextSpan(String text) {
    final lines = text.split('\n');
    final children = <InlineSpan>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();

      if (line.isEmpty) {
        children.add(const TextSpan(text: '\n'));
        continue;
      }

      if (line.startsWith('>')) {
        final content = line.substring(1).trim();
        final span = TextSpan(
          text: '❝ ',
          style: _textStyle(
            weight: FontWeight.w600,
          ).copyWith(color: Colors.tealAccent.shade100),
          children: _parseInline(content),
        );
        children.add(
          TextSpan(
            children: [span],
            style: _textStyle().copyWith(
              fontStyle: FontStyle.italic,
              color: Colors.white70,
            ),
          ),
        );
        children.add(const TextSpan(text: '\n'));
        continue;
      }

      final olMatch = RegExp(r'^\s*(\d+)\.\s+(.*)\$').firstMatch(line);
      if (olMatch != null) {
        final idx = olMatch.group(1)!;
        final content = olMatch.group(2)!;
        children.add(
          TextSpan(
            children: [
              TextSpan(
                text: '$idx. ',
                style: _textStyle(
                  weight: FontWeight.w600,
                ).copyWith(color: Colors.tealAccent.shade100),
              ),
              ..._parseInline(content),
            ],
          ),
        );
        children.add(const TextSpan(text: '\n'));
        continue;
      }

      final bulletMatch = RegExp(r'^\s*[-*]\s+(.*)\$').firstMatch(line);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)!;
        children.add(
          TextSpan(
            children: [
              TextSpan(
                text: '• ',
                style: _textStyle(
                  weight: FontWeight.w600,
                ).copyWith(color: Colors.tealAccent.shade100),
              ),
              ..._parseInline(content),
            ],
          ),
        );
        children.add(const TextSpan(text: '\n'));
        continue;
      }

      children.addAll(_parseInline(line));
      children.add(const TextSpan(text: '\n'));
    }

    if (children.isNotEmpty && children.last is TextSpan) {
      final last = children.removeLast() as TextSpan;
      if (last.text == '\n') {
        // removed trailing single newline
      } else {
        children.add(last);
      }
    }

    return TextSpan(children: children, style: _textStyle());
  }

  List<TextSpan> _parseInline(String input) {
    final spans = <TextSpan>[];
    var s = input;

    final linkReg = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    final boldReg = RegExp(r'\*\*([^*]+)\*\*');
    final italicReg = RegExp(r'_(.+?)_');

    while (s.isNotEmpty) {
      final linkMatch = linkReg.firstMatch(s);
      final boldMatch = boldReg.firstMatch(s);
      final italicMatch = italicReg.firstMatch(s);

      Match? earliest;
      String type = '';
      if (linkMatch != null) {
        earliest = linkMatch;
        type = 'link';
      }
      if (boldMatch != null &&
          (earliest == null || boldMatch.start < earliest.start)) {
        earliest = boldMatch;
        type = 'bold';
      }
      if (italicMatch != null &&
          (earliest == null || italicMatch.start < earliest.start)) {
        earliest = italicMatch;
        type = 'italic';
      }

      if (earliest == null) {
        spans.add(TextSpan(text: s));
        break;
      }

      if (earliest.start > 0) {
        spans.add(TextSpan(text: s.substring(0, earliest.start)));
      }

      if (type == 'link') {
        final label = earliest.group(1)!;
        final url = earliest.group(2)!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            if (url.startsWith('/')) {
              Navigator.pushNamed(context, url);
            } else {
              // non-app links: you may want to launch URL with url_launcher
            }
          };
        _linkRecognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: label,
            style: _textStyle().copyWith(
              color: Colors.tealAccent.shade100,
              decoration: TextDecoration.underline,
            ),
            recognizer: recognizer,
          ),
        );
      } else if (type == 'bold') {
        final inner = earliest.group(1)!;
        spans.add(
          TextSpan(
            text: inner,
            style: _textStyle(
              weight: FontWeight.w700,
            ).copyWith(color: Colors.tealAccent.shade100),
          ),
        );
      } else if (type == 'italic') {
        final inner = earliest.group(1)!;
        spans.add(
          TextSpan(
            text: inner,
            style: _textStyle(
              weight: FontWeight.w500,
            ).copyWith(fontStyle: FontStyle.italic, color: Colors.white70),
          ),
        );
      } else {
        spans.add(TextSpan(text: earliest.group(0)));
      }

      s = s.substring(earliest.end);
    }

    return spans;
  }

  // --- API key resolution (dart-define first, then dotenv) ---
  Future<String?> _getApiKey(_AiProvider forProvider) async {
    if (forProvider == _AiProvider.openai) {
      const compileTimeApiKey = String.fromEnvironment(
        'OPENAI_API_KEY',
        defaultValue: '',
      );
      if (compileTimeApiKey.isNotEmpty) return compileTimeApiKey;

      try {
        final dot = dotenv.env['OPENAI_API_KEY'];
        if (dot != null && dot.trim().isNotEmpty) return dot.trim();
      } catch (e) {
        debugPrint('dotenv lookup failed: $e');
      }
      return null;
    } else {
      // GEMINI
      const compileTimeApiKey = String.fromEnvironment(
        'GEMINI_API_KEY',
        defaultValue: '',
      );
      if (compileTimeApiKey.isNotEmpty) return compileTimeApiKey;

      try {
        final dot = dotenv.env['GEMINI_API_KEY'];
        if (dot != null && dot.trim().isNotEmpty) return dot.trim();
      } catch (e) {
        debugPrint('dotenv lookup failed: $e');
      }
      return null;
    }
  }

  String _systemPromptForCBT() {
    return '''
You are Dr. Kanhaiya (DrKtv) — an empathetic AI psychiatrist who replies in a concise, 
warm, supportive, and practical tone based on CBT principles when helpful.  
If the user writes in Hindi or Hinglish, reply mainly in Hindi (Devanagari) and 
add English words in brackets for clarity — e.g., विचार(thought), चिंता(anxiety), 
गतिविधि(activity).  
Use natural language with emojis 🌸🧠🌱💡✅🙏🌻👉.  

Adapt your style:
- For emotional or factual questions → give brief empathetic and clear answers.  
- For anxiety/overthinking issues → include short CBT-style steps.  

End each reply with an encouraging or reflective question inviting follow-up.
''';
  }

  // --- OpenAI call (UTF-8 safe + defensive API key) ---
  Future<String> _queryOpenAI(
    String prompt,
    List<Map<String, String>> history,
    String apiKey,
  ) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('OpenAI API key not set.');
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
      'temperature': 1,
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

    final utf8Body = utf8.decode(resp.bodyBytes);
    final data = jsonDecode(utf8Body) as Map<String, dynamic>;

    final choice = (data['choices'] as List).first;
    final text = ((choice['message'] ?? {})['content'] ?? '') as String;
    return text.trim();
  }

  // --- Gemini call (Generative Language HTTP REST) ---
  Future<String> _queryGemini(String prompt, String apiKey) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('Gemini API key not set.');
    }

    final model = dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash-lite';
    final base =
        'https://generativelanguage.googleapis.com/v1/models/$model:generateContent';

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '${_systemPromptForCBT()}\n\nUser: $prompt\nAssistant:'},
          ],
        },
      ],
      'generation_config': {'temperature': 0.8, 'maxOutputTokens': 800},
    });

    // 1) Try API key in query param first (common for API keys)
    try {
      final keyUrl = Uri.parse('$base?key=$apiKey');
      final resp = await http.post(
        keyUrl,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      debugPrint('Gemini (key param) status: ${resp.statusCode}');
      debugPrint('Gemini (key param) headers: ${resp.headers}');
      debugPrint('Gemini (key param) body: ${utf8.decode(resp.bodyBytes)}');

      if (resp.statusCode < 400) {
        final utf8Body = utf8.decode(resp.bodyBytes);
        final data = jsonDecode(utf8Body) as Map<String, dynamic>;
        return _extractGeminiText(data);
      }
    } catch (e) {
      debugPrint('Gemini key-param attempt failed: $e');
    }

    // 2) Try Bearer auth (useful if apiKey is an OAuth access token)
    try {
      final bearerUrl = Uri.parse(base);
      final resp = await http.post(
        bearerUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: body,
      );

      debugPrint('Gemini (bearer) status: ${resp.statusCode}');
      debugPrint('Gemini (bearer) headers: ${resp.headers}');
      debugPrint('Gemini (bearer) body: ${utf8.decode(resp.bodyBytes)}');

      if (resp.statusCode < 400) {
        final utf8Body = utf8.decode(resp.bodyBytes);
        final data = jsonDecode(utf8Body) as Map<String, dynamic>;
        return _extractGeminiText(data);
      } else {
        final safe = utf8.decode(resp.bodyBytes);
        throw Exception('Gemini error ${resp.statusCode}: $safe');
      }
    } catch (e) {
      throw Exception('Gemini request failed: $e');
    }
  }

  List<Map<String, String>> _buildHistoryForOpenAI() {
    final out = <Map<String, String>>[];
    for (final m in _messages) {
      out.add({'role': m.isUser ? 'user' : 'assistant', 'content': m.text});
    }
    return out;
  }

  // New helper: ensure chatIndex doc exists and update pending count/lastMessage
  Future<void> _updateChatIndexForPending(String lastMessageText) async {
    if (_chatId == null) return;
    final chatIndexRef = _firestore.collection('chatIndex').doc(_chatId);
    try {
      await chatIndexRef.set({
        'userId': _chatId,
        'userName': _userName ?? '',
        'lastMessage': lastMessageText,
        'lastUpdated': FieldValue.serverTimestamp(),
        'pendingCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to update chatIndex: $e');
    }
  }

  // New: write user message doc to Firestore (for doctor's view)
  Future<void> _writeUserMessageToFirestore(
    String messageId,
    String text,
    int ts,
  ) async {
    if (_chatId == null) return;
    final messagesRef = _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages');
    try {
      await messagesRef.doc(messageId).set({
        'sender': 'user',
        'text': text,
        'timestamp': ts,
        'approved': true, // user messages are visible immediately
      }, SetOptions(merge: true));
      // Also update chatIndex (non-pending update)
      await _firestore.collection('chatIndex').doc(_chatId).set({
        'userId': _chatId,
        'userName': _userName ?? '',
        'lastMessage': text,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to write user message to Firestore: $e');
    }
  }

  // New: write AI-suggested assistant reply to Firestore with approved:false and parentId
  Future<void> _writeAiReplyToFirestore(
    String text,
    int ts,
    String parentMessageId,
  ) async {
    if (_chatId == null) return;
    final messagesRef = _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages');
    try {
      final docRef = messagesRef.doc(); // generated id
      await docRef.set({
        'sender': 'assistant',
        'text': text,
        'timestamp': ts,
        'approved': false,
        'suggestedBy': 'ai',
        'parentId': parentMessageId,
      }, SetOptions(merge: true));

      // update chatIndex so doctor can see a pending reply
      await _updateChatIndexForPending('AI response pending approval');

      debugPrint(
        'AI reply written to Firestore (awaiting approval): ${docRef.id}',
      );
    } catch (e) {
      debugPrint('Failed to write AI reply to Firestore: $e');
    }
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

    // Create local user message and persist
    final userMsg = _ChatMessage.user(text);
    setState(() {
      _messages.add(userMsg);
      _ctrl.clear();
    });
    await _saveMessagesToPrefs();
    _scrollToBottom();

    // Write the user message to Firestore (immediately visible to doctor)
    await _writeUserMessageToFirestore(userMsg.id, text, userMsg.timestamp);

    _setLoading(true);

    try {
      // Query AI provider
      String reply;
      if (_provider == _AiProvider.openai) {
        final apiKey = await _getApiKey(_AiProvider.openai);
        if (apiKey == null) throw Exception('OpenAI API key not found.');
        final history = _buildHistoryForOpenAI();
        reply = await _queryOpenAI(text, history, apiKey);
      } else {
        final apiKey = await _getApiKey(_AiProvider.gemini);
        if (apiKey == null) throw Exception('Gemini API key not found.');
        reply = await _queryGemini(text, apiKey);
      }

      // Write AI reply to Firestore as approved:false so doctor can review/edit/approve
      final ts = DateTime.now().millisecondsSinceEpoch;
      await _writeAiReplyToFirestore(reply, ts, userMsg.id);

      // Do NOT add AI reply to _messages (user should not see it until doctor approves).
      // Show a short acknowledgement
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Response generated and sent to your reviewer for approval.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on Exception catch (e) {
      debugPrint('Chat send error (AI): $e');
      // If AI fails, show assistant error message locally (so user isn't left hanging).
      final errMsg = _ChatMessage.assistant(
        'Sorry — failed to get a reply. (${e})',
      );
      setState(() {
        _messages.add(errMsg);
      });
      await _saveMessagesToPrefs();
      _scrollToBottom();
    } finally {
      _setLoading(false);
    }
  }

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

  Widget buildProfileAvatar() {
    const neonColors = [
      Color(0xFF00F5D4),
      Color(0xFF00E5FF),
      Color(0xFF8A2BE2),
      Color(0xFF00F5D4),
    ];

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_loading)
            RotationTransition(
              turns: _ringController,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    startAngle: 0.0,
                    endAngle: 3.14 * 2,
                    colors: neonColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent.withOpacity(0.18),
                      blurRadius: 14,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),

          if (_loading)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),

          CircleAvatar(
            radius: 18,
            backgroundImage: const AssetImage('images/drkanhaiya.png'),
            backgroundColor: Colors.teal.shade200,
          ),
        ],
      ),
    );
  }

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
            ],
          ),
        ),
      ),
    );
  }

  void _openDisclaimerSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _buildDisclaimerCard(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Close', style: _textStyle()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            buildProfileAvatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dr. Kanhaiya (AI)',
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    maxLines: 1,
                    style: _textStyle(weight: FontWeight.w700, size: 15),
                  ),
                  if (!_consentAccepted)
                    Text(
                      'Tap the info for disclaimer',
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                      style: _textStyle(
                        size: 11,
                      ).copyWith(color: Colors.white54),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Disclaimer',
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _openDisclaimerSheet,
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF021515),
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'clear') {
                _confirmClear();
              } else if (value == 'save') {
                await _saveMessagesToPrefs();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat saved locally')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'save',
                child: Text(
                  'Save chat locally',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Text(
                  'Clear chat',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),

      body: SafeArea(
        child: Stack(
          children: [
            // --- existing chat column (unchanged) ---
            Column(
              children: [
                const SizedBox(height: 8),
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
                if (_loading) _buildTypingIndicator(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
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
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _ctrl,
                                    textInputAction: TextInputAction.send,
                                    minLines: 1,
                                    maxLines: 6,
                                    style: _textStyle(),
                                    cursorColor: const Color(0xFF008F89),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Ask Dr. Kanhaiya a question...',
                                      hintStyle: _textStyle(
                                        size: 14,
                                      ).copyWith(color: Colors.white54),
                                      border: InputBorder.none,
                                      isDense: true,
                                      filled: false,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                    ),
                                    onSubmitted: (_) {
                                      if (!_loading) _sendMessage();
                                    },
                                  ),
                                ),
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
                                    color: Colors.transparent,
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
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
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

            // --- FAB positioned under AppBar (top-right) ---
            Positioned(
              top:
                  8, // small gap below AppBar (Scaffold places body under AppBar already)
              right: 12,
              child: FloatingActionButton.extended(
                onPressed: _showProviderPicker,
                label: Text(
                  _provider == _AiProvider.openai ? 'OpenAI' : 'Gemini',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: Icon(
                  _provider == _AiProvider.openai
                      ? Icons.open_in_new
                      : Icons.flash_on,
                ),
                backgroundColor: const Color(0xFF008F89),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),

      // Floating action button to choose provider
    );
  }

  void _showProviderPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF021515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose AI provider',
                  style: _textStyle(weight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: Text('OpenAI', style: _textStyle()),
                  subtitle: Text(
                    'Uses your OpenAI key',
                    style: _textStyle(size: 12),
                  ),
                  trailing: _provider == _AiProvider.openai
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _provider = _AiProvider.openai);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flash_on),
                  title: Text('Gemini (Flash 2.5 Lite)', style: _textStyle()),
                  subtitle: Text(
                    'Uses your GEMINI_API_KEY',
                    style: _textStyle(size: 12),
                  ),
                  trailing: _provider == _AiProvider.gemini
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() => _provider = _AiProvider.gemini);
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

  Widget _buildActionButtonsForMessage(String text) {
    final lower = text.toLowerCase();
    final actions = <_ActionItem>[];
    void add(String label, String route, IconData icon) {
      actions.add(_ActionItem(label: label, route: route, icon: icon));
    }

    if (lower.contains('abcd')) {
      add('ABCD Worksheet', '/abcd', Icons.description_outlined);
    }
    if (lower.contains('grounding')) {
      add('Grounding', '/grounding', Icons.grass_outlined);
    }
    if (lower.contains('breath') || lower.contains('relax')) {
      add('Relax Breathing', '/relax/breath', Icons.air_outlined);
    }
    if (lower.contains('pmr') ||
        lower.contains('progressive muscle') ||
        lower.contains('muscle relaxation')) {
      add(
        'PMR — Muscle Relaxation',
        '/relax_pmr',
        Icons.self_improvement_outlined,
      );
    }
    if (lower.contains('thought record') || lower.contains('thought')) {
      add('Thought Record', '/thought', Icons.menu_book_outlined);
    }
    if (lower.contains('meditation')) {
      add(
        'Mini Meditation',
        '/minimeditation',
        Icons.self_improvement_outlined,
      );
    }
    if (lower.contains('safety') ||
        lower.contains('help') ||
        lower.contains('crisis') ||
        lower.contains('danger')) {
      add('Get Help', '/safety', Icons.warning_amber_outlined);
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    const Color tealLight = Color(0xFF79C2BF);
    const Color tealMid = Color(0xFF008F89);

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions.map((a) {
            return Semantics(
              button: true,
              label: a.label,
              child: Tooltip(
                message: a.label,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pushNamed(context, a.route);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      constraints: const BoxConstraints(minHeight: 40),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.02),
                            Colors.white.withOpacity(0.01),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: tealMid.withOpacity(0.9),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 28,
                            width: 28,
                            decoration: BoxDecoration(
                              color: tealLight.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(a.icon, size: 16, color: tealLight),
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              a.label,
                              overflow: TextOverflow.ellipsis,
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
                ),
              ),
            );
          }).toList(),
        ),
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
                  SelectableText.rich(
                    _parseMarkdownToTextSpan(m.text),
                    showCursor: false,
                    cursorWidth: 0,
                  ),
                  const SizedBox(height: 8),
                  if (!m.isUser) _buildActionButtonsForMessage(m.text),
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

/// Small helper to hold assistant messages with parentId metadata
class _ChatMessageWithMeta {
  final String id;
  final String text;
  final int timestamp;
  final String? parentId;
  final bool editedByDoctor;
  _ChatMessageWithMeta({
    required this.id,
    required this.text,
    required this.timestamp,
    this.parentId,
    this.editedByDoctor = false,
  });
}

/// Internal message model (keeps your existing constructors)
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

  // Exposed private ctor to create message with explicit id (used for incoming firestore messages)
  factory _ChatMessage._withId(
    String id,
    String t, {
    bool isUser = false,
    int? timestamp,
  }) => _ChatMessage._(id: id, text: t, isUser: isUser, timestamp: timestamp);

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

class _ActionItem {
  final String label;
  final String route;
  final IconData icon;
  _ActionItem({required this.label, required this.route, required this.icon});
}
