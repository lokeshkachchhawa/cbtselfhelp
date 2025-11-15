import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// ======= ENHANCED THEME =======
const Color teal1 = Color.fromARGB(255, 1, 108, 108);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);
const Color successGreen = Color(0xFF10B981);
const Color errorRed = Color(0xFFEF4444);
const Color warningAmber = Color(0xFFF59E0B);
const String kRandomCategoryTitle = "Random Mix (100)";

// ======= SHORT TUTORIALS (per category) =======
const Map<String, List<String>> kCategoryTutorials = {
  "Mind Reading": [
    "🔎 Summary: बिना पूछे मान लेना कि लोग क्या सोच रहे हैं।",
    "आप बिना proof के assume कर लेते हैं कि लोग आपके बारे में negative सोच रहे हैं।",
    "कैसे पकड़ें: “They must think…”, “सब मुझे judge कर रहे हैं।” जैसी बातें।",
    "उदाहरण: कॉन्फ़्रेंस में लोग फ़ोन देख रहे हैं → आप सोचते हैं कि वे आपको boring समझ रहे हैं।",
    "क्या करें: सोच का सबूत ढूँढें, शांत मन से पूछकर clarify कर सकते हैं।",
  ],

  "Overgeneralisation": [
    "🔎 Summary: एक घटना से पूरी life का निष्कर्ष निकालना।",
    "आप एक ही चीज़ से हमेशा/कभी नहीं वाला conclusion बना लेते हैं।",
    "कैसे पकड़ें: ‘कभी नहीं’, ‘हमेशा’, ‘सब’, ‘कोई नहीं’ जैसे शब्द।",
    "उदाहरण: एक exam खराब होने पर सोचना— “मैं कभी अच्छा नहीं कर सकता।”",
    "क्या करें: Specific सोचें, हर situation अलग होती है।",
  ],

  "Personalisation": [
    "🔎 Summary: हर बात की responsibility अपने ऊपर ले लेना।",
    "आप ऐसी चीज़ों के लिए भी खुद को blame करते हैं जिन पर आपका control नहीं।",
    "कैसे पकड़ें: “मेरी वजह से…”, “It’s my fault…”",
    "उदाहरण: दोस्तों का मूड खराब है → आप सोचते हैं कि आपने कुछ गलत किया।",
    "क्या करें: Other possible reasons भी विचार करें।",
  ],

  "Permanent Thinking": [
    "🔎 Summary: Current problem को हमेशा का truth मान लेना।",
    "आप सोचते हैं कि चीज़ें बदलेंगी ही नहीं।",
    "कैसे पकड़ें: “हमेशा”, “कभी नहीं होगा।”",
    "उदाहरण: नौकरी नहीं मिली → सोचना कि अब कभी नहीं मिलेगी।",
    "क्या करें: याद रखें, समय और कोशिश से बहुत कुछ बदलता है।",
  ],

  "Pervasive Thinking": [
    "🔎 Summary: एक problem → पूरा life खराब मान लेना।",
    "आप किसी एक area की परेशानी को पूरे जीवन पर लागू कर देते हैं।",
    "कैसे पकड़ें: “सब खराब है”, “Life खत्म।”",
    "उदाहरण: Interview खराब → लगना कि पूरी life बिगड़ गई।",
    "क्या करें: Identify करें— problem किस area में है; बाकी areas ठीक हैं।",
  ],

  "Magical Thinking": [
    "🔎 Summary: बिना connection वाली चीज़ों को result से जोड़ना।",
    "आप believe करते हैं कि lucky चीज़ें result बदल देती हैं।",
    "कैसे पकड़ें: lucky number, ring, ritual से outcome बदलने का विश्वास।",
    "उदाहरण: Interview में success lucky shirt पहनने से होगी।",
    "क्या करें: छोटे test करें— ritual न करने पर भी result बदलता नहीं।",
  ],

  "Emotional Reasoning": [
    "🔎 Summary: Feelings = Fact मान लेना।",
    "आप जो महसूस करते हैं, उसे truth मान लेते हैं।",
    "कैसे पकड़ें: “मुझे डर लग रहा है → मैं खतरे में हूँ।”",
    "उदाहरण: Nervous होकर सोचना कि लोग judge कर रहे हैं।",
    "क्या करें: Feeling और real situation को अलग-अलग देखें।",
  ],

  "Labeling": [
    "🔎 Summary: एक गलती से खुद या दूसरों को global टैग दे देना।",
    "आप behavior की जगह पूरी identity को negative label देते हैं।",
    "कैसे पकड़ें: “मैं बेकार हूँ”, “वो बुरा इंसान है।”",
    "उदाहरण: Presentation खराब → “मैं useless हूँ।”",
    "क्या करें: व्यक्ति नहीं— behavior को describe करें।",
  ],

  "All-or-None Thinking": [
    "🔎 Summary: चीज़ों को 100% या 0% में देखना — बीच नहीं।",
    "आप सोचते हैं— Perfect नहीं → Fail।",
    "कैसे पकड़ें: “अगर पूरी तरह नहीं हुआ → कुछ नहीं।”",
    "उदाहरण: Diet एक दिन टूट गई → “अब सब बेकार।”",
    "क्या करें: Middle progress देखें— थोड़ा भी gain important है।",
  ],

  "Disqualifying the Positive": [
    "🔎 Summary: अच्छाइयों को ignore करना या luck कहना।",
    "आप positive feedback को serious नहीं लेते।",
    "कैसे पकड़ें: “They’re just being nice…”, “बस किस्मत।”",
    "उदाहरण: Compliment मिलने पर कहना— “वो बस formal बोल रहे थे।”",
    "क्या करें: सोचें— आपकी मेहनत ने कैसे help किया।",
  ],
  "Random Mix (100)": [
    "🔎 Summary: सभी categories से 100 random questions—हर बार नया mix।",
    "यह mode आपकी real-world पहचान की तरह unpredictable practice देता है।",
    "कैसे पकड़ें: बिना pattern देखे concept पहचानने की आदत डालें।",
    "उदाहरण: Mind Reading, Labeling, Magical Thinking — सब random order में।",
    "क्या करें: हर question पर पहले category पहचानें, फिर explanation पढ़कर सीख मजबूत करें।",
  ],
};

