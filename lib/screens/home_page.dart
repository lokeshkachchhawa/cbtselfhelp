// lib/screens/home_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Palette
const Color teal1 = Color.fromARGB(255, 1, 108, 108);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

final List<Color> tealPalette = [teal1, teal2, teal3, teal4, teal5, teal6];

// --- Local mood models (top-level) ---
class _MoodRecord {
  final int score;
  final DateTime createdAt; // stored as UTC
  _MoodRecord({required this.score, required this.createdAt});
}

class _DayMood {
  final DateTime date; // local date for display
  final int? score;
  final DateTime? createdAt; // original timestamp (if any)
  _DayMood({required this.date, required this.score, this.createdAt});
}

// --- Progress models (top-level) ---
class ProgramProgress {
  final String id;
  final String title;
  final int completed;
  final int total;
  final double percent; // 0.0 - 1.0

  ProgramProgress({
    required this.id,
    required this.title,
    required this.completed,
    required this.total,
    required this.percent,
  });
}

class _ProgressSummary {
  final int completedLessons;
  final int totalLessons;
  final double percentComplete;
  final double? averageMoodLast7Days;
  final List<ProgramProgress> perProgram;

  _ProgressSummary({
    required this.completedLessons,
    required this.totalLessons,
    required this.percentComplete,
    required this.averageMoodLast7Days,
    required this.perProgram,
  });

  factory _ProgressSummary.empty() => _ProgressSummary(
    completedLessons: 0,
    totalLessons: 0,
    percentComplete: 0.0,
    averageMoodLast7Days: null,
    perProgram: const [],
  );
}

