// lib/screens/activities_page.dart
// Unified Activities screen showing Thought Records and ABCD worksheets (local-only)
// Updated theme: dark teal UI, tutorial from app bar with English/Hindi toggle,
// modal bottom sheets styled to match app theme.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:uuid/uuid.dart';

const String _kThoughtKey = 'thought_records_v1';
const String _kAbcdKey = 'abcd_worksheets_v1';

final _uuid = Uuid();

// Teal palette (match app)
const Color teal1 = Color(0xFFC6EDED);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);
const Color teal6 = Color(0xFF004E4D);

class _ActivityItem {
  final String id;
  final String type; // 'thought' | 'abcd'
  final String title;
  final String subtitle;
  final Map<String, dynamic> raw;
  final DateTime createdAt;

  _ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.raw,
    required this.createdAt,
  });
}

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<_ActivityItem> _items = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final List<_ActivityItem> items = [];

    // Load thought records
    final tJson = prefs.getString(_kThoughtKey);
    if (tJson != null && tJson.isNotEmpty) {
      try {
        final List<dynamic> list = json.decode(tJson) as List<dynamic>;
        for (final e in list) {
          final m = Map<String, dynamic>.from(e as Map);
          final id = m['id'] as String? ?? '';
          final title = (m['situation'] as String?)?.trim() ?? 'Thought record';
          final created =
              DateTime.tryParse(m['createdAt'] as String? ?? '') ??
              DateTime.now();
          final subtitle = (m['automaticThought'] as String?)?.trim() ?? '';
          items.add(
            _ActivityItem(
              id: id,
              type: 'thought',
              title: title.isEmpty ? 'Thought record' : title,
              subtitle: subtitle,
              raw: m,
              createdAt: created,
            ),
          );
        }
      } catch (_) {
        // ignore parse errors
      }
    }

    // Load ABCD worksheets
    final aJson = prefs.getString(_kAbcdKey);
    if (aJson != null && aJson.isNotEmpty) {
      try {
        final List<dynamic> list = json.decode(aJson) as List<dynamic>;
        for (final e in list) {
          final m = Map<String, dynamic>.from(e as Map);
          final id = m['id'] as String? ?? '';
          final title =
              (m['activatingEvent'] as String?)?.trim() ?? 'ABCD worksheet';
          final created =
              DateTime.tryParse(m['createdAt'] as String? ?? '') ??
              DateTime.now();
          final subtitle = (m['belief'] as String?)?.trim() ?? '';
          items.add(
            _ActivityItem(
              id: id,
              type: 'abcd',
              title: title.isEmpty ? 'ABCD worksheet' : title,
              subtitle: subtitle,
              raw: m,
              createdAt: created,
            ),
          );
        }
      } catch (_) {
        // ignore
      }
    }

    // Sort newest first
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _deleteItem(_ActivityItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This will remove the item from local storage.'),
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
    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    if (item.type == 'thought') {
      final jsonStr = prefs.getString(_kThoughtKey) ?? '';
      if (jsonStr.isNotEmpty) {
        final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
        list.removeWhere((e) => (e as Map)['id'] == item.id);
        await prefs.setString(_kThoughtKey, json.encode(list));
      }
    } else {
      final jsonStr = prefs.getString(_kAbcdKey) ?? '';
      if (jsonStr.isNotEmpty) {
        final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
        list.removeWhere((e) => (e as Map)['id'] == item.id);
        await prefs.setString(_kAbcdKey, json.encode(list));
      }
    }

    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
    }
  }

  void _openItem(_ActivityItem item) {
    showDialog<void>(
      context: context,
      builder: (dctx) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            item.type == 'thought' ? 'Thought record' : 'ABCD worksheet',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: item.type == 'thought'
                  ? _buildThoughtDetail(item)
                  : _buildAbcdDetail(item),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dctx).pop();
                _editItem(item);
              },
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dctx).pop();
                _deleteItem(item);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildThoughtDetail(_ActivityItem item) {
    final m = item.raw;
    return [
      _detailRow('Situation', m['situation'] ?? ''),
      const SizedBox(height: 8),
      _detailRow('Automatic thought', m['automaticThought'] ?? ''),
      const SizedBox(height: 8),
      _detailRow('Evidence FOR', m['evidenceFor'] ?? ''),
      const SizedBox(height: 8),
      _detailRow('Evidence AGAINST', m['evidenceAgainst'] ?? ''),
      const SizedBox(height: 8),
      _detailRow('Alternative', m['alternativeThought'] ?? ''),
      const SizedBox(height: 8),
      Text(
        'Before mood: ${m['beforeMood'] ?? ''}   After mood: ${m['afterMood'] ?? ''}',
        style: const TextStyle(color: Colors.white70),
      ),
    ];
  }

  List<Widget> _buildAbcdDetail(_ActivityItem item) {
    final m = item.raw;
    return [
      _detailRow('Activating event', m['activatingEvent'] ?? ''),
      const SizedBox(height: 8),
      _detailRow('Belief', m['belief'] ?? ''),
      const SizedBox(height: 8),
      _detailRow('Evidence FOR', m['evidenceFor'] ?? ''),
      const SizedBox(height: 8),
      _detailRow('Evidence AGAINST', m['evidenceAgainst'] ?? ''),
      const SizedBox(height: 8),
      _detailRow('Disputation / Alternative', m['dispute'] ?? ''),
      const SizedBox(height: 8),
      Text(
        'Before mood: ${m['beforeMood'] ?? ''}   After mood: ${m['afterMood'] ?? ''}',
        style: const TextStyle(color: Colors.white70),
      ),
    ];
  }

  Widget _detailRow(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white60)),
      ],
    );
  }

  void _editItem(_ActivityItem item) {
    // Open modal sheet for edit depending on type
    if (item.type == 'thought') {
      _openThoughtSheet(id: item.id);
    } else {
      _openAbcdSheet(id: item.id);
    }
  }

  List<_ActivityItem> _filterItems(String filter) {
    if (filter == 'all') return _items;
    if (filter == 'thought')
      return _items.where((i) => i.type == 'thought').toList();
    if (filter == 'abcd') return _items.where((i) => i.type == 'abcd').toList();
    return _items;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildList(String filter) {
    final list = _filterItems(filter);
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No items',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your thought records and ABCD worksheets will appear here.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal3,
                  // ADDED: Reduced padding to shrink the button horizontally
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                onPressed: () => _openCreateOptions(),
                child: const Text('Create a thought record'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      edgeOffset: 10,
      color: teal2,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, idx) {
          final it = list[idx];
          final timeStr = MaterialLocalizations.of(
            context,
          ).formatFullDate(it.createdAt);
          return Card(
            color: Colors.black.withOpacity(0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: it.type == 'thought' ? teal3 : teal4,
                child: Icon(
                  it.type == 'thought' ? Icons.note_alt : Icons.rule,
                  color: Colors.white,
                ),
              ),
              title: Text(
                it.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                '${it.type.toUpperCase()} • $timeStr\n${it.subtitle}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                color: const Color(0xFF022525),
                onSelected: (v) {
                  if (v == 'open') _openItem(it);
                  if (v == 'edit') _editItem(it);
                  if (v == 'delete') _deleteItem(it);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('Open')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              onTap: () => _openItem(it),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _sheetFieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFFFFFF).withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ---------------- Tutorial ----------------
  void _showTutorial() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            bool isHindi = false;
            return StatefulBuilder(
              builder: (context, setStateSheet) {
                Widget englishContent() {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
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
                                'Activities — what this screen is for',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(Icons.close, color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Purpose',
                          style: TextStyle(
                            color: teal2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This screen collects and shows your thought records and ABCD worksheets in one place. '
                          'Use it to review, edit, and manage entries you’ve created while working through CBT exercises. '
                          'Everything is stored locally on the device.',
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'When to use each tool',
                          style: TextStyle(
                            color: teal2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _bullet(
                          'Thought Record — use when you want to examine an upsetting situation in detail: the situation, automatic thought, evidence for/against, and alternative thought. It helps re-evaluate unhelpful thinking.',
                        ),
                        _bullet(
                          'ABCD Worksheet — a concise CBT-style worksheet: A (Activating event), B (Belief), C (Consequences), D (Dispute / alternative thought). Use when you prefer a structured step-by-step format.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'How to use',
                          style: TextStyle(
                            color: teal2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _numbered(
                          'Create',
                          'Tap the + button and choose Thought or ABCD to create a new entry.',
                        ),
                        _numbered(
                          'Describe',
                          'Write the situation and the thought you had — be specific.',
                        ),
                        _numbered(
                          'Weigh evidence',
                          'Use the "evidence for" and "evidence against" fields to examine whether your automatic thought is fully supported.',
                        ),
                        _numbered(
                          'Generate alternatives',
                          'Write kinder or more balanced alternative thoughts. Rate your mood before and after to track change.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Privacy & notes',
                          style: TextStyle(
                            color: teal2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All entries are stored locally on your device and are not transmitted anywhere. If you want to share a worksheet, use the menu on any item to copy it to clipboard.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tips',
                          style: TextStyle(
                            color: teal2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _bullet(
                          'Be specific and concrete — details help reveal patterns.',
                        ),
                        _bullet(
                          'Revisit entries later to notice progress — the "after mood" slider makes change visible.',
                        ),
                        _bullet(
                          'Use the AB C D structure for quick practice in the moment.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: teal3,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Got it'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }

                Widget hindiContent() {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
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
                                'Activities — इस स्क्रीन का उद्देश्य',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(Icons.close, color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'उद्देश्य',
                          style: TextStyle(
                            color: teal2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'यह स्क्रीन आपके Thought Records और ABCD worksheets को एक जगह दिखाती है। '
                          'इन्हें आप देख, सम्पादित और प्रबंधित कर सकते हैं। सभी डेटा आपके डिवाइस पर ही सुरक्षित रहते हैं।',
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'कब किसे उपयोग करें',
                          style: TextStyle(
                            color: teal2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _bullet(
                          'Thought Record — जटिल या परेशान करने वाली स्थिति के लिए प्रयोग करें: स्थिति, स्वचालित सोच, सहायक/विरोधी सबूत और वैकल्पिक सोच।',
                        ),
                        _bullet(
                          'ABCD Worksheet — तेज़ और संरचित तरीका: A (घटना), B (विश्वास), C (परिणाम), D (विकार)।',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'कैसे उपयोग करें',
                          style: TextStyle(
                            color: teal2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _numbered(
                          'बनाएँ',
                          'ऊपर + बटन दबाएँ और Thought या ABCD चुनें।',
                        ),
                        _numbered(
                          'विवरण दें',
                          'स्थिति और आपकी सोच को स्पष्ट रूप से लिखें।',
                        ),
                        _numbered(
                          'साक्ष्य परखें',
                          'साक्ष्य FOR/AGAINST भरकर सोच की सच्चाई जाँचें।',
                        ),
                        _numbered(
                          'वैकल्पिक सोच',
                          'दयालु/संतुलित विकल्प लिखें और मूड before/after दर्ज करें।',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'गोपनीयता',
                          style: TextStyle(
                            color: teal2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'सभी प्रविष्टियाँ आपके डिवाइस पर स्थानीय रूप से संग्रहीत होती हैं और कहीं भेजी नहीं जातीं। साझा करने के लिए किसी आइटम का टेक्स्ट कॉपी करें।',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: teal3,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('समझ गया'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF081F1F),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 4),
                            const Text(
                              'Language:',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(width: 8),
                            ToggleButtons(
                              isSelected: [!isHindi, isHindi],
                              onPressed: (i) {
                                setStateSheet(() => isHindi = (i == 1));
                              },
                              borderRadius: BorderRadius.circular(8),
                              selectedColor: Colors.white,
                              color: Colors.white70,
                              fillColor: teal3,
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Text('English'),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Text('हिंदी'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: isHindi ? hindiContent() : englishContent(),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.brightness_1, size: 8, color: teal2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _numbered(String title, String body) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: teal3, shape: BoxShape.circle),
            child: Center(
              child: Text(
                title[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title — $body',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    // dark teal background gradient
    const darkBgTop = Color(0xFF022626);
    const darkBgBottom = Color(0xFF021919);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Activities'),
          backgroundColor: teal4,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'How to use Activities',
              onPressed: _showTutorial,
              icon: const Icon(Icons.help_outline),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Thought'),
              Tab(text: 'ABCD'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [darkBgTop, darkBgBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList('all'),
                    _buildList('thought'),
                    _buildList('abcd'),
                  ],
                ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: teal3,
          child: const Icon(Icons.add),
          onPressed: () => _openCreateOptions(),
        ),
      ),
    );
  }

  void _openCreateOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      backgroundColor: const Color(0xFF081F1F),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: teal3,
                    child: const Icon(Icons.note_alt, color: Colors.white),
                  ),
                  title: const Text(
                    'New thought record',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openThoughtSheet(); // open sheet for new thought
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: teal4,
                    child: const Icon(Icons.rule, color: Colors.white),
                  ),
                  title: const Text(
                    'New ABCD worksheet',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openAbcdSheet(); // open sheet for new abcd
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------- Thought modal sheet --------------------
  Future<Map<String, dynamic>?> _loadThoughtMapById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kThoughtKey) ?? '';
    if (jsonStr.isEmpty) return null;
    final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      if ((m['id'] as String? ?? '') == id) return m;
    }
    return null;
  }

  Future<void> _saveThoughtMap(Map<String, dynamic> m) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kThoughtKey) ?? '';
    final List<dynamic> list = jsonStr.isNotEmpty
        ? json.decode(jsonStr) as List<dynamic>
        : [];
    final idx = list.indexWhere((e) => (e as Map)['id'] == m['id']);
    if (idx >= 0) {
      list[idx] = m;
    } else {
      list.insert(0, m);
    }
    await prefs.setString(_kThoughtKey, json.encode(list));
  }

  Future<void> _openThoughtSheet({String? id}) async {
    // controllers & local state
    final situationCtrl = TextEditingController();
    final automaticCtrl = TextEditingController();
    final evidenceForCtrl = TextEditingController();
    final evidenceAgainstCtrl = TextEditingController();
    final alternativeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    int localBefore = 5;
    int localAfter = 5;
    bool isEditing = false;
    String editingId = id ?? '';

    if (id != null) {
      final map = await _loadThoughtMapById(id);
      if (map != null) {
        isEditing = true;
        editingId = map['id'] as String? ?? id;
        situationCtrl.text = map['situation'] as String? ?? '';
        automaticCtrl.text = map['automaticThought'] as String? ?? '';
        evidenceForCtrl.text = map['evidenceFor'] as String? ?? '';
        evidenceAgainstCtrl.text = map['evidenceAgainst'] as String? ?? '';
        alternativeCtrl.text = map['alternativeThought'] as String? ?? '';
        noteCtrl.text = map['note'] as String? ?? '';
        localBefore = (map['beforeMood'] is int)
            ? (map['beforeMood'] as int)
            : int.tryParse((map['beforeMood'] ?? '5').toString()) ?? 5;
        localAfter = (map['afterMood'] is int)
            ? (map['afterMood'] as int)
            : int.tryParse((map['afterMood'] ?? '5').toString()) ?? 5;
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF081F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom;
        return FractionallySizedBox(
          heightFactor: 0.9,
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
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 5,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEditing
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
                            icon: Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white10, height: 1),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Situation',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: situationCtrl,
                              minLines: 2,
                              maxLines: 5,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint: 'Where were you? What happened?',
                              ),
                            ),
                            const SizedBox(height: 12),

                            const Text(
                              'Automatic thought',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: automaticCtrl,
                              minLines: 1,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint: 'What went through your mind?',
                              ),
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
                            const Text(
                              'Evidence FOR',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: evidenceForCtrl,
                              minLines: 2,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint: 'Facts that support the thought',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Evidence AGAINST',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: evidenceAgainstCtrl,
                              minLines: 2,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint: 'Facts that contradict the thought',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Alternative thought',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: alternativeCtrl,
                              minLines: 2,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint: 'A kinder or balanced thought',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Note (optional)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: noteCtrl,
                              minLines: 1,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint: 'Optional strategy or reminder',
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final situation = situationCtrl.text
                                          .trim();
                                      final auto = automaticCtrl.text.trim();
                                      if (situation.isEmpty || auto.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please complete situation and automatic thought',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      final now = DateTime.now();
                                      // preserve original createdAt if editing, otherwise use now
                                      final existingThought = isEditing
                                          ? await _loadThoughtMapById(editingId)
                                          : null;
                                      final thoughtCreatedAtStr =
                                          existingThought != null
                                          ? (existingThought['createdAt']
                                                    as String? ??
                                                now.toIso8601String())
                                          : now.toIso8601String();

                                      final map = {
                                        'id': isEditing
                                            ? editingId
                                            : _uuid.v4(),
                                        'situation': situation,
                                        'automaticThought': auto,
                                        'evidenceFor': evidenceForCtrl.text
                                            .trim(),
                                        'evidenceAgainst': evidenceAgainstCtrl
                                            .text
                                            .trim(),
                                        'alternativeThought': alternativeCtrl
                                            .text
                                            .trim(),
                                        'beforeMood': localBefore,
                                        'afterMood': localAfter,
                                        'note': noteCtrl.text.trim(),
                                        'createdAt': thoughtCreatedAtStr,
                                      };
                                      await _saveThoughtMap(map);
                                      await _loadAll();
                                      if (mounted) {
                                        Navigator.of(ctx).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Saved locally'),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: teal4,
                                    ),
                                    child: const Text('Save locally'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (isEditing)
                                  OutlinedButton(
                                    onPressed: () async {
                                      Navigator.of(ctx).pop();
                                      // delete
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final jsonStr =
                                          prefs.getString(_kThoughtKey) ?? '';
                                      if (jsonStr.isNotEmpty) {
                                        final List<dynamic> list =
                                            json.decode(jsonStr)
                                                as List<dynamic>;
                                        list.removeWhere(
                                          (e) => (e as Map)['id'] == editingId,
                                        );
                                        await prefs.setString(
                                          _kThoughtKey,
                                          json.encode(list),
                                        );
                                        await _loadAll();
                                        if (mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Deleted'),
                                            ),
                                          );
                                      }
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

  // -------------------- ABCD modal sheet --------------------
  Future<Map<String, dynamic>?> _loadAbcdMapById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kAbcdKey) ?? '';
    if (jsonStr.isEmpty) return null;
    final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      if ((m['id'] as String? ?? '') == id) return m;
    }
    return null;
  }

  Future<void> _saveAbcdMap(Map<String, dynamic> m) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kAbcdKey) ?? '';
    final List<dynamic> list = jsonStr.isNotEmpty
        ? json.decode(jsonStr) as List<dynamic>
        : [];
    final idx = list.indexWhere((e) => (e as Map)['id'] == m['id']);
    if (idx >= 0) {
      list[idx] = m;
    } else {
      list.insert(0, m);
    }
    await prefs.setString(_kAbcdKey, json.encode(list));
  }

  Future<void> _openAbcdSheet({String? id}) async {
    // controllers & local state
    final activatingCtrl = TextEditingController();
    final beliefCtrl = TextEditingController();
    final consequencesCtrl = TextEditingController();
    final disputeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    int localBefore = 5;
    int localAfter = 5;
    bool isEditing = false;
    String editingId = id ?? '';

    if (id != null) {
      final map = await _loadAbcdMapById(id);
      if (map != null) {
        isEditing = true;
        editingId = map['id'] as String? ?? id;
        activatingCtrl.text = map['activatingEvent'] as String? ?? '';
        beliefCtrl.text = map['belief'] as String? ?? '';
        consequencesCtrl.text = map['consequences'] as String? ?? '';
        disputeCtrl.text = map['dispute'] as String? ?? '';
        noteCtrl.text = map['note'] as String? ?? '';
        localBefore = (map['beforeMood'] is int)
            ? (map['beforeMood'] as int)
            : int.tryParse((map['beforeMood'] ?? '5').toString()) ?? 5;
        localAfter = (map['afterMood'] is int)
            ? (map['afterMood'] as int)
            : int.tryParse((map['afterMood'] ?? '5').toString()) ?? 5;
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF081F1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final pad = MediaQuery.of(ctx).viewInsets.bottom;
        return FractionallySizedBox(
          heightFactor: 0.9,
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
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 5,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEditing
                                  ? 'Edit ABCD worksheet'
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
                            icon: Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white10, height: 1),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'A — Activating event',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: activatingCtrl,
                              minLines: 2,
                              maxLines: 5,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint:
                                    'Describe what happened (who, when, where)',
                              ),
                            ),
                            const SizedBox(height: 10),

                            const Text(
                              'B — Belief / Automatic thought',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: beliefCtrl,
                              minLines: 1,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint: 'What thought went through your mind?',
                              ),
                            ),
                            const SizedBox(height: 10),

                            const Text(
                              'C — Consequences (feelings & actions)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: consequencesCtrl,
                              minLines: 2,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint: 'How did you feel or behave?',
                              ),
                            ),
                            const SizedBox(height: 10),

                            const Text(
                              'D — Dispute / Alternative thought',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: disputeCtrl,
                              minLines: 2,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint: 'A kinder or more balanced thought',
                              ),
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
                                        onChanged: _updateBefore,
                                        activeColor: teal3,
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
                                        onChanged: _updateAfter,
                                        activeColor: teal4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),
                            const Text(
                              'Note (optional)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: noteCtrl,
                              minLines: 1,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white),
                              decoration: _sheetFieldDecoration(
                                hint: 'Optional note / strategy / reminder',
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final activating = activatingCtrl.text
                                          .trim();
                                      final belief = beliefCtrl.text.trim();
                                      if (activating.isEmpty ||
                                          belief.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please complete the event and belief fields',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      final now = DateTime.now();
                                      final existing = isEditing
                                          ? await _loadAbcdMapById(editingId)
                                          : null;
                                      final createdAtStr = existing != null
                                          ? (existing['createdAt'] as String? ??
                                                now.toIso8601String())
                                          : now.toIso8601String();
                                      final map = {
                                        'id': isEditing
                                            ? editingId
                                            : _uuid.v4(),
                                        'activatingEvent': activating,
                                        'belief': belief,
                                        'consequences': consequencesCtrl.text
                                            .trim(),
                                        'dispute': disputeCtrl.text.trim(),
                                        'beforeMood': localBefore,
                                        'afterMood': localAfter,
                                        'note': noteCtrl.text.trim(),
                                        'createdAt': createdAtStr,
                                      };
                                      await _saveAbcdMap(map);
                                      await _loadAll();
                                      if (mounted) {
                                        Navigator.of(ctx).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Saved locally'),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: teal4,
                                    ),
                                    child: const Text('Save locally'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (isEditing)
                                  OutlinedButton(
                                    onPressed: () async {
                                      Navigator.of(ctx).pop();
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final jsonStr =
                                          prefs.getString(_kAbcdKey) ?? '';
                                      if (jsonStr.isNotEmpty) {
                                        final List<dynamic> list =
                                            json.decode(jsonStr)
                                                as List<dynamic>;
                                        list.removeWhere(
                                          (e) => (e as Map)['id'] == editingId,
                                        );
                                        await prefs.setString(
                                          _kAbcdKey,
                                          json.encode(list),
                                        );
                                        await _loadAll();
                                        if (mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Deleted'),
                                            ),
                                          );
                                      }
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
}
