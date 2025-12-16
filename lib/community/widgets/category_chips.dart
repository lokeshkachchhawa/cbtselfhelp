import 'package:flutter/material.dart';

const Color teal3 = Color(0xFF008F89);

class CategoryChips extends StatelessWidget {
  final String selected;
  final Function(String) onSelected;

  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const categories = [
    {'id': 'all', 'label': 'All'},
    {'id': 'anxiety', 'label': 'Anxiety'},
    {'id': 'depression', 'label': 'Low mood'},
    {'id': 'sleep', 'label': 'Sleep'},
    {'id': 'relationships', 'label': 'Relationships'},
    {'id': 'self_growth', 'label': 'Self growth'},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = categories[i];
          final isActive = selected == c['id'];

          return ChoiceChip(
            label: Text(c['label']!),
            selected: isActive,
            onSelected: (_) => onSelected(c['id']!),
            selectedColor: teal3,
            backgroundColor: Colors.white.withOpacity(0.08),
            labelStyle: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }
}