// --- HomePage ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int mood = 5;
  final user = FirebaseAuth.instance.currentUser;

  late Future<_ProgressSummary> _progressFuture;

  // Known programs — keep titles and lesson counts in sync with JSONs in assets
  final Map<String, Map<String, dynamic>> _programMeta = {
    '7day_mood_boost': {'title': '7-Day Mood Boost', 'lessons': 7},
    'managing_worry_4week': {'title': 'Managing Worry', 'lessons': 28},
    'sleep_better_2week': {'title': 'Sleep Better', 'lessons': 14},
  };

  static const String _kLocalMoodKey = 'local_mood_logs';

  @override
  void initState() {
    super.initState();
    _progressFuture = _loadProgressSummary();
  }
  // Add this method inside _HomePageState (near other _build* methods)

  Widget _buildDrKanhaiyaChatCard() {
    return Card(
      elevation: 3,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.05), teal4.withOpacity(0.15)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---- Dr. Kanhaiya Circular Photo ----
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: teal3.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset('images/drkanhaiya.png', fit: BoxFit.cover),
              ),
            ),

            const SizedBox(width: 14),

            // ---- Text content ----
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. Kanhaiya (AI)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'AI CBT Companion • Mind & Mood Coach',
                    style: TextStyle(
                      color: Colors.tealAccent.shade100,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ask about mood, anxiety, or coping skills. Responses use Cognitive Behavioral Therapy (CBT) tools — informational only, not clinical advice.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // ---- Buttons ----
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _onOpenDrKanhaiyaChat,
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Start Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teal3,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _showDrKanhaiyaInfoSheet,
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Info'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.15),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Consent + navigation handler (add below the widget)
  void _onOpenDrKanhaiyaChat() async {
    final prefs = await SharedPreferences.getInstance();
    final hideConsent = prefs.getBool('hide_drkanhaiya_consent') ?? false;

    // if user already accepted once and checked "don't show again"
    if (hideConsent) {
      Navigator.pushNamed(context, '/drktv_chat');
      return;
    }

    bool dontShowAgain = false;

    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: StatefulBuilder(
          builder: (ctx, setState) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF004E4D).withOpacity(0.95),
                  const Color(0xFF016C6C).withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Circular avatar ---
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.white12,
                  child: ClipOval(
                    child: Image.asset(
                      'images/drkanhaiya.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- Title ---
                const Text(
                  'About this AI Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),

                // --- Description ---
                Text(
                  'The digital avatar of Dr. Kanhaiya provides informational guidance using CBT principles to support emotional wellbeing.\n\n'
                  '⚠️ This chat is not a replacement for professional diagnosis or emergency care.\n'
                  'If you are in crisis, please use the “Get Help” option or contact local services.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 14,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // --- Checkbox: Don't show again ---
                GestureDetector(
                  onTap: () => setState(() => dontShowAgain = !dontShowAgain),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: dontShowAgain,
                        onChanged: (val) =>
                            setState(() => dontShowAgain = val ?? false),
                        activeColor: const Color(0xFF008F89),
                        checkColor: Colors.white,
                      ),
                      Text(
                        "Don't show this again",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // --- Buttons ---
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (dontShowAgain) {
                            prefs.setBool('hide_drkanhaiya_consent', true);
                          }
                          Navigator.of(ctx).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teal3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 3,
                          shadowColor: teal3.withOpacity(0.5),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (accept == true) {
      Navigator.pushNamed(context, '/drktv_chat');
    }
  }

  // Info sheet for more details (optional)
  // Add this import at top of the file if missing

  void _showDrKanhaiyaInfoSheet() {
    String lang = 'English'; // <-- move it OUTSIDE StatefulBuilder

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final Map<String, Map<String, String>> L = {
              'English': {
                'title': 'Dr. Kanhaiya — AI Avatar (DrKtv)',
                'desc':
                    'An AI assistant trained to provide CBT-informed guidance and practical coping tools. It does not replace clinical care or crisis help.',
                'how': 'How to use',
                'step1':
                    '1️⃣  Ask a short question about your mood, thought, or worry.',
                'step2':
                    '2️⃣  Use clear, everyday words or choose your language.',
                'step3': '3️⃣  Try a CBT tip or exercise suggested by DrKtv.',
                'examples': 'Examples (tap to copy)',
                'ex1': 'I feel anxious before meetings — what can I do?',
                'ex2': 'I keep thinking “I will fail” — help me challenge it.',
                'safetyTitle': 'Safety first',
                'safety':
                    '⚠️ If you are in crisis or feel unsafe, please use the “Get Help” button below or call local emergency services. This chat provides educational guidance only.',
                'start': 'Start chat',
                'close': 'Close',
                'copied': 'Copied to clipboard',
              },
              'हिन्दी': {
                'title': 'डॉ. कन्हैया — एआई अवतार (DrKtv)',
                'desc':
                    'यह एक एआई सहायक है जो CBT-आधारित मार्गदर्शन और व्यावहारिक सहयोग रणनीतियाँ देता है। यह चिकित्सकीय सलाह या आपातकालीन सहायता का विकल्प नहीं है।',
                'how': 'कैसे उपयोग करें',
                'step1':
                    '1️⃣  अपने मूड, विचार या चिंता से जुड़ा छोटा प्रश्न पूछें।',
                'step2': '2️⃣  सरल शब्दों में लिखें या अपनी भाषा चुनें।',
                'step3':
                    '3️⃣  DrKtv द्वारा सुझाए गए CBT सुझावों या अभ्यासों को आज़माएँ।',
                'examples': 'उदाहरण (कॉपी करने के लिए टैप करें)',
                'ex1': 'मुझे मीटिंग से पहले चिंता होती है — मैं क्या करूं?',
                'ex2':
                    'मैं सोचता/सोचती हूँ “मैं असफल हो जाऊँगा/गी” — इसे कैसे चुनौती दूँ?',
                'safetyTitle': 'सुरक्षा',
                'safety':
                    '⚠️ यदि आप संकट में हैं या खुद को असुरक्षित महसूस करते हैं, तो कृपया “Get Help” बटन दबाएँ या स्थानीय आपातकालीन सेवाओं से संपर्क करें। यह चैट केवल शैक्षणिक सहायता प्रदान करती है।',
                'start': 'चैट शुरू करें',
                'close': 'बंद करें',
                'copied': 'कॉपी किया गया',
              },
            };

            final t = L[lang]!;

            Future<void> _copy(String text) async {
              await Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(t['copied']!)));
            }

            return SafeArea(
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF021515),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: image, title, lang toggle, close
                      Row(
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'images/drkanhaiya.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t['title']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          // Toggle Buttons
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() {
                                    lang = 'English';
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: lang == 'English'
                                          ? teal3
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'EN',
                                      style: TextStyle(
                                        color: lang == 'English'
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    lang = 'हिन्दी';
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: lang == 'हिन्दी'
                                          ? teal3
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'हि',
                                      style: TextStyle(
                                        color: lang == 'हिन्दी'
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t['desc']!,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        t['how']!,
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t['step1']!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        t['step2']!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        t['step3']!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t['examples']!,
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _copy(t['ex1']!),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t['ex1']!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _copy(t['ex2']!),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t['ex2']!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t['safetyTitle']!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t['safety']!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                t['close']!,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _onOpenDrKanhaiyaChat();
                              },
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: Text(t['start']!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: teal3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                              ),
                            ),
                          ),
                        ],
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

  // Load per-program progress summary from SharedPreferences and compute avg mood from local entries
  Future<_ProgressSummary> _loadProgressSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final List<ProgramProgress> perProgram = [];
    int completedLessons = 0;
    int totalLessons = 0;

    for (final entry in _programMeta.entries) {
      final pid = entry.key;
      final title = entry.value['title'] as String;
      final lessons = (entry.value['lessons'] as int?) ?? 0;
      totalLessons += lessons;

      final key = 'prog_${pid}_completed';
      final list = prefs.getStringList(key) ?? [];
      final completedCount = list
          .map((s) => int.tryParse(s) ?? 0)
          .where((n) => n > 0)
          .length;
      completedLessons += completedCount;

      final percent = lessons == 0
          ? 0.0
          : (completedCount / lessons).clamp(0.0, 1.0);

      perProgram.add(
        ProgramProgress(
          id: pid,
          title: title,
          completed: completedCount,
          total: lessons,
          percent: percent,
        ),
      );
    }

    final overallPercent = totalLessons == 0
        ? 0.0
        : (completedLessons / totalLessons).clamp(0.0, 1.0);

    // Average mood from local last 7 days
    double? avgMood;
    try {
      final recs = await _getLocalMoodRecords();
      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      final filtered = recs
          .where((r) => !r.createdAt.isBefore(start.toUtc()))
          .toList();

      // pick latest per day, then average those scores
      final Map<String, _MoodRecord> latestPerDay = {};
      for (final r in filtered) {
        final dtLocal = r.createdAt.toLocal();
        final key =
            '${dtLocal.year}-${dtLocal.month.toString().padLeft(2, '0')}-${dtLocal.day.toString().padLeft(2, '0')}';
        final existing = latestPerDay[key];
        if (existing == null || r.createdAt.isAfter(existing.createdAt)) {
          latestPerDay[key] = r;
        }
      }
      final scores = latestPerDay.values.map((e) => e.score).toList();
      if (scores.isNotEmpty) {
        avgMood = scores.reduce((a, b) => a + b) / scores.length;
      }
    } catch (e) {
      debugPrint('Failed to compute average mood: $e');
      avgMood = null;
    }

    return _ProgressSummary(
      completedLessons: completedLessons,
      totalLessons: totalLessons,
      percentComplete: overallPercent,
      averageMoodLast7Days: avgMood,
      perProgram: perProgram,
    );
  }

  // ---------------- UI ----------------
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

                    // Themed settings menu (dark)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      color: const Color(0xFF021515),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onSelected: (value) async {
                        switch (value) {
                          case 'privacy':
                            _showSettingsInfo('privacy');
                            break;
                          case 'terms':
                            _showSettingsInfo('terms');
                            break;
                          case 'refund':
                            _showSettingsInfo('refund');
                            break;
                          case 'safety':
                            _showSettingsInfo('safety');
                            break;
                          case 'about':
                            _showSettingsInfo('about');
                            break;
                          case 'faq':
                            _showSettingsInfo('faq');
                            break;
                          case 'rate':
                            await _openWebsite(
                              'https://play.google.com/store/apps/details?id=com.reportx.app',
                              preferMarketForPlayStore: true,
                            );
                            break;
                          case 'signout':
                            await _confirmAndSignOut();
                            break;
                          default:
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Unknown option')),
                            );
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'privacy',
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'terms',
                          child: Text(
                            'Terms & Conditions',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'refund',
                          child: Text(
                            'Refund Policy',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'safety',
                          child: Text(
                            'Data Safety',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'about',
                          child: Text(
                            'About / Contact',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'faq',
                          child: Text(
                            'FAQ / Help',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'rate',
                          child: Text(
                            '⭐ Rate us on Play Store',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'signout',
                          child: Text(
                            'Sign out',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
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
                      // Mood quick entry card (local-only)
                      _buildMoodCard(),

                      const SizedBox(height: 12),

                      // Today's task card (now has ABCD option)
                      _buildTaskCard(),

                      const SizedBox(height: 12),

                      // Quick tools row (includes ABCD)
                      _buildQuickTools(),

                      const SizedBox(height: 12),
                      _buildDrKanhaiyaChatCard(),
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

                      // Progress card (per-program tiles)
                      FutureBuilder<_ProgressSummary>(
                        future: _progressFuture,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const SizedBox(
                              height: 160,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snap.hasError) {
                            return _buildProgressErrorCard(
                              snap.error.toString(),
                            );
                          }
                          final data = snap.data ?? _ProgressSummary.empty();
                          return _buildProgressCardWithPerProgram(data);
                        },
                      ),

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

  // ---------------- Mood UI & local storage ----------------

  Widget _buildMoodCard() {
    return InkWell(
      onTap: _showMoodHistory, // open local history
      borderRadius: BorderRadius.circular(14),
      child: Card(
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
                  TextButton.icon(
                    onPressed: _showMoodHistory,
                    icon: const Icon(Icons.history, color: Colors.white70),
                    label: Text(
                      'Last 7 days',
                      style: TextStyle(color: Colors.white70),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tap the card to view daily history',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                ),
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Save mood locally only (SharedPreferences)
  void _saveMood() async {
    final score = mood;
    final now = DateTime.now().toUtc();

    try {
      await _saveMoodLocally(score, now);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mood saved locally')));
      // refresh progress summary which reads local mood for average
      setState(() {
        _progressFuture = _loadProgressSummary();
      });
    } catch (e) {
      debugPrint('Failed to save mood locally: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save mood')));
    }
  }

  // Append a mood entry to local storage; keep up to maxEntries
  Future<void> _saveMoodLocally(int score, DateTime createdAtUtc) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kLocalMoodKey) ?? <String>[];

    final entry = {'score': score, 'createdAt': createdAtUtc.toIso8601String()};
    raw.add(json.encode(entry));

    // Keep recent N entries (adjust if you prefer)
    const int maxEntries = 365;
    final keep = raw.length <= maxEntries
        ? raw
        : raw.sublist(raw.length - maxEntries);
    await prefs.setStringList(_kLocalMoodKey, keep);
  }

  // Read local entries and convert to _MoodRecord
  Future<List<_MoodRecord>> _getLocalMoodRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kLocalMoodKey) ?? <String>[];
    final out = <_MoodRecord>[];
    for (final s in raw) {
      try {
        final m = json.decode(s) as Map<String, dynamic>;
        final score = (m['score'] is int)
            ? m['score'] as int
            : (m['score'] is double
                  ? (m['score'] as double).toInt()
                  : int.tryParse(m['score']?.toString() ?? ''));
        final iso = m['createdAt']?.toString();
        if (score != null && iso != null) {
          final dt = DateTime.parse(iso).toUtc();
          out.add(_MoodRecord(score: score, createdAt: dt));
        }
      } catch (_) {
        // ignore malformed entry
      }
    }
    return out;
  }

  // Show last 7 calendar days using only local entries
  Future<void> _showMoodHistory() async {
    final now = DateTime.now();
    final startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6)); // 7 days inclusive

    // load local entries and compute latest per calendar day
    List<_MoodRecord> local = [];
    try {
      local = await _getLocalMoodRecords();
    } catch (e) {
      debugPrint('Failed to read local mood records: $e');
    }

    // Map dateKey -> latest record for that date (by createdAt)
    final Map<String, _MoodRecord> latestPerDay = {};
    for (final r in local) {
      if (r.createdAt.isBefore(startDate.toUtc())) continue;
      final dtLocal = r.createdAt.toLocal();
      final key =
          '${dtLocal.year}-${dtLocal.month.toString().padLeft(2, '0')}-${dtLocal.day.toString().padLeft(2, '0')}';
      final existing = latestPerDay[key];
      if (existing == null || r.createdAt.isAfter(existing.createdAt)) {
        latestPerDay[key] = r;
      }
    }

    // Build ordered list for display (oldest -> newest)
    final List<_DayMood> days = [];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final rec = latestPerDay[key];
      days.add(_DayMood(date: d, score: rec?.score, createdAt: rec?.createdAt));
    }

    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF021515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mood — last 7 days',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: days.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12),
                    itemBuilder: (context, i) {
                      final d = days[i];
                      final label = _formatDateLabel(d.date);
                      final scoreText = d.score != null
                          ? d.score.toString()
                          : '—';
                      final moodText = d.score != null
                          ? moodLabel(d.score!)
                          : 'No entry';
                      final subtitle = d.createdAt != null
                          ? 'Saved at ${_formatTime(d.createdAt!.toLocal())}'
                          : null;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: d.score != null
                              ? teal3
                              : Colors.white12,
                          child: Text(
                            scoreText,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              moodText,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: use Save to store today\'s mood locally.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // small date label like: Mon 6 Oct
  String _formatDateLabel(DateTime d) {
    const wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = wk[(d.weekday - 1) % 7];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthName = months[d.month - 1];
    return '$weekday ${d.day} $monthName';
  }

  String _formatTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ---------------- Programs / Quick tools (unchanged) ----------------

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
      {'icon': Icons.rule, 'label': 'ABCD', 'route': '/abcd'},
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

  // ---------------- Progress card with per-program tiles ----------------

  Widget _buildProgressCardWithPerProgram(_ProgressSummary data) {
    final percent = (data.percentComplete * 100).toInt();
    final avgMood = data.averageMoodLast7Days;

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
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: data.percentComplete,
                        strokeWidth: 8,
                        valueColor: const AlwaysStoppedAnimation<Color>(teal2),
                        backgroundColor: Colors.white12,
                      ),
                      Center(
                        child: Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lessons completed: ${data.completedLessons}/${data.totalLessons}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        avgMood != null
                            ? 'Average mood this week: ${avgMood.toStringAsFixed(1)}'
                            : 'No mood entries in last 7 days',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/programs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teal3,
                          // ADDED: Reduced padding for a more compact button
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        child: const Text('View programs'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            // Per-program tiles
            Column(
              children: data.perProgram.map((p) {
                final pPct = (p.percent * 100).toInt();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: p.percent,
                              strokeWidth: 5,
                              valueColor: AlwaysStoppedAnimation<Color>(teal4),
                              backgroundColor: Colors.white12,
                            ),
                            Center(
                              child: Text(
                                '$pPct%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p.completed}/${p.total} lessons',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Continue goes to programs screen — deep linking to specific program can be added later.
                          Navigator.pushNamed(context, '/programs');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teal3,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressErrorCard(String message) {
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
            Text(
              'Failed to load progress.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: Colors.red.shade300)),
          ],
        ),
      ),
    );
  }

  // ---------------- Helpers / Settings / Misc ----------------

  Future<void> _openWebsite(
    String rawUrl, {
    bool preferMarketForPlayStore = false,
  }) async {
    try {
      if (rawUrl.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Link not configured')));
        return;
      }

      String urlStr = rawUrl.trim();

      // If relative (like "privacy.html"), prepend base site
      const base = 'https://phpstack-1484732-5862316.cloudwaysapps.com/';
      if (!urlStr.startsWith('http://') &&
          !urlStr.startsWith('https://') &&
          !urlStr.startsWith('mailto:') &&
          !urlStr.startsWith('tel:') &&
          !urlStr.startsWith('whatsapp:')) {
        if (urlStr.startsWith('/')) urlStr = urlStr.substring(1);
        urlStr = base + urlStr;
      }

      // Play Store special handling (keeps same package)
      if (preferMarketForPlayStore && urlStr.contains('play.google.com')) {
        const packageId = 'com.medisnap.scanner'; // your appId
        final marketUri = Uri.parse('market://details?id=$packageId');
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          return;
        }
        urlStr = 'https://play.google.com/store/apps/details?id=$packageId';
      }

      final uri = Uri.parse(urlStr);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      debugPrint('Failed to open URL "$rawUrl": $e\n$st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open link: $e')));
    }
  }

  // Quick create bottom sheet
  void _openQuickCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF021515),
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
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: teal4,
                    child: const Icon(Icons.note_alt, color: Colors.white),
                  ),
                  title: const Text(
                    'New thought record',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Capture an automatic thought quickly',
                    style: TextStyle(color: Colors.white70),
                  ),
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
                  title: const Text(
                    'New ABCD worksheet',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Open the ABCD worksheet (Activating event → Belief → Consequence → Dispute)',
                    style: TextStyle(color: Colors.white70),
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

  // ---------------- Settings info sheets -----------------------
  void _showSettingsInfo(String key) {
    final title = _settingsTitleFor(key);
    final content = _settingsContentFor(key);
    final external = _settingsHasExternalLink(key);
    final externalPath = _settingsExternalPath(key);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF021515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom;
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Padding(
            padding: EdgeInsets.only(bottom: pad),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 5,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          content,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (external && externalPath != null)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _openWebsite(
                                externalPath,
                                preferMarketForPlayStore: key == 'rate',
                              );
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('View full page'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: teal3,
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            if (key == 'about') {
                              _openWebsite('mailto:hello@example.com');
                            } else {
                              Navigator.of(ctx).pop();
                            }
                          },
                          child: Text(
                            key == 'about' ? 'Contact us' : 'Close',
                            style: TextStyle(color: teal2),
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
      },
    );
  }

  String _settingsTitleFor(String key) {
    switch (key) {
      case 'privacy':
        return 'Privacy Policy';
      case 'terms':
        return 'Terms & Conditions';
      case 'refund':
        return 'Refund Policy';
      case 'safety':
        return 'Data safety';
      case 'about':
        return 'About & contact';
      case 'faq':
        return 'FAQ & help';
      default:
        return 'Info';
    }
  }

  bool _settingsHasExternalLink(String key) {
    return key == 'privacy' ||
        key == 'terms' ||
        key == 'refund' ||
        key == 'about' ||
        key == 'faq' ||
        key == 'rate';
  }

  String? _settingsExternalPath(String key) {
    switch (key) {
      case 'privacy':
        return 'privacy.html';
      case 'terms':
        return 'terms.html';
      case 'refund':
        return 'refund.html';
      case 'safety':
        return 'data-safety.html';
      case 'about':
        return 'about.html';
      case 'faq':
        return 'faq.html';
      case 'rate':
        return 'https://play.google.com/store/apps/details?id=com.reportx.app';
      default:
        return null;
    }
  }

  String _settingsContentFor(String key) {
    switch (key) {
      case 'privacy':
        return '''
We collect minimal data locally to provide the app experience. Personal info (if you sign in) is stored with your authentication provider (e.g. Firebase) and any remote data storage is subject to that provider's policies. 

What we do:
• Store your thought records locally on your device by default.
• Optionally (if signed in) we may sync mood logs to your user account.
• We do not sell your data.

If you want the full legal text, tap "View full page".''';
      case 'terms':
        return '''
These terms explain the app's intended use and limitations. This app provides tools for mood tracking and CBT-style journaling and is not a replacement for professional mental health care.

Key points:
• Use at your own discretion — seek professional help for high-risk situations.
• The app provides local storage for your entries; syncing requires sign-in.
• We may update terms from time to time; consult the full text for details.''';
      case 'refund':
        return '''
Refunds, if applicable, depend on the store (Google Play / App Store) policies and purchases. If you purchased premium content through a store you should request refunds through the store's purchase history. 

Contact support via the About / Contact sheet for assistance.''';
      case 'safety':
        return '''
Data safety: the app limits personal data collection. If you sign in, minimal profile and mood logs may be stored in your account for backup and cross-device access. Sensitive data (therapy notes, medical diagnoses) should not be entered unless you are comfortable storing it.

If you're in immediate danger or experiencing a crisis, please use local emergency services, crisis hotlines, or the 'Get Help' button on this screen.''';
      case 'about':
        return '''
About this app
This app offers small daily practices (breathing, thought records, ABCD worksheets, ambient sounds) to help with mood regulation and building cognitive skills.

Contact
For questions, feedback or licensing queries email: drktvtech@gmail.com

Tap "Contact us" to open your mail app.''';
      case 'faq':
        return '''
FAQ — quick answers

Q: Where are my thought records stored?
A: By default they're saved locally on your device. If you sign in, some features (like mood logs) may be synced.

Q: How do I export my data?
A: Use the Export option (if available in settings) to save a JSON copy or use copy/paste on individual items.

Q: Is this a therapy app?
A: No — it provides tools informed by CBT but is not a substitute for professional mental health care.

For more, tap "View full page".''';
      default:
        return 'Information not available.';
    }
  }

  // Confirm then sign out
  Future<void> _confirmAndSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed out')));
      setState(() {
        _progressFuture = _loadProgressSummary();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to sign out: $e')));
    }
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
}
