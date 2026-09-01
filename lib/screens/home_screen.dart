import 'dart:async';

import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_bloc.dart';
import '../bloc/sip_bloc.dart';
import '../widgets/call_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/dialpad.dart';
import '../widgets/profile_dialog.dart';
import '../widgets/reg_status_chip.dart';
import 'sdk_crash_test_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _profileTapCount = 0;
  bool _showTestingAction = false;
  Timer? _profileTapDebounceTimer;

  @override
  void dispose() {
    _profileTapDebounceTimer?.cancel();
    super.dispose();
  }

  void _showProfile(BuildContext context) {
    showDialog(context: context, builder: (_) => const ProfileDialog());
  }

  void _handleProfileTap() {
    _profileTapDebounceTimer?.cancel();
    _profileTapCount++;

    if (_profileTapCount >= 10) {
      _profileTapCount = 0;
      if (!_showTestingAction) {
        setState(() {
          _showTestingAction = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧪 Developer Testing Mode Enabled!'),
            backgroundColor: Colors.indigo,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // If user does not tap again within 350ms, treat as regular single tap
      _profileTapDebounceTimer = Timer(const Duration(milliseconds: 350), () {
        _profileTapCount = 0;
        if (mounted) {
          _showProfile(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocBuilder<SipBloc, SipState>(
      builder: (context, sipState) {
        // Show active call overlay when in call and not minimized
        if (sipState.isInCall && !sipState.isCallMinimized) {
          return const CallScreen();
        }

        final hasConfig = sipState.config != null;

        return Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 2.0,
            title: Row(
              children: [
                Icon(Icons.phone_in_talk, color: colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  hasConfig
                      ? (sipState.config!.displayName.isNotEmpty
                            ? sipState.config!.displayName
                            : sipState.config!.username)
                      : 'SIP VoIP',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              // SDK Crash & Stability Test button (Unlocked after 10 taps on profile)
              if (_showTestingAction)
                IconButton(
                  icon: const Icon(Icons.shield_outlined, color: Colors.amber),
                  tooltip: 'SDK Crash & Stability Test',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SdkCrashTestScreen(),
                      ),
                    );
                  },
                ),

              // Network indicator
              if (!sipState.networkConnected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.wifi_off,
                    color: colorScheme.error,
                    size: 20,
                  ),
                ),

              // Registration status chip
              if (hasConfig)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: RegStatusChip(state: sipState.regState),
                ),

              // Profile avatar (10 taps unlocks testing icon)
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 8),
                child: GestureDetector(
                  onTap: _handleProfileTap,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      _initials(
                        hasConfig
                            ? (sipState.config!.displayName.isNotEmpty
                                  ? sipState.config!.displayName
                                  : sipState.config!.username)
                            : 'VoIP',
                      ),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Active ongoing call banner when minimized
              if (sipState.isInCall) _OngoingCallBanner(state: sipState),

              // Error banner
              if (sipState.lastError != null)
                _ErrorBanner(
                  message: sipState.lastError!,
                  onDismiss: () =>
                      context.read<SipBloc>().add(const ClearErrorSip()),
                ),

              // Status bar when not registered
              if (hasConfig &&
                  sipState.regState != RegistrationState.registered)
                _RegStatusBar(state: sipState),

              // Dynamic body
              Expanded(
                child: hasConfig
                    ? _DialerBody(sipState: sipState)
                    : _LandingBody(),
              ),
            ],
          ),
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return '?';
  }
}

// ── Dialer Body ───────────────────────────────────────────────────────────────

class _DialerBody extends StatelessWidget {
  final SipState sipState;
  const _DialerBody({required this.sipState});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, homeState) {
        return Column(
          children: [
            // Dial input display
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: _DialInput(
                dialInput: homeState.dialInput,
                onChanged: (value) {
                  // Direct text entry — replace entire input
                  final bloc = context.read<HomeBloc>();
                  bloc.add(const HomeDialClear());
                  for (final ch in value.characters) {
                    bloc.add(HomeDialAppend(ch));
                  }
                },
                onBackspace: () =>
                    context.read<HomeBloc>().add(const HomeDialBackspace()),
              ),
            ),

            // Dialpad
            const Spacer(),
            Dialpad(
              onKeyPressed: (digit) =>
                  context.read<HomeBloc>().add(HomeDialAppend(digit)),
              onCall: () {
                final uri = homeState.dialInput.trim();
                if (uri.isNotEmpty) {
                  context.read<SipBloc>().add(StartCallSip(uri));
                  context.read<HomeBloc>().add(const HomeDialClear());
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// ── Landing Body ──────────────────────────────────────────────────────────────

class _LandingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // M3 Styled security logo container
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 2.0,
                ),
              ),
              child: Icon(
                Icons.security_rounded,
                color: colorScheme.primary,
                size: 54,
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'Secure SIP Client',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Experience end-to-end encrypted VoIP calling with dynamic NAT traversal and custom certificate mutual TLS authentication.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),

            // ── Standard / Full Setup card ─────────────────────────────────
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: colorScheme.onPrimaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'No active account',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'To initiate and receive secure audio calls, you must provision your account credentials and connection protocol.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    CustomButton(
                      type: CustomButtonType.filled,
                      icon: Icons.settings,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SetupScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Configure SIP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: colorScheme.onErrorContainer,
              size: 20,
            ),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _RegStatusBar extends StatelessWidget {
  final SipState state;
  const _RegStatusBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (color, icon, spinning) = switch (state.regState) {
      RegistrationState.registering => (colorScheme.tertiary, Icons.sync, true),
      RegistrationState.registered => (
        colorScheme.primary,
        Icons.check_circle,
        false,
      ),
      RegistrationState.unregistering => (
        colorScheme.outline,
        Icons.remove_circle_outline,
        false,
      ),
      RegistrationState.failed => (
        colorScheme.error,
        Icons.error_outline,
        false,
      ),
      RegistrationState.offline => (
        colorScheme.outline,
        Icons.radio_button_unchecked,
        false,
      ),
    };

    return Container(
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            state.regLabel,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (spinning) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _DialInput extends StatefulWidget {
  final String dialInput;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _DialInput({
    required this.dialInput,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  State<_DialInput> createState() => _DialInputState();
}

class _DialInputState extends State<_DialInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.dialInput);
  }

  @override
  void didUpdateWidget(covariant _DialInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.dialInput != widget.dialInput &&
        _controller.text != widget.dialInput) {
      _controller.value = TextEditingValue(
        text: widget.dialInput,
        selection: TextSelection.collapsed(offset: widget.dialInput.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              readOnly: false,
              showCursor: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter number or SIP URI',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 14,
                  letterSpacing: 0,
                ),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          if (widget.dialInput.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.backspace_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: widget.onBackspace,
            ),
        ],
      ),
    );
  }
}

// ── Ongoing Active Call Banner (When Minimized) ──────────────────────────────

class _OngoingCallBanner extends StatelessWidget {
  final SipState state;
  const _OngoingCallBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bloc = context.read<SipBloc>();
    final isEstablished = state.callState == CallState.established;
    final isHeld = state.callState == CallState.held;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulse green indicator
          GestureDetector(
            onTap: () => bloc.add(const RestoreCallSip()),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isHeld ? Colors.orange.shade700 : Colors.green.shade600,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_in_talk,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Caller info & duration (tap to restore call screen)
          Expanded(
            child: GestureDetector(
              onTap: () => bloc.add(const RestoreCallSip()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isHeld ? Colors.orange : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isHeld
                            ? 'Call on hold'
                            : (isEstablished ? 'Active Call' : state.callLabel),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                      if (isEstablished) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${state.callLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.callPeerUri.isNotEmpty
                        ? state.callPeerUri
                        : 'VoIP Call',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Quick actions: Mute toggle, Maximize button, Hang up
          IconButton(
            icon: Icon(
              state.isMuted ? Icons.mic_off : Icons.mic,
              color: state.isMuted
                  ? colorScheme.error
                  : colorScheme.onPrimaryContainer,
              size: 20,
            ),
            tooltip: state.isMuted ? 'Unmute' : 'Mute',
            onPressed: () => bloc.add(const ToggleMuteSip()),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_full, size: 18),
            tooltip: 'Open call screen',
            onPressed: () => bloc.add(const RestoreCallSip()),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 16),
            ),
            tooltip: 'End call',
            onPressed: () => bloc.add(const HangupCallSip()),
          ),
        ],
      ),
    );
  }
}
