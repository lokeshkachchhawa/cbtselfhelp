// lib/screens/programs_page.dart
// Programs UI — dark teal theme + gradient thumbnails, onboarding overlay,
// and simple language support (English / हिन्दी). If a localized program JSON
// exists (filename with _hi.json), it will be loaded; otherwise the base JSON
// is used.
//
// NOTE: Make sure localized JSON files (e.g. 7day_mood_boost_hi.json) are
// added to assets/programs and registered in pubspec.yaml.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

// NEW: Flutter TTS
import 'package:flutter_tts/flutter_tts.dart';

const Color teal1 = Color(0xFFC6EDED);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);
// Assumed colors from previous context:
// const Color teal1 = Color(0xFF016C6C);

// New helper colors for contrast and status
const Color darkBackground = Color(0xFF011F1F);
const Color completedBackground = Color(
  0xFF023232,
); // Slightly lighter than darkBackground
const Color completedAccent = Color(
  0xFF4CAF50,
); // Standard green for completion

// --- Models (same structure as before) ---
class Program {
  final String id;
  final String title;
  final String shortDescription;
  final String description;
  final int days;
  final int recommendedDailyMinutes;
  final List<Lesson> lessons;
  final String language;
  final String? thumbnail; // NEW

  Program({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.description,
    required this.days,
    required this.recommendedDailyMinutes,
    required this.lessons,
    required this.language,
    this.thumbnail, // NEW
  });

  factory Program.fromMap(Map<String, dynamic> m) {
    final lessons = (m['lessons'] as List<dynamic>? ?? [])
        .map((e) => Lesson.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Program(
      id: m['id'] as String? ?? 'program_unknown',
      title: m['title'] as String? ?? '',
      shortDescription: m['shortDescription'] as String? ?? '',
      description: m['description'] as String? ?? '',
      days: (m['days'] as num?)?.toInt() ?? lessons.length,
      recommendedDailyMinutes:
          (m['recommendedDailyMinutes'] as num?)?.toInt() ?? 0,
      lessons: lessons,
      language: (m['language'] as String?)?.toLowerCase() ?? 'en',
      thumbnail: m['thumbnail'] as String?, // NEW
    );
  }
}

class Lesson {
  final String id;
  final int day;
  final String title;
  final String summary;
  final int minutes;
  final List<Block> blocks;
  Lesson({
    required this.id,
    required this.day,
    required this.title,
    required this.summary,
    required this.minutes,
    required this.blocks,
  });

  factory Lesson.fromMap(Map<String, dynamic> m) {
    final blocks = (m['blocks'] as List<dynamic>? ?? [])
        .map((e) => Block.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Lesson(
      id: m['id'] as String? ?? '',
      day: (m['day'] as num?)?.toInt() ?? 0,
      title: m['title'] as String? ?? '',
      summary: m['summary'] as String? ?? '',
      minutes: (m['minutes'] as num?)?.toInt() ?? 0,
      blocks: blocks,
    );
  }
}

class Block {
  final String type; // text | exercise | prompt | action | audio
  final String title;
  final String? content;
  final int? durationMinutes;
  final dynamic extra; // suggestedAction, suggestedActions, asset, etc.
  Block({
    required this.type,
    required this.title,
    this.content,
    this.durationMinutes,
    this.extra,
  });

