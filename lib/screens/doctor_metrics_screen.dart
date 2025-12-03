// lib/screens/doctor_metrics_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Color _bgDark = Color(0xFF021515);
const Color _cardDark = Color(0xFF082022);
const Color _accentTeal = Color(0xFF008F89);
const Color _accentYellow = Color(0xFFFFC857);

// Relax feature colors (matching RelaxPage vibe)
const Color _relaxBreathBlue = Color(0xFF3B82F6); // breathing
const Color _relaxPmrViolet = Color(0xFF8B5CF6); // PMR
const Color _relaxGroundGreen = Color(0xFF10B981); // grounding
const Color _relaxMeditationAmber = Color(0xFFF59E0B); // mini meditation

class DoctorMetricsScreen extends StatelessWidget {
  const DoctorMetricsScreen({super.key});

  Future<_MetricsData> _loadMetrics() async {
    final fs = FirebaseFirestore.instance;
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));

    // ✅ Use feature_events (from analytics_helper.trackFeatureUse)
    final snap = await fs
        .collection('feature_events')
        .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('ts', descending: true)
        .limit(5000) // safety cap
        .get();

    final Map<String, int> featureCounts = {};
    final Set<String> uniqueUsers = {};
    int total = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final rawKey = (data['featureKey'] ?? 'unknown').toString();
      final uid = (data['uid'] ?? 'anonymous').toString();

      // ⛔ Duration-type keys: screen_relax_seconds_123 etc — skip from "event count"
      if (rawKey.contains('_seconds_')) {
        continue;
      }

      total += 1;
      featureCounts[rawKey] = (featureCounts[rawKey] ?? 0) + 1;
      uniqueUsers.add(uid);
    }

    final List<_FeatureCount> topFeatures =
        featureCounts.entries
            .map((e) => _FeatureCount(key: e.key, count: e.value))
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));

    return _MetricsData(
      totalEvents30d: total,
      uniqueUsers30d: uniqueUsers.length,
      topFeatures: topFeatures,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgDark,
      child: FutureBuilder<_MetricsData>(
        future: _loadMetrics(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Failed to load metrics: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final data = snap.data ?? _MetricsData.empty();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryRow(data),
              const SizedBox(height: 16),
              _buildTopFeatureCard(data),
              const SizedBox(height: 16),
              _buildFeatureListCard(data),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(_MetricsData data) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Events (30 days)',
            value: data.totalEvents30d.toString(),
            icon: Icons.touch_app_outlined,
            color: _accentTeal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Unique users',
            value: data.uniqueUsers30d.toString(),
            icon: Icons.person_outline,
            color: _accentYellow,
          ),
        ),
      ],
    );
  }

  Widget _buildTopFeatureCard(_MetricsData data) {
    final top = data.topFeatures.isNotEmpty ? data.topFeatures.first : null;

    return Container(
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most used feature (30 days)',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (top == null)
            const Text(
              'No usage events in last 30 days.',
              style: TextStyle(color: Colors.white54),
            )
          else ...[
            Text(
              _prettyFeatureName(top.key),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${top.count} uses (30 days)',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: 1.0,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                _featureVisual(top.key).color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureListCard(_MetricsData data) {
    return Container(
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'Feature breakdown (last 30 days)',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const Divider(color: Colors.white10),
          if (data.topFeatures.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'No feature usage recorded yet.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            ...data.topFeatures.map((f) {
              final double pct = data.totalEvents30d == 0
                  ? 0
                  : (f.count / data.totalEvents30d);
              final visual = _featureVisual(f.key);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 6.0,
                ),
                child: Row(
                  children: [
                    // Icon + color per feature
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: visual.color.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(visual.icon, size: 18, color: visual.color),
                    ),
                    const SizedBox(width: 10),

                    // Name + progress bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _prettyFeatureName(f.key),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                visual.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Count + %
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          f.count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(pct * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  /// 📝 Human-readable feature names
  String _prettyFeatureName(String raw) {
    switch (raw) {
      // ✅ Relax page features (recommended keys)
      case 'feature_relax_breath':
        return 'Relax — Breathing exercises';
      case 'feature_relax_pmr':
        return 'Relax — Progressive muscle relaxation';
      case 'feature_relax_grounding':
        return 'Relax — Grounding 5-4-3-2-1';
      case 'feature_relax_meditation':
        return 'Relax — Mini meditation timer';

      // 🔙 Backward compatibility for old relax keys (before renaming)
      case 'relax_breath':
        return 'Relax — Breathing exercises';
      case 'relax_pmr':
        return 'Relax — Progressive muscle relaxation';
      case 'relax_grounding':
        return 'Relax — Grounding 5-4-3-2-1';
      case 'relax_mini_meditation':
        return 'Relax — Mini meditation timer';

      // ✅ Other core features (you can extend this list)
      case 'feature_thought_record':
        return 'Thought record';
      case 'feature_abcd':
        return 'ABCD worksheet';
      case 'feature_cbt_quiz':
        return 'CBT quiz';
      case 'feature_drktv_chat':
        return 'DrKtv assistant chat';

      // ✅ Screen tracking (RouteAware)
      case 'screen_relax_open':
        return 'Screen — Relax page (open)';
      case 'screen_relax_resume':
        return 'Screen — Relax page (resume)';
      case 'screen_home_open':
        return 'Screen — Home (open)';

      default:
        // fallback: snake_case → Title Case
        return raw
            .replaceAll('_', ' ')
            .replaceAll('-', ' ')
            .split(' ')
            .map(
              (w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}',
            )
            .join(' ');
    }
  }

  /// 🎨 Icon + color per feature key (used in list + top card)
  _FeatureVisual _featureVisual(String raw) {
    switch (raw) {
      // Relax features (new keys)
      case 'feature_relax_breath':
      case 'relax_breath':
        return const _FeatureVisual(
          icon: Icons.air_rounded,
          color: _relaxBreathBlue,
        );
      case 'feature_relax_pmr':
      case 'relax_pmr':
        return const _FeatureVisual(
          icon: Icons.self_improvement_rounded,
          color: _relaxPmrViolet,
        );
      case 'feature_relax_grounding':
      case 'relax_grounding':
        return const _FeatureVisual(
          icon: Icons.spa_rounded,
          color: _relaxGroundGreen,
        );
      case 'feature_relax_meditation':
      case 'relax_mini_meditation':
        return const _FeatureVisual(
          icon: Icons.timer_rounded,
          color: _relaxMeditationAmber,
        );

      // Other core features (add more as needed)
      case 'feature_thought_record':
        return const _FeatureVisual(
          icon: Icons.note_alt_outlined,
          color: _accentTeal,
        );
      case 'feature_abcd':
        return const _FeatureVisual(icon: Icons.rule, color: _accentTeal);
      case 'feature_cbt_quiz':
        return const _FeatureVisual(
          icon: Icons.psychology,
          color: _accentYellow,
        );
      case 'feature_drktv_chat':
        return const _FeatureVisual(
          icon: Icons.chat_bubble_outline,
          color: _accentTeal,
        );

      // Screen tracking
      case 'screen_relax_open':
      case 'screen_relax_resume':
        return const _FeatureVisual(
          icon: Icons.spa_outlined,
          color: _relaxGroundGreen,
        );
      case 'screen_home_open':
        return const _FeatureVisual(
          icon: Icons.home_outlined,
          color: _accentTeal,
        );

      default:
        return const _FeatureVisual(
          icon: Icons.insights_outlined,
          color: _accentTeal,
        );
    }
  }
}

class _MetricsData {
  final int totalEvents30d;
  final int uniqueUsers30d;
  final List<_FeatureCount> topFeatures;

  _MetricsData({
    required this.totalEvents30d,
    required this.uniqueUsers30d,
    required this.topFeatures,
  });

  factory _MetricsData.empty() =>
      _MetricsData(totalEvents30d: 0, uniqueUsers30d: 0, topFeatures: const []);
}

class _FeatureCount {
  final String key;
  final int count;

  _FeatureCount({required this.key, required this.count});
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureVisual {
  final IconData icon;
  final Color color;
  const _FeatureVisual({required this.icon, required this.color});
}
