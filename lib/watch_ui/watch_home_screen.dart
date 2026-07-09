import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_bloc.dart';
import '../bloc/sip_bloc.dart';
import '../widgets/call_screen.dart';
import 'watch_setup_screen.dart';

class WatchHomeScreen extends StatelessWidget {
  const WatchHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<SipBloc, SipState>(
      builder: (context, sipState) {
        if (sipState.isInCall) {
          return const CallScreen();
        }

        final hasConfig = sipState.config != null;

        return Scaffold(
          backgroundColor: Colors.black, // Battery saving pure black for Wear OS
          body: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sipState.lastError != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        sipState.lastError!,
                        style: TextStyle(color: colorScheme.error, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  if (!hasConfig)
                    _buildSetupPrompt(context)
                  else
                    _buildWatchDialer(context, sipState),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSetupPrompt(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Icon(Icons.security, color: colorScheme.primary, size: 32),
        const SizedBox(height: 8),
        Text(
          'Sip\nUnconfigured',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WatchSetupScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Setup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildWatchDialer(BuildContext context, SipState sipState) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, homeState) {
        return Column(
          children: [
            // Status Indicator
            _WatchRegStatus(state: sipState.regState),
            const SizedBox(height: 8),
            
            // Input Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Text(
                homeState.dialInput.isEmpty ? 'Enter No.' : homeState.dialInput,
                style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            
            // Mini Dialpad
            SizedBox(
              width: 140, // Constrain width for watch
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final keys = ['1','2','3','4','5','6','7','8','9','*','0','#'];
                  final key = keys[index];
                  return InkWell(
                    onTap: () => context.read<HomeBloc>().add(HomeDialAppend(key)),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(key, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            
            // Actions (Call & Backspace & Settings)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white54, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WatchSetupScreen()),
                    );
                  },
                ),
                const SizedBox(width: 4),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: colorScheme.primaryContainer,
                  onPressed: () {
                    final uri = homeState.dialInput.trim();
                    if (uri.isNotEmpty) {
                      context.read<SipBloc>().add(StartCallSip(uri));
                      context.read<HomeBloc>().add(const HomeDialClear());
                    }
                  },
                  child: Icon(Icons.call, color: colorScheme.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.backspace, color: Colors.white54, size: 20),
                  onPressed: () {
                    context.read<HomeBloc>().add(const HomeDialBackspace());
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WatchRegStatus extends StatelessWidget {
  final RegistrationState state;
  const _WatchRegStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color color;
    IconData icon;
    
    switch (state) {
      case RegistrationState.registering:
        color = colorScheme.tertiary;
        icon = Icons.sync;
        break;
      case RegistrationState.registered:
        color = colorScheme.primary;
        icon = Icons.check_circle;
        break;
      default:
        color = colorScheme.outline;
        icon = Icons.remove_circle_outline;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          state.name.toUpperCase(),
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
