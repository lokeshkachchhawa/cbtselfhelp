import 'dart:convert';
import 'package:cbt_drktv/widgets/abcd_tutorial_sheet.dart';
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

const Color colorA = Color(0xFFE57373); // Light Red/Coral for Activating Event
const Color colorB = Color(0xFFFDD835); // Amber/Yellow for Beliefs
const Color colorC = Color(0xFF64B5F6); // Light Blue for Consequences
const Color colorD = Color(0xFF81C784); // Light Green for Dispute
const Color colorE = Color(0xFFFFB74D); // Orange for Effects

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

  // B — Belief (four types)
  final String beliefEmotional;
  final String beliefPsychological;
  final String beliefPhysical;
  final String beliefBehavioural;

  final String consequences;
  final String dispute;

  // E — Effects (four types)
  final String emotionalEffect;
  final String psychologicalEffect;
  final String physicalEffect;
  final String behaviouralEffect;

  final String note;
  final DateTime createdAt;

  AbcdWorksheet({
    required this.id,
    required this.activatingEvent,
    required this.beliefEmotional,
    required this.beliefPsychological,
    required this.beliefPhysical,
    required this.beliefBehavioural,
    required this.consequences,
    required this.dispute,
    required this.emotionalEffect,
    required this.psychologicalEffect,
    required this.physicalEffect,
    required this.behaviouralEffect,
    required this.note,
    required this.createdAt,
  });

  AbcdWorksheet copyWith({
    String? activatingEvent,
    String? beliefEmotional,
    String? beliefPsychological,
    String? beliefPhysical,
    String? beliefBehavioural,
    String? consequences,
    String? dispute,
    String? emotionalEffect,
    String? psychologicalEffect,
    String? physicalEffect,
    String? behaviouralEffect,
    String? note,
  }) {
    return AbcdWorksheet(
      id: id,
      activatingEvent: activatingEvent ?? this.activatingEvent,
      beliefEmotional: beliefEmotional ?? this.beliefEmotional,
      beliefPsychological: beliefPsychological ?? this.beliefPsychological,
      beliefPhysical: beliefPhysical ?? this.beliefPhysical,
      beliefBehavioural: beliefBehavioural ?? this.beliefBehavioural,
      consequences: consequences ?? this.consequences,
      dispute: dispute ?? this.dispute,
      emotionalEffect: emotionalEffect ?? this.emotionalEffect,
      psychologicalEffect: psychologicalEffect ?? this.psychologicalEffect,
      physicalEffect: physicalEffect ?? this.physicalEffect,
      behaviouralEffect: behaviouralEffect ?? this.behaviouralEffect,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'activatingEvent': activatingEvent,
    'beliefEmotional': beliefEmotional,
    'beliefPsychological': beliefPsychological,
    'beliefPhysical': beliefPhysical,
    'beliefBehavioural': beliefBehavioural,
    'consequences': consequences,
    'dispute': dispute,
    'emotionalEffect': emotionalEffect,
    'psychologicalEffect': psychologicalEffect,
    'physicalEffect': physicalEffect,
    'behaviouralEffect': behaviouralEffect,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  static AbcdWorksheet fromMap(Map<String, dynamic> m) {
    // Support legacy single 'belief' field by mapping it to emotional belief
    final legacyBelief = m['belief'] as String?;

    return AbcdWorksheet(
      id: m['id'] as String,
      activatingEvent: m['activatingEvent'] as String? ?? '',
      beliefEmotional: m['beliefEmotional'] as String? ?? legacyBelief ?? '',
      beliefPsychological: m['beliefPsychological'] as String? ?? '',
      beliefPhysical: m['beliefPhysical'] as String? ?? '',
      beliefBehavioural: m['beliefBehavioural'] as String? ?? '',
      consequences: m['consequences'] as String? ?? '',
      dispute: m['dispute'] as String? ?? '',
      emotionalEffect: m['emotionalEffect'] as String? ?? '',
      psychologicalEffect: m['psychologicalEffect'] as String? ?? '',
      physicalEffect: m['physicalEffect'] as String? ?? '',
      behaviouralEffect: m['behaviouralEffect'] as String? ?? '',
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

class _AbcdWorksheetPageState extends State<AbcdWorksheetPage>
    with TickerProviderStateMixin {
  final _storage = AbcdStorage();

  // controllers
  final _activatingCtrl = TextEditingController();

  // B — belief controllers (four types)
  final _belEmoCtrl = TextEditingController();
  final _belPsyCtrl = TextEditingController();
  final _belPhyCtrl = TextEditingController();
  final _belBehCtrl = TextEditingController();

  final _consequencesCtrl = TextEditingController();
  final _disputeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // E controllers (four thought types)
  final _emoCtrl = TextEditingController();
  final _psyCtrl = TextEditingController();
  final _phyCtrl = TextEditingController();
  final _behCtrl = TextEditingController();

  late final TabController _effectsTabController;
  late final TabController _beliefTabController;

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
    _effectsTabController = TabController(length: 4, vsync: this);
    _beliefTabController = TabController(length: 4, vsync: this);
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
    _belEmoCtrl.dispose();
    _belPsyCtrl.dispose();
    _belPhyCtrl.dispose();
    _belBehCtrl.dispose();
    _consequencesCtrl.dispose();
    _disputeCtrl.dispose();
    _noteCtrl.dispose();
    _emoCtrl.dispose();
    _psyCtrl.dispose();
    _phyCtrl.dispose();
    _behCtrl.dispose();
    _effectsTabController.dispose();
    _beliefTabController.dispose();
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
      _belEmoCtrl.clear();
      _belPsyCtrl.clear();
      _belPhyCtrl.clear();
      _belBehCtrl.clear();
      _consequencesCtrl.clear();
      _disputeCtrl.clear();
      _noteCtrl.clear();
      _emoCtrl.clear();
      _psyCtrl.clear();
      _phyCtrl.clear();
      _behCtrl.clear();
      _effectsTabController.index = 0;
      _beliefTabController.index = 0;
    });
    _showFormSheet();
  }

  void _startEdit(AbcdWorksheet item) {
    setState(() {
      _editing = item;
      _activatingCtrl.text = item.activatingEvent;
      _belEmoCtrl.text = item.beliefEmotional;
      _belPsyCtrl.text = item.beliefPsychological;
      _belPhyCtrl.text = item.beliefPhysical;
      _belBehCtrl.text = item.beliefBehavioural;
      _consequencesCtrl.text = item.consequences;
      _disputeCtrl.text = item.dispute;
      _noteCtrl.text = item.note;
      _emoCtrl.text = item.emotionalEffect;
      _psyCtrl.text = item.psychologicalEffect;
      _phyCtrl.text = item.physicalEffect;
      _behCtrl.text = item.behaviouralEffect;
      _effectsTabController.index = 0;
      _beliefTabController.index = 0;
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

    final belEmo = _belEmoCtrl.text.trim();
    final belPsy = _belPsyCtrl.text.trim();
    final belPhy = _belPhyCtrl.text.trim();
    final belBeh = _belBehCtrl.text.trim();

    final consequences = _consequencesCtrl.text.trim();
    final dispute = _disputeCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    final emo = _emoCtrl.text.trim();
    final psy = _psyCtrl.text.trim();
    final phy = _phyCtrl.text.trim();
    final beh = _behCtrl.text.trim();

    if (activating.isEmpty ||
        (belEmo.isEmpty &&
            belPsy.isEmpty &&
            belPhy.isEmpty &&
            belBeh.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete the event and at least one belief field',
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (_editing != null) {
      final updated = _editing!.copyWith(
        activatingEvent: activating,
        beliefEmotional: belEmo,
        beliefPsychological: belPsy,
        beliefPhysical: belPhy,
        beliefBehavioural: belBeh,
        consequences: consequences,
        dispute: dispute,
        emotionalEffect: emo,
        psychologicalEffect: psy,
        physicalEffect: phy,
        behaviouralEffect: beh,
        note: note,
      );
      await _storage.update(updated);
    } else {
      final newItem = AbcdWorksheet(
        id: _uuid.v4(),
        activatingEvent: activating,
        beliefEmotional: belEmo,
        beliefPsychological: belPsy,
        beliefPhysical: belPhy,
        beliefBehavioural: belBeh,
        consequences: consequences,
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

                              // B — Beliefs
                              _sectionWrapper(
                                color: colorB,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _headerLabel(
                                      'B',
                                      'Belief / Automatic thoughts',
                                      colorB,
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
                                            controller: _beliefTabController,
                                            indicator: BoxDecoration(
                                              color: colorB,
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
                                            height: 120,
                                            child: TabBarView(
                                              controller: _beliefTabController,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _belEmoCtrl,
                                                    hint:
                                                        'Emotional belief / feeling',
                                                    minLines: 2,
                                                    maxLines: 4,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _belPsyCtrl,
                                                    hint:
                                                        'Psychological / cognitive belief',
                                                    minLines: 2,
                                                    maxLines: 4,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _belPhyCtrl,
                                                    hint:
                                                        'Physical belief / bodily thought',
                                                    minLines: 2,
                                                    maxLines: 4,
                                                    maxLength: 400,
                                                    showCounter: true,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: AppTextField(
                                                    controller: _belBehCtrl,
                                                    hint:
                                                        'Behavioural belief (impulse to act)',
                                                    minLines: 2,
                                                    maxLines: 4,
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

                              // C — Consequences
                              _sectionLabelAndField(
                                letter: 'C',
                                title: 'Consequences (feelings & actions)',
                                color: colorC,
                                child: AppTextField(
                                  controller: _consequencesCtrl,
                                  hint: 'How did you feel or behave?',
                                  minLines: 2,
                                  maxLines: 4,
                                  maxLength: 800,
                                  showCounter: true,
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

  Widget _beliefSummaryWidget(AbcdWorksheet item) {
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

    final bParts = <String>[];
    final bEmo = firstLine(item.beliefEmotional);
    final bPsy = firstLine(item.beliefPsychological);
    final bPhy = firstLine(item.beliefPhysical);
    final bBeh = firstLine(item.beliefBehavioural);
    if (bEmo.isNotEmpty) bParts.add('Emo: $bEmo');
    if (bPsy.isNotEmpty) bParts.add('Psy: $bPsy');
    if (bPhy.isNotEmpty) bParts.add('Phy: $bPhy');
    if (bBeh.isNotEmpty) bParts.add('Beh: $bBeh');
    if (bParts.isNotEmpty) {
      sections.add({
        'label': 'B — Beliefs',
        'text': bParts.join(' | '),
        'color': colorB,
      });
    }

    final c = firstLine(item.consequences);
    if (c.isNotEmpty)
      sections.add({'label': 'C — Consequences', 'text': c, 'color': colorC});

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

  // Helper function to create a concise summary of the belief types present

  // Separate the PopupMenuButton into its own helper function for cleaner code
  Widget _buildPopupMenu(AbcdWorksheet item) {
    return PopupMenuButton<String>(
      color: Colors.white,
      icon: const Icon(
        Icons.more_vert,
        color: Colors.white54,
      ), // Subtle icon color
      onSelected: (v) {
        if (v == 'edit') _startEdit(item);
        if (v == 'delete') _deleteItem(item.id);
        if (v == 'share') {
          final txt = [
            'ABCD worksheet',
            'A: ${item.activatingEvent}',
            'B — Beliefs:',
            '  Emotional: ${item.beliefEmotional}',
            '  Psychological: ${item.beliefPsychological}',
            '  Physical: ${item.beliefPhysical}',
            '  Behavioural: ${item.beliefBehavioural}',
            'C: ${item.consequences}',
            'D: ${item.dispute}',
            'E — Effects:',
            '  Emotional: ${item.emotionalEffect}',
            '  Psychological: ${item.psychologicalEffect}',
            '  Physical: ${item.physicalEffect}',
            '  Behavioural: ${item.behaviouralEffect}',
            if (item.note.isNotEmpty) 'Note: ${item.note}',
          ].join('\n');
          Clipboard.setData(ClipboardData(text: txt));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard (for sharing)')),
          );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'share', child: Text('Copy for share')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ), // Highlight delete
      ],
    );
  }

  // --- THE MAIN WIDGET ---
  Widget _buildListTile(AbcdWorksheet item) {
    // Use a final variable for a clean separation of the 'A' event.
    final titleText = item.activatingEvent.isNotEmpty
        ? item.activatingEvent
        : 'ABCD worksheet';

    final dateStr = MaterialLocalizations.of(
      context,
    ).formatFullDate(item.createdAt);
    _beliefSummaryWidget(item); // Get the concise summary

    return Card(
      // Enhanced Card Styling
      color: cardDark,
      margin: const EdgeInsets.symmetric(
        horizontal: 5.0,
        vertical: 3.0,
      ), // Add outer margin
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // Softer, modern shape
        side: const BorderSide(
          color: Colors.white10,
          width: 0.8,
        ), // Subtle border
      ),
      elevation: 3, // Subtle lift for a layered effect

      child: InkWell(
        // Use InkWell for better tap feedback on the whole card
        onTap: () => _showDetail(item),
        borderRadius: BorderRadius.circular(16), // Match card border

        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 12.0,
            horizontal: 8.0,
          ), // Internal padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ROW 1: Title and Menu ---
              Row(
                children: [
                  // Icon for the Activating Event (The 'A')
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, right: 12.0),
                    child: Icon(
                      (Icons.flash_on),
                      color: Colors.yellow,
                      size: 24,
                    ), // Teal accent
                  ),

                  // Main Title (Activating Event)
                  Expanded(
                    child: Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.w800, // Extra bold for primary info
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // Menu Button
                  _buildPopupMenu(item),
                ],
              ),

              // --- Separator ---
              const Divider(
                color: Colors.white10,
                height: 16,
                indent: 16,
                endIndent: 16,
              ),

              // --- ROW 2: Sub-details (Beliefs & Date) ---
              Padding(
                padding: const EdgeInsets.only(
                  left: 12.0,
                  right: 16.0,
                  bottom: 4.0,
                ),
                child: Row(
                  children: [
                    // Belief Summary with Icon
                    Expanded(child: _beliefSummaryWidget(item)),

                    // Date Saved with Icon (Aligned to the right)
                  ],
                ),
              ),
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
                      ), // Subtle date
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

  // Separate the PopupMenuButton into its own helper function for cleaner code

  // NOTE: You will need to make sure the _beliefSummary function is defined
  // within the scope of your class or passed in, as done in the example above.

  // Define your custom color palette for the ABCD/E sections

  // 1. New Helper Widget for the Main Section Headers (A, B, C, D, E)
  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Text(
        title,
        style: TextStyle(
          color: color, // Use the assigned color
          fontSize: 18,
          fontWeight: FontWeight.w800, // Extra bold
        ),
      ),
    );
  }

  // 2. Updated Helper Widget for the detail rows (if you have one defined elsewhere)
  // Assuming _detailRow is defined as:
  // Widget _detailRow(String label, String value) { ... }

  // --- THE UPDATED SHOW DETAIL FUNCTION ---

  void _showDetail(AbcdWorksheet item) {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        // Modernize the dialog shape slightly
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cardDark,
        title: const Text(
          'Worksheet Detail',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A - Activating Event (Red/Coral)
              _sectionHeader('A — Activating Event', colorA),
              _detailCard('Description', item.activatingEvent, colorA),

              // B - Beliefs (Amber/Yellow)
              _sectionHeader('B — Beliefs', colorB),
              _detailCard('Emotional', item.beliefEmotional, colorB),
              _detailCard('Psychological', item.beliefPsychological, colorB),
              _detailCard('Physical', item.beliefPhysical, colorB),
              _detailCard('Behavioural', item.beliefBehavioural, colorB),

              // C - Consequences (Light Blue)
              _sectionHeader('C — Consequences', colorC),
              _detailCard('Description', item.consequences, colorC),

              // D - Dispute (Light Green)
              _sectionHeader('D — Dispute', colorD),
              _detailCard('Description', item.dispute, colorD),

              // E - Effects (Orange)
              _sectionHeader('E — Effects', colorE),
              _detailCard('Emotional', item.emotionalEffect, colorE),
              _detailCard('Psychological', item.psychologicalEffect, colorE),
              _detailCard('Physical', item.physicalEffect, colorE),
              _detailCard('Behavioural', item.behaviouralEffect, colorE),

              // Note (Optional, neutral color)
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeader('Note', Colors.white70),
                // Use a neutral accent color for the Note card border
                _detailCard('Details', item.note, Colors.white38),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorA,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(dctx).pop();
              _startEdit(item);
            },
            child: const Text('Edit', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(String label, String value, Color sectionColor) {
    // Only display the card if there is actual content
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Card(
        color: Colors.transparent, // Use transparent so cardDark shows through
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          // Subtle, colored border to tie the card to its section color
          side: BorderSide(color: sectionColor.withOpacity(0.4), width: 1),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            // Use a very subtle, slightly lighter background for the content area
            color: cardDark.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label (e.g., Emotional, Psychological)
              Text(
                '$label:',
                style: TextStyle(
                  color: sectionColor, // Use the section color for the label
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              // Value (The actual content)
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ),
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
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize
                            .min, // Essential to keep the button size minimal
                        children: [
                          const Icon(Icons.add),
                          const SizedBox(height: 4),
                          const Text(
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
