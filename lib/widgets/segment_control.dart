import 'package:flutter/material.dart';

class SegmentControl extends StatelessWidget {
  final List<String> options;
  final List<String>? labels;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const SegmentControl({
    super.key,
    required this.options,
    this.labels,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: enabled
              ? colorScheme.primary
              : colorScheme.primary.withValues(alpha: 0.4),
          selectedForegroundColor: colorScheme.onPrimary,
          foregroundColor: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surface,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        segments: List.generate(options.length, (index) {
          final opt = options[index];
          final label = labels != null ? labels![index] : opt.toUpperCase();
          return ButtonSegment<String>(
            value: opt,
            label: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          );
        }),
        selected: {selected},
        onSelectionChanged: enabled
            ? (newSelection) => onChanged(newSelection.first)
            : null,
        showSelectedIcon: false,
      ),
    );
  }
}
