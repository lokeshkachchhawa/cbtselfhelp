// lib/screens/thought_record_page.dart
// Thought Record page — local-only storage using shared_preferences.
// UI aligned with ABCD sheet: list view + modal bottom sheet create/edit.
// Includes reusable AppTextField.

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

/// Reusable AppTextField — neat borders, teal focus color, optional counter
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
      fillColor: Colors.white,
      isDense: true,
      counterText: showCounter ? null : '',
      hintStyle: TextStyle(color: Colors.grey.shade600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
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
        title: const Text('Delete thought record?'),
        content: const Text(
          'This will permanently delete the record from local storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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

                return Column(
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 5,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
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
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

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
                                      // close sheet after save
                                      if (mounted) Navigator.of(ctx).pop();
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
      child: Text(s, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );

  Widget _buildListTile(ThoughtRecord item) {
    final dateStr = MaterialLocalizations.of(
      context,
    ).formatFullDate(item.createdAt);
    return Card(
      child: ListTile(
        isThreeLine: true,
        title: Text(
          item.situation.isNotEmpty ? item.situation : 'Thought record',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('Thought: ${item.automaticThought}\nSaved: $dateStr'),
        trailing: PopupMenuButton<String>(
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
        title: const Text('Thought record'),
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
              ),
              const SizedBox(height: 8),
              if (item.note.isNotEmpty) _detailRow('Note', item.note),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thought Records'),
        backgroundColor: teal4,
        actions: [
          IconButton(
            onPressed: _startNew,
            icon: const Icon(Icons.add),
            tooltip: 'New thought record',
          ),
        ],
        // REMOVE the IconButton here (if present) so add action is only via FAB
        // actions: [ IconButton(...) ],  <-- remove this line
      ),

      // <-- ADD the FAB here. Tapping it calls _startNew() which opens the bottom sheet.
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
                    const Text(
                      'No saved thought records',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a new thought record to capture a situation and work through it.',
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _startNew,
                      icon: const Icon(Icons.add),
                      label: const Text('Create thought'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                itemBuilder: (_, i) => _buildListTile(_items[i]),
              ),
            ),
    );
  }
}