List<String> kDistortionLabels = [
  "Mind reading",
  "Overgeneralisation",
  "Personalisation",
  "Permanent Thinking",
  "Pervasive Thinking",
  "Magical Thinking",
  "Emotional Reasoning",
  "Labeling",
  "All-or-None Thinking",
  "Disqualifying the Positive",
];

// Enhanced icon mapping for categories
Map<String, IconData> categoryIcons = {
  "Mind reading": Icons.psychology_outlined,
  "Overgeneralisation": Icons.scatter_plot_outlined,
  "Personalisation": Icons.person_outline,
  "Permanent Thinking": Icons.all_inclusive,
  "Pervasive Thinking": Icons.bubble_chart_outlined,
  "Magical Thinking": Icons.auto_fix_high,
  "Emotional Reasoning": Icons.favorite_border,
  "Labeling": Icons.label_outline,
  "All-or-None Thinking": Icons.toggle_off_outlined,
  "Disqualifying the Positive": Icons.highlight_off_outlined,
  "Random Mix (100)": Icons.shuffle,
};

// === per-category color palette (place near categoryIcons) ===
final Map<String, Color> categoryColors = {
  "Mind Reading": Color(0xFF6C5CE7), // purple
  "Overgeneralisation": Color.fromARGB(255, 240, 232, 0), // mint green
  "Personalisation": Color(0xFF0984E3), // bright blue
  "Permanent Thinking": Color(0xFFFD79A8), // pink
  "Pervasive Thinking": Color(0xFFF6C85F), // warm yellow
  "Magical Thinking": Color(0xFFAA00FF), // vivid violet
  "Emotional Reasoning": Color(0xFFFE7F2D), // orange
  "Labeling": Color(0xFF00CED1), // turquoise
  "All-or-None Thinking": Color(0xFF2D9CDB), // soft azure
  "Disqualifying the Positive": Color(0xFFEF476F),
  "Random Mix (100)": Color(0xFF4CAF50), // green
};

List<String> buildOptions(String correct) {
  final others = kDistortionLabels.where((e) => e != correct).toList()
    ..shuffle();
  final opts = [correct, ...others.take(3)];
  opts.shuffle();
  return opts;
}

