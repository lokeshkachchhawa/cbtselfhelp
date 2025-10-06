// lib/screens/thought_record_page.dart
// Thought Record page — local-only storage using shared_preferences.
// Dark teal theme + expanded CBT tutorial bottom sheet (EN/HI toggle).
// UI aligned with ABCD sheet: list view + modal bottom sheet create/edit.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kThoughtStorageKey = 'thought_records_v1';
final _uuid = Uuid();

// Teal palette (match app)
const Color teal1 = Color(0xFFC6EDED);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

// Dark surfaces for theme
const Color surfaceDark = Color(0xFF071617);
const Color cardDark = Color(0xFF072726);
const Color mutedText = Color(0xFFBFDCDC);
const Color dimText = Color(0xFFA3CFCB);

/// Reusable AppTextField — dark variant with teal focus color and optional counter
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final String? label;
  final int minLines;
  final int maxLines;
  final TextInputType keyboardType;
  final int? maxLength;
  final bool showCounter;
  final bool autofocus;

  const AppTextField({
    required this.controller,
    this.hint,
    this.label,
    this.minLines = 1,
    this.maxLines = 4,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.showCounter = false,
    this.autofocus = false,
    super.key,
  });

  InputDecoration _dec(BuildContext context) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: cardDark,
      isDense: true,
      counterText: showCounter ? null : '',
      hintStyle: TextStyle(color: Colors.white38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white10, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: teal3, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      autofocus: autofocus,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: _dec(context),
    );
  }
}

// ----------------- Domain model & storage -----------------

class ThoughtRecord {
  final String id;
  final String situation;
  final String automaticThought;
  final String evidenceFor;
  final String evidenceAgainst;
  final String alternativeThought;
  final int beforeMood;
  final int afterMood;
  final String note;
  final DateTime createdAt;

  ThoughtRecord({
    required this.id,
    required this.situation,
    required this.automaticThought,
    required this.evidenceFor,
    required this.evidenceAgainst,
    required this.alternativeThought,
    required this.beforeMood,
    required this.afterMood,
    required this.note,
    required this.createdAt,
  });

