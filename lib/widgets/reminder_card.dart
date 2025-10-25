// lib/widgets/reminder_card_improved.dart
// Improved ReminderCard — visual polish, clearer layout, accessible controls,
// better handling of loading/empty/next states, and small UX niceties.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../services/reminder_service.dart';

const Color _teal3 = Color(0xFF008F89);
const Color _teal4 = Color(0xFF007A78);
const Color _cardBg = Color(0xFF021515);

class ReminderCardImproved extends StatefulWidget {
  const ReminderCardImproved({Key? key}) : super(key: key);

  @override
  State<ReminderCardImproved> createState() => _ReminderCardImprovedState();
}

class _ReminderCardImprovedState extends State<ReminderCardImproved> {
  final ReminderStorage _storage = ReminderStorage();
  final NotificationService _notifs = NotificationService();

  bool _loading = true;
  List<Reminder> _all = [];
  String? _error;

  final List<Map<String, dynamic>> _activities = [
    {
      'id': 'activity_thought',
      'title': 'Thought record',
      'subtitle': 'Capture an automatic thought',
      'icon': Icons.note_alt,
      'defaultTime': const TimeOfDay(hour: 9, minute: 0),
    },
    {
      'id': 'activity_abcd',
      'title': 'ABCD worksheet',
      'subtitle': 'Try an ABCD exercise',
      'icon': Icons.rule,
      'defaultTime': const TimeOfDay(hour: 12, minute: 0),
    },
    {
      'id': 'activity_relax',
      'title': 'Relax (breathing)',
      'subtitle': 'Short relaxation practice',
      'icon': Icons.self_improvement,
      'defaultTime': const TimeOfDay(hour: 18, minute: 0),
    },
    {
      'id': 'activity_drktv',
      'title': 'DrKanhaiya chat',
      'subtitle': 'Check-in with AI companion',
      'icon': Icons.chat_bubble_outline,
      'defaultTime': const TimeOfDay(hour: 20, minute: 0),
    },
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _storage.loadAll();
      items.sort((a, b) {
        try {
          final na = _nextOccurrence(a).millisecondsSinceEpoch;
          final nb = _nextOccurrence(b).millisecondsSinceEpoch;
          return na.compareTo(nb);
        } catch (e) {
          return 1;
        }
      });
      if (mounted) setState(() => _all = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _nextOccurrence(Reminder r) {
    final now = DateTime.now();
    try {
      final dyn = r as dynamic;
      if (dyn.enabled == false) return now.add(const Duration(days: 365 * 10));
    } catch (_) {}

    final scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      r.scheduledAt.hour,
      r.scheduledAt.minute,
      r.scheduledAt.second,
    );

    switch (r.recurrence) {
      case ReminderRecurrence.none:
        if (r.scheduledAt.isAfter(now)) return r.scheduledAt;
        if (scheduledToday.isAfter(now)) return scheduledToday;
        return now.add(const Duration(days: 365 * 10));
      case ReminderRecurrence.daily:
        if (scheduledToday.isAfter(now)) return scheduledToday;
        return scheduledToday.add(const Duration(days: 1));
      case ReminderRecurrence.weekly:
        return _nextWeekdayInstance(r.scheduledAt.weekday, r.scheduledAt);
      case ReminderRecurrence.weekdays:
        for (int offset = 0; offset < 7; offset++) {
          final candidate = scheduledToday.add(Duration(days: offset));
          if (candidate.weekday >= DateTime.monday &&
              candidate.weekday <= DateTime.friday &&
              candidate.isAfter(now)) {
            return candidate;
          }
        }
        return scheduledToday.add(const Duration(days: 1));
      default:
        return scheduledToday;
    }
  }

  DateTime _nextWeekdayInstance(int weekday, DateTime dtTemplate) {
    final now = DateTime.now();
    DateTime candidate = DateTime(
      now.year,
      now.month,
      now.day,
      dtTemplate.hour,
      dtTemplate.minute,
      dtTemplate.second,
    );

    int safety = 0;
    while ((candidate.weekday != weekday || !candidate.isAfter(now)) &&
        safety < 14) {
      candidate = candidate.add(const Duration(days: 1));
      safety++;
    }
    if (!candidate.isAfter(now)) return now.add(const Duration(days: 1));
    return candidate;
  }

  Future<void> _toggle(Reminder r, bool enabled) async {
    Reminder toPersist = r;
    try {
      toPersist = (r as dynamic).copyWith(enabled: enabled) as Reminder;
    } catch (_) {}

    try {
      await (_storage as dynamic).update(toPersist);
    } catch (e) {
      debugPrint('Toggle storage update failed: $e');
    }

    if (enabled) {
      try {
        await _notifs.cancelReminder(toPersist);
      } catch (_) {}
      try {
        await _notifs.scheduleReminder(toPersist);
      } catch (e) {
        debugPrint('Schedule failed: $e');
      }
    } else {
      try {
        await _notifs.cancelReminder(toPersist);
      } catch (e) {
        debugPrint('Cancel failed: $e');
      }
    }

    await _refresh();
  }

  Future<void> _snooze(Reminder r, {int minutes = 15}) async {
    final now = DateTime.now();
    final snoozeDt = now.add(Duration(minutes: minutes));

    final snoozeReminder = Reminder.create(
      id: 'snooze_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Snooze — ${r.title}',
      body: r.body,
      scheduledAt: snoozeDt,
      recurrence: ReminderRecurrence.none,
    );

    Reminder toSchedule = snoozeReminder;
    try {
      toSchedule =
          (snoozeReminder as dynamic).copyWith(enabled: true) as Reminder;
    } catch (_) {}

    try {
      await _notifs.scheduleReminder(toSchedule);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Snoozed for $minutes minutes')));
    } catch (e) {
      debugPrint('Snooze schedule failed: $e');
      try {
        await _notifs.scheduleReminder(snoozeReminder);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Snoozed for $minutes minutes')));
      } catch (e2) {
        debugPrint('Snooze fallback failed: $e2');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to snooze')));
      }
    }
  }

  void _openReminders() {
    try {
      Navigator.pushNamed(context, '/reminders').then((_) => _refresh());
    } catch (e) {
      debugPrint('Navigation failed: $e');
    }
  }

  Future<void> _openCreateActivitySheet() async {
    String activityId = _activities.first['id'] as String;
    TimeOfDay time = _activities.first['defaultTime'] as TimeOfDay;
    ReminderRecurrence recurrence = ReminderRecurrence.none;
    final titleController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final act = _activities.firstWhere((a) => a['id'] == activityId);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Create activity alarm',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: activityId,
                      dropdownColor: _cardBg,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        labelText: 'Activity',
                        labelStyle: const TextStyle(color: Colors.white70),
                      ),
                      items: _activities
                          .map(
                            (a) => DropdownMenuItem<String>(
                              value: a['id'] as String,
                              child: Row(
                                children: [
                                  Icon(
                                    a['icon'] as IconData,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a['title'] as String,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        a['subtitle'] as String,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final chosen = _activities.firstWhere(
                          (a) => a['id'] == v,
                        );
                        setState(() {
                          activityId = v;
                          time = chosen['defaultTime'] as TimeOfDay;
                          titleController.text = chosen['title'] as String;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.access_time,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Time — ${time.format(ctx)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            onPressed: () async {
                              final res = await showTimePicker(
                                context: ctx,
                                initialTime: time,
                              );
                              if (res != null) setState(() => time = res);
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<ReminderRecurrence>(
                          color: _cardBg,
                          onSelected: (r) => setState(() => recurrence = r),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: ReminderRecurrence.none,
                              child: Text(
                                'One time',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const PopupMenuItem(
                              value: ReminderRecurrence.daily,
                              child: Text(
                                'Daily',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const PopupMenuItem(
                              value: ReminderRecurrence.weekly,
                              child: Text(
                                'Weekly',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const PopupMenuItem(
                              value: ReminderRecurrence.weekdays,
                              child: Text(
                                'Weekdays',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              recurrence == ReminderRecurrence.none
                                  ? 'One time'
                                  : recurrence == ReminderRecurrence.daily
                                  ? 'Daily'
                                  : recurrence == ReminderRecurrence.weekly
                                  ? 'Weekly'
                                  : 'Weekdays',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(color: Colors.white12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final now = DateTime.now();
                              DateTime scheduled = DateTime(
                                now.year,
                                now.month,
                                now.day,
                                time.hour,
                                time.minute,
                              );
                              if (!scheduled.isAfter(now) &&
                                  (recurrence == ReminderRecurrence.none ||
                                      recurrence == ReminderRecurrence.daily)) {
                                scheduled = scheduled.add(
                                  const Duration(days: 1),
                                );
                              }

                              final activity = _activities.firstWhere(
                                (a) => a['id'] == activityId,
                              );
                              final remTitle = titleController.text.isNotEmpty
                                  ? titleController.text
                                  : (activity['title'] as String);

                              final reminder = Reminder.create(
                                id: 'act_${activityId}_${DateTime.now().millisecondsSinceEpoch}',
                                title: remTitle,
                                body: activity['subtitle'] as String,
                                scheduledAt: scheduled,
                                recurrence: recurrence,
                              );

                              Reminder toPersist = reminder;
                              try {
                                toPersist =
                                    (reminder as dynamic).copyWith(
                                          enabled: true,
                                        )
                                        as Reminder;
                              } catch (_) {}

                              var persisted = false;
                              try {
                                await (_storage as dynamic).create(toPersist);
                                persisted = true;
                              } catch (_) {
                                try {
                                  await (_storage as dynamic).add(toPersist);
                                  persisted = true;
                                } catch (_) {
                                  try {
                                    await (_storage as dynamic).update(
                                      toPersist,
                                    );
                                    persisted = true;
                                  } catch (_) {}
                                }
                              }

                              if (!persisted) {
                                try {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final raw =
                                      prefs.getStringList('ad_hoc_reminders') ??
                                      [];
                                  raw.add(_serializeReminder(toPersist));
                                  await prefs.setStringList(
                                    'ad_hoc_reminders',
                                    raw,
                                  );
                                } catch (pf) {
                                  debugPrint('Fallback save failed: $pf');
                                }
                              }

                              try {
                                await _notifs.scheduleReminder(toPersist);
                              } catch (e) {
                                debugPrint('Schedule activity failed: $e');
                              }

                              Navigator.of(ctx).pop();
                              await _refresh();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _teal3,
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _serializeReminder(Reminder r) {
    final Map<String, dynamic> m = {};
    try {
      final dyn = r as dynamic;
      if (dyn.id != null) m['id'] = dyn.id;
    } catch (_) {}
    try {
      final dyn = r as dynamic;
      if (dyn.title != null) m['title'] = dyn.title;
    } catch (_) {}
    try {
      final dyn = r as dynamic;
      if (dyn.body != null) m['body'] = dyn.body;
    } catch (_) {}
    try {
      final dyn = r as dynamic;
      if (dyn.scheduledAt != null) {
        final dt = dyn.scheduledAt as DateTime;
        m['scheduledAt'] = dt.toIso8601String();
      }
    } catch (_) {}
    try {
      final dyn = r as dynamic;
      if (dyn.recurrence != null) m['recurrence'] = dyn.recurrence.toString();
    } catch (_) {}
    try {
      final dyn = r as dynamic;
      m['enabled'] = dyn.enabled ?? true;
    } catch (_) {}
    return json.encode(m);
  }

  String _recurrenceLabel(Reminder r) {
    switch (r.recurrence) {
      case ReminderRecurrence.none:
        return '';
      case ReminderRecurrence.daily:
        return 'Every day';
      case ReminderRecurrence.weekly:
        return 'Every week';
      case ReminderRecurrence.weekdays:
        return 'Weekdays';
    }
  }

  String _formatTimeFor(Reminder r) {
    final dt = _nextOccurrence(r);
    try {
      final fmt = DateFormat.jm();
      return fmt.format(dt);
    } catch (_) {
      return '${r.scheduledAt.hour.toString().padLeft(2, '0')}:${r.scheduledAt.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildContent() {
    if (_loading) {
      return SizedBox(
        height: 96,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(
                'Loading reminders...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Failed to load reminders',
              style: TextStyle(color: Colors.red.shade200),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(backgroundColor: _teal3),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _openReminders,
                  child: const Text('Open'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final enabledList = _all.where((r) {
      try {
        final dyn = r as dynamic;
        return dyn.enabled != false;
      } catch (_) {
        return true;
      }
    }).toList();

    final next = enabledList.isNotEmpty ? enabledList.first : null;

    if (next == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reminders',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'No active reminders. Tap to add one.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _openCreateActivitySheet,
                icon: const Icon(Icons.add_alarm),
                label: const Text('Add activity alarm'),
                style: ElevatedButton.styleFrom(backgroundColor: _teal3),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _openReminders,
                icon: const Icon(Icons.list),
                label: const Text('All reminders'),
                style: ElevatedButton.styleFrom(backgroundColor: _teal4),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _refresh,
                child: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white12),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // -- next reminder view --
    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [_teal4, _teal3]),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.notifications, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                next.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    _formatTimeFor(next),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  if (_recurrenceLabel(next).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _recurrenceLabel(next),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                next.body,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Tooltip(
              message: 'Enable / disable reminder',
              child: Switch(
                value: (() {
                  try {
                    final dyn = next as dynamic;
                    return dyn.enabled != false;
                  } catch (_) {
                    return true;
                  }
                })(),
                onChanged: (v) => _toggle(next, v),
                activeColor: _teal3,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<int>(
                  tooltip: 'Snooze',
                  onSelected: (mins) => _snooze(next, minutes: mins),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 5, child: Text('Snooze 5m')),
                    PopupMenuItem(value: 15, child: Text('Snooze 15m')),
                    PopupMenuItem(value: 30, child: Text('Snooze 30m')),
                    PopupMenuItem(value: 60, child: Text('Snooze 60m')),
                  ],
                  child: TextButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.snooze, color: Colors.white70),
                    label: const Text(
                      'Snooze',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: _openCreateActivitySheet,
                  style: ElevatedButton.styleFrom(backgroundColor: _teal3),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: _openReminders,
                  style: ElevatedButton.styleFrom(backgroundColor: _teal4),
                  child: const Icon(Icons.list),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openReminders,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reminders',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    tooltip: 'Refresh reminders',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
