// lib/screens/thought_record_page.dart
// Thought Record page — local-only storage using shared_preferences.
// Dark teal theme + expanded CBT tutorial bottom sheet (EN/HI toggle).
// UI aligned with ABCD sheet: list view + modal bottom sheet create/edit.

import 'dart:convert';
import 'package:cbt_drktv/widgets/thought_tutorial_sheet.dart'
    show showThoughtTutorialSheet;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

bool _examplesInHindi = true; // false = English, true = Hindi

const _kThoughtStorageKey = 'thought_records_v1';
final _uuid = Uuid();

// Teal palette (match app)
const Color teal1 = Color(0xFFC6EDED);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);
// Emotion colors (for field distinction)
const Color colorA = Color(0xFFE57373); // Light Red/Coral — Emotion
const Color colorB = Color(0xFFFDD835); // Amber/Yellow — Awareness
const Color colorC = Color(0xFF64B5F6); // Light Blue — Thought
const Color colorD = Color(0xFF81C784); // Light Green — Rational
const Color colorE = Color(0xFFFFB74D); // Orange — Action/Reflection

// Dark surfaces for theme
const Color surfaceDark = Color(0xFF071617);
const Color cardDark = Color(0xFF072726);
const Color mutedText = Color(0xFFBFDCDC);
const Color dimText = Color(0xFFA3CFCB);

// ----------------- Embedded Hindi examples JSON -----------------
// You can keep this embedded or move to an asset file (assets/examples_hi.json) and load it via rootBundle.loadString.

