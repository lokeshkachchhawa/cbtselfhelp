// updated_abcd_worksheets.dart
import 'dart:convert';
import 'package:cbt_drktv/services/chat_share.dart';
import 'package:cbt_drktv/widgets/abcd_tutorial_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kStorageKey = 'ABCDE_worksheets_v1';
const String _kExampleIdsKey = 'ABCDE_example_ids_v1';
const String _kExamplesImportedFlag = 'ABCDE_examples_imported_v1';
const String _kLegacyExampleIdKey = 'ABCDE_example_id_v1';

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

const Color colorA = Color(0xFFE57373); // Light Red/Coral for Activating Event
const Color colorB = Color(0xFFFDD835); // Amber/Yellow for Beliefs
const Color colorC = Color(0xFF64B5F6); // Light Blue for Consequences
const Color colorD = Color(0xFF81C784); // Light Green for Dispute
const Color colorE = Color(0xFFFFB74D); // Orange for Effects
const Color countBackgroundColor = Colors.green;
const Color countTextColor = Colors.white;

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
      counterStyle: const TextStyle(color: Colors.white),
      hintStyle: const TextStyle(color: Colors.white38),
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

class ABCDEWorksheet {
  final String id;
  final String activatingEvent;
  final String belief;
  final String consequencesEmotional;
  final String consequencesPsychological;
  final String consequencesPhysical;
  final String consequencesBehavioural;
  final String dispute;
  final String emotionalEffect;
  final String psychologicalEffect;
  final String physicalEffect;
  final String behaviouralEffect;
  final String note;
  final DateTime createdAt;

  // NEW
  final bool isExample;

  ABCDEWorksheet({
    required this.id,
    required this.activatingEvent,
    required this.belief,
    required this.consequencesEmotional,
    required this.consequencesPsychological,
    required this.consequencesPhysical,
    required this.consequencesBehavioural,
    required this.dispute,
    required this.emotionalEffect,
    required this.psychologicalEffect,
    required this.physicalEffect,
    required this.behaviouralEffect,
    required this.note,
    required this.createdAt,
    this.isExample = false, // default: user-created
  });

