// lib/screens/abcd_worksheet.dart
// Improved ABCD worksheet page — local-only storage using shared_preferences.
// Dark teal theme + tutorial bottom sheet with EN/HI toggle.
// Tutorial expanded to include CBT concepts and a sample walkthrough.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kStorageKey = 'abcd_worksheets_v1';
final _uuid = Uuid();

// Teal palette (kept consistent)
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

/// Reusable text field with teal focus styling (dark theme)
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

  // tutorial language: false = EN, true = HI
  bool _tutorialInHindi = false;

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
        backgroundColor: cardDark,
        title: const Text('Delete worksheet?'),
        content: const Text(
          'This will permanently delete the worksheet from local storage.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
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
                      // drag handle
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        height: 5,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white24,
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
                                hint:
                                    'Describe what happened (who, when, where)',
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
                                            color: Colors.white70,
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
                                            color: Colors.white70,
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

  Widget _buildListTile(AbcdWorksheet item) {
    final dateStr = MaterialLocalizations.of(
      context,
    ).formatFullDate(item.createdAt);
    return Card(
      color: cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        isThreeLine: true,
        title: Text(
          item.activatingEvent.isNotEmpty
              ? item.activatingEvent
              : 'ABCD worksheet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Belief: ${item.belief}\nSaved: $dateStr',
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: PopupMenuButton<String>(
          color: cardDark,
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
        backgroundColor: cardDark,
        title: const Text(
          'Worksheet detail',
          style: TextStyle(color: Colors.white),
        ),
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

  // ----- Tutorial sheet -----
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
                                  'ABCD Worksheet — Detailed CBT Tutorial',
                                  'ABCD वर्कशीट — विस्तृत CBT मार्गदर्शिका',
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

                        // language toggle
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
                                // quick tip: copy short CBT checklist to clipboard
                                final enChecklist = [
                                  '1) Identify activating event (A).',
                                  '2) Notice automatic thought (B).',
                                  '3) Record consequences (C): feelings & actions.',
                                  '4) Examine evidence for/against (Socratic questions).',
                                  '5) Generate alternative balanced thought (D).',
                                  '6) Rate mood again and plan a behavioural experiment / reminder.',
                                ].join('\n');
                                final hiChecklist = [
                                  '1) घटना (A) पहचानें।',
                                  '2) स्वचालित विचार (B) नोट करें।',
                                  '3) परिणाम (C): भावनाएँ और क्रियाएँ लिखें।',
                                  '4) प्रमाण के लिए/विरुद्ध जाँचें (सॉक्रेटिक प्रश्न)।',
                                  '5) वैकल्पिक संतुलित विचार (D) बनाएं।',
                                  '6) फिर से मूड रेट करें और व्यवहारिक प्रयोग/नोट तय करें।',
                                ].join('\n');
                                Clipboard.setData(
                                  ClipboardData(
                                    text: _tutorialInHindi
                                        ? hiChecklist
                                        : enChecklist,
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

                        const SizedBox(height: 10),

                        Text(
                          t(
                            'What is this and why CBT?',
                            'यह क्या है और CBT क्यों?',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'The ABCD worksheet is a practical CBT (Cognitive Behavioural Therapy) tool. CBT helps us notice how our thoughts influence feelings and behaviour. By writing them down we can test and change unhelpful automatic thoughts and plan actions that reduce distress.',
                            'ABCD वर्कशीट एक व्यवहारिक CBT (कॉग्निटिव बिहेवियरल थेरेपी) उपकरण है। CBT यह समझने में मदद करता है कि हमारे विचार हमारी भावनाओं और व्यवहार को कैसे प्रभावित करते हैं। लिखने से हम उन स्वचालित विचारों का परीक्षण कर सकते हैं और उन्हें बदलने के तरीके ढूंढ सकते हैं।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t(
                            'Core CBT ideas (short)',
                            'CBT के मुख्य विचार (संक्षेप)',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _bulletItem(
                          Icons.lightbulb,
                          t(
                            'Automatic thoughts are quick, often unexamined reactions to events.',
                            'स्वचालित विचार तीव्र, जल्दी आने वाले और अक्सर बिना जाँच के होते हैं।',
                          ),
                        ),
                        _bulletItem(
                          Icons.filter_alt,
                          t(
                            'Cognitive distortions are predictable thinking errors (e.g. all-or-nothing, mind-reading, catastrophising).',
                            'कॉग्निटिव डिस्टॉर्शन सोच की सामान्य गलतियाँ हैं (जैसे सब-या-कुछ नहीं, दिमाग पढ़ना, तबाही का अनुमान)।',
                          ),
                        ),
                        _bulletItem(
                          Icons.search,
                          t(
                            'Socratic questioning helps you examine evidence for and against a thought.',
                            'सॉक्रेटिक प्रश्न आपको किसी विचार के पक्ष/विपक्ष के प्रमाण जांचने में मदद करते हैं।',
                          ),
                        ),
                        _bulletItem(
                          Icons.build,
                          t(
                            'Behavioural experiments test beliefs by trying small actions and observing results.',
                            'व्यवहारिक प्रयोग छोटे कदम उठाकर और परिणाम देखकर विश्वास का परीक्षण करते हैं।',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t(
                            'How to use this worksheet (practical steps)',
                            'वर्कशीट कैसे प्रयोग करें (व्यवहारिक कदम)',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _numberedItem(
                          1,
                          t(
                            'A — Activating event: briefly describe the situation (who, what, when, where). Be specific; avoid interpretations here — facts only.',
                            'A — घटना: संक्षेप में स्थिति बताएं (कौन, क्या, कब, कहाँ)। विशिष्ट रहें; यहाँ केवल तथ्य लिखें, व्याख्या नहीं।',
                          ),
                        ),
                        _numberedItem(
                          2,
                          t(
                            'B — Belief / Automatic thought: the immediate thought that came to mind (often short — e.g. "I messed up", "They don’t like me").',
                            'B — विश्वास/स्वचालित विचार: तत्क्षण जो विचार आया (अक्सर छोटा — जैसे "मैंने गलती कर दी", "उसे मैं पसंद नहीं हूँ")।',
                          ),
                        ),
                        _numberedItem(
                          3,
                          t(
                            'C — Consequences: list emotional & behavioural outcomes (e.g. anxiety 8/10, avoided calling, felt tearful). Rate mood (before).',
                            'C — परिणाम: भावनात्मक और व्यवहारिक परिणाम लिखें (जैसे चिंता 8/10, कॉल करने से बचा, दुख हुआ)। पहले मूड रेट करें।',
                          ),
                        ),
                        _numberedItem(
                          4,
                          t(
                            'D — Dispute / Alternative thought: examine evidence for and against the belief using Socratic questions (below) and write a kinder, balanced alternative thought.',
                            'D — विवाद/वैकल्पिक विचार: सॉक्रेटिक प्रश्नों का उपयोग करके विश्वास के पक्ष/विपक्ष के प्रमाण जांचें और एक दयालु/संतुलित वैकल्पिक विचार लिखें।',
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          t(
                            'Socratic prompts (use these while filling D)',
                            'सॉक्रेटिक प्रश्न (D भरते समय उपयोग करें)',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _bulletItem(
                          Icons.help_outline,
                          t(
                            'What is the evidence that supports this thought?',
                            'किस बात का प्रमाण है जो इस विचार का समर्थन करता है?',
                          ),
                        ),
                        _bulletItem(
                          Icons.help_outline,
                          t(
                            'What is the evidence that does NOT support it?',
                            'ऐसा क्या प्रमाण है जो इसका विरोध करता है?',
                          ),
                        ),
                        _bulletItem(
                          Icons.help_outline,
                          t(
                            'Am I jumping to conclusions or mind-reading?',
                            'क्या मैं निष्कर्ष तक जल्दी पहुँच रहा/रही हूँ या दिमाग पढ़ रहा/रही हूँ?',
                          ),
                        ),
                        _bulletItem(
                          Icons.help_outline,
                          t(
                            'Is there a less catastrophic way to view this?',
                            'क्या इसे कम भयावह तरीके से देखा जा सकता है?',
                          ),
                        ),
                        _bulletItem(
                          Icons.help_outline,
                          t(
                            'What would I tell a friend who had this thought?',
                            'यदि कोई दोस्त ऐसा कहे तो मैं उसे क्या सलाह दूँगा/दूँगी?',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t(
                            'Behavioural experiments and follow-up',
                            'व्यवहारिक प्रयोग और फॉलो-अप',
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
                            'After you write a balanced alternative thought, consider a small experiment you can try this week to test the belief (e.g. make one phone call, speak briefly to a colleague). Note results and re-rate your mood.',
                            'एक बार वैकल्पिक विचार लिखने के बाद, एक छोटा व्यवहारिक प्रयोग सोचें जिसे आप इस सप्ताह कर सकते हैं (जैसे एक फोन कॉल करना, सहकर्मी से संक्षेप में बात करना)। परिणाम नोट करें और मूड फिर से रेट करें।',
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t(
                            'Common cognitive distortions (examples)',
                            'सामान्य संज्ञानात्मक विकृतियाँ (उदाहरण)',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _bulletItem(
                          Icons.block,
                          t(
                            'All-or-nothing thinking — "If it’s not perfect, it’s a failure."',
                            'सभी-या-कुछ नहीं सोच — "यदि यह परिपूर्ण नहीं है, तो यह विफलता है"',
                          ),
                        ),
                        _bulletItem(
                          Icons.visibility_off,
                          t(
                            'Mind-reading — assuming someone thinks badly of you.',
                            'दिमाग पढ़ना — मान लेना कि कोई आपके बारे में बुरा सोचता है।',
                          ),
                        ),
                        _bulletItem(
                          Icons.warning,
                          t(
                            'Catastrophising — expecting the worst outcome.',
                            'बुरे परिणाम की आशंका — सबसे बुरा सोच लेना।',
                          ),
                        ),
                        _bulletItem(
                          Icons.timeline,
                          t(
                            'Overgeneralisation — using one incident to judge everything.',
                            'अति-व्यापकता — एक घटना के आधार पर सब कुछ जज कर देना।',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          t(
                            'Worked example (short)',
                            'व्यवहारिक उदाहरण (संक्षेप)',
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
                              'Left a meeting and noticed two colleagues whispering; thought "They were talking about me — I must have sounded stupid."',
                          hiTitle: 'स्थिति',
                          hiBody:
                              'मीटिंग छोड़ी और दो सहयोगी फुसफुसाते हुए दिखे; सोचा "वे मेरे बारे में बात कर रहे थे — मैं बेवकूफ लगा।"',
                        ),
                        const SizedBox(height: 8),
                        _exampleBlock(
                          enTitle: 'Automatic thought (B)',
                          enBody: '"I sounded stupid; they don’t respect me."',
                          hiTitle: 'स्वचालित विचार (B)',
                          hiBody: '"मैं बेवकूफ लगा; वे मेरी इज्जत नहीं करते।"',
                        ),
                        const SizedBox(height: 8),
                        _exampleBlock(
                          enTitle: 'Evidence for',
                          enBody:
                              'I heard them whisper; my voice shook slightly.',
                          hiTitle: 'समर्थक प्रमाण',
                          hiBody:
                              'मैंने फुसफुसाहट सुनी; मेरी आवाज थोड़ा कांपी थी।',
                        ),
                        const SizedBox(height: 8),
                        _exampleBlock(
                          enTitle: 'Evidence against',
                          enBody:
                              'They often chat; one later smiled and said nothing negative. No one said anything directly critical.',
                          hiTitle: 'विरोधी प्रमाण',
                          hiBody:
                              'वे अक्सर बातें करते हैं; बाद में एक ने मुस्कुराया और कुछ नकारात्मक नहीं कहा। किसी ने सीधे आलोचना नहीं की।',
                        ),
                        const SizedBox(height: 8),
                        _exampleBlock(
                          enTitle: 'Balanced alternative (D)',
                          enTitleHi: 'संतुलित वैकल्पिक विचार (D)',
                          enBody:
                              'Maybe they were talking about plans; even if I felt awkward, it doesn’t mean I’m stupid. I can follow up if needed.',
                          hiTitle: 'संतुलित वैकल्पिक विचार (D)',
                          hiBody:
                              'शायद वे योजनाओं के बारे में बात कर रहे थे; भले ही मैं थोड़ा असहज महसूस करूँ, इसका मतलब यह नहीं कि मैं बेवकूफ हूँ। ज़रूरत पड़ने पर मैं बाद में बात कर सकता/सकती हूँ।',
                        ),
                        const SizedBox(height: 12),

                        Text(
                          t('Safety & limits', 'सुरक्षा और सीमाएँ'),
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
                            'This worksheet is a self-help tool and does not replace therapy. If distress is intense or persistent, contact a mental health professional.',
                            'यह वर्कशीट स्व-मदद का उपकरण है और थेरेपी का विकल्प नहीं है। यदि कष्ट तीव्र या लगातार है, तो किसी मानसिक स्वास्थ्य पेशेवर से संपर्क करें।',
                          ),
                        ),
                        _bulletItem(
                          Icons.error_outline,
                          t(
                            'If a worksheet brings up traumatic memories or severe distress, stop and seek support — don’t try to push through alone.',
                            'यदि वर्कशीट करने से आघात संबंधी यादें या गंभीर कष्ट उठते हैं, तो रोकें और सहायता लें — अकेले इसे दबाने की कोशिश न करें।',
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
                                  t('Create worksheet', 'वर्कशीट बनाएं'),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
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
    String? enTitleHi,
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
        title: const Text('ABCD Worksheet'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: Theme.of(context).appBarTheme.systemOverlayStyle,
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
            tooltip: 'New worksheet',
          ),
        ],
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
                    Text(
                      'No saved worksheets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a new ABCD worksheet to capture a situation, your thought, and a balanced alternative.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: dimText),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _startNew,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal3,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        // You might need to adjust padding to make the wrapped text look good
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize
                            .min, // Essential to keep the button size minimal
                        children: [
                          const Icon(Icons.add),
                          const SizedBox(height: 4),
                          // Text naturally wraps if it exceeds the button's internal width
                          const Text(
                            'Create worksheet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                            ), // Smaller text helps prevent overflow
                          ),
                        ],
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
