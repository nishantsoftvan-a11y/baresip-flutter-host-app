import 'dart:async';

import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/sip_bloc.dart';
import '../utils/call_log_service.dart';
import 'call_stats_widget.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SipBloc>().state;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: state.hasIncoming
            ? _IncomingCallView(state: state)
            : _ActiveCallView(state: state),
      ),
    );
  }
}

// ── Incoming call ─────────────────────────────────────────────────────────────

class _IncomingCallView extends StatelessWidget {
  final SipState state;
  const _IncomingCallView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bloc = context.read<SipBloc>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 60),

        // Caller info
        Column(
          children: [
            _Avatar(uri: state.callPeerUri, size: 100),
            const SizedBox(height: 24),
            Text(
              'Incoming Call',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatUri(state.callPeerUri),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),

        // Pulse animation ring
        _PulseRing(child: _Avatar(uri: state.callPeerUri, size: 70)),

        // Answer / Reject
        Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallActionButton(
                icon: Icons.call_end,
                color: colorScheme.error,
                iconColor: colorScheme.onError,
                label: 'Decline',
                onTap: () => bloc.add(const RejectCallSip()),
              ),
              _CallActionButton(
                icon: Icons.call,
                color: Colors.green.shade600,
                iconColor: Colors.white,
                label: 'Answer',
                onTap: () => bloc.add(const AnswerCallSip()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Active / outgoing call ────────────────────────────────────────────────────

class _ActiveCallView extends StatefulWidget {
  final SipState state;
  const _ActiveCallView({required this.state});

  @override
  State<_ActiveCallView> createState() => _ActiveCallViewState();
}

class _ActiveCallViewState extends State<_ActiveCallView> {
  bool _showStats = false;
  bool _isSharing = false;
  String? _prevPeerUri;
  CallState? _prevCallState;

  // Background logger — polls every second regardless of the stats UI toggle.
  Timer? _logTimer;

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    // If we're already in an established/held call when the widget mounts
    if (s.callPeerUri.isNotEmpty) {
      CallLogService.instance.startSession(
        peerUri: s.callPeerUri,
        direction: s.callState == CallState.incoming ? 'incoming' : 'outgoing',
      );
      _prevPeerUri = s.callPeerUri;
      _prevCallState = s.callState;
    }
    if (s.callState == CallState.established || s.callState == CallState.held) {
      _startLogPolling();
    }
  }

  @override
  void didUpdateWidget(_ActiveCallView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final s = widget.state;
    final prev = oldWidget.state;

    // Start a new session when a call begins (peer URI becomes non-empty)
    if (s.callPeerUri.isNotEmpty && _prevPeerUri != s.callPeerUri) {
      final direction = s.callState == CallState.incoming
          ? 'incoming'
          : 'outgoing';
      CallLogService.instance.startSession(
        peerUri: s.callPeerUri,
        direction: direction,
      );
    }

    // Log every state transition
    if (s.callState != _prevCallState && s.callState != null) {
      CallLogService.instance.logState(s.callState!.name);
    }
    if (s.callState == null && _prevCallState != null) {
      CallLogService.instance.logState('closed');
    }

    // Start/stop the background log poller when call state changes
    final nowActive =
        s.callState == CallState.established || s.callState == CallState.held;
    final wasActive =
        prev.callState == CallState.established ||
        prev.callState == CallState.held;
    if (nowActive && !wasActive) _startLogPolling();
    if (!nowActive && wasActive) _stopLogPolling();

    _prevPeerUri = s.callPeerUri;
    _prevCallState = s.callState;
  }

  @override
  void dispose() {
    _stopLogPolling();
    super.dispose();
  }

  void _startLogPolling() {
    _logTimer?.cancel();
    _logTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final stats = await SipClient.instance.getCallStats();
        if (stats != null) CallLogService.instance.logStats(stats);
      } catch (_) {}
    });
  }

  void _stopLogPolling() {
    _logTimer?.cancel();
    _logTimer = null;
  }

  Future<void> _shareLog() async {
    setState(() => _isSharing = true);
    try {
      CallLogService.instance.endSession();
      await CallLogService.instance.shareLog(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share log: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bloc = context.read<SipBloc>();
    final isEstablished = state.callState == CallState.established;
    final isHeld = state.callState == CallState.held;

    return Column(
      children: [
        const SizedBox(height: 50),

        // Status label
        Text(
          state.callLabel,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isEstablished
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: isEstablished ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 1.5,
            fontFeatures: isEstablished
                ? const [FontFeature.tabularFigures()]
                : null,
          ),
        ),

        const SizedBox(height: 24),

        // Avatar
        _Avatar(uri: state.callPeerUri, size: 80),
        const SizedBox(height: 16),

        // Peer URI
        Text(
          _formatUri(state.callPeerUri),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        if (isHeld)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Call on hold',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        const SizedBox(height: 12),

        // ── Stats toggle & panel ─────────────────────────────────────────
        if (isEstablished || isHeld) ..._buildStatsSection(colorScheme),

        const Spacer(),

        // Control buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Row 1: mute, speaker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ToggleButton(
                    icon: state.isMuted ? Icons.mic_off : Icons.mic,
                    label: state.isMuted ? 'Unmute' : 'Mute',
                    active: state.isMuted,
                    onTap: isEstablished || isHeld
                        ? () => bloc.add(const ToggleMuteSip())
                        : null,
                  ),
                  _ToggleButton(
                    icon: _getRouteIcon(state.currentRoute),
                    label: _getRouteLabel(state.currentRoute),
                    active: state.currentRoute != AudioRoute.earpiece,
                    onTap: isEstablished
                        ? () => _handleSpeakerTap(context, state)
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Share log button (visible only when established or held)
              if (isEstablished || isHeld)
                TextButton.icon(
                  onPressed: _isSharing ? null : _shareLog,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share, size: 18),
                  label: Text(_isSharing ? 'Sharing…' : 'Share Call Log'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Hang up
              GestureDetector(
                onTap: () => bloc.add(const HangupCallSip()),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.error.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.call_end,
                    color: colorScheme.onError,
                    size: 32,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStatsSection(ColorScheme colorScheme) {
    return [
      // Toggle chip
      GestureDetector(
        onTap: () => setState(() => _showStats = !_showStats),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _showStats
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _showStats
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 15,
                color: _showStats
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                _showStats ? 'Hide Stats' : 'Show Stats',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _showStats
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),

      // Collapsible stats widget
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) =>
            SizeTransition(sizeFactor: anim, child: child),
        child: _showStats
            ? Padding(
                key: const ValueKey('stats'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: CallStatsWidget(visible: true, refreshIntervalMs: 1000),
              )
            : const SizedBox.shrink(key: ValueKey('no_stats')),
      ),
    ];
  }

  IconData _getRouteIcon(AudioRoute route) {
    switch (route) {
      case AudioRoute.speaker:
        return Icons.volume_up;
      case AudioRoute.bluetooth:
        return Icons.bluetooth;
      case AudioRoute.wiredHeadset:
        return Icons.headset;
      case AudioRoute.earpiece:
        return Icons.volume_down;
    }
  }

  String _getRouteLabel(AudioRoute route) {
    switch (route) {
      case AudioRoute.speaker:
        return 'Speaker';
      case AudioRoute.bluetooth:
        return 'Bluetooth';
      case AudioRoute.wiredHeadset:
        return 'Headset';
      case AudioRoute.earpiece:
        return 'Earpiece';
    }
  }

  Future<void> _handleSpeakerTap(BuildContext context, SipState state) async {
    final client = SipClient.instance;
    final colorScheme = Theme.of(context).colorScheme;

    try {
      final routes = await client.getAvailableRoutes();
      final hasBluetooth = routes.contains(AudioRoute.bluetooth);

      if (hasBluetooth) {
        if (!context.mounted) return;

        final selectedRoute = await showDialog<AudioRoute>(
          context: context,
          builder: (BuildContext ctx) {
            return AlertDialog(
              backgroundColor: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Select Audio Route',
                textAlign: TextAlign.center,
              ),
              contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.phone_android,
                      color: state.currentRoute == AudioRoute.earpiece
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      'Earpiece',
                      style: TextStyle(
                        color: state.currentRoute == AudioRoute.earpiece
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: state.currentRoute == AudioRoute.earpiece
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () => Navigator.of(ctx).pop(AudioRoute.earpiece),
                  ),
                  Divider(color: colorScheme.outlineVariant, height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.volume_up,
                      color: state.currentRoute == AudioRoute.speaker
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      'Speaker',
                      style: TextStyle(
                        color: state.currentRoute == AudioRoute.speaker
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: state.currentRoute == AudioRoute.speaker
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () => Navigator.of(ctx).pop(AudioRoute.speaker),
                  ),
                  Divider(color: colorScheme.outlineVariant, height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.bluetooth,
                      color: state.currentRoute == AudioRoute.bluetooth
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      'Bluetooth',
                      style: TextStyle(
                        color: state.currentRoute == AudioRoute.bluetooth
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: state.currentRoute == AudioRoute.bluetooth
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () => Navigator.of(ctx).pop(AudioRoute.bluetooth),
                  ),
                ],
              ),
            );
          },
        );

        if (selectedRoute != null) {
          await client.setAudioRoute(selectedRoute);
        }
      } else {
        final next = state.currentRoute == AudioRoute.speaker
            ? AudioRoute.earpiece
            : AudioRoute.speaker;
        await client.setAudioRoute(next);
      }
    } catch (e) {
      // ignore
    }
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String uri;
  final double size;
  const _Avatar({required this.uri, required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(uri);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 2.0,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _initials(String uri) {
    final clean = uri.replaceAll(RegExp(r'sip:|@.*'), '');
    if (clean.isEmpty) return '?';
    return clean[0].toUpperCase();
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.3,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: active
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: active
                    ? Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.5),
                      )
                    : null,
              ),
              child: Icon(
                icon,
                color: active
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseRing extends StatefulWidget {
  final Widget child;
  const _PulseRing({required this.child});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _scale = Tween(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: _opacity.value),
              ),
            ),
          ),
          child!,
        ],
      ),
      child: widget.child,
    );
  }
}

String _formatUri(String uri) {
  if (uri.isEmpty) return 'Unknown';
  return uri.replaceAll(RegExp(r'^sip:'), '').split('@').first;
}
