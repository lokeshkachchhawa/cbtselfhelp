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
  ///
  /// Each entry has: title, options[4], correctIndex.
  final List<_Preset> _presets = const [
    _Preset(
      title: 'Mind Reading set (A–D includes correct C)',
      options: [
        'Personalization',
        'Catastrophizing',
        'Mind Reading',
        'Emotional Reasoning',
      ],
      correctIndex: 2,
    ),
    _Preset(
      title: 'Catastrophizing set (Correct: D)',
      options: [
        'Emotional Reasoning',
        'Mind Reading',
        'Labeling',
        'Catastrophizing',
      ],
      correctIndex: 3,
    ),
    _Preset(
      title: 'Personalization set (Correct: A)',
      options: [
        'Personalization',
        'Filtering',
        'Should Thinking',
        'Overgeneralization',
      ],
      correctIndex: 0,
    ),
    _Preset(
      title: 'Jumping to Conclusions (Correct: D)',
      options: [
        'Filtering',
        'Labeling',
        'Should Thinking',
        'Jumping to Conclusion',
      ],
      correctIndex: 3,
    ),
    _Preset(
      title: 'All-or-Nothing vs Common (Correct: C)',
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

      // Build document
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
        // Space for future features:
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
    final ansIdx = _correctIndex;
    final explain = _explanationCtrl.text.trim();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: pageBg,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        contentTextStyle: const TextStyle(color: Colors.white70),
        title: const Text('Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: ${_quizType.name}'),
              const SizedBox(height: 8),
              Text('Q:\n$q'),
              const SizedBox(height: 8),
              Text('A. ${opts[0]}'),
              Text('B. ${opts[1]}'),
              Text('C. ${opts[2]}'),
              Text('D. ${opts[3]}'),
              const SizedBox(height: 8),
              Text('✅ उत्तर: ${['A', 'B', 'C', 'D'][ansIdx]}. ${opts[ansIdx]}'),
              if (explain.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Explanation:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(explain),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white54),
    filled: true,
    fillColor: Colors.white12,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: teal4,
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
            padding: const EdgeInsets.all(12),
            children: [
              // Quiz type
              Card(
                color: Colors.white.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: DropdownButtonFormField<QuizType>(
                    value: _quizType,
                    decoration: _inputDecoration('Quiz type'),
                    dropdownColor: pageBg,
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
                    onChanged: (v) => setState(
                      () => _quizType = v ?? QuizType.thoughtDetective,
                    ),
                  ),
                ),
              ),

              // Optional language selector
              Row(
                children: [
                  const Text(
                    'Language:',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _languageCode,
                    dropdownColor: pageBg,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'hi',
                        child: Text(
                          'Hindi',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(
                          'English',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _languageCode = v ?? 'hi'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Predefined options (only shown for Thought Detective)
              if (_quizType == QuizType.thoughtDetective) ...[
                DropdownButtonFormField<_Preset>(
                  value: _selectedPreset,
                  decoration: _inputDecoration('Predefined options (optional)'),
                  dropdownColor: pageBg,
                  items: [
                    const DropdownMenuItem<_Preset>(
                      value: null,
                      child: Text(
                        '— None —',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    ..._presets.map(
                      (p) => DropdownMenuItem<_Preset>(
                        value: p,
                        child: Text(
                          p.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (p) {
                    if (p != null)
                      _applyPreset(p);
                    else
                      setState(() => _selectedPreset = null);
                  },
                ),
                const SizedBox(height: 8),
              ],

              // Question text
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
              const SizedBox(height: 12),

              // Options A–D with radio to select the correct one
              const Text(
                'Options (A–D):',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ...List.generate(4, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Radio<int>(
                        value: i,
                        groupValue: _correctIndex,
                        activeColor: teal3,
                        onChanged: (v) =>
                            setState(() => _correctIndex = v ?? 0),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _optionCtrls[i],
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                            '${['A', 'B', 'C', 'D'][i]}. Option text',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Explanation
              const SizedBox(height: 6),
              TextFormField(
                controller: _explanationCtrl,
                minLines: 2,
                maxLines: 6,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  'Explanation (विस्तृत कारण / rationale)',
                ),
              ),

              const SizedBox(height: 16),

              // Actions
              Row(
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
              ),
              const SizedBox(height: 8),
              const Text(
                'Tip: Select a preset to auto-fill A–D for common cognitive distortions. You can still edit them.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
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
