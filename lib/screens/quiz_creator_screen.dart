import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Use your shared theme if you have one.
// Keeping your teal theme consistent with DoctorHome:
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color pageBg = Color(0xFF021515);

enum QuizType {
  thoughtDetective, // Cognitive distortions (Mind Reading, etc.)
  other, // Placeholder for future types
}

class QuizCreatorScreen extends StatefulWidget {
  const QuizCreatorScreen({super.key});

  @override
  State<QuizCreatorScreen> createState() => _QuizCreatorScreenState();
}

class _QuizCreatorScreenState extends State<QuizCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // Core fields
  QuizType _quizType = QuizType.thoughtDetective;

  final TextEditingController _questionCtrl = TextEditingController();
  final TextEditingController _explanationCtrl = TextEditingController();

  // Four options (A–D)
  final List<TextEditingController> _optionCtrls = List.generate(
    4,
    (_) => TextEditingController(),
  );

  // Which index [0..3] is correct
  int _correctIndex = 0;

  // Optional language (defaults to Hindi given your examples)
  String _languageCode = 'hi';

  bool _submitting = false;

  /// Predefined option sets (auto-fills A–D and correct answer)
  /// Designed for Thought Detective questions.
  final List<_Preset> _presets = const [
    _Preset(
      title: 'Mind Reading set (C)',
      options: [
        'Personalization',
        'Catastrophizing',
        'Mind Reading',
        'Emotional Reasoning',
      ],
      correctIndex: 2,
    ),
    _Preset(
      title: 'Catastrophizing set (D)',
      options: [
        'Emotional Reasoning',
        'Mind Reading',
        'Labeling',
        'Catastrophizing',
      ],
      correctIndex: 3,
    ),
    _Preset(
      title: 'Personalization set (A)',
      options: [
        'Personalization',
        'Filtering',
        'Should Thinking',
        'Overgeneralization',
      ],
      correctIndex: 0,
    ),
    _Preset(
      title: 'Jumping to Conclusions (D)',
      options: [
        'Filtering',
        'Labeling',
        'Should Thinking',
        'Jumping to Conclusion',
      ],
      correctIndex: 3,
    ),
    _Preset(
      title: 'All-or-Nothing vs Common (C)',
      options: [
        'Overgeneralization',
        'Labeling',
        'All-or-Nothing Thinking',
        'Fortune Telling',
      ],
      correctIndex: 2,
    ),
  ];

  _Preset? _selectedPreset;

  @override
  void dispose() {
    _questionCtrl.dispose();
    _explanationCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyPreset(_Preset preset) {
    for (int i = 0; i < 4; i++) {
      _optionCtrls[i].text = preset.options[i];
    }
    setState(() {
      _correctIndex = preset.correctIndex;
      _selectedPreset = preset;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final now = FieldValue.serverTimestamp();

      final doc = {
        'quizType': _quizType.name, // 'thoughtDetective' | 'other'
        'question': _questionCtrl.text.trim(),
        'options': _optionCtrls
            .map((c) => c.text.trim())
            .toList(growable: false),
        'correctIndex': _correctIndex,
        'explanation': _explanationCtrl.text.trim(),
        'language': _languageCode, // 'hi' by default
        'createdBy': uid ?? '',
        'createdAt': now,
        'updatedAt': now,
        'status': 'active', // or 'draft'
        'tags': _quizType == QuizType.thoughtDetective
            ? ['cognitive_distortion']
            : [],
      };

      await _firestore.collection('quizBank').add(doc);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Quiz saved to Firestore')),
      );

      // Clear for next entry
      _questionCtrl.clear();
      _explanationCtrl.clear();
      for (final c in _optionCtrls) c.clear();
      setState(() {
        _correctIndex = 0;
        _selectedPreset = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving quiz: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showPreview() {
    final q = _questionCtrl.text.trim();
    final opts = _optionCtrls.map((c) => c.text.trim()).toList();
    final explain = _explanationCtrl.text.trim();

    if (q.isEmpty || opts.any((o) => o.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preview se pehle question aur options भर दें.'),
        ),
      );
      return;
    }

    final ansIdx = _correctIndex.clamp(0, 3);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent, // 👈 no default white surface
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: pageBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                    child: const Icon(
                      Icons.visibility,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Type chip
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    _quizType == QuizType.thoughtDetective
                        ? 'Thought Detective'
                        : 'Other',
                  ),
                  backgroundColor: Colors.white10,
                  labelStyle: const TextStyle(color: Colors.white70),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 10),

              // Question text
              Text(
                q,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),

              // Options list
              ...List.generate(4, (i) {
                final label = ['A', 'B', 'C', 'D'][i];
                final isCorrect = i == ansIdx;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$label. ',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          opts[i],
                          style: TextStyle(
                            color: isCorrect
                                ? Colors.greenAccent
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 10),

              // Correct answer line
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '✅ सही उत्तर: ${['A', 'B', 'C', 'D'][ansIdx]}. ${opts[ansIdx]}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),

              if (explain.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Explanation / कारण:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  explain,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Actions row
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {String? helper}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        helperText: helper,
        helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        filled: true,
        fillColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: teal3, width: 1.2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: teal4,
        elevation: 0,
        title: const Text('Create Quiz Question'),
        actions: [
          IconButton(
            tooltip: 'Preview',
            icon: const Icon(Icons.visibility),
            onPressed: _showPreview,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 12),
              _buildTypeAndLanguageCard(),
              const SizedBox(height: 12),
              _buildQuestionCard(),
              const SizedBox(height: 12),
              _buildOptionsCard(),
              const SizedBox(height: 12),
              _buildExplanationCard(),
              const SizedBox(height: 16),
              _buildActionButtons(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Sections ---

  Widget _buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [teal4.withOpacity(0.7), pageBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
              boxShadow: [
                BoxShadow(
                  color: teal3.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_alt_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Thought Detective Quiz Builder',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add CBT questions (scenario + thinking trap) for your quiz bank.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeAndLanguageCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quiz settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          // Quiz type dropdown
          DropdownButtonFormField<QuizType>(
            value: _quizType,
            decoration: _inputDecoration('Quiz type'),
            dropdownColor: pageBg,
            iconEnabledColor: Colors.white70,
            items: const [
              DropdownMenuItem(
                value: QuizType.thoughtDetective,
                child: Text(
                  'Thought Detective',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              DropdownMenuItem(
                value: QuizType.other,
                child: Text(
                  'Other type (coming soon)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
            onChanged: (v) =>
                setState(() => _quizType = v ?? QuizType.thoughtDetective),
          ),
          const SizedBox(height: 12),

          // Language + small hint
          Row(
            children: [
              const Text('Language:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButton<String>(
                  value: _languageCode,
                  dropdownColor: pageBg,
                  underline: const SizedBox.shrink(),
                  iconEnabledColor: Colors.white70,
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) => setState(() => _languageCode = v ?? 'hi'),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Hint: Most current questions are in Hindi.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Predefined options (only for Thought Detective)
          if (_quizType == QuizType.thoughtDetective)
            DropdownButtonFormField<_Preset?>(
              value: _selectedPreset,
              isExpanded: true,
              decoration: _inputDecoration(
                'Predefined distortion options (optional)',
                helper: 'Auto-fill A–D with common thinking errors.',
              ),
              dropdownColor: pageBg,
              iconEnabledColor: Colors.white70,
              items: [
                const DropdownMenuItem<_Preset?>(
                  value: null,
                  child: Text(
                    '— None —',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ..._presets.map(
                  (p) => DropdownMenuItem<_Preset?>(
                    value: p,
                    child: Text(
                      p.title,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (p) {
                if (p != null) {
                  _applyPreset(p);
                } else {
                  setState(() => _selectedPreset = null);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Question',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _questionCtrl,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              'Question text (e.g., हिंदी में परिदृश्य + “यह कौन सी सोच की गलती है?”)',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter a question'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Options (A–D) & correct answer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap the circle to mark the correct cognitive distortion.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ...List.generate(4, (i) {
            final label = ['A', 'B', 'C', 'D'][i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact radio to avoid overflow
                  Radio<int>(
                    value: i,
                    groupValue: _correctIndex,
                    activeColor: teal3,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (v) => setState(() => _correctIndex = v ?? 0),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextFormField(
                      controller: _optionCtrls[i],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('$label. Option text'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explanation (optional)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _explanationCtrl,
            minLines: 2,
            maxLines: 6,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              'Explanation / rationale (e.g., यह Mind Reading है क्योंकि...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.visibility),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _showPreview,
            label: const Text('Preview'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            style: ElevatedButton.styleFrom(
              backgroundColor: teal3,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _submitting ? null : _submit,
            label: Text(_submitting ? 'Saving...' : 'Submit'),
          ),
        ),
      ],
    );
  }
}

class _Preset {
  final String title;
  final List<String> options;
  final int correctIndex;

  const _Preset({
    required this.title,
    required this.options,
    required this.correctIndex,
  });
}