// ----------------- Reusable AppTextField -----------------

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
  final TextCapitalization textCapitalization;

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
    this.textCapitalization = TextCapitalization.sentences,
  });

  InputDecoration _dec(BuildContext context) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: cardDark,
      isDense: true,
      counterText: showCounter ? null : '',
      hintStyle: const TextStyle(color: Colors.white38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white10, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: teal3, width: 2),
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
      textCapitalization: textCapitalization,
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

  // examples loaded from JSON (each is a Map<String,String>)
  List<Map<String, String>> _examples = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadExamples();
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

  Future<void> _loadExamples() async {
    try {
      final file = _examplesInHindi
          ? 'assets/examples_hi.json'
          : 'assets/examples_en.json';

      final jsonStr = await rootBundle.loadString(file);
      final List<dynamic> parsed = json.decode(jsonStr) as List<dynamic>;

      _examples = parsed
          .map((e) => Map<String, String>.from(e as Map))
          .toList(growable: false);
    } catch (e) {
      _examples = [];
      debugPrint('Failed to load examples: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _storage.loadAll();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _startNew({Map<String, String>? fromExample}) {
    setState(() {
      _editing = null;
      _situationCtrl.text = fromExample?['situation'] ?? '';
      _automaticCtrl.text = fromExample?['automaticThought'] ?? '';
      _evidenceForCtrl.text = fromExample?['evidenceFor'] ?? '';
      _evidenceAgainstCtrl.text = fromExample?['evidenceAgainst'] ?? '';
      _alternativeCtrl.text = fromExample?['alternativeThought'] ?? '';
      _noteCtrl.text = fromExample?['note'] ?? '';
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleted')));
      }
    }
  }

  void _applyExampleToForm(Map<String, String> example) {
    // open form with example values pre-filled (as a new record)
    _startNew(fromExample: example);
  }

  void _showFormSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom;
        int localBefore = _beforeMood;
        int localAfter = _afterMood;

        return FractionallySizedBox(
          heightFactor: 0.9, // 90% height
          child: Padding(
            padding: EdgeInsets.only(bottom: pad),
            child: StatefulBuilder(
              builder: (BuildContext ctx2, StateSetter setModalState) {
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
                                    ? 'Edit Thought Record'
                                    : 'New Thought Record',
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
                              // 🔴 SITUATION (Coral/Amber)
                              ColoredFieldTile(
                                label: 'Situation',
                                hint: 'Where were you? What happened?',
                                controller: _situationCtrl,
                                startColor: colorA,
                                endColor: colorB,
                                icon: Icons.location_on_outlined,
                                minLines: 2,
                                maxLines: 5,
                              ),

                              // 🔵 AUTOMATIC THOUGHT (Blue)
                              ColoredFieldTile(
                                label: 'Automatic Thought',
                                hint: 'What went through your mind?',
                                controller: _automaticCtrl,
                                startColor: colorC,
                                endColor: colorC.withOpacity(0.7),
                                icon: Icons.cloud,
                              ),

                              // 🟢 EVIDENCE FOR (Green)
                              ColoredFieldTile(
                                label: 'Evidence For',
                                hint: 'Facts that support the thought',
                                controller: _evidenceForCtrl,
                                startColor: colorD,
                                endColor: colorD.withOpacity(0.6),
                                icon: Icons.trending_up_outlined,
                                minLines: 2,
                                maxLines: 4,
                              ),

                              // 🟠 EVIDENCE AGAINST (Amber → Orange)
                              ColoredFieldTile(
                                label: 'Evidence Against',
                                hint: 'Facts that contradict the thought',
                                controller: _evidenceAgainstCtrl,
                                startColor: colorB,
                                endColor: colorE,
                                icon: Icons.trending_down_outlined,
                                minLines: 2,
                                maxLines: 4,
                              ),

                              // 💡 ALTERNATIVE THOUGHT (Light Blue → Green)
                              ColoredFieldTile(
                                label: 'Alternative Thought',
                                hint: 'A kinder or balanced thought',
                                controller: _alternativeCtrl,
                                startColor: colorC,
                                endColor: colorD,
                                icon: Icons.lightbulb_outline,
                                minLines: 2,
                                maxLines: 4,
                              ),

                              // 🟤 NOTE (Neutral / soft blend)
                              ColoredFieldTile(
                                label: 'Note (Optional)',
                                hint: 'Optional strategy or reminder',
                                controller: _noteCtrl,
                                startColor: Colors.white30,
                                endColor: Colors.white10,
                                icon: Icons.sticky_note_2_outlined,
                                minLines: 1,
                                maxLines: 3,
                              ),

                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
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
          icon: const Icon(
            Icons.more_vert,
            color: Colors.white70, // white icon on dark background
          ),
          color: Colors.white, // popup menu background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: const [
                  Icon(Icons.edit_outlined, size: 18, color: Colors.black54),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'share',
              child: Row(
                children: const [
                  Icon(Icons.copy_outlined, size: 18, color: Colors.black54),
                  SizedBox(width: 8),
                  Text('Copy for share'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: const [
                  Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),

        onTap: () => _showDetail(item),
      ),
    );
  }

  void _showDetail(ThoughtRecord item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dctx) {
        final media = MediaQuery.of(dctx);
        final pad = media.viewInsets.bottom;
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: Padding(
            padding: EdgeInsets.only(bottom: pad),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceDark,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  // Drag handle + header
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    height: 6,
                    width: 72,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.article_outlined, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thought record',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatFullDate(item.createdAt),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // top actions: copy all, edit
                        IconButton(
                          onPressed: () {
                            final txt = [
                              'Situation: ${item.situation}',
                              'Thought: ${item.automaticThought}',
                              'Evidence FOR: ${item.evidenceFor}',
                              'Evidence AGAINST: ${item.evidenceAgainst}',
                              'Alternative: ${item.alternativeThought}',
                              'Before: ${item.beforeMood} • After: ${item.afterMood}',
                              if (item.note.isNotEmpty) 'Note: ${item.note}',
                            ].join('\n');
                            Clipboard.setData(ClipboardData(text: txt));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, color: Colors.white70),
                          tooltip: 'Copy all',
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(dctx).pop();
                            _startEdit(item);
                          },
                          icon: const Icon(Icons.edit, color: Colors.white70),
                          tooltip: 'Edit',
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white10, height: 1),

                  // content area — uses same tile pattern as the form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Situation — coral -> amber (colorA -> colorB)
                          ReadOnlyColoredFieldTile(
                            label: 'Situation',
                            value: item.situation,
                            startColor: colorA,
                            endColor: colorB,
                            icon: Icons.location_on_outlined,
                          ),

                          // Automatic thought — blue (colorC)
                          ReadOnlyColoredFieldTile(
                            label: 'Automatic thought',
                            value: item.automaticThought,
                            startColor: colorC,
                            endColor: colorC.withOpacity(0.8),
                            icon: Icons.psychology_outlined,
                          ),

                          // Evidence FOR — green (colorD)
                          ReadOnlyColoredFieldTile(
                            label: 'Evidence FOR',
                            value: item.evidenceFor,
                            startColor: colorD,
                            endColor: colorD.withOpacity(0.7),
                            icon: Icons.thumb_up_alt_outlined,
                          ),

                          // Evidence AGAINST — amber -> orange (colorB -> colorE)
                          ReadOnlyColoredFieldTile(
                            label: 'Evidence AGAINST',
                            value: item.evidenceAgainst,
                            startColor: colorB,
                            endColor: colorE,
                            icon: Icons.thumb_down_alt_outlined,
                          ),

                          // Alternative thought — blue -> green (colorC -> colorD)
                          ReadOnlyColoredFieldTile(
                            label: 'Alternative thought',
                            value: item.alternativeThought,
                            startColor: colorC,
                            endColor: colorD,
                            icon: Icons.lightbulb_outline,
                          ),

                          // Note
                          ReadOnlyColoredFieldTile(
                            label: 'Note',
                            value: item.note,
                            startColor: colorC,
                            endColor: colorD,
                            icon: Icons.note,
                          ),

                          const SizedBox(height: 10),

                          // Mood row (keeps parity with form layout)
                        ],
                      ),
                    ),
                  ),

                  // footer actions (sticky)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dctx).pop(),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: teal2),
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(dctx).pop();
                            _deleteItem(item.id);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: teal3,
                          ),
                          onPressed: () {
                            Navigator.of(dctx).pop();
                            _startEdit(item);
                          },
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ----- Tutorial sheet (unchanged) -----
  void _showTutorial() {
    showThoughtTutorialSheet(context, initialHindi: false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: surfaceDark,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thought',
                style: TextStyle(
                  fontSize: 16, // 👈 same as ABCDE
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  'Records CBT Tool',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),

          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,

          // Gradient background
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [teal6, teal4],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Tab bar with improved styling
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  const Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Examples'),
                        SizedBox(height: 2),
                        Text('(उदाहरण)', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('My Thoughts'),
                            ThoughtCountBadge(_items.length),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '(मेरे विचार)',
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons with improved design
          actions: [
            // 🔤 Language toggle (pill style)
            GestureDetector(
              onTap: () {
                setState(() => _examplesInHindi = !_examplesInHindi);
                _loadExamples();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _examplesInHindi
                        ? [Colors.orange, Colors.deepOrange]
                        : [teal3, teal4],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.language, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _examplesInHindi ? 'हिंदी' : 'EN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ❓ Help button (pill style)
            GestureDetector(
              onTap: _showTutorial,
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF5C7CFA),
                      Color(0xFF4C6EF5),
                    ], // soft blue help
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.help_outline, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Help',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // FAB
        floatingActionButton: GlowPulse(
          color: teal2, // soft mint glow
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.green, teal2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: teal2.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () => _startNew(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Thought',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          ),
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        body: TabBarView(
          children: [
            // ---------------------- Tab 1: Examples ----------------------
            _examples.isEmpty
                ? Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No examples available',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: mutedText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Examples will show here. You can tap "Use example" to prefill the form.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: dimText),
                                ),
                              ],
                            ),
                          ),
                  )
                : RefreshIndicator(
                    backgroundColor: cardDark,
                    color: teal2,
                    onRefresh: () async => _loadExamples(),
                    child: Builder(
                      builder: (ctx) {
                        final bottomInset = MediaQuery.of(ctx)
                            .viewPadding
                            .bottom; // safe-area (e.g. iPhone home indicator)
                        final fabExtra =
                            76.0; // approximate FAB + margin — tweak to taste
                        return ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            12,
                            12,
                            bottomInset + fabExtra,
                          ),
                          itemCount: _examples.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: ExampleCard(
                              example: _examples[i],
                              onUse: (example) => _applyExampleToForm(example),
                              onCopyText: (txt) {
                                Clipboard.setData(ClipboardData(text: txt));
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),

            // ---------------------- Tab 2: My thoughts ----------------------
            _loading
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
                            onPressed: () => _startNew(),
                            icon: const Icon(Icons.add),
                            label: const Text('Create thought'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: teal3,
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
          ],
        ),
      ),
    );
  }
}

class ExampleCard extends StatefulWidget {
  final Map<String, String> example;
  final void Function(Map<String, String>) onUse;
  final void Function(String) onCopyText;

  const ExampleCard({
    required this.example,
    required this.onUse,
    required this.onCopyText,
    super.key,
  });

  @override
  State<ExampleCard> createState() => _ExampleCardState();
}

class _ExampleCardState extends State<ExampleCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.example;
    final title = e['title'] ?? '';
    final situation = e['situation'] ?? '';
    final preview = situation.length > 120
        ? '${situation.substring(0, 117)}…'
        : situation;
    final hasNote = (e['note'] ?? '').isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Card(
        color: cardDark,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row: badge + title + icon
                Row(
                  children: [
                    // small badge (topic)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withOpacity(0.95),
                            teal3.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Example',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // expand/collapse icon
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // situation preview
                Text(
                  preview,
                  style: const TextStyle(color: Colors.white70, height: 1.3),
                  maxLines: _expanded ? 10 : 3,
                  overflow: TextOverflow.fade,
                ),

                if (_expanded) ...[
                  const SizedBox(height: 10),
                  ReadOnlyColoredFieldTile(
                    label: 'Situation',
                    value: e['situation'] ?? '',
                    startColor: colorA,
                    endColor: colorA.withOpacity(0.8),
                    icon: Icons.location_on_outlined,
                  ),

                  // Automatic thought (compact tile)
                  ReadOnlyColoredFieldTile(
                    label: 'Automatic thought',
                    value: e['automaticThought'] ?? '',
                    startColor: colorC,
                    endColor: colorC.withOpacity(0.8),
                    icon: Icons.psychology_outlined,
                  ),

                  // Evidence FOR
                  ReadOnlyColoredFieldTile(
                    label: 'Evidence FOR',
                    value: e['evidenceFor'] ?? '',
                    startColor: colorD,
                    endColor: colorD.withOpacity(0.7),
                    icon: Icons.thumb_up_alt_outlined,
                  ),

                  // Evidence AGAINST
                  ReadOnlyColoredFieldTile(
                    label: 'Evidence AGAINST',
                    value: e['evidenceAgainst'] ?? '',
                    startColor: colorB,
                    endColor: colorE,
                    icon: Icons.thumb_down_alt_outlined,
                  ),

                  // Alternative thought
                  ReadOnlyColoredFieldTile(
                    label: 'Alternative thought',
                    value: e['alternativeThought'] ?? '',
                    startColor: colorC,
                    endColor: colorD,
                    icon: Icons.lightbulb_outline,
                  ),

                  // Note (optional)
                  if (hasNote) ...[
                    ReadOnlyColoredFieldTile(
                      label: 'Note',
                      value: e['note'] ?? '',
                      startColor: Colors.white30,
                      endColor: Colors.white10,
                      icon: Icons.sticky_note_2_outlined,
                    ),
                  ],

                  const SizedBox(height: 6),

                  // footer action row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => widget.onUse(widget.example),
                        icon: const Icon(Icons.playlist_add_check, size: 18),
                        label: const Text(
                          'Use example',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ColoredFieldTile extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final Color startColor;
  final Color endColor;
  final IconData icon;
  final int minLines;
  final int maxLines;

  const ColoredFieldTile({
    required this.label,
    required this.hint,
    required this.controller,
    required this.startColor,
    required this.endColor,
    required this.icon,
    this.minLines = 1,
    this.maxLines = 3,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor.withOpacity(0.22), endColor.withOpacity(0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: startColor.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: startColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: controller,
              hint: hint,
              minLines: minLines,
              maxLines: maxLines,
              showCounter: true,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- Read-only colored tile (for detail view) -----------------
class ReadOnlyColoredFieldTile extends StatelessWidget {
  final String label;
  final String value;
  final Color startColor;
  final Color endColor;
  final IconData icon;

  const ReadOnlyColoredFieldTile({
    required this.label,
    required this.value,
    required this.startColor,
    required this.endColor,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor.withOpacity(0.18), endColor.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: startColor.withOpacity(0.38), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // icon column
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: startColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: startColor),
            ),
            const SizedBox(width: 12),

            // content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value.isNotEmpty ? value : '—',
                    style: const TextStyle(color: Colors.white70, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThoughtCountBadge extends StatelessWidget {
  final int count;

  const ThoughtCountBadge(this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class GlowPulse extends StatefulWidget {
  final Widget child;
  final Color color;

  const GlowPulse({required this.child, required this.color, super.key});

  @override
  State<GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<GlowPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(_opacity.value),
                ),
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}