  factory Block.fromMap(Map<String, dynamic> m) {
    return Block(
      type: m['type'] as String? ?? 'text',
      title: m['title'] as String? ?? '',
      content: m['content'] as String?,
      durationMinutes: (m['durationMinutes'] as num?)?.toInt(),
      extra: m['suggestedAction'] ?? m['suggestedActions'] ?? m['asset'],
    );
  }
}

// --- ProgramsPage ---
class ProgramsPage extends StatefulWidget {
  const ProgramsPage({super.key});
  @override
  State<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends State<ProgramsPage> {
  // base program asset filenames (register these in pubspec.yaml)
  final List<String> _programAssets = [
    'assets/programs/7day_mood_boost.json',
    'assets/programs/managing_worry_4week.json',
    'assets/programs/sleep_better_2week.json',
    // add more program json paths here
  ];

  // current UI language code — used to attempt localized variants
  String _lang = 'en';
  late Future<List<Program>> _programsFuture;

  @override
  void initState() {
    super.initState();
    _programsFuture = _loadPrograms();
  }

  Future<List<Program>> _loadPrograms() async {
    final List<Program> out = [];
    for (final asset in _programAssets) {
      // attempt localized variant first: e.g. 7day_mood_boost_hi.json
      final localized = asset.replaceFirst(
        '.json',
        '_${_lang == 'hi' ? 'hi' : _lang}.json',
      );
      String? payload;
      // Try localized asset
      try {
        if (localized != asset) {
          payload = await rootBundle.loadString(localized);
        }
      } catch (_) {
        payload = null;
      }
      // Fallback to base asset
      try {
        final str = payload ?? await rootBundle.loadString(asset);
        final m = json.decode(str) as Map<String, dynamic>;
        out.add(Program.fromMap(m));
      } catch (e) {
        debugPrint(
          'Failed to load program asset (localized:$localized) or base:$asset : $e',
        );
      }
    }
    return out;
  }

  void _setLang(String lang) {
    if (lang == _lang) return;
    setState(() {
      _lang = lang;
      _programsFuture = _loadPrograms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021515),
      appBar: AppBar(
        title: const Text('Programs'),
        backgroundColor: teal4,
        elevation: 0,
        actions: [
          // language selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _lang,
                dropdownColor: const Color(0xFF021515),
                items: const [
                  DropdownMenuItem(
                    value: 'en',
                    child: Text(
                      'English',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'hi',
                    child: Text(
                      'हिन्दी',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) _setLang(v);
                },
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF021515),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lang == 'hi'
                              ? 'प्रोग्राम कैसे काम करते हैं'
                              : 'How Programs work',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: teal2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _lang == 'hi'
                              ? 'प्रोग्राम छोटे दैनिक पाठों का अनुक्रम होते हैं जो व्यावहारिक मानसिक स्वास्थ्य कौशल सिखाते हैं (अक्सर CBT पर आधारित)। प्रत्येक दिन में एक संक्षिप्त रीडिंग, एक अभ्यास, और एक जर्नलिंग संकेत शामिल हो सकता है।'
                              : 'Programs are short sequences of daily lessons that teach practical mental health skills (often rooted in CBT). Each lesson includes a short reading, an optional practice, and a journaling prompt.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _lang == 'hi'
                              ? 'Suggested actions से आप सीधे Thought Record या ABCD जैसे उपकरण खोल सकते हैं।'
                              : 'Use suggested actions to jump to in-app exercises (Thought Record, ABCD, Relax). Progress is stored locally.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Program>>(
        future: _programsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final programs = snap.data ?? [];
          if (programs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.volunteer_activism,
                      size: 56,
                      color: teal3,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _lang == 'hi'
                          ? 'कोई प्रोग्राम नहीं मिला'
                          : 'No programs found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lang == 'hi'
                          ? 'सुनिश्चित करें कि प्रोग्राम JSON फ़ाइलें assets/programs में हैं और pubspec.yaml में जोड़ी गई हैं।'
                          : 'Add program JSON files to assets/programs and register them in pubspec.yaml.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: programs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final p = programs[i];
              return ProgramCard(program: p, lang: _lang);
            },
          );
        },
      ),
    );
  }
}

// --- ProgramCard with gradient thumbnail ---
class ProgramCard extends StatefulWidget {
  final Program program;
  final String lang;
  const ProgramCard({required this.program, required this.lang, super.key});

  @override
  State<ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends State<ProgramCard> {
  late Future<Set<int>> _completedFuture;

  @override
  void initState() {
    super.initState();
    _completedFuture = _loadCompleted();
  }

  Future<Set<int>> _loadCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'prog_${widget.program.id}_completed';
    final list = prefs.getStringList(key) ?? [];
    return list.map((s) => int.tryParse(s) ?? 0).where((n) => n > 0).toSet();
  }

  double _progress(Set<int> completed) {
    final total = widget.program.lessons.length;
    if (total == 0) return 0.0;
    return completed.length / total;
  }