  ABCDEWorksheet copyWith({
    String? activatingEvent,
    String? belief,
    String? consequencesEmotional,
    String? consequencesPsychological,
    String? consequencesPhysical,
    String? consequencesBehavioural,
    String? dispute,
    String? emotionalEffect,
    String? psychologicalEffect,
    String? physicalEffect,
    String? behaviouralEffect,
    String? note,
    bool? isExample, // NEW
  }) {
    return ABCDEWorksheet(
      id: id,
      activatingEvent: activatingEvent ?? this.activatingEvent,
      belief: belief ?? this.belief,
      consequencesEmotional:
          consequencesEmotional ?? this.consequencesEmotional,
      consequencesPsychological:
          consequencesPsychological ?? this.consequencesPsychological,
      consequencesPhysical: consequencesPhysical ?? this.consequencesPhysical,
      consequencesBehavioural:
          consequencesBehavioural ?? this.consequencesBehavioural,
      dispute: dispute ?? this.dispute,
      emotionalEffect: emotionalEffect ?? this.emotionalEffect,
      psychologicalEffect: psychologicalEffect ?? this.psychologicalEffect,
      physicalEffect: physicalEffect ?? this.physicalEffect,
      behaviouralEffect: behaviouralEffect ?? this.behaviouralEffect,
      note: note ?? this.note,
      createdAt: createdAt,
      isExample: isExample ?? this.isExample,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'activatingEvent': activatingEvent,
    'belief': belief,
    'consequencesEmotional': consequencesEmotional,
    'consequencesPsychological': consequencesPsychological,
    'consequencesPhysical': consequencesPhysical,
    'consequencesBehavioural': consequencesBehavioural,
    'dispute': dispute,
    'emotionalEffect': emotionalEffect,
    'psychologicalEffect': psychologicalEffect,
    'physicalEffect': physicalEffect,
    'behaviouralEffect': behaviouralEffect,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'isExample': isExample, // NEW
  };

  static ABCDEWorksheet fromMap(Map<String, dynamic> m) {
    // …your legacy compose code stays the same…
    final legacyBelEmo = m['beliefEmotional'] as String?;
    final legacyBelPsy = m['beliefPsychological'] as String?;
    final legacyBelPhy = m['beliefPhysical'] as String?;
    final legacyBelBeh = m['beliefBehavioural'] as String?;

    String composedBelief =
        (m['belief'] as String?) ??
        ([
          if ((legacyBelEmo ?? '').trim().isNotEmpty)
            'Emo: ${legacyBelEmo!.trim()}',
          if ((legacyBelPsy ?? '').trim().isNotEmpty)
            'Psy: ${legacyBelPsy!.trim()}',
          if ((legacyBelPhy ?? '').trim().isNotEmpty)
            'Phy: ${legacyBelPhy!.trim()}',
          if ((legacyBelBeh ?? '').trim().isNotEmpty)
            'Beh: ${legacyBelBeh!.trim()}',
        ].join(' | '));

    final legacyConsequences = m['consequences'] as String?;

    return ABCDEWorksheet(
      id: m['id'] as String,
      activatingEvent: m['activatingEvent'] as String? ?? '',
      belief: composedBelief,
      consequencesEmotional:
          m['consequencesEmotional'] as String? ?? legacyConsequences ?? '',
      consequencesPsychological:
          m['consequencesPsychological'] as String? ?? '',
      consequencesPhysical: m['consequencesPhysical'] as String? ?? '',
      consequencesBehavioural: m['consequencesBehavioural'] as String? ?? '',
      dispute: m['dispute'] as String? ?? '',
      emotionalEffect: m['emotionalEffect'] as String? ?? '',
      psychologicalEffect: m['psychologicalEffect'] as String? ?? '',
      physicalEffect: m['physicalEffect'] as String? ?? '',
      behaviouralEffect: m['behaviouralEffect'] as String? ?? '',
      note: m['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      isExample:
          (m['isExample'] as bool?) ?? false, // NEW (defaults to user item)
    );
  }
}

class ABCDEStorage {
  Future<List<ABCDEWorksheet>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kStorageKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
      return list
          .map(
            (e) => ABCDEWorksheet.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<ABCDEWorksheet> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(items.map((e) => e.toMap()).toList());
    await prefs.setString(_kStorageKey, jsonStr);
  }

  Future<void> add(ABCDEWorksheet item) async {
    final all = await loadAll();
    all.insert(0, item); // newest first
    await saveAll(all);
  }

  Future<void> update(ABCDEWorksheet item) async {
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

  Future<List<ABCDEWorksheet>> loadUserOnly() async {
    final all = await loadAll();
    return all.where((w) => !w.isExample).toList();
  }
}

// ---------------- Page UI ----------------

class ABCDEWorksheetPage extends StatefulWidget {
  const ABCDEWorksheetPage({super.key});

  @override
  State<ABCDEWorksheetPage> createState() => _ABCDEWorksheetPageState();
}

class _ABCDEWorksheetPageState extends State<ABCDEWorksheetPage>
    with TickerProviderStateMixin {
  final _storage = ABCDEStorage();

  // controllers
  final _activatingCtrl = TextEditingController();

  // B — belief controller (single)
  final _beliefCtrl = TextEditingController();

  // C — consequences controllers (four types)
  final _consecEmoCtrl = TextEditingController();
  final _consecPsyCtrl = TextEditingController();
  final _consecPhyCtrl = TextEditingController();
  final _consecBehCtrl = TextEditingController();

  final _disputeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // E controllers (four thought types)
  final _emoCtrl = TextEditingController();
  final _psyCtrl = TextEditingController();
  final _phyCtrl = TextEditingController();
  final _behCtrl = TextEditingController();

  late final TabController _effectsTabController;
  late final TabController _consequencesTabController;
  late final TabController _mainTabController;

  // multiple example ids support
  Set<String> _exampleIds = {};

  bool _loading = true;
  List<ABCDEWorksheet> _items = [];
  ABCDEWorksheet? _editing;

  // auto-open guard (if route passes open:true)
  bool _didAutoOpen = false;

  // tutorial language: false = EN, true = HI
  bool _tutorialInHindi = false;

  @override
  void initState() {
    super.initState();
    _effectsTabController = TabController(length: 4, vsync: this);
    _consequencesTabController = TabController(length: 4, vsync: this);
    _mainTabController = TabController(length: 2, vsync: this); // <-- new
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
    _consecEmoCtrl.dispose();
    _consecPsyCtrl.dispose();
    _consecPhyCtrl.dispose();
    _consecBehCtrl.dispose();
    _disputeCtrl.dispose();
    _noteCtrl.dispose();
    _emoCtrl.dispose();
    _psyCtrl.dispose();
    _phyCtrl.dispose();
    _behCtrl.dispose();
    _effectsTabController.dispose();
    _consequencesTabController.dispose();
    _mainTabController.dispose();

    super.dispose();
  }

  // Helper: build an ABCDEWorksheet from JSON map ensuring id & createdAt exist
  // Helper: build an ABCDEWorksheet from JSON map ensuring id & createdAt exist
  ABCDEWorksheet _worksheetFromJsonMap(
    Map<String, dynamic> m, {
    bool asExample = false,
  }) {
    final id = (m['id'] as String?) ?? _uuid.v4();
    final mapCopy = Map<String, dynamic>.from(m);
    mapCopy['id'] = id;
    mapCopy['createdAt'] =
        mapCopy['createdAt'] ?? DateTime.now().toIso8601String();
    mapCopy['isExample'] = asExample; // NEW
    return ABCDEWorksheet.fromMap(mapCopy);
  }

  void _startNewWithPrefill(ABCDEWorksheet from) {
    setState(() {
      _editing = null; // important: new item, not editing!
      _activatingCtrl.text = from.activatingEvent;
      _beliefCtrl.text = from.belief;
      _consecEmoCtrl.text = from.consequencesEmotional;
      _consecPsyCtrl.text = from.consequencesPsychological;
      _consecPhyCtrl.text = from.consequencesPhysical;
      _consecBehCtrl.text = from.consequencesBehavioural;
      _disputeCtrl.text = from.dispute;
      _noteCtrl.text = from.note;
      _emoCtrl.text = from.emotionalEffect;
      _psyCtrl.text = from.psychologicalEffect;
      _phyCtrl.text = from.physicalEffect;
      _behCtrl.text = from.behaviouralEffect;
      _effectsTabController.index = 0;
      _consequencesTabController.index = 0;
    });
    _showFormSheet();
  }

  /// Import examples from asset JSON once (idempotent)
  Future<void> _importExamplesFromAssetsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final imported = prefs.getBool(_kExamplesImportedFlag) ?? false;
    if (imported) {
      // read persisted example ids if present
      final saved = prefs.getStringList(_kExampleIdsKey);
      if (saved != null) _exampleIds = saved.toSet();
      return;
    }

    try {
      final jsonStr = await rootBundle.loadString('assets/abcd_examples.json');
      final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
      final examples = list
          .map(
            (e) => _worksheetFromJsonMap(
              Map<String, dynamic>.from(e as Map),
              asExample: true,
            ),
          )
          .toList();

      final existing = (await _storage.loadAll()).map((e) => e.id).toSet();

      for (final ex in examples) {
        if (!existing.contains(ex.id)) {
          await _storage.add(ex);
        }
        _exampleIds.add(ex.id);
      }

      await prefs.setStringList(_kExampleIdsKey, _exampleIds.toList());
      await prefs.setBool(_kExamplesImportedFlag, true);
    } catch (e) {
      debugPrint('Failed to import example worksheets from assets: $e');
    }
  }

  /// Migration for older installs that used a single example id key
  Future<void> _runLegacyMigrationIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_kLegacyExampleIdKey);
    if (legacy != null && legacy.isNotEmpty) {
      final saved = prefs.getStringList(_kExampleIdsKey) ?? <String>[];
      if (!saved.contains(legacy)) {
        saved.add(legacy);
        await prefs.setStringList(_kExampleIdsKey, saved);
      }
      _exampleIds = saved.toSet();
    } else {
      // if no legacy but there is saved set, read it
      final saved = prefs.getStringList(_kExampleIdsKey);
      if (saved != null) _exampleIds = saved.toSet();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // migration
    await _runLegacyMigrationIfNeeded();

    // import examples from assets if needed
    await _importExamplesFromAssetsIfNeeded();

    // now load stored items
    final items = await _storage.loadAll();

    // refresh _exampleIds from prefs in case anything changed
    final prefs = await SharedPreferences.getInstance();
    final savedExampleIds = prefs.getStringList(_kExampleIdsKey);
    if (savedExampleIds != null) _exampleIds = savedExampleIds.toSet();

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
      _consecEmoCtrl.clear();
      _consecPsyCtrl.clear();
      _consecPhyCtrl.clear();
      _consecBehCtrl.clear();
      _disputeCtrl.clear();
      _noteCtrl.clear();
      _emoCtrl.clear();
      _psyCtrl.clear();
      _phyCtrl.clear();
      _behCtrl.clear();
      _effectsTabController.index = 0;
      _consequencesTabController.index = 0;
    });
    _showFormSheet();
  }

  void _startEdit(ABCDEWorksheet item) {
    if (item.isExample) {
      // Use example → create a fresh, user-owned draft
      _startNewWithPrefill(item);
      return;
    }
    // normal edit for user-owned items
    setState(() {
      _editing = item;
      _activatingCtrl.text = item.activatingEvent;
      _beliefCtrl.text = item.belief;
      _consecEmoCtrl.text = item.consequencesEmotional;
      _consecPsyCtrl.text = item.consequencesPsychological;
      _consecPhyCtrl.text = item.consequencesPhysical;
      _consecBehCtrl.text = item.consequencesBehavioural;
      _disputeCtrl.text = item.dispute;
      _noteCtrl.text = item.note;
      _emoCtrl.text = item.emotionalEffect;
      _psyCtrl.text = item.psychologicalEffect;
      _phyCtrl.text = item.physicalEffect;
      _behCtrl.text = item.behaviouralEffect;
      _effectsTabController.index = 0;
      _consequencesTabController.index = 0;
    });
    _showFormSheet();
  }

  // wraps a child with a subtle border and a left color stripe
  Widget _sectionWrapper({required Widget child, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: color.withOpacity(0.95),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(8.0), child: child),
          ),
        ],
      ),
    );
  }

  // convenience helper to render header + field inside a colored wrapper
  Widget _sectionLabelAndField({
    required String letter,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return _sectionWrapper(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerLabel(letter, title, color),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Future<void> _saveFromForm() async {
    final activating = _activatingCtrl.text.trim();
    final belief = _beliefCtrl.text.trim();

    final consecEmo = _consecEmoCtrl.text.trim();
    final consecPsy = _consecPsyCtrl.text.trim();
    final consecPhy = _consecPhyCtrl.text.trim();
    final consecBeh = _consecBehCtrl.text.trim();

    final dispute = _disputeCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    final emo = _emoCtrl.text.trim();
    final psy = _psyCtrl.text.trim();
    final phy = _phyCtrl.text.trim();
    final beh = _behCtrl.text.trim();

    if (activating.isEmpty || belief.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the event and the belief field'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (_editing != null) {
      final updated = _editing!.copyWith(
        activatingEvent: activating,
        belief: belief,
        consequencesEmotional: consecEmo,
        consequencesPsychological: consecPsy,
        consequencesPhysical: consecPhy,
        consequencesBehavioural: consecBeh,
        dispute: dispute,
        emotionalEffect: emo,
        psychologicalEffect: psy,
        physicalEffect: phy,
        behaviouralEffect: beh,
        note: note,
      );
      await _storage.update(updated);
    } else {
      final newItem = ABCDEWorksheet(
        id: _uuid.v4(),
        activatingEvent: activating,
        belief: belief,
        consequencesEmotional: consecEmo,
        consequencesPsychological: consecPsy,
        consequencesPhysical: consecPhy,
        consequencesBehavioural: consecBeh,
        dispute: dispute,
        emotionalEffect: emo,
        psychologicalEffect: psy,
        physicalEffect: phy,
        behaviouralEffect: beh,
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
    // Prevent deletion of any built-in example
    if (_exampleIds.contains(id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This is an example worksheet and cannot be deleted.',
            ),
          ),
        );
      }
      return;
    }

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

        return FractionallySizedBox(
          heightFactor: 0.9,
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
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _editing != null ? 'Edit ' : 'New ',
                                      style: const TextStyle(
                                        color: Color.fromARGB(
                                          255,
                                          86,
                                          240,
                                          225,
                                        ),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'A',
                                      style: TextStyle(color: colorA),
                                    ),
                                    TextSpan(
                                      text: 'B',
                                      style: TextStyle(color: colorB),
                                    ),
                                    TextSpan(
                                      text: 'C',
                                      style: TextStyle(color: colorC),
                                    ),
                                    TextSpan(
                                      text: 'D',
                                      style: TextStyle(color: colorD),
                                    ),
                                    TextSpan(
                                      text: 'E',
                                      style: TextStyle(color: colorE),
                                    ),
                                    const TextSpan(
                                      text: ' worksheet',
                                      style: TextStyle(
                                        color: Color.fromARGB(
                                          255,
                                          86,
                                          240,
                                          225,
                                        ),
                                      ),
                                    ),
                                  ],
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
                              // A — Activating event
                              _sectionLabelAndField(
                                letter: 'A',
                                title: 'Activating event',
                                color: colorA,
                                child: AppTextField(
                                  controller: _activatingCtrl,
                                  hint:
                                      'Describe what happened (who, when, where)',
                                  minLines: 2,
                                  maxLines: 5,
                                  maxLength: 800,
                                  showCounter: true,
                                  autofocus: _editing == null,
                                ),
                              ),

                              // B — Belief (single)
                              _sectionLabelAndField(
                                letter: 'B',
                                title: 'Belief / Automatic thought',
                                color: colorB,
                                child: AppTextField(
                                  controller: _beliefCtrl,
                                  hint:
                                      'Write the immediate thought (short — e.g. "I messed up")',
                                  minLines: 2,
                                  maxLines: 4,
                                  maxLength: 800,
                                  showCounter: true,
                                ),
                              ),

                              // C — Consequences (now four types)
                              _sectionWrapper(
                                color: colorC,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _headerLabel(
                                      'C',
                                      'Consequences (feelings & actions)',
                                      colorC,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: cardDark,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white10,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          TabBar(
                                            controller:
                                                _consequencesTabController,
                                            indicator: BoxDecoration(
                                              color: colorC,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            indicatorPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: -4,
                                                  vertical: 4,
                                                ),
                                            labelPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 4,
                                                ),
                                            labelColor: Colors.black,
                                            unselectedLabelColor:
                                                Colors.white70,
                                            tabs: const [
                                              Tab(text: 'Emotional'),
                                              Tab(text: 'Psychological'),
                                              Tab(text: 'Physical'),
                                              Tab(text: 'Behavioural'),
                                            ],
                                            isScrollable: true,
                                          ),
                                          SizedBox(
                                            height: 140,
                                            child: TabBarView(
                                              controller:
                                                  _consequencesTabController,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _consecEmoCtrl,
                                                    hint:
                                                        'Emotional consequence (how you felt)',
                                                    minLines: 3,
                                                    maxLines: 6,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _consecPsyCtrl,
                                                    hint:
                                                        'Psychological / cognitive consequence',
                                                    minLines: 3,
                                                    maxLines: 6,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _consecPhyCtrl,
                                                    hint:
                                                        'Physical consequence (tension, heart-rate)',
                                                    minLines: 3,
                                                    maxLines: 6,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _consecBehCtrl,
                                                    hint:
                                                        'Behavioural consequence (avoidance, actions)',
                                                    minLines: 3,
                                                    maxLines: 6,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // D — Dispute
                              _sectionLabelAndField(
                                letter: 'D',
                                title: 'Dispute / Alternative thought',
                                color: colorD,
                                child: AppTextField(
                                  controller: _disputeCtrl,
                                  hint: 'A kinder or more balanced thought',
                                  minLines: 2,
                                  maxLines: 4,
                                  maxLength: 600,
                                  showCounter: true,
                                ),
                              ),

                              // E — Effects
                              _sectionWrapper(
                                color: colorE,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _headerLabel(
                                      'E',
                                      'Effects (four types)',
                                      colorE,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: cardDark,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white10,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          TabBar(
                                            controller: _effectsTabController,
                                            indicator: BoxDecoration(
                                              color: colorE,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            indicatorPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: -4,
                                                  vertical: 4,
                                                ),
                                            labelColor: Colors.black,
                                            unselectedLabelColor:
                                                Colors.white70,
                                            tabs: const [
                                              Tab(text: 'Emotional'),
                                              Tab(text: 'Psychological'),
                                              Tab(text: 'Physical'),
                                              Tab(text: 'Behavioural'),
                                            ],
                                            isScrollable: true,
                                          ),
                                          SizedBox(
                                            height: 140,
                                            child: TabBarView(
                                              controller: _effectsTabController,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _emoCtrl,
                                                    hint:
                                                        'Emotional thoughts / feelings',
                                                    minLines: 3,
                                                    maxLines: 6,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _psyCtrl,
                                                    hint:
                                                        'Psychological / cognitive reactions',
                                                    minLines: 3,
                                                    maxLines: 6,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _phyCtrl,
                                                    hint:
                                                        'Physical sensations (tension, heart-rate)',
                                                    minLines: 3,
                                                    maxLines: 6,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _behCtrl,
                                                    hint:
                                                        'Behavioural responses (avoidance, actions)',
                                                    minLines: 3,
                                                    maxLines: 6,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

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

  /// Share a structured ABCDE worksheet directly to the doctor chat.
  /// Used when user taps "Share with Doctor" in worksheet page.

  // 1. Refactored Widget: _HeaderLabel
  // Replace existing _headerLabel with this color-aware version
  Widget _headerLabel(String letter, String labelText, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Colored large letter
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: accentColor,
                height: 1.0,
              ),
            ),
          ),

          // Label Text
          Text(
            labelText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _beliefSummaryWidget(ABCDEWorksheet item) {
    // --- Define colors same as in detail sheet ---
    const colorA = Color(0xFFFF6F61); // Coral / reddish
    const colorB = Color(0xFFFFC107); // Amber
    const colorC = Color(0xFF29B6F6); // Light Blue
    const colorD = Color(0xFF81C784); // Light Green
    const colorE = Color(0xFFFFA726); // Orange

    String firstLine(String? s, {int maxLen = 80}) {
      if (s == null) return '';
      final trimmed = s.trim();
      if (trimmed.isEmpty) return '';
      final lines = trimmed.split(RegExp(r'\r?\n'));
      final fl = lines.first.trim();
      if (fl.length <= maxLen) return fl;
      return fl.substring(0, maxLen - 1).trim() + '…';
    }

    // Collect section text
    final sections = <Map<String, dynamic>>[];

    final a = firstLine(item.activatingEvent);
    if (a.isNotEmpty)
      sections.add({'label': 'A — Event', 'text': a, 'color': colorA});

    final b = firstLine(item.belief);
    if (b.isNotEmpty)
      sections.add({'label': 'B — Belief', 'text': b, 'color': colorB});

    // Build short consequences summary by joining present parts
    final cParts = <String>[];
    final cEmo = firstLine(item.consequencesEmotional);
    final cPsy = firstLine(item.consequencesPsychological);
    final cPhy = firstLine(item.consequencesPhysical);
    final cBeh = firstLine(item.consequencesBehavioural);
    if (cEmo.isNotEmpty) cParts.add('Emo: $cEmo');
    if (cPsy.isNotEmpty) cParts.add('Psy: $cPsy');
    if (cPhy.isNotEmpty) cParts.add('Phy: $cPhy');
    if (cBeh.isNotEmpty) cParts.add('Beh: $cBeh');
    if (cParts.isNotEmpty) {
      sections.add({
        'label': 'C — Consequences',
        'text': cParts.join(' | '),
        'color': colorC,
      });
    }

    final d = firstLine(item.dispute);
    if (d.isNotEmpty)
      sections.add({'label': 'D — Dispute', 'text': d, 'color': colorD});

    final eParts = <String>[];
    final eEmo = firstLine(item.emotionalEffect);
    final ePsy = firstLine(item.psychologicalEffect);
    final ePhy = firstLine(item.physicalEffect);
    final eBeh = firstLine(item.behaviouralEffect);
    if (eEmo.isNotEmpty) eParts.add('Emo: $eEmo');
    if (ePsy.isNotEmpty) eParts.add('Psy: $ePsy');
    if (ePhy.isNotEmpty) eParts.add('Phy: $ePhy');
    if (eBeh.isNotEmpty) eParts.add('Beh: $eBeh');
    if (eParts.isNotEmpty) {
      sections.add({
        'label': 'E — Effects',
        'text': eParts.join(' | '),
        'color': colorE,
      });
    }

    if (sections.isEmpty) {
      return const Text(
        'Empty',
        style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${s['label']}: ',
                    style: TextStyle(
                      color: s['color'] as Color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  TextSpan(
                    text: s['text'] as String,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPopupMenu(ABCDEWorksheet item) {
    final isExample = _exampleIds.contains(item.id);

    return PopupMenuButton<String>(
      color: Colors.white,
      icon: const Icon(Icons.more_vert, color: Colors.white54),
      onSelected: (v) async {
        if (v == 'edit') {
          _startEdit(item);
        } else if (v == 'delete') {
          _deleteItem(item.id);
        } else if (v == 'share') {
          final txt = [
            'ABCDE worksheet',
            'A: ${item.activatingEvent}',
            'B — Belief: ${item.belief}',
            'C — Consequences:',
            '  Emotional: ${item.consequencesEmotional}',
            '  Psychological: ${item.consequencesPsychological}',
            '  Physical: ${item.consequencesPhysical}',
            '  Behavioural: ${item.consequencesBehavioural}',
            'D: ${item.dispute}',
            'E — Effects:',
            '  Emotional: ${item.emotionalEffect}',
            '  Psychological: ${item.psychologicalEffect}',
            '  Physical: ${item.physicalEffect}',
            '  Behavioural: ${item.behaviouralEffect}',
            if (item.note.isNotEmpty) 'Note: ${item.note}',
          ].join('\n');
          await Clipboard.setData(ClipboardData(text: txt));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied to clipboard (for sharing)'),
              ),
            );
          }
        } else if (v == 'share_doctor') {
          try {
            await ChatShare.sendAbcdeWorksheetToDoctor(item.toMap());
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Worksheet shared with doctor')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to share with doctor: $e')),
              );
            }
          }
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'share', child: Text('Copy for share')),
          const PopupMenuItem(
            value: 'share_doctor',
            child: Text('Share with Doctor'),
          ),
        ];

        // Add delete only if not the example
        if (!isExample) {
          items.add(
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          );
        } else {
          // Optionally show a disabled Delete menu entry (visual hint)
          items.add(
            const PopupMenuItem(
              enabled: false,
              value: 'delete_disabled',
              child: Text(
                'Delete (not allowed)',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return items;
      },
    );
  }

  Widget _buildListTile(ABCDEWorksheet item) {
    final titleText = item.activatingEvent.isNotEmpty
        ? item.activatingEvent
        : 'ABCDE worksheet';
    final dateStr = MaterialLocalizations.of(
      context,
    ).formatFullDate(item.createdAt);

    return Card(
      color: cardDark,
      margin: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 3.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10, width: 0.8),
      ),
      elevation: 3,
      child: InkWell(
        onTap: () => _showDetail(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, right: 12.0),
                    child: Icon(Icons.flash_on, color: Colors.yellow, size: 24),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_exampleIds.contains(item.id))
                          Container(
                            margin: const EdgeInsets.only(left: 8.0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Text(
                              'Example',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildPopupMenu(item),
                ],
              ),

              const Divider(
                color: Colors.white10,
                height: 16,
                indent: 16,
                endIndent: 16,
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 12.0,
                  right: 16.0,
                  bottom: 4.0,
                ),
                child: Row(
                  children: [Expanded(child: _beliefSummaryWidget(item))],
                ),
              ),
              // Show date only for non-example worksheets
              if (!_exampleIds.contains(item.id))
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white38,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListForItems(List<ABCDEWorksheet> items) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No worksheets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: mutedText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a new ABCDE worksheet to capture a situation, your thought, and a balanced alternative.',
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
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add),
                    SizedBox(height: 4),
                    Text(
                      'Create worksheet',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      backgroundColor: cardDark,
      color: teal2,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: _buildListTile(items[i]),
        ),
      ),
    );
  }

  void _showDetail(ABCDEWorksheet item) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  // --- Header ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          surfaceDark.withOpacity(0.02),
                          const Color(0xFF003E3D).withOpacity(0.08),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        // avatar / small icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [colorE, colorC],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(
                            Icons.psychology_alt, // brain-like icon
                            color: Color.fromARGB(255, 0, 40, 72),
                            size: 30,
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Title & subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Worksheet Detail',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_exampleIds.contains(item.id))
                                const SizedBox(height: 6),
                              if (_exampleIds.contains(item.id))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Example',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Top-right actions: copy + close
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Copy summary',
                              onPressed: () {
                                final txt = [
                                  'ABCDE worksheet',
                                  'A: ${item.activatingEvent}',
                                  'B — Belief: ${item.belief}',
                                  'C — Consequences:',
                                  '  Emotional: ${item.consequencesEmotional}',
                                  '  Psychological: ${item.consequencesPsychological}',
                                  '  Physical: ${item.consequencesPhysical}',
                                  '  Behavioural: ${item.consequencesBehavioural}',
                                  'D: ${item.dispute}',
                                  'E — Effects:',
                                  '  Emotional: ${item.emotionalEffect}',
                                  '  Psychological: ${item.psychologicalEffect}',
                                  '  Physical: ${item.physicalEffect}',
                                  '  Behavioural: ${item.behaviouralEffect}',
                                  if (item.note.isNotEmpty)
                                    'Note: ${item.note}',
                                ].join('\n');
                                Clipboard.setData(ClipboardData(text: txt));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Copied worksheet summary to clipboard',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.copy,
                                color: Colors.white70,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(dctx).pop(),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // subtle divider
                  const Divider(color: Colors.white10, height: 1),

                  // --- Content (scrollable) ---
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Reusable section widget pattern
                          _buildSectionCard(
                            'A',
                            'Activating Event',
                            colorA,
                            item.activatingEvent,
                          ),
                          const SizedBox(height: 8),
                          _buildSectionCard('B', 'Belief', colorB, item.belief),
                          const SizedBox(height: 8),

                          // C group displayed as sub-cards in a row on wide screens or column on narrow screens
                          _sectionLabel(
                            'C',
                            'Consequences (feelings & actions)',
                            colorC,
                          ),
                          const SizedBox(height: 8),
                          _buildSubCardsForGroup([
                            {
                              'label': 'Emotional',
                              'value': item.consequencesEmotional,
                            },
                            {
                              'label': 'Psychological',
                              'value': item.consequencesPsychological,
                            },
                            {
                              'label': 'Physical',
                              'value': item.consequencesPhysical,
                            },
                            {
                              'label': 'Behavioural',
                              'value': item.consequencesBehavioural,
                            },
                          ]),

                          const SizedBox(height: 12),
                          _buildSectionCard(
                            'D',
                            'Dispute / Alternative thought',
                            colorD,
                            item.dispute,
                          ),
                          const SizedBox(height: 8),

                          _sectionLabel('E', 'Effects (four types)', colorE),
                          const SizedBox(height: 8),
                          _buildSubCardsForGroup([
                            {
                              'label': 'Emotional',
                              'value': item.emotionalEffect,
                            },
                            {
                              'label': 'Psychological',
                              'value': item.psychologicalEffect,
                            },
                            {'label': 'Physical', 'value': item.physicalEffect},
                            {
                              'label': 'Behavioural',
                              'value': item.behaviouralEffect,
                            },
                          ]),

                          if (item.note.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _sectionLabel(
                              'Note',
                              'To be practiced',
                              Colors.white70,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardDark.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Text(
                                item.note,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),

                  // --- Actions row (sticky) ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cardDark.withOpacity(0.9),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      border: const Border(
                        top: BorderSide(color: Colors.white10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Close the parent dialog/sheet (using the dialog context `dctx`)
                              try {
                                Navigator.of(dctx).pop();
                              } catch (_) {
                                // fallback: if dctx isn't available or pop fails, try current context
                                try {
                                  Navigator.of(context).pop();
                                } catch (_) {}
                              }

                              // Call your existing Edit handler
                              _startEdit(item);

                              // Optional: show a small confirmation snackbar
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Opening editor...'),
                                    backgroundColor: Color(0xFF007A78), // teal4
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.edit, color: Colors.white),
                            label: const Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                0,
                                174,
                                55,
                              ), // teal3
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
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

  // ----------------- Helper widgets used above -----------------

  Widget _sectionLabel(String letter, String labelText, Color accentColor) {
    // small pill label used in content area
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.92),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          labelText,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    String letter,
    String title,
    Color color,
    String value,
  ) {
    if (value.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(letter, title, color),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardDark.withOpacity(0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text('—', style: TextStyle(color: Colors.white38)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(letter, title, color),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardDark.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(value, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _buildSubCardsForGroup(List<Map<String, String>> items) {
    // horizontal wrap with responsive behavior (if narrow -> column)
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 520;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((m) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 6.0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cardDark.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['label'] ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m['value'] ?? '',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        } else {
          return Column(
            children: items.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardDark.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['label'] ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m['value'] ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // compute filtered lists
    final exampleList = _items
        .where((it) => _exampleIds.contains(it.id))
        .toList();
    final userList = _items
        .where((it) => !_exampleIds.contains(it.id))
        .toList();

    return Scaffold(
      backgroundColor: surfaceDark,
      appBar: AppBar(
        title: const Text('ABCDE Worksheet'),
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
            onPressed: () {
              showAbcdTutorialSheet(
                context,
                initialHindi: _tutorialInHindi,
                onCreate: _startNew,
                onLanguageChanged: (v) {
                  setState(() => _tutorialInHindi = v);
                },
              );
            },
            icon: const Icon(Icons.help, color: Colors.white70),
            tooltip: 'Show tutorial',
          ),
          IconButton(
            onPressed: _startNew,
            icon: const Icon(Icons.add, color: Colors.white70),
            tooltip: 'New worksheet',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TabBar(
              controller: _mainTabController,
              indicatorColor: teal3, // or teal2 / Colors.tealAccent
              indicatorWeight: 3.0, // thickness of the line
              indicatorSize: TabBarIndicatorSize.tab, // full-width underline

              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,

              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('  Examples'),
                      const SizedBox(width: 6),
                      if (exampleList.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: countBackgroundColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${exampleList.length}',
                            style: const TextStyle(
                              color: countTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('  My worksheets'),
                      const SizedBox(width: 6),
                      if (userList.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: countBackgroundColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${userList.length}',
                            style: const TextStyle(
                              color: countTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Colors.green, // teal3
              Color(0xFF007A78), // teal4
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30), // must match FAB shape
        ),
        child: FloatingActionButton.extended(
          onPressed: _startNew,
          icon: const Icon(Icons.add),
          label: const Text('New worksheet'),
          backgroundColor: Colors.transparent, // IMPORTANT
          elevation: 0, // looks cleaner
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: Column(
        children: [
          // Keep a thin separator under the tab bar for visual separation
          Container(height: 6, color: Colors.transparent),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _mainTabController,
              children: [
                // Examples tab
                _buildListForItems(exampleList),

                // My worksheets tab
                _buildListForItems(userList),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
