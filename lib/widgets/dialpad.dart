import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/sip_bloc.dart';
import '../constants.dart';

class Dialpad extends StatelessWidget {
  /// Called when a key is tapped — passes the digit/character pressed.
  final void Function(String digit) onKeyPressed;

  /// Called when the green call button is tapped.
  final VoidCallback onCall;

  const Dialpad({
    super.key,
    required this.onKeyPressed,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sipState = context.watch<SipBloc>().state;
    final canCall = sipState.isRegistered && !sipState.isBusy;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Digit grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: AppConstants.dialpadKeys.length,
            itemBuilder: (_, i) {
              final digit = AppConstants.dialpadKeys[i][0];
              final sub   = AppConstants.dialpadKeys[i][1];
              return _DialKey(
                digit: digit,
                sub: sub,
                onTap: () => onKeyPressed(digit),
              );
            },
          ),

          // Call button row
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: canCall ? onCall : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: canCall
                          ? (colorScheme.primaryContainer == colorScheme.surface
                              ? Colors.green.shade600
                              : colorScheme.primaryContainer)
                          : colorScheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      boxShadow: canCall
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.2),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.call,
                      color: canCall
                          ? (colorScheme.primaryContainer == colorScheme.surface
                              ? Colors.white
                              : colorScheme.onPrimaryContainer)
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      size: 32,
                    ),
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

class _DialKey extends StatelessWidget {
  final String digit;
  final String sub;
  final VoidCallback onTap;

  const _DialKey({required this.digit, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