  // generate two colors from program id for the gradient
  List<Color> _thumbColors() {
    final id = widget.program.id;
    final a = id.hashCode;
    final b = id.hashCode * 31;
    Color c1 = Color((0xFF000000 + (a & 0x00FFFFFF)).toUnsigned(32));
    Color c2 = Color((0xFF000000 + (b & 0x00FFFFFF)).toUnsigned(32));
    // blend toward teal palette for better look
    c1 = Color.lerp(c1, teal3, 0.55) ?? teal3;
    c2 = Color.lerp(c2, teal4, 0.55) ?? teal4;
    return [c1, c2];
  }

  @override
  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    return FutureBuilder<Set<int>>(
      future: _completedFuture,
      builder: (context, snap) {
        final completed = snap.data ?? <int>{};
        final prog = _progress(completed);
        _thumbColors();

        return Card(
          color: const Color(0xFF011F1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProgramDetailPage(program: p, lang: widget.lang),
                ),
              );
              setState(() => _completedFuture = _loadCompleted());
            },
            child: Row(
              children: [
                // --- LEFT: Thumbnail with fallback ---
                // LEFT: portrait thumbnail like course cards
                Container(
                  width: 90, // portrait strip
                  height: 200, // gives a nice balance inside the card
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    child: (p.thumbnail != null && p.thumbnail!.isNotEmpty)
                        ? Image.asset(
                            p.thumbnail!,
                            fit: BoxFit.cover, // important
                          )
                        : Container(
                            color: Colors.black26,
                            child: Icon(Icons.menu_book, color: teal2),
                          ),
                  ),
                ),

                // --- RIGHT: Text + actions ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.shortDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF022F2F),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${p.recommendedDailyMinutes} ${widget.lang == "hi" ? "मिन/दिन" : "min/day"}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                value: prog,
                                strokeWidth: 6,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  teal2,
                                ),
                                backgroundColor: Colors.white12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProgramDetailPage(
                                    program: p,
                                    lang: widget.lang,
                                  ),
                                ),
                              );
                              setState(
                                () => _completedFuture = _loadCompleted(),
                              );
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF011F1F),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            child: Text(
                              widget.lang == 'hi' ? 'खोलें' : 'Open',
                              style: const TextStyle(color: Colors.white),
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
      },
    );
  }
}

// --- ProgramDetailPage with onboarding overlay ---
// NOTE: small but important change: pass `lang` along to LessonPage so the lesson reader knows which voice/language to use.
class ProgramDetailPage extends StatefulWidget {
  final Program program;
  final String lang;
  const ProgramDetailPage({
    required this.program,
    required this.lang,
    super.key,
  });
  @override
  State<ProgramDetailPage> createState() => _ProgramDetailPageState();
}