  ThoughtRecord copyWith({
    String? situation,
    String? automaticThought,
    String? evidenceFor,
    String? evidenceAgainst,
    String? alternativeThought,
    int? beforeMood,
    int? afterMood,
    String? note,
  }) {
    return ThoughtRecord(
      id: id,
      situation: situation ?? this.situation,
      automaticThought: automaticThought ?? this.automaticThought,
      evidenceFor: evidenceFor ?? this.evidenceFor,
      evidenceAgainst: evidenceAgainst ?? this.evidenceAgainst,
      alternativeThought: alternativeThought ?? this.alternativeThought,
      beforeMood: beforeMood ?? this.beforeMood,
      afterMood: afterMood ?? this.afterMood,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'situation': situation,
    'automaticThought': automaticThought,
    'evidenceFor': evidenceFor,
    'evidenceAgainst': evidenceAgainst,
    'alternativeThought': alternativeThought,
    'beforeMood': beforeMood,
    'afterMood': afterMood,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  static ThoughtRecord fromMap(Map<String, dynamic> m) {
    int _parseInt(dynamic v, [int fallback = 5]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return ThoughtRecord(
      id: m['id'] as String,
      situation: m['situation'] as String? ?? '',
      automaticThought: m['automaticThought'] as String? ?? '',
      evidenceFor: m['evidenceFor'] as String? ?? '',
      evidenceAgainst: m['evidenceAgainst'] as String? ?? '',
      alternativeThought: m['alternativeThought'] as String? ?? '',
      beforeMood: _parseInt(m['beforeMood']),
      afterMood: _parseInt(m['afterMood']),
      note: m['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ThoughtStorage {
  Future<List<ThoughtRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kThoughtStorageKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
      return list
          .map(
            (e) => ThoughtRecord.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<ThoughtRecord> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(items.map((e) => e.toMap()).toList());
    await prefs.setString(_kThoughtStorageKey, jsonStr);
  }

  Future<void> add(ThoughtRecord item) async {
    final all = await loadAll();
    all.insert(0, item); // newest first
    await saveAll(all);
  }

  Future<void> update(ThoughtRecord item) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      all[idx] = item;
      await saveAll(all);
    }
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await saveAll(all);
  }

  Future<ThoughtRecord?> loadById(String id) async {
    final all = await loadAll();
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}

// ----------------- Page UI -----------------

class ThoughtRecordPage extends StatefulWidget {
  const ThoughtRecordPage({super.key});

  @override
  State<ThoughtRecordPage> createState() => _ThoughtRecordPageState();
}

class _ThoughtRecordPageState extends State<ThoughtRecordPage> {
  final _storage = ThoughtStorage();

  // controllers for the modal form
  final _situationCtrl = TextEditingController();
  final _automaticCtrl = TextEditingController();
  final _evidenceForCtrl = TextEditingController();
  final _evidenceAgainstCtrl = TextEditingController();
  final _alternativeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  int _beforeMood = 5;
  int _afterMood = 5;

  bool _loading = true;
  List<ThoughtRecord> _items = [];
  ThoughtRecord? _editing;

  // tutorial language: false = EN, true = HI
  bool _tutorialInHindi = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _situationCtrl.dispose();
    _automaticCtrl.dispose();
    _evidenceForCtrl.dispose();
    _evidenceAgainstCtrl.dispose();
    _alternativeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _storage.loadAll();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _startNew() {
    setState(() {
      _editing = null;
      _situationCtrl.clear();
      _automaticCtrl.clear();
      _evidenceForCtrl.clear();
      _evidenceAgainstCtrl.clear();
      _alternativeCtrl.clear();
      _noteCtrl.clear();
      _beforeMood = 5;
      _afterMood = 5;
    });
    _showFormSheet();
  }

  void _startEdit(ThoughtRecord item) {
    setState(() {
      _editing = item;
      _situationCtrl.text = item.situation;
      _automaticCtrl.text = item.automaticThought;
      _evidenceForCtrl.text = item.evidenceFor;
      _evidenceAgainstCtrl.text = item.evidenceAgainst;
      _alternativeCtrl.text = item.alternativeThought;
      _noteCtrl.text = item.note;
      _beforeMood = item.beforeMood;
      _afterMood = item.afterMood;
    });
    _showFormSheet();
  }

  Future<void> _saveFromForm() async {
    final situation = _situationCtrl.text.trim();
    final auto = _automaticCtrl.text.trim();

    if (situation.isEmpty || auto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete situation and automatic thought'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (_editing != null) {
      final updated = _editing!.copyWith(
        situation: situation,
        automaticThought: auto,
        evidenceFor: _evidenceForCtrl.text.trim(),
        evidenceAgainst: _evidenceAgainstCtrl.text.trim(),
        alternativeThought: _alternativeCtrl.text.trim(),
        beforeMood: _beforeMood,
        afterMood: _afterMood,
        note: _noteCtrl.text.trim(),
      );
      await _storage.update(updated);
    } else {
      final newItem = ThoughtRecord(
        id: _uuid.v4(),
        situation: situation,
        automaticThought: auto,
        evidenceFor: _evidenceForCtrl.text.trim(),
        evidenceAgainst: _evidenceAgainstCtrl.text.trim(),
        alternativeThought: _alternativeCtrl.text.trim(),
        beforeMood: _beforeMood,
        afterMood: _afterMood,
        note: _noteCtrl.text.trim(),
        createdAt: now,
      );
      await _storage.add(newItem);
    }

    await _load();
    if (mounted) {
      Navigator.of(context).pop(); // close sheet
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved locally')));
    }
  }

  Future<void> _deleteItem(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: cardDark,
        title: const Text(
          'Delete thought record?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete the record from local storage.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: teal2)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.delete(id);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  void _showFormSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom;

        // Use local copies so sliders update inside the sheet instantly
        int localBefore = _beforeMood;
        int localAfter = _afterMood;

        return FractionallySizedBox(
          heightFactor: 0.9, // 90% height
          child: Padding(
            padding: EdgeInsets.only(bottom: pad),
            child: StatefulBuilder(
              builder: (BuildContext ctx2, StateSetter setModalState) {
                void _updateBefore(double v) =>
                    setModalState(() => localBefore = v.toInt());
                void _updateAfter(double v) =>
                    setModalState(() => localAfter = v.toInt());

                return Container(
                  decoration: BoxDecoration(
                    color: surfaceDark,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        height: 5,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      // Header row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _editing != null
                                    ? 'Edit thought record'
                                    : 'New thought record',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: Colors.white10, height: 1),

                      // Scrollable form area
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _fieldLabel('Situation'),
                              AppTextField(
                                controller: _situationCtrl,
                                hint: 'Where were you? What happened?',
                                minLines: 2,
                                maxLines: 5,
                                maxLength: 800,
                                showCounter: true,
                                autofocus: _editing == null,
                              ),
                              const SizedBox(height: 10),

                              _fieldLabel('Automatic thought'),
                              AppTextField(
                                controller: _automaticCtrl,
                                hint: 'What went through your mind?',
                                minLines: 1,
                                maxLines: 3,
                                maxLength: 300,
                                showCounter: true,
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Before mood',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Slider(
                                          value: localBefore.toDouble(),
                                          min: 0,
                                          max: 10,
                                          divisions: 10,
                                          label: '$localBefore',
                                          activeColor: teal3,
                                          onChanged: _updateBefore,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'After mood',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Slider(
                                          value: localAfter.toDouble(),
                                          min: 0,
                                          max: 10,
                                          divisions: 10,
                                          label: '$localAfter',
                                          activeColor: teal4,
                                          onChanged: _updateAfter,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),
                              _fieldLabel('Evidence FOR'),
                              AppTextField(
                                controller: _evidenceForCtrl,
                                hint: 'Facts that support the thought',
                                minLines: 2,
                                maxLines: 4,
                                maxLength: 800,
                                showCounter: true,
                              ),
                              const SizedBox(height: 10),
                              _fieldLabel('Evidence AGAINST'),
                              AppTextField(
                                controller: _evidenceAgainstCtrl,
                                hint: 'Facts that contradict the thought',
                                minLines: 2,
                                maxLines: 4,
                                maxLength: 800,
                                showCounter: true,
                              ),
                              const SizedBox(height: 10),
                              _fieldLabel('Alternative thought'),
                              AppTextField(
                                controller: _alternativeCtrl,
                                hint: 'A kinder or balanced thought',
                                minLines: 2,
                                maxLines: 4,
                                maxLength: 600,
                                showCounter: true,
                              ),
                              const SizedBox(height: 10),
                              _fieldLabel('Note (optional)'),
                              AppTextField(
                                controller: _noteCtrl,
                                hint: 'Optional strategy or reminder',
                                minLines: 1,
                                maxLines: 3,
                                maxLength: 400,
                                showCounter: true,
                              ),

                              const SizedBox(height: 16),

                              // Buttons row (save/cancel/delete)
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        // copy modal-local sliders back to parent and save
                                        setState(() {
                                          _beforeMood = localBefore;
                                          _afterMood = localAfter;
                                        });
                                        await _saveFromForm();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: teal4,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      child: const Text(
                                        'Save locally',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  if (_editing != null) ...[
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        _deleteItem(_editing!.id);
                                      },
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _fieldLabel(String s) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        s,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );

  Widget _buildListTile(ThoughtRecord item) {
    final dateStr = MaterialLocalizations.of(
      context,
    ).formatFullDate(item.createdAt);
    return Card(
      color: cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        isThreeLine: true,
        title: Text(
          item.situation.isNotEmpty ? item.situation : 'Thought record',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Thought: ${item.automaticThought}\nSaved: $dateStr',
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: PopupMenuButton<String>(
          color: cardDark,
          onSelected: (v) {
            if (v == 'edit') _startEdit(item);
            if (v == 'delete') _deleteItem(item.id);
            if (v == 'share') {
              final txt = [
                'Thought record',
                'Situation: ${item.situation}',
                'Thought: ${item.automaticThought}',
                'Evidence FOR: ${item.evidenceFor}',
                'Evidence AGAINST: ${item.evidenceAgainst}',
                'Alternative: ${item.alternativeThought}',
                'Before mood: ${item.beforeMood} • After mood: ${item.afterMood}',
                if (item.note.isNotEmpty) 'Note: ${item.note}',
              ].join('\n');
              Clipboard.setData(ClipboardData(text: txt));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard (for sharing)'),
                ),
              );
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'share', child: Text('Copy for share')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _showDetail(item),
      ),
    );
  }

  void _showDetail(ThoughtRecord item) {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: cardDark,
        title: const Text(
          'Thought record',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Situation', item.situation),
              const SizedBox(height: 8),
              _detailRow('Automatic thought', item.automaticThought),
              const SizedBox(height: 8),
              _detailRow('Evidence FOR', item.evidenceFor),
              const SizedBox(height: 8),
              _detailRow('Evidence AGAINST', item.evidenceAgainst),
              const SizedBox(height: 8),
              _detailRow('Alternative thought', item.alternativeThought),
              const SizedBox(height: 8),
              Text(
                'Before mood: ${item.beforeMood} • After mood: ${item.afterMood}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              if (item.note.isNotEmpty) _detailRow('Note', item.note),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('Close', style: TextStyle(color: teal2)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: teal3),
            onPressed: () {
              Navigator.of(dctx).pop();
              _startEdit(item);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  // ----- Tutorial sheet (expanded explanation) -----
  void _showTutorial() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: surfaceDark,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: StatefulBuilder(
                builder: (sheetCtx, sheetSetState) {
                  String t(String en, String hi) => _tutorialInHindi ? hi : en;

                  return SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 6,
                          width: 60,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t(
                                  'Thought Record — CBT tutorial (expanded)',
                                  'थॉट रिकॉर्ड — CBT मार्गदर्शिका (विस्तारित)',
                                ),
                                style: TextStyle(
                                  color: mutedText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // language toggle + copy checklist
                        Row(
                          children: [
                            Text(
                              _tutorialInHindi
                                  ? 'Switch to EN'
                                  : 'Switch to हिंदी',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _tutorialInHindi,
                              activeColor: teal3,
                              onChanged: (v) {
                                sheetSetState(() => _tutorialInHindi = v);
                                setState(() => _tutorialInHindi = v);
                              },
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                final enClipboard = [
                                  'Thought Record steps:',
                                  '1) Describe the situation.',
                                  '2) Note the automatic thought.',
                                  '3) List evidence for and against.',
                                  '4) Create a balanced alternative thought.',
                                  '5) Re-rate mood; plan a small experiment or reminder.',
                                ].join('\n');
                                final hiClipboard = [
                                  'थॉट रिकॉर्ड कदम:',
                                  '1) स्थिति का वर्णन करें।',
                                  '2) स्वचालित विचार लिखें।',
                                  '3) समर्थन/विरोध के प्रमाण लिखें।',
                                  '4) संतुलित वैकल्पिक विचार बनाएं।',
                                  '5) मूड फिर से रेट करें; छोटा प्रयोग/नोट प्लान करें।',
                                ].join('\n');
                                Clipboard.setData(
                                  ClipboardData(
                                    text: _tutorialInHindi
                                        ? hiClipboard
                                        : enClipboard,
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t(
                                        'Checklist copied',
                                        'चेकलिस्ट कॉपी हो गई',
                                      ),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.copy,
                                color: Colors.white70,
                                size: 18,
                              ),
                              label: Text(
                                t('Copy checklist', 'चेकलिस्ट कॉपी करें'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // WHAT is a thought record + WHY helpful
                        Text(
                          t(
                            'What is a Thought Record?',
                            'थॉट रिकॉर्ड क्या है?',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t(
                            'A Thought Record is a structured worksheet used in Cognitive Behavioural Therapy (CBT) to help you examine distressing situations step-by-step. It guides you to separate facts from feelings, identify the quick automatic thought, evaluate supporting and contradicting evidence, and create a more balanced alternative thought.',
                            'थॉट रिकॉर्ड CBT (संज्ञानात्मक व्यवहार थेरेपी) में उपयोग किया जाने वाला एक संरचित वर्कशीट है जो कठिन स्थितियों को चरण-दर-चरण देखने में मदद करता है। यह आपको तथ्यों और भावनाओं को अलग करने, तात्कालिक स्वचालित विचार की पहचान करने, समर्थन और विरोध के प्रमाणों का मूल्यांकन करने और एक संतुलित वैकल्पिक विचार बनाने में मार्गदर्शन करता है।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t('Why it helps', 'यह कैसे मदद करता है'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _bulletItem(
                          Icons.check_circle_outline,
                          t(
                            'It slows down thinking so you can inspect the thought rather than react to it.',
                            'यह सोचने की गति धीमी करता है ताकि आप प्रतिक्रिया देने की बजाय विचार का निरीक्षण कर सकें।',
                          ),
                        ),
                        _bulletItem(
                          Icons.analytics,
                          t(
                            'It separates evidence from emotion — decisions based on evidence tend to be less biased.',
                            'यह भावनाओं से प्रमाणों को अलग करता है — प्रमाणों पर आधारित निर्णय कम पूर्वाग्रहपूर्ण होते हैं।',
                          ),
                        ),
                        _bulletItem(
                          Icons.self_improvement,
                          t(
                            'Over time, it trains you to spot thinking traps (catastrophising, black-and-white thinking, mind-reading).',
                            'समय के साथ, यह आपको सोचने के जाल (विशालकरण, काले-से-सफेद सोच, दिमाग पढ़ना) को पहचानना सिखाता है।',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t(
                            'How it works (the practical method)',
                            'यह कैसे काम करता है (व्यावहारिक विधि)',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t(
                            'Use the worksheet as a short experiment. Fill each section in order, using short factual statements where possible. The core idea: treat your automatic thought as a hypothesis and test it with evidence. Then form a balanced alternative and notice any change in mood or behavior.',
                            'वर्कशीट को एक छोटे प्रयोग के रूप में उपयोग करें। प्रत्येक खंड को क्रम में भरें, जहाँ संभव हो संक्षिप्त तथ्यात्मक वाक्य का उपयोग करें। मूल विचार: अपने स्वचालित विचार को एक अनुमान के रूप में देखें और प्रमाणों से जांचें। फिर एक संतुलित वैकल्पिक विचार बनाएं और मूड/व्यवहार में किसी भी बदलाव को नोट करें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),

                        const SizedBox(height: 10),

                        // Step-by-step with more detail
                        _numberedItem(
                          1,
                          t(
                            'Situation — write only the observable facts (who, what, when, where). Avoid interpretation here.',
                            'स्थिति — केवल अवलोकनीय तथ्यों को लिखें (कौन, क्या, कब, कहाँ)। यहाँ व्याख्या से बचें।',
                          ),
                        ),
                        _numberedItem(
                          2,
                          t(
                            'Automatic thought — the immediate sentence or image that appears in your mind (keep it short).',
                            'स्वचालित विचार — तुरंत जो वाक्य या छवि आपके मन में आती है उसे लिखें (संक्षेप में)।',
                          ),
                        ),
                        _numberedItem(
                          3,
                          t(
                            'Evidence FOR — factual points that would support this thought (dates, quotes, actions).',
                            'समर्थक प्रमाण — तथ्यात्मक बिंदु जो इस विचार का समर्थन करते हैं (तिथियाँ, उद्धरण, क्रियाएँ)।',
                          ),
                        ),
                        _numberedItem(
                          4,
                          t(
                            'Evidence AGAINST — concrete facts that contradict or weaken the thought.',
                            'विरोधी प्रमाण — ठोस तथ्य जो विचार का विरोध या उस कमज़ोर करते हैं।',
                          ),
                        ),
                        _numberedItem(
                          5,
                          t(
                            'Alternative thought — a kinder, more balanced hypothesis that fits the evidence. It does not need to be perfectly positive — just more realistic.',
                            'वैकल्पिक विचार — एक दयालु, अधिक संतुलित अनुमान जो प्रमाणों से मेल खाता है। यह पूरी तरह सकारात्मक नहीं होना चाहिए — केवल अधिक वास्तविक होना चाहिए।',
                          ),
                        ),
                        _numberedItem(
                          6,
                          t(
                            'Behaviour / plan — note a small experiment or action you can try to test the alternative (e.g., ask a question, wait, observe).',
                            'व्यवहार / योजना — एक छोटा प्रयोग या क्रिया नोट करें जिसे आप वैकल्पिक विचार का परीक्षण करने के लिए कर सकते हैं (उदा., प्रश्न पूछना, प्रतीक्षा करना, अवलोकन करना)।',
                          ),
                        ),
                        _numberedItem(
                          7,
                          t(
                            'Re-rate mood — before and after; notice any reduction in distress.',
                            'मूड फिर से रेट करें — पहले और बाद में; कष्ट में किसी भी कमी को नोट करें।',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t(
                            'Socratic questioning — examples to use while completing the sheet',
                            'सॉक्रेटिक प्रश्न — शीट भरते समय इस्तेमाल करने हेतु उदाहरण',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _bulletItem(
                          Icons.question_mark,
                          t(
                            'What is the evidence for this? What is the evidence against it?',
                            'इसके पक्ष में क्या प्रमाण हैं? इसके खिलाफ क्या प्रमाण हैं?',
                          ),
                        ),
                        _bulletItem(
                          Icons.question_mark,
                          t(
                            'Am I assuming intentions or mind-reading? Is there another explanation?',
                            'क्या मैं इरादों का अनुमान लगा रहा/रही हूँ? क्या कोई और व्याख्या संभव है?',
                          ),
                        ),
                        _bulletItem(
                          Icons.question_mark,
                          t(
                            'What would I say to a friend who had this thought?',
                            'यदि किसी मित्र के साथ ऐसा विचार हो तो मैं क्या कहूँगा/कहूँगी?',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t(
                            'Worked example (detailed)',
                            'व्यवहारिक उदाहरण (विस्तृत)',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _exampleBlock(
                          enTitle: 'Situation',
                          enBody:
                              'Spoke up in a meeting; the manager looked at their phone and didn\'t comment immediately.',
                          hiTitle: 'स्थिति',
                          hiBody:
                              'मीटिंग में बोलने पर मैनेजर ने फोन देखा और तुरंत प्रतिक्रिया नहीं दी।',
                        ),
                        const SizedBox(height: 8),
                        _exampleBlock(
                          enTitle: 'Automatic thought',
                          enBody: '\"They ignored me; I must be unimportant.\"',
                          hiTitle: 'स्वचालित विचार',
                          hiBody:
                              '\"उन्होंने मुझे अनदेखा किया; मैं महत्वहीन हूँ।\"',
                        ),
                        const SizedBox(height: 8),
                        _exampleBlock(
                          enTitle: 'Evidence FOR',
                          enBody:
                              'They didn\'t respond and looked away during my comment.',
                          hiTitle: 'समर्थक प्रमाण',
                          hiBody:
                              'मेरी टिप्पणी के दौरान उन्होंने प्रतिक्रिया नहीं दी और नजर हटा ली।',
                        ),
                        const SizedBox(height: 8),
                        _exampleBlock(
                          enTitle: 'Evidence AGAINST',
                          enBody:
                              'They often check devices during meetings; later they praised the point in private. Colleagues were distracted too.',
                          hiTitle: 'विरोधी प्रमाण',
                          hiBody:
                              'वे अक्सर मीटिंग में डिवाइस देखते हैं; बाद में उन्होंने निजी रूप से प्रशंसा की। अन्य साथी भी व्यस्त थे।',
                        ),
                        const SizedBox(height: 8),
                        _exampleBlock(
                          enTitle: 'Balanced alternative',
                          enBody:
                              'Maybe they were checking something urgent; my point still had value. I can follow up for feedback.',
                          hiTitle: 'संतुलित वैकल्पिक विचार',
                          hiBody:
                              'शायद वे कुछ आवश्यक देख रहे थे; मेरी बात अभी भी महत्वपूर्ण थी। मैं फॉलो-अप कर सकता/सकती हूँ।',
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t(
                            'Practical tips & common mistakes',
                            'व्यावहारिक सुझाव और सामान्य गलतियाँ',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _bulletItem(
                          Icons.lightbulb_outline,
                          t(
                            'Be concrete — prefer observable facts (quotes, times) over feelings when listing evidence.',
                            'सटीक रहें — प्रमाण सूचीबद्ध करते समय भावनाओं के बजाय अवलोकनीय तथ्यों (उद्धरण, समय) को प्राथमिकता दें।',
                          ),
                        ),
                        _bulletItem(
                          Icons.timer,
                          t(
                            'Don\'t rush. Spend a few minutes on each section.',
                            'जल्दी न करें। प्रत्येक खंड पर कुछ मिनट बिताएँ।',
                          ),
                        ),
                        _bulletItem(
                          Icons.loop,
                          t(
                            'Use the alternative thought as a hypothesis — try a small experiment to test it.',
                            'वैकल्पिक विचार को एक अनुमान के रूप में उपयोग करें — इसे जांचने के लिए एक छोटा प्रयोग आज़माएँ।',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t('When to seek help', 'कब सहायता लें'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _bulletItem(
                          Icons.medical_services,
                          t(
                            'If thoughts are persistent, intrusive, or linked to self-harm, contact a mental health professional immediately.',
                            'यदि विचार लगातार, घुसपैठिया या आत्म-हानि से जुड़े हों, तो तुरंत मानसिक स्वास्थ्य पेशेवर से संपर्क करें।',
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _startNew();
                                },
                                icon: const Icon(Icons.add),
                                label: Text(
                                  t(
                                    'Create thought record',
                                    'थॉट रिकॉर्ड बनाएँ',
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teal3,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white12),
                              ),
                              child: Text(
                                t('Close', 'बंद करें'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _bulletItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: teal2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _numberedItem(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: teal3,
            child: Text(
              '$n',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _exampleBlock({
    required String enTitle,
    required String enBody,
    String? hiTitle,
    String? hiBody,
  }) {
    final showHi = _tutorialInHindi;
    final title = showHi ? (hiTitle ?? enTitle) : enTitle;
    final body = showHi ? (hiBody ?? enBody) : enBody;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceDark,
      appBar: AppBar(
        title: const Text('Thought Records'),
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
        actions: [
          IconButton(
            onPressed: _showTutorial,
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            tooltip: 'Show tutorial',
          ),
          IconButton(
            onPressed: _startNew,
            icon: const Icon(Icons.add, color: Colors.white70),
            tooltip: 'New thought record',
          ),
        ],
      ),

      // FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNew,
        icon: const Icon(Icons.add),
        label: const Text('Add Thought'),
        backgroundColor: teal3,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No saved thought records',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a new thought record to capture a situation and work through it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: dimText),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _startNew,
                      icon: const Icon(Icons.add),
                      label: const Text('Create thought'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal3,
                        // ADDED: Reduced padding for a more compact button shape
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              backgroundColor: cardDark,
              color: teal2,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: _buildListTile(_items[i]),
                ),
              ),
            ),
    );
  }
}
