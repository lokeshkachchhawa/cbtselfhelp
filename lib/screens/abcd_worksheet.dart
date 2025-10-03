// lib/screens/abcd_worksheet.dart
// Improved ABCD worksheet page — local-only storage using shared_preferences.
// Matches ThoughtRecord style: AppTextField, teal theme, FAB, 90% modal bottom sheet.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kStorageKey = 'abcd_worksheets_v1';
final _uuid = Uuid();

// Teal palette (keep consistent with app)
const Color teal1 = Color(0xFFC6EDED);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

/// Reusable text field with teal focus styling (same as ThoughtRecord)
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

// ---------------- Domain model & local storage ----------------

class AbcdWorksheet {
  final String id;
  final String activatingEvent;
  final String belief;
  final String consequences;
  final String dispute;
  final int beforeMood;
  final int afterMood;
  final String note;
  final DateTime createdAt;

  AbcdWorksheet({
    required this.id,
    required this.activatingEvent,
    required this.belief,
    required this.consequences,
    required this.dispute,
    required this.beforeMood,
    required this.afterMood,
    required this.note,
    required this.createdAt,
  });

  AbcdWorksheet copyWith({
    String? activatingEvent,
    String? belief,
    String? consequences,
    String? dispute,
    int? beforeMood,
    int? afterMood,
    String? note,
  }) {
    return AbcdWorksheet(
      id: id,
      activatingEvent: activatingEvent ?? this.activatingEvent,
      belief: belief ?? this.belief,
      consequences: consequences ?? this.consequences,
      dispute: dispute ?? this.dispute,
      beforeMood: beforeMood ?? this.beforeMood,
      afterMood: afterMood ?? this.afterMood,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'activatingEvent': activatingEvent,
    'belief': belief,
    'consequences': consequences,
    'dispute': dispute,
    'beforeMood': beforeMood,
    'afterMood': afterMood,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  static AbcdWorksheet fromMap(Map<String, dynamic> m) {
    int _parseInt(dynamic v, [int fallback = 5]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return AbcdWorksheet(
      id: m['id'] as String,
      activatingEvent: m['activatingEvent'] as String? ?? '',
      belief: m['belief'] as String? ?? '',
      consequences: m['consequences'] as String? ?? '',
      dispute: m['dispute'] as String? ?? '',
      beforeMood: _parseInt(m['beforeMood']),
      afterMood: _parseInt(m['afterMood']),
      note: m['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AbcdStorage {
  Future<List<AbcdWorksheet>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kStorageKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
      return list
          .map(
            (e) => AbcdWorksheet.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<AbcdWorksheet> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(items.map((e) => e.toMap()).toList());
    await prefs.setString(_kStorageKey, jsonStr);
  }

  Future<void> add(AbcdWorksheet item) async {
    final all = await loadAll();
    all.insert(0, item); // newest first
    await saveAll(all);
  }

  Future<void> update(AbcdWorksheet item) async {
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
}

// ---------------- Page UI ----------------

class AbcdWorksheetPage extends StatefulWidget {
  const AbcdWorksheetPage({super.key});

  @override
  State<AbcdWorksheetPage> createState() => _AbcdWorksheetPageState();
}

class _AbcdWorksheetPageState extends State<AbcdWorksheetPage> {
  final _storage = AbcdStorage();

  // controllers
  final _activatingCtrl = TextEditingController();
  final _beliefCtrl = TextEditingController();
  final _consequencesCtrl = TextEditingController();
  final _disputeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  int _beforeMood = 5;
  int _afterMood = 5;

  bool _loading = true;
  List<AbcdWorksheet> _items = [];
  AbcdWorksheet? _editing;

  // auto-open guard (if route passes open:true)
  bool _didAutoOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoOpen) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && (args['open'] == true || args['open'] == 'true')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startNew();
        });
        _didAutoOpen = true;
      }
    }
  }

  @override
  void dispose() {
    _activatingCtrl.dispose();
    _beliefCtrl.dispose();
    _consequencesCtrl.dispose();
    _disputeCtrl.dispose();
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
      _activatingCtrl.clear();
      _beliefCtrl.clear();
      _consequencesCtrl.clear();
      _disputeCtrl.clear();
      _noteCtrl.clear();
      _beforeMood = 5;
      _afterMood = 5;
    });
    _showFormSheet();
  }

  void _startEdit(AbcdWorksheet item) {
    setState(() {
      _editing = item;
      _activatingCtrl.text = item.activatingEvent;
      _beliefCtrl.text = item.belief;
      _consequencesCtrl.text = item.consequences;
      _disputeCtrl.text = item.dispute;
      _noteCtrl.text = item.note;
      _beforeMood = item.beforeMood;
      _afterMood = item.afterMood;
    });
    _showFormSheet();
  }

  Future<void> _saveFromForm() async {
    final activating = _activatingCtrl.text.trim();
    final belief = _beliefCtrl.text.trim();
    final consequences = _consequencesCtrl.text.trim();
    final dispute = _disputeCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (activating.isEmpty || belief.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the event and belief fields'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (_editing != null) {
      final updated = _editing!.copyWith(
        activatingEvent: activating,
        belief: belief,
        consequences: consequences,
        dispute: dispute,
        beforeMood: _beforeMood,
        afterMood: _afterMood,
        note: note,
      );
      await _storage.update(updated);
    } else {
      final newItem = AbcdWorksheet(
        id: _uuid.v4(),
        activatingEvent: activating,
        belief: belief,
        consequences: consequences,
        dispute: dispute,
        beforeMood: _beforeMood,
        afterMood: _afterMood,
        note: note,
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
        title: const Text('Delete worksheet?'),
        content: const Text(
          'This will permanently delete the worksheet from local storage.',
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

        // local slider copies so the sliders update instantly inside the sheet
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
                    // drag handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 5,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // header row
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
                                  ? 'Edit worksheet'
                                  : 'New ABCD worksheet',
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

                    // form (scrollable)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _fieldLabel('A — Activating event'),
                            AppTextField(
                              controller: _activatingCtrl,
                              hint: 'Describe what happened (who, when, where)',
                              minLines: 2,
                              maxLines: 5,
                              maxLength: 800,
                              showCounter: true,
                              autofocus: _editing == null,
                            ),
                            const SizedBox(height: 10),

                            _fieldLabel('B — Belief / Automatic thought'),
                            AppTextField(
                              controller: _beliefCtrl,
                              hint: 'What thought went through your mind?',
                              minLines: 1,
                              maxLines: 3,
                              maxLength: 400,
                              showCounter: true,
                            ),
                            const SizedBox(height: 10),

                            _fieldLabel(
                              'C — Consequences (feelings & actions)',
                            ),
                            AppTextField(
                              controller: _consequencesCtrl,
                              hint: 'How did you feel or behave?',
                              minLines: 2,
                              maxLines: 4,
                              maxLength: 800,
                              showCounter: true,
                            ),
                            const SizedBox(height: 10),

                            _fieldLabel('D — Dispute / Alternative thought'),
                            AppTextField(
                              controller: _disputeCtrl,
                              hint: 'A kinder or more balanced thought',
                              minLines: 2,
                              maxLines: 4,
                              maxLength: 600,
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

                            AppTextField(
                              controller: _noteCtrl,
                              hint: 'Optional note / strategy / reminder',
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 400,
                              showCounter: true,
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      // write modal-local values back to parent and save
                                      setState(() {
                                        _beforeMood = localBefore;
                                        _afterMood = localAfter;
                                      });
                                      await _saveFromForm();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: teal4,
                                    ),
                                    child: const Text('Save locally'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (_editing != null)
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

  Widget _buildListTile(AbcdWorksheet item) {
    final dateStr = MaterialLocalizations.of(
      context,
    ).formatFullDate(item.createdAt);
    return Card(
      child: ListTile(
        isThreeLine: true,
        title: Text(
          item.activatingEvent.isNotEmpty
              ? item.activatingEvent
              : 'ABCD worksheet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('Belief: ${item.belief}\nSaved: $dateStr'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _startEdit(item);
            if (v == 'delete') _deleteItem(item.id);
            if (v == 'share') {
              final txt = [
                'ABCD worksheet',
                'A: ${item.activatingEvent}',
                'B: ${item.belief}',
                'C: ${item.consequences}',
                'D: ${item.dispute}',
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

  void _showDetail(AbcdWorksheet item) {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Worksheet detail'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('A — Event', item.activatingEvent),
              const SizedBox(height: 8),
              _detailRow('B — Belief', item.belief),
              const SizedBox(height: 8),
              _detailRow('C — Consequences', item.consequences),
              const SizedBox(height: 8),
              _detailRow('D — Dispute', item.dispute),
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
        title: const Text('ABCD Worksheet'),
        backgroundColor: teal4,
        actions: [
          IconButton(
            onPressed: _startNew,
            icon: const Icon(Icons.add),
            tooltip: 'New worksheet',
          ),
        ],
        // add button moved to FAB
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNew,
        icon: const Icon(Icons.add),
        label: const Text('New worksheet'),
        backgroundColor: teal3,
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
                      'No saved worksheets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a new ABCD worksheet to capture a situation, your thought, and a balanced alternative.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _startNew,
                      icon: const Icon(Icons.add),
                      label: const Text('Create worksheet'),
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