class _ProgramDetailPageState extends State<ProgramDetailPage> {
  late SharedPreferences _prefs;
  Set<int> _completed = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCompleted();
    // show onboarding once per program per language
    final onboardKey = 'prog_${widget.program.id}_onboard_${widget.lang}';
    final shown = _prefs.getBool(onboardKey) ?? false;
    if (!shown) {
      // show after small delay so the page is visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOnboarding();
      });
      await _prefs.setBool(onboardKey, true);
    }
  }

  void _loadCompleted() {
    final key = 'prog_${widget.program.id}_completed';
    final list = _prefs.getStringList(key) ?? [];
    setState(() {
      _completed = list
          .map((s) => int.tryParse(s) ?? 0)
          .where((n) => n > 0)
          .toSet();
    });
  }

  Future<void> _toggleCompleted(int day) async {
    final key = 'prog_${widget.program.id}_completed';
    if (_completed.contains(day))
      _completed.remove(day);
    else
      _completed.add(day);
    await _prefs.setStringList(
      key,
      _completed.map((e) => e.toString()).toList(),
    );
    setState(() {});
  }

  // Onboarding overlay modal
  void _showOnboarding() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final p = widget.program;
        final isHi = widget.lang == 'hi';
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [teal6.withOpacity(0.95), teal4, teal3],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Colors.amberAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isHi
                            ? 'कार्यक्रम कैसे करें'
                            : 'How to use this program',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isHi
                      ? 'यह ${p.days}-दिन का कार्यक्रम CBT कौशलों को सरल भाषा और छोटे अभ्यासों में सिखाता है। हर दिन एक छोटा पाठ, अभ्यास और जर्नल संकेत होता है।'
                      : 'This ${p.days}-day program teaches CBT skills through small daily lessons, practices and journaling prompts that connect to Thought Record and ABCD tools.',
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 18),
                Text(
                  isHi ? 'क्या करना है' : 'What to do',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stepItem(
                      Icons.menu_book_rounded,
                      isHi
                          ? 'हर दिन एक पाठ खोलें और पढ़ें'
                          : 'Open one lesson daily and read briefly',
                    ),
                    _stepItem(
                      Icons.self_improvement,
                      isHi
                          ? 'दिए गए अभ्यास को 2–5 मिनट आज़माएँ'
                          : 'Try the short guided exercise (2–5 mins)',
                    ),
                    _stepItem(
                      Icons.edit_note_rounded,
                      isHi
                          ? 'जर्नल संकेत से Thought Record या ABCD खोलें'
                          : 'Use the journaling prompt to open Thought Record or ABCD',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  isHi ? 'त्वरित क्रियाएँ' : 'Quick actions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _glowButton(
                      label: isHi
                          ? 'Thought रिकॉर्ड खोलें'
                          : 'Open Thought Record',
                      color: teal3,
                      icon: Icons.psychology_alt_rounded,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.pushNamed(context, '/thought');
                      },
                    ),
                    _glowButton(
                      label: isHi
                          ? 'ABCD वर्कशीट खोलें'
                          : 'Open ABCD worksheet',
                      color: teal4,
                      icon: Icons.rule_rounded,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.pushNamed(context, '/abcd');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white70,
                    ),
                    label: Text(
                      isHi ? 'ठीक है, समझ गया' : 'Got it, let’s begin',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
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

  Widget _stepItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: teal2, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.9),
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        shadowColor: color.withOpacity(0.6),
      ),
    );
  }

  // NEW: lightweight preview speak for each lesson card (instantiates a short-lived FlutterTts)
  Future<void> _speakLessonPreview(Lesson lesson) async {
    final FlutterTts tts = FlutterTts();
    final locale = widget.lang == 'hi' ? 'hi-IN' : 'en-US';
    try {
      await tts.setLanguage(locale);
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      final text = _lessonPreviewText(lesson);
      // wait for completion
      await tts.awaitSpeakCompletion(true);
      await tts.speak(text);
      // speak completes and stops automatically (awaitSpeakCompletion handles completion)
    } catch (e) {
      debugPrint('TTS preview error: $e');
    } finally {
      try {
        await tts.stop();
      } catch (_) {}
    }
  }

  String _lessonPreviewText(Lesson lesson) {
    final sb = StringBuffer();
    sb.writeln('Day ${lesson.day}. ${lesson.title}.');
    sb.writeln(lesson.summary);
    return sb.toString();
  }

  Widget _lessonTile(Lesson lesson) {
    final done = _completed.contains(lesson.day);
    final bgColor = done ? completedBackground : darkBackground;
    final titleColor = done ? Colors.white : Colors.white;
    final subtitleColor = done ? Colors.white70 : Colors.white60;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0), // Add spacing between tiles
      child: Card(
        elevation: 0, // Cards often look better flat in dark/minimalist designs
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          // Optional: Add a light border for visual pop
          side: done
              ? BorderSide(color: completedAccent.withOpacity(0.4), width: 1.5)
              : BorderSide.none,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8.0,
            horizontal: 16.0,
          ),

          // 1. IMPROVEMENT: Lesson Day/Status Icon
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: done ? completedAccent : teal4,
              borderRadius: BorderRadius.circular(
                8,
              ), // Square or rounded square look
            ),
            alignment: Alignment.center,
            child: Text(
              '${lesson.day}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          // 2. IMPROVEMENT: Title and Subtitle Styling
          title: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              lesson.title,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
            ),
          ),
          subtitle: Text(
            lesson.summary,
            style: TextStyle(color: subtitleColor, fontSize: 13),
            maxLines: 2, // Ensure summary doesn't take up too much space
            overflow: TextOverflow.ellipsis,
          ),

          // 3. IMPROVEMENT: Simplified Trailing Actions
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TTS/Listen Button
              IconButton(
                tooltip: widget.lang == 'hi' ? 'पाठ सुनें' : 'Listen',
                icon: const Icon(Icons.volume_up),
                color: done
                    ? Colors.white60
                    : teal2, // Use accent color for listen
                onPressed: () async {
                  await _speakLessonPreview(lesson);
                },
              ),

              // Toggle Complete Button (Primary Status Indicator)
              IconButton(
                tooltip: done ? 'Mark as undone' : 'Mark complete',
                icon: Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 28, // Make the check icon larger
                ),
                color: done
                    ? completedAccent
                    : Colors.white38, // Stronger visual cue
                onPressed: () => _toggleCompleted(lesson.day),
              ),
            ],
          ),

          // 4. IMPROVEMENT: Main Navigation on Tap (Better UX)
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LessonPage(
                  lesson: lesson,
                  programId: widget.program.id,
                  lang: widget.lang,
                ),
              ),
            );
            _loadCompleted();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    final total = p.lessons.length;
    final completed = _completed.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final isHi = widget.lang == 'hi';

    return Scaffold(
      backgroundColor: const Color(0xFF021515),
      appBar: AppBar(title: Text(p.title), backgroundColor: teal4),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              color: const Color(0xFF011F1F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        valueColor: const AlwaysStoppedAnimation(teal2),
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.shortDescription,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${completed} of ${total} ${isHi ? 'पाठ पूर्ण' : 'lessons complete'}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  if (p.lessons.isNotEmpty)
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => LessonPage(
                                          lesson: p.lessons.first,
                                          programId: p.id,
                                          lang: widget.lang,
                                        ),
                                      ),
                                    );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teal3,
                                  // ADDED: Reduced padding to make the button more compact
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                child: Text(
                                  isHi
                                      ? 'पहला पाठ शुरू करें'
                                      : 'Start first lesson',
                                  // ADDED: Allow text to wrap onto multiple lines
                                  maxLines: 2,
                                  overflow: TextOverflow
                                      .ellipsis, // Truncate if it still doesn't fit
                                  textAlign: TextAlign
                                      .center, // Center the text if it wraps
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () async {
                                  final key = 'prog_${p.id}_completed';
                                  await _prefs.setStringList(key, []);
                                  _loadCompleted();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isHi
                                            ? 'प्रगति रीसेट'
                                            : 'Progress reset',
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: Text(isHi ? 'रीसेट' : 'Reset progress'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: p.lessons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _lessonTile(p.lessons[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- LessonPage same theme (kept compact) ---
// NOTE: added TTS controls and per-block playback support via a global lesson reader.
class LessonPage extends StatefulWidget {
  final Lesson lesson;
  final String programId;
  final String lang; // NEW: language hint for TTS
  const LessonPage({
    required this.lesson,
    required this.programId,
    required this.lang,
    super.key,
  });
  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  late SharedPreferences _prefs;
  bool _done = false;

  // TTS
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      _prefs = p;
      _loadState();
    });

    // initialize TTS
    _flutterTts = FlutterTts();
    _setupTtsHandlers();
  }

  void _setupTtsHandlers() {
    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
    _flutterTts.setCancelHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
    _flutterTts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  @override
  void dispose() {
    _stopTtsImmediate();
    try {
      _flutterTts.stop();
    } catch (_) {}
    super.dispose();
  }

  void _loadState() {
    final key = 'prog_${widget.programId}_completed';
    final list = _prefs.getStringList(key) ?? [];
    final set = list
        .map((s) => int.tryParse(s) ?? 0)
        .where((n) => n > 0)
        .toSet();
    setState(() => _done = set.contains(widget.lesson.day));
  }

  Future<void> _setDone(bool v) async {
    final key = 'prog_${widget.programId}_completed';
    final list = _prefs.getStringList(key) ?? [];
    final set = list
        .map((s) => int.tryParse(s) ?? 0)
        .where((n) => n > 0)
        .toSet();
    if (v)
      set.add(widget.lesson.day);
    else
      set.remove(widget.lesson.day);
    await _prefs.setStringList(key, set.map((e) => e.toString()).toList());
    setState(() => _done = v);
  }

  Widget _buildBlock(Block b) {
    switch (b.type) {
      case 'exercise':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF011F1F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // small per-block speak button
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.white70),
                    onPressed: () =>
                        _speakText('${b.title}. ${b.content ?? ''}'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (b.content != null)
                Text(b.content!, style: const TextStyle(color: Colors.white70)),
              if (b.durationMinutes != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF022F2F),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${b.durationMinutes} min',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),
        );
      case 'prompt':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF011F1F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.white70),
                    onPressed: () =>
                        _speakText('${b.title}. ${b.content ?? ''}'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (b.content != null)
                Text(b.content!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  final action = b.extra;
                  if (action is String) {
                    Navigator.pushNamed(context, action);
                  } else if (action is List && action.isNotEmpty) {
                    Navigator.pushNamed(context, action.first.toString());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No action configured')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal3,
                  // ADDED: Reduced horizontal padding for compactness
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                child: const Text('Open thought tool'),
              ),
            ],
          ),
        );
      case 'action':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF011F1F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.white70),
                    onPressed: () =>
                        _speakText('${b.title}. ${b.content ?? ''}'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (b.content != null)
                Text(b.content!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              if (b.extra != null)
                (b.extra is List
                    ? Wrap(
                        spacing: 8,
                        children: (b.extra as List)
                            .map<Widget>(
                              (a) => ElevatedButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, a.toString()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teal4,
                                ),
                                child: Text(a.toString()),
                              ),
                            )
                            .toList(),
                      )
                    : ElevatedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, b.extra.toString()),
                        style: ElevatedButton.styleFrom(backgroundColor: teal4),
                        child: const Text('Open'),
                      )),
            ],
          ),
        );
      case 'text':
      default:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF011F1F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.white70),
                    onPressed: () =>
                        _speakText('${b.title}. ${b.content ?? ''}'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (b.content != null)
                Text(b.content!, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        );
    }
  }

  // Build the full lesson text to read
  String _fullLessonText() {
    final l = widget.lesson;
    final sb = StringBuffer();
    sb.writeln('Day ${l.day}. ${l.title}.');
    sb.writeln(l.summary);
    for (final b in l.blocks) {
      sb.writeln(b.title);
      if (b.content != null && b.content!.trim().isNotEmpty) {
        sb.writeln(b.content);
      }
    }
    return sb.toString();
  }

  // Speak helpers
  Future<void> _speakText(String text) async {
    if (text.trim().isEmpty) return;
    try {
      final locale = widget.lang == 'hi' ? 'hi-IN' : 'en-US';
      await _flutterTts.setLanguage(locale);
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.speak(text);
      setState(() {
        _isSpeaking = true;
      });
    } catch (e) {
      debugPrint('TTS speak error: $e');
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  Future<void> _stopTtsImmediate() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
    setState(() {
      _isSpeaking = false;
    });
  }

  // toggle speak full lesson
  Future<void> _toggleSpeakFullLesson() async {
    if (_isSpeaking) {
      await _stopTtsImmediate();
    } else {
      final full = _fullLessonText();
      await _speakText(full);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    return Scaffold(
      backgroundColor: const Color(0xFF021515),
      appBar: AppBar(
        title: Text('Day ${l.day} • ${l.title}'),
        backgroundColor: teal4,
        actions: [
          IconButton(
            icon: Icon(
              _done ? Icons.check_circle : Icons.radio_button_unchecked,
            ),
            onPressed: () => _setDone(!_done),
            color: Colors.white,
          ),
          // NEW: main lesson TTS button in app bar
          IconButton(
            tooltip: _isSpeaking ? 'Stop reading' : 'Read lesson aloud',
            icon: Icon(
              _isSpeaking ? Icons.stop : Icons.volume_up,
              color: Colors.white,
            ),
            onPressed: _toggleSpeakFullLesson,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              color: const Color(0xFF011F1F),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.summary,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF022F2F),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${l.minutes} min',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: l.blocks.map(_buildBlock).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _done ? null : () => _setDone(true),
                    style: ElevatedButton.styleFrom(backgroundColor: teal3),
                    child: const Text('Mark lesson complete'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _setDone(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white12),
                  ),
                  child: const Text('Mark undone'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
