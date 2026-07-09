import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import 'package:flutter/material.dart';

class RegStatusChip extends StatelessWidget {
  final RegistrationState state;
  const RegStatusChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Map SDK states → 4 display states
    final (label, color, isSpinning) = switch (state) {
      RegistrationState.registered    => ('Registered',    colorScheme.primary,  false),
      RegistrationState.registering   => ('Registering',   colorScheme.tertiary, true),
      RegistrationState.unregistering => ('Unregistered',  colorScheme.outline,   false),
      RegistrationState.failed        => ('Unregistered',  colorScheme.error,   false),
      RegistrationState.offline       => ('Idle',          colorScheme.outlineVariant, false),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isSpinning
              ? SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
                )
              : Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
