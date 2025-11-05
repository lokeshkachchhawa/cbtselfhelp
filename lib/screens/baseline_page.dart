import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Dark teal palette (use your shared constants if you already have them) ---
const Color teal1 = Color.fromARGB(255, 1, 108, 108); // #016C6C
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);
const Color surfaceDark = Color(0xFF021515);

enum AppLang { en, hi }

class BaselinePage extends StatefulWidget {
  const BaselinePage({super.key});

  @override
  State<BaselinePage> createState() => _BaselinePageState();
}

class _BaselinePageState extends State<BaselinePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late final PageController _pageCtrl;

  // language + prefs
  AppLang _lang = AppLang.en;
  late SharedPreferences _prefs;

  // answers (0..3) for each of 9 questions
  final List<int?> _answers = List<int?>.filled(9, null);

  // ui state
  int _currentIndex = 0;
  bool _submitting = false;
  String? _error;

  static const int HIGH_SCORE_THRESHOLD = 20;
  static const int Q9_RISK_MIN = 1;

  // ------------------- Text: EN / HI -------------------
  List<String> get _qEN => const [
    'Little interest or pleasure in doing things',
    'Feeling down, depressed, or hopeless',
    'Trouble falling or staying asleep, or sleeping too much',
    'Feeling tired or having little energy',
    'Poor appetite or overeating',
    'Feeling bad about yourself — or that you are a failure or have let yourself or your family down',
    'Trouble concentrating on things, such as reading the newspaper or watching television',
    'Moving or speaking so slowly that other people could have noticed? Or the opposite — being so fidgety or restless that you have been moving a lot more than usual',
    'Thoughts that you would be better off dead or of hurting yourself in some way',
  ];

  List<String> get _qHI => const [
    'कामों में रुचि/आनंद कम होना',
    'मन उदास/निराश/हतोत्साहित रहना',
    'नींद आने/बने रहने में दिक्कत या बहुत अधिक सोना',
    'थकान महसूस होना या ऊर्जा कम रहना',
    'भूख कम लगना या ज़्यादा खाना',
    'अपने बारे में बुरा महसूस करना — जैसे कि आप असफल हैं या परिवार को निराश कर रहे हैं',
    'ध्यान लगाने में दिक्कत (जैसे पढ़ते/टीवी देखते समय)',
    'धीरे चलना/बोलना जिसे लोग नोटिस कर लें — या इसके उलट, बहुत बेचैनी/घबराहट के कारण सामान्य से ज़्यादा चलना-फिरना',
    'ऐसे विचार कि काश आप नहीं होते या अपने आप को चोट पहुँचाने के विचार',
  ];

  List<String> get _optsEN => const [
    'Not at all', // 0
    'Several days', // 1
    'More than half the days', // 2
    'Nearly every day', // 3
  ];

  List<String> get _optsHI => const [
    'बिल्कुल नहीं',
    'कुछ दिनों तक',
    'आधे से ज़्यादा दिनों तक',
    'लगभग हर दिन',
  ];

  List<String> get _Q => _lang == AppLang.en ? _qEN : _qHI;
  List<String> get _OPT => _lang == AppLang.en ? _optsEN : _optsHI;

  // ------------------- Lifecycle -------------------
  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _initPrefsThenMaybeShowIntro();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _initPrefsThenMaybeShowIntro() async {
    _prefs = await SharedPreferences.getInstance();

    // restore saved language (optional)
    final savedLang = _prefs.getString('preferred_lang');
    if (savedLang == 'hi')
      _lang = AppLang.hi;
    else if (savedLang == 'en')
      _lang = AppLang.en;

    // show intro only if not seen or user tapped from quick sheet
    final seen = _prefs.getBool('baseline_intro_seen_v1') ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!seen) _showIntroDialog();
      setState(() {}); // refresh after language restore
    });
  }

  // ------------------- Intro dialog with language selector -------------------
  Future<void> _showIntroDialog() async {
    bool dontShowAgain = true;
    AppLang tempLang = _lang;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [surfaceDark, surfaceDark.withOpacity(0.95)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with animated icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [teal6, teal3],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: teal6.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.psychology_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _lang == AppLang.en
                              ? 'PHQ-9 Baseline Check'
                              : 'PHQ-9 प्रारंभिक जाँच',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _lang == AppLang.en
                                ? 'This 9-question screening helps us understand your mood over the last 2 weeks. It is not a diagnosis.'
                                : 'यह 9-प्रश्नीय स्क्रीनिंग पिछले 2 हफ्तों के आपके मूड को समझने में मदद करती है। यह निदान नहीं है।',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Language selector
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language_rounded,
                              color: Colors.white.withOpacity(0.7),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _lang == AppLang.en
                                  ? 'Choose language'
                                  : 'भाषा चुनें',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildLanguageOption(
                                'English',
                                '🇬🇧',
                                tempLang == AppLang.en,
                                () {
                                  setDialogState(() {
                                    tempLang = AppLang.en;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildLanguageOption(
                                'हिंदी',
                                '🇮🇳',
                                tempLang == AppLang.hi,
                                () {
                                  setDialogState(() {
                                    tempLang = AppLang.hi;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Don't show again checkbox
                  InkWell(
                    onTap: () {
                      setDialogState(() {
                        dontShowAgain = !dontShowAgain;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: dontShowAgain ? teal3 : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: dontShowAgain
                                    ? teal3
                                    : Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: dontShowAgain
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _lang == AppLang.en
                                  ? "Don't show again"
                                  : 'फिर से न दिखाएँ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.7),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _lang == AppLang.en ? 'Skip for now' : 'अभी छोड़ें',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            // persist language + intro flag
                            _lang = tempLang;
                            await _prefs.setString(
                              'preferred_lang',
                              _lang == AppLang.en ? 'en' : 'hi',
                            );
                            if (dontShowAgain) {
                              await _prefs.setBool(
                                'baseline_intro_seen_v1',
                                true,
                              );
                            }

                            final uid = _auth.currentUser?.uid;
                            if (uid != null) {
                              await _firestore
                                  .collection('users')
                                  .doc(uid)
                                  .set({
                                    'preferredLang': _lang == AppLang.en
                                        ? 'en'
                                        : 'hi',
                                    'baselineIntroSeen': true,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                            }
                            if (mounted) setState(() {});
                            if (context.mounted) Navigator.of(ctx).pop();
                          },
                          style:
                              ElevatedButton.styleFrom(
                                backgroundColor: teal3,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                shadowColor: teal3.withOpacity(0.5),
                              ).copyWith(
                                backgroundColor:
                                    MaterialStateProperty.resolveWith<Color>((
                                      Set<MaterialState> states,
                                    ) {
                                      if (states.contains(
                                        MaterialState.pressed,
                                      )) {
                                        return teal6;
                                      }
                                      return teal3;
                                    }),
                              ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _lang == AppLang.en ? 'Start' : 'शुरू करें',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
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
      ),
    );
  }

  Widget _buildLanguageOption(
    String label,
    String flag,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? teal3.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? teal3 : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, color: teal3, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------- Score helpers -------------------
  int get _totalScore => _answers.fold<int>(0, (p, a) => p + (a ?? 0));
  int get _answeredCount => _answers.where((a) => a != null).length;

  Color _scoreColor(int score) {
    if (score >= 20) return Colors.redAccent.shade200;
    if (score >= 15) return Colors.orangeAccent.shade200;
    if (score >= 10) return Colors.amber.shade300;
    if (score >= 5) return Colors.lightBlueAccent.shade200;
    return Colors.greenAccent.shade200;
  }

  // ------------------- Submit -------------------
  Future<void> _submit() async {
    if (_answers.any((a) => a == null)) {
      setState(
        () => _error = _lang == AppLang.en
            ? 'Please answer all questions before submitting.'
            : 'सब प्रश्न उत्तर दें, फिर सबमिट करें।',
      );
      final firstUnanswered = _answers.indexWhere((a) => a == null);
      if (firstUnanswered != -1) {
        _pageCtrl.animateToPage(
          firstUnanswered,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('Not authenticated');

      final score = _totalScore;
      final q9Value = _answers[8] ?? 0;

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('assessments')
          .doc()
          .set({
            'type': 'PHQ9',
            'answers': _answers.map((e) => e ?? 0).toList(),
            'score': score,
            'lang': _lang == AppLang.en ? 'en' : 'hi',
            'createdAt': FieldValue.serverTimestamp(),
          });

      await _firestore.collection('users').doc(uid).set({
        'baselineCompleted': true,
        'baselineAt': FieldValue.serverTimestamp(),
        'lastBaselineScore': score,
        'preferredLang': _lang == AppLang.en ? 'en' : 'hi',
      }, SetOptions(merge: true));

      if (q9Value >= Q9_RISK_MIN || score >= HIGH_SCORE_THRESHOLD) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/safety',
          arguments: {'reason': 'phq9_risk', 'score': score},
        );
        return;
      }

      // ...
      if (!mounted) return;
      // take user to paywall immediately after baseline completion
      Navigator.pushReplacementNamed(context, '/paywall');
      // or, if you want to clear history so back doesn't return here:
      // Navigator.pushNamedAndRemoveUntil(context, '/paywall', (route) => false);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _lang == AppLang.en
              ? 'Failed to submit. Try again.'
              : 'सबमिट करने में समस्या। फिर प्रयास करें।',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ------------------- Per-option tap -------------------
  Future<void> _onSelect(int qIndex, int optIndex) async {
    setState(() {
      _answers[qIndex] = optIndex;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 100));
    final isLast = qIndex == _Q.length - 1;
    if (isLast) return; // no auto-submit; show submit button on last slide

    if (!mounted) return;
    _pageCtrl.animateToPage(
      qIndex + 1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  // ------------------- UI building -------------------
  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: teal5.withOpacity(0.6),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white10),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );

  Widget _buildOption({
    required bool selected,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: _submitting ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? teal6.withOpacity(0.45)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? teal3 : Colors.white10,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? teal3 : Colors.white30,
                  width: 2,
                ),
                color: selected ? teal3 : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.circle, size: 10, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.white.withOpacity(selected ? 0.98 : 0.86),
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionSlide(int index) {
    final q = _Q[index];
    final selected = _answers[index];
    final isLast = index == _Q.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _chip(
                '${_lang == AppLang.en ? 'Question' : 'प्रश्न'} ${index + 1} / ${_Q.length}',
              ),
              const Spacer(),
              if (selected != null)
                const Icon(Icons.check_circle, color: Colors.white54, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            q,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              height: 1.35,
              color: Colors.white,
            ),
          ),
          if (isLast) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.priority_high,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lang == AppLang.en
                          ? 'Critical question — if these thoughts are present, please reach out for help.'
                          : 'महत्वपूर्ण प्रश्न — यदि ऐसे विचार आ रहे हों, कृपया सहायता लें।',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          ...List.generate(_OPT.length, (i) {
            final isSelected = selected == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildOption(
                selected: isSelected,
                label: _OPT[i],
                onTap: () => _onSelect(index, i),
              ),
            );
          }),
          const Spacer(),
          Row(
            children: [
              Text(
                '${_lang == AppLang.en ? 'Answered' : 'उत्तर दिए'}: $_answeredCount / ${_Q.length}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const Spacer(),
              if (_currentIndex > 0)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  onPressed: _submitting
                      ? null
                      : () => _pageCtrl.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                  icon: const Icon(Icons.chevron_left),
                  label: Text(_lang == AppLang.en ? 'Back' : 'पीछे'),
                ),
              const SizedBox(width: 4),
              if (_currentIndex < _Q.length - 1)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: selected == null
                        ? Colors.white24
                        : Colors.white,
                  ),
                  onPressed: (selected == null || _submitting)
                      ? null
                      : () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                  icon: const Icon(Icons.chevron_right),
                  label: Text(_lang == AppLang.en ? 'Next' : 'आगे'),
                ),
            ],
          ),
          if (isLast) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (selected == null || _submitting) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal3,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.white10,
                ),
                icon: const Icon(Icons.check),
                label: Text(
                  _lang == AppLang.en
                      ? 'Submit Assessment'
                      : 'मूल्यांकन सबमिट करें',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / _Q.length;
    final score = _totalScore;
    final scoreC = _scoreColor(score);

    return Scaffold(
      backgroundColor: surfaceDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: teal6,
        title: Text(
          _lang == AppLang.en
              ? 'Mental Health Assessment'
              : 'मानसिक स्वास्थ्य आकलन',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: SizedBox(
            height: 8,
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(teal2),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<AppLang>(
              initialValue: _lang,
              color: surfaceDark,
              icon: const Icon(Icons.language, color: Colors.white),
              onSelected: (val) async {
                setState(() => _lang = val);
                await _prefs.setString(
                  'preferred_lang',
                  _lang == AppLang.en ? 'en' : 'hi',
                );
                final uid = _auth.currentUser?.uid;
                if (uid != null) {
                  await _firestore.collection('users').doc(uid).set({
                    'preferredLang': _lang == AppLang.en ? 'en' : 'hi',
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: AppLang.en,
                  child: const Text(
                    'English',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                PopupMenuItem(
                  value: AppLang.hi,
                  child: const Text(
                    'हिंदी',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  '${_lang == AppLang.en ? 'Score' : 'स्कोर'}: $score',
                  style: TextStyle(color: scoreC, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              physics: const ClampingScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemCount: _Q.length,
              itemBuilder: (_, i) => _buildQuestionSlide(i),
            ),
            if (_submitting)
              Container(
                color: Colors.black.withOpacity(0.2),
                child: const Center(
                  child: SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: (_error == null)
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                border: Border(
                  top: BorderSide(color: Colors.red.withOpacity(0.25)),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