void showCategoryTutorial(BuildContext context, String title) {
  final bulletPoints =
      kCategoryTutorials[title] ??
      const ["What it is.", "How to spot it.", "Try this practice."];

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF032020),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    isScrollControlled: true,
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: teal2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$title — Quick Tutorial",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...bulletPoints.map(
              (b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "•  ",
                      style: TextStyle(color: teal2, fontSize: 16),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.38,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal3,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text("Got it"),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ======= DATA MODEL =======
class CBTQuestion {
  final String id;
  final String text;
  final List<String> answers;
  final String explanation;

  CBTQuestion({
    required this.id,
    required this.text,
    required this.answers,
    required this.explanation,
  });

  factory CBTQuestion.fromJson(Map<String, dynamic> json) => CBTQuestion(
    id: json["id"],
    text: json["text"],
    answers: List<String>.from(json["answers"]),
    explanation: json["explanation"],
  );
}

class CBTCategory {
  final String title;
  final List<CBTQuestion> questions;
  final String? icon;

  CBTCategory({required this.title, required this.questions, this.icon});
}

// ======= MAIN SCREEN WITH ENHANCED UI =======
class CBTGameScreen extends StatefulWidget {
  const CBTGameScreen({Key? key}) : super(key: key);

  @override
  State<CBTGameScreen> createState() => _CBTGameScreenState();
}

class _CBTGameScreenState extends State<CBTGameScreen>
    with TickerProviderStateMixin {
  List<CBTCategory> categories = [];
  bool loaded = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<String> labels = [
    "Mind Reading",
    "Overgeneralisation",
    "Personalisation",
    "Permanent Thinking",
    "Pervasive Thinking",
    "Magical Thinking",
    "Emotional Reasoning",
    "Labeling",
    "All-or-None Thinking",
    "Disqualifying the Positive",
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    loadJson();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> loadJson() async {
    String raw = await rootBundle.loadString(
      "assets/data/thought_detective_questions.json",
    );
    final List<dynamic> data = json.decode(raw);

    // Build the regular 10 categories (10 each)
    final List<CBTCategory> temp = [];
    for (int i = 0; i < 10; i++) {
      final subset = data.skip(i * 10).take(10).toList();
      temp.add(
        CBTCategory(
          title: labels[i],
          questions: subset
              .map((e) => CBTQuestion.fromJson(e as Map<String, dynamic>))
              .toList(),
          icon: null,
        ),
      );
    }

    // ----- NEW: Random Mix (100) -----
    final List<dynamic> all = List<dynamic>.from(data);
    all.shuffle(); // randomize order every load
    final int takeCount = all.length >= 100 ? 100 : all.length;

    final CBTCategory randomCategory = CBTCategory(
      title: kRandomCategoryTitle,
      questions: all
          .take(takeCount)
          .map((e) => CBTQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    // You can choose position (first card or last card):
    // put first:
    // temp.insert(0, randomCategory);
    // or put last:
    temp.add(randomCategory);

    setState(() {
      categories = temp;
      loaded = true;
    });
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: teal6,
      appBar: AppBar(
        title: const Text('Thought Detactive'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [teal6, teal4],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: loaded
          ? FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Header section with stats
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color.fromARGB(255, 7, 123, 111),
                          const Color.fromARGB(255, 1, 25, 21),
                          const Color.fromARGB(255, 2, 55, 47),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Choose a Cognitive Distortion",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${categories.length} categories • ${categories.fold<int>(0, (sum, c) => sum + c.questions.length)} total questions",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Grid view
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        itemCount: categories.length,
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.88,
                            ),
                        itemBuilder: (_, i) {
                          final c = categories[i];
                          return _CategoryCard(
                            category: c,
                            index: i,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CBTQuizPage(category: c),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: teal2, strokeWidth: 3),
                  const SizedBox(height: 20),
                  Text(
                    "Loading questions...",
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
    );
  }
}

// ======= ANIMATED CATEGORY CARD =======
class _CategoryCard extends StatefulWidget {
  final CBTCategory category;
  final int index;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.index,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = categoryIcons[widget.category.title] ?? Icons.psychology_alt;
    final Color baseColor =
        categoryColors[widget.category.title] ?? teal3; // fallback
    final Color iconColor = Colors.white;
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        Future.delayed(const Duration(milliseconds: 150), widget.onTap);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPressed ? [teal3, teal5] : [teal4, teal6],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with animated background
              // --- Modern per-category icon (replace previous Container) ---
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      baseColor.withOpacity(0.22),
                      baseColor.withOpacity(0.10),
                    ],
                    center: Alignment(0.0, 0.0),
                    radius: 0.9,
                  ),
                  boxShadow: [
                    // gentle colored glow
                    BoxShadow(
                      color: baseColor,
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                    // subtle elevation shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: baseColor.withOpacity(0.18),
                    width: 1.5,
                  ),
                ),
                child: Center(child: Icon(icon, color: iconColor, size: 28)),
              ),

              const SizedBox(height: 10),

              // Title
              // --- FIXED TITLE + PILL (PREVENT OVERFLOW) ---
              Column(
                mainAxisSize: MainAxisSize.min, // <<< ADD THIS ONE LINE
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title (max 2 lines always)
                  Text(
                    widget.category.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 5),

                  // Question Count Pill (never pushes or gets pushed)
                  FittedBox(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(
                          255,
                          0,
                          135,
                          47,
                        ).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: teal2.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "${widget.category.questions.length} Questions",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
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
    );
  }
}

// ======= ENHANCED QUIZ PAGE =======
class CBTQuizPage extends StatefulWidget {
  final CBTCategory category;
  const CBTQuizPage({Key? key, required this.category}) : super(key: key);

  @override
  State<CBTQuizPage> createState() => _CBTQuizPageState();
}

class _CBTQuizPageState extends State<CBTQuizPage>
    with TickerProviderStateMixin {
  int index = 0;
  int score = 0;
  String? selected;
  bool locked = false;
  late List<String> options;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    options = _makeOptionsFor(index);
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  List<String> _makeOptionsFor(int i) {
    final q = widget.category.questions[i];
    final correct = q.answers.first;
    return buildOptions(correct);
  }

  void _next() {
    final last = index + 1 == widget.category.questions.length;
    if (last) {
      final percent = (score / widget.category.questions.length) * 100.0;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CBTScorePage(
            category: widget.category,
            percent: percent,
            score: score,
            totalQuestions: widget.category.questions.length,
          ),
        ),
      );
    } else {
      _slideController.reset();
      setState(() {
        index++;
        locked = false;
        selected = null;
        options = _makeOptionsFor(index);
      });
      _slideController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.category.questions[index];
    final correct = q.answers.first;
    final progress = (index + 1) / widget.category.questions.length;

    return Scaffold(
      backgroundColor: teal6,
      appBar: AppBar(
        title: Text(
          widget.category.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: teal3,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Tutorial",
            icon: const Icon(Icons.help_outline),
            onPressed: () =>
                showCategoryTutorial(context, widget.category.title),
          ),
        ],
      ),

      body: Column(
        children: [
          // Enhanced progress header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [teal3, teal4],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Question ${index + 1}/${widget.category.questions.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: warningAmber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "Score: $score",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: progress),
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(teal2),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Question card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [teal5.withOpacity(0.6), teal6],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: teal3.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "QUESTION",
                                  style: TextStyle(
                                    color: teal2,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            q.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Options label
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        "Select the cognitive distortion:",
                        style: TextStyle(
                          color: teal2,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Options
                    ...options.asMap().entries.map((entry) {
                      final opt = entry.value;
                      final isCorrect = opt == correct;
                      final isSelected = selected == opt;

                      return _OptionCard(
                        option: opt,
                        isCorrect: isCorrect,
                        isSelected: isSelected,
                        locked: locked,
                        onTap: locked
                            ? null
                            : () {
                                setState(() {
                                  selected = opt;
                                  locked = true;
                                  if (isCorrect) score++;
                                });
                              },
                      );
                    }).toList(),

                    const SizedBox(height: 16),

                    // Explanation
                    if (locked)
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        tween: Tween(begin: 0, end: 1),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: (0.9 + (value * 0.1)).clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: (selected == correct)
                                  ? [
                                      successGreen.withOpacity(0.15),
                                      successGreen.withOpacity(0.08),
                                    ]
                                  : [
                                      errorRed.withOpacity(0.15),
                                      errorRed.withOpacity(0.08),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (selected == correct)
                                  ? successGreen.withOpacity(0.5)
                                  : errorRed.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    (selected == correct)
                                        ? Icons.check_circle
                                        : Icons.info_outline,
                                    color: (selected == correct)
                                        ? successGreen
                                        : errorRed,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (selected == correct)
                                        ? "Correct Answer!"
                                        : "Correct Answer: $correct",
                                    style: TextStyle(
                                      color: (selected == correct)
                                          ? successGreen
                                          : errorRed,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                q.explanation,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Next button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: locked
                              ? teal3
                              : teal5.withOpacity(0.5),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: locked ? 4 : 0,
                          shadowColor: Colors.black38,
                        ),
                        onPressed: locked ? _next : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              index + 1 == widget.category.questions.length
                                  ? "Finish Quiz"
                                  : "Next Question",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (locked) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 20),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======= OPTION CARD WIDGET =======
class _OptionCard extends StatefulWidget {
  final String option;
  final bool isCorrect;
  final bool isSelected;
  final bool locked;
  final VoidCallback? onTap;

  const _OptionCard({
    required this.option,
    required this.isCorrect,
    required this.isSelected,
    required this.locked,
    this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bg = teal5;
    Color borderColor = Colors.white.withOpacity(0.1);
    IconData iconData = Icons.circle_outlined;

    if (widget.locked) {
      if (widget.isCorrect) {
        bg = successGreen;
        borderColor = successGreen;
        iconData = Icons.check_circle;
      } else if (widget.isSelected && !widget.isCorrect) {
        bg = errorRed;
        borderColor = errorRed;
        iconData = Icons.cancel;
      }
    } else if (widget.isSelected) {
      bg = teal4;
      borderColor = teal2;
    }

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(iconData, color: Colors.white, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.option,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======= ENHANCED SCORE PAGE =======
class CBTScorePage extends StatefulWidget {
  final double percent;
  final int score;
  final int totalQuestions;
  final CBTCategory category;

  const CBTScorePage({
    Key? key,
    required this.percent,
    required this.score,
    required this.totalQuestions,
    required this.category,
  }) : super(key: key);

  @override
  State<CBTScorePage> createState() => _CBTScorePageState();
}

class _CBTScorePageState extends State<CBTScorePage>
    with TickerProviderStateMixin {
  late ConfettiController confetti;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    confetti = ConfettiController(duration: const Duration(seconds: 4));
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Trigger confetti and fade-in
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        confetti.play();
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    confetti.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String get feedback {
    if (widget.percent >= 90) return "Outstanding! 🎉";
    if (widget.percent >= 75) return "Great job! 🌟";
    if (widget.percent >= 50) return "Good effort! Keep improving 💪";
    return "Keep practicing — You can do better 💚";
  }

  String get encouragement {
    if (widget.percent >= 90) {
      return "You've mastered this cognitive distortion! Your understanding is exceptional.";
    } else if (widget.percent >= 75) {
      return "You have a solid grasp of this concept. Keep practicing to maintain your skills.";
    } else if (widget.percent >= 50) {
      return "You're on the right track. Review the explanations and try again to improve.";
    } else {
      return "Don't worry! Learning takes time. Review the material and practice more.";
    }
  }

  Color get scoreColor {
    if (widget.percent >= 90) return successGreen;
    if (widget.percent >= 75) return teal2;
    if (widget.percent >= 50) return warningAmber;
    return errorRed;
  }

  IconData get scoreIcon {
    if (widget.percent >= 90) return Icons.emoji_events;
    if (widget.percent >= 75) return Icons.thumb_up;
    if (widget.percent >= 50) return Icons.trending_up;
    return Icons.refresh;
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.percent / 100;

    return Scaffold(
      backgroundColor: teal6,
      appBar: AppBar(
        backgroundColor: teal3,
        elevation: 0,
        title: const Text(
          "Quiz Complete!",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Confetti
          ConfettiWidget(
            confettiController: confetti,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.03,
            numberOfParticles: 25,
            colors: const [
              successGreen,
              teal2,
              warningAmber,
              Colors.white,
              teal3,
            ],
          ),

          // Main content
          FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Score icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scoreColor.withOpacity(0.5),
                        width: 3,
                      ),
                    ),
                    child: Icon(scoreIcon, color: scoreColor, size: 40),
                  ),

                  const SizedBox(height: 24),

                  // Category name
                  Text(
                    widget.category.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Quiz Results",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Circular percentage display
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: pct),
                    builder: (context, value, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 180,
                            width: 180,
                            child: CircularProgressIndicator(
                              value: value,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              strokeWidth: 12,
                              strokeCap: StrokeCap.round,
                              valueColor: AlwaysStoppedAnimation(scoreColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${(value * 100).toStringAsFixed(0)}%",
                                style: const TextStyle(
                                  fontSize: 42,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Accuracy",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Score details card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Score breakdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ScoreStat(
                              icon: Icons.check_circle,
                              label: "Correct",
                              value: "${widget.score}",
                              color: successGreen,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            _ScoreStat(
                              icon: Icons.cancel,
                              label: "Wrong",
                              value: "${widget.totalQuestions - widget.score}",
                              color: errorRed,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            _ScoreStat(
                              icon: Icons.quiz,
                              label: "Total",
                              value: "${widget.totalQuestions}",
                              color: teal2,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        Divider(
                          color: Colors.white.withOpacity(0.2),
                          thickness: 1,
                        ),
                        const SizedBox(height: 20),

                        // Feedback message
                        Text(
                          feedback,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          encouragement,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Performance insight
                  if (widget.percent < 100)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: teal3.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: teal3.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: warningAmber,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Tip: Review the explanations for questions you missed to improve your understanding.",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.home, size: 20),
                          label: const Text(
                            "Home",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: teal3,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(52),
                            elevation: 4,
                            shadowColor: Colors.black38,
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CBTQuizPage(category: widget.category),
                              ),
                            );
                          },
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text(
                            "Retry",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======= SCORE STAT WIDGET =======
class _ScoreStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ScoreStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
