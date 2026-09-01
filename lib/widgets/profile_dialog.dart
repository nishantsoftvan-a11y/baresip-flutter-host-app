import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/sip_bloc.dart';
import '../screens/sdk_crash_test_screen.dart';
import '../screens/setup_screen.dart';
import 'custom_button.dart';

class ProfileDialog extends StatelessWidget {
  const ProfileDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = context.watch<SipBloc>().state;
    final cfg = state.config;
    final bloc = context.read<SipBloc>();

    return Dialog(
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            CircleAvatar(
              radius: 36,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                _initials(cfg?.displayName ?? cfg?.username ?? '?'),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Display name
            Text(
              cfg?.displayName.isNotEmpty == true
                  ? cfg!.displayName
                  : cfg?.username ?? '—',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),

            // SIP address
            Text(
              cfg != null ? '${cfg.username}@${cfg.host}' : 'Unconfigured',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Status
            _StatusRow(state: state),
            const SizedBox(height: 20),

            // Details
            if (cfg != null) ...[
              _InfoTile(label: 'Server', value: '${cfg.host}:${cfg.port}'),
              _InfoTile(label: 'Transport', value: cfg.transport.label),
              _InfoTile(
                label: 'Codecs',
                value: cfg.audioCodecs.map((c) => c.shortName).join(', '),
              ),
              if (cfg.natConfig?.stunServer.isNotEmpty == true)
                _InfoTile(label: 'STUN', value: cfg.natConfig!.stunServer),
              const SizedBox(height: 10),
            ],

            const Divider(),
            const SizedBox(height: 12),

            // Setup Navigation Option inside Dialog
            CustomButton(
              type: CustomButtonType.filled,
              icon: Icons.settings,
              onPressed: () {
                Navigator.pop(context); // Pop Dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SetupScreen()),
                );
              },
              child: const Text(
                'Configure Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            // SDK Crash & Stability Test Option
            CustomButton(
              type: CustomButtonType.outlined,
              icon: Icons.shield_outlined,
              foregroundColor: Colors.amber.shade800,
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SdkCrashTestScreen(),
                  ),
                );
              },
              child: const Text(
                'SDK Crash & Stability Test',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                // Go offline (stays on home screen, keeps config)
                if (state.isRegistered) ...[
                  Expanded(
                    child: CustomButton(
                      type: CustomButtonType.outlined,
                      icon: Icons.cloud_off,
                      foregroundColor: colorScheme.tertiary,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () {
                        Navigator.pop(context);
                        bloc.add(const GoOfflineSip());
                      },
                      child: const Text(
                        'Go Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Go online (registers again)
                if (!state.isRegistered &&
                    state.regState != RegistrationState.registering &&
                    cfg != null) ...[
                  Expanded(
                    child: CustomButton(
                      type: CustomButtonType.outlined,
                      icon: Icons.cloud_done,
                      foregroundColor: colorScheme.primary,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () {
                        Navigator.pop(context);
                        bloc.add(const GoOnlineSip());
                      },
                      child: const Text(
                        'Go Online',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Unregister — clears config
                if (cfg != null)
                  Expanded(
                    child: CustomButton(
                      type: CustomButtonType.outlined,
                      icon: Icons.logout,
                      foregroundColor: colorScheme.error,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () {
                        Navigator.pop(context);
                        bloc.add(const UnregisterAndResetSip());
                      },
                      child: const Text(
                        'Reset Config',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return '?';
  }
}

class _StatusRow extends StatelessWidget {
  final SipState state;
  const _StatusRow({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (label, color) = switch (state.regState) {
      RegistrationState.registered => ('Registered', colorScheme.primary),
      RegistrationState.registering => ('Registering', colorScheme.tertiary),
      RegistrationState.unregistering => ('Unregistered', colorScheme.outline),
      RegistrationState.failed => ('Unregistered', colorScheme.error),
      RegistrationState.offline => ('Idle', colorScheme.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (state.regState == RegistrationState.registering) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
