import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../bloc/setup_bloc.dart';
import '../bloc/sip_bloc.dart';

class WatchSetupScreen extends StatelessWidget {
  const WatchSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SetupBloc>(
      create: (_) {
        final bloc = SetupBloc();
        final config = context.read<SipBloc>().state.config;
        if (config != null) {
          bloc.add(SetupLoadFromConfig(config));
        }
        return bloc;
      },
      child: const _WatchSetupForm(),
    );
  }
}

class _WatchSetupForm extends StatefulWidget {
  const _WatchSetupForm();

  @override
  State<_WatchSetupForm> createState() => _WatchSetupFormState();
}

class _WatchSetupFormState extends State<_WatchSetupForm> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();

  // Hidden controllers for mTLS
  final _portCtrl = TextEditingController(text: '5060');
  final _stunCtrl = TextEditingController();
  final _authUsernameCtrl = TextEditingController();
  final _mtlsAliasCtrl = TextEditingController();
  final _enrollmentUrlCtrl = TextEditingController();
  final _authTokenCtrl = TextEditingController();
  final _clientCertCtrl = TextEditingController();
  final _privateKeyCtrl = TextEditingController();
  final _caCertCtrl = TextEditingController();
  int _lastSyncToken = 0;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _stunCtrl.dispose();
    _authUsernameCtrl.dispose();
    _mtlsAliasCtrl.dispose();
    _enrollmentUrlCtrl.dispose();
    _authTokenCtrl.dispose();
    _clientCertCtrl.dispose();
    _privateKeyCtrl.dispose();
    _caCertCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.phone,
      Permission.notification,
    ].request();
  }

  void _submit(BuildContext context) async {
    final setupBloc = context.read<SetupBloc>();
    await _requestPermissions();
    if (!mounted) return;

    setupBloc.add(
      SetupSubmit(
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
        displayName: _usernameCtrl.text,
        host: _hostCtrl.text,
        port: _portCtrl.text,
        stunServer: _stunCtrl.text,
        stunPort: '3478',
        stunRefreshPeriod: '30',
        stunAllowPrivateAddress: false,
        stunAllowPrivateServer: false,
        stunDnsSrv: false,
        useRportSignalling: true,
        useRportMedia: false,
        authUsername: _authUsernameCtrl.text,
        mtlsAlias: _mtlsAliasCtrl.text,
        caCertPem: _caCertCtrl.text,
        clientCertPem: _clientCertCtrl.text,
        privateKeyPem: _privateKeyCtrl.text,
        enrollmentUrl: _enrollmentUrlCtrl.text,
        authToken: _authTokenCtrl.text,
        turnServer: '',
        turnPort: '3478',
        turnUsername: '',
        turnPassword: '',
        iceAggressiveNomination: false,
        iceKeepAliveInterval: '15',
      ),
    );
  }

  void _handleSetupBloc(BuildContext context, SetupState state) {
    if (state.syncToken != _lastSyncToken) {
      _lastSyncToken = state.syncToken;
      if (state.syncUsername != null) _usernameCtrl.text = state.syncUsername!;
      if (state.syncPassword != null) _passwordCtrl.text = state.syncPassword!;
      if (state.syncHost != null) _hostCtrl.text = state.syncHost!;
      if (state.syncPort != null) _portCtrl.text = state.syncPort!;
      if (state.syncStun != null) _stunCtrl.text = state.syncStun!;
      if (state.syncAuthUsername != null)
        _authUsernameCtrl.text = state.syncAuthUsername!;
      if (state.syncMtlsAlias != null)
        _mtlsAliasCtrl.text = state.syncMtlsAlias!;
    }

    if (state.pendingAction != SetupPendingAction.none) {
      final sipBloc = context.read<SipBloc>();
      switch (state.pendingAction) {
        case SetupPendingAction.csrEnroll:
          if (state.pendingConfig != null && state.pendingCsrConfig != null) {
            sipBloc.add(
              InitializeWithCsrAndLoginSip(
                state.pendingConfig!,
                state.pendingCsrConfig!,
              ),
            );
          }
        case SetupPendingAction.mtlsPem:
          if (state.pendingConfig != null && state.pendingMtlsConfig != null) {
            sipBloc.add(
              InitializeWithMtlsAndLoginSip(
                state.pendingConfig!,
                mtlsConfig: state.pendingMtlsConfig,
              ),
            );
            if (Navigator.canPop(context)) Navigator.pop(context);
          }
        case SetupPendingAction.plainLogin:
          if (state.pendingConfig != null) {
            sipBloc.add(InitializeAndLoginSip(state.pendingConfig!));
            if (Navigator.canPop(context)) Navigator.pop(context);
          }
        case SetupPendingAction.none:
          break;
      }
      context.read<SetupBloc>().add(const SetupPendingConsumed());
    }
  }

  void _handleSipBloc(BuildContext context, SipState sipState) {
    final setupBloc = context.read<SetupBloc>();
    final setupState = setupBloc.state;

    if (!setupState.isEnrolling) return;

    if (sipState.lastError != null) {
      setupBloc.add(const SetupEnrollmentDone());
      // Show mini error on watch
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(sipState.lastError!)));
    } else if (!sipState.isBusy && sipState.config != null) {
      setupBloc.add(const SetupEnrollmentDone());
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MultiBlocListener(
      listeners: [
        BlocListener<SetupBloc, SetupState>(listener: _handleSetupBloc),
        BlocListener<SipBloc, SipState>(listener: _handleSipBloc),
      ],
      child: BlocBuilder<SetupBloc, SetupState>(
        builder: (context, setupState) {
          final sipState = context.watch<SipBloc>().state;
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SIP Setup',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),
                        _buildFormFields(),
                        const SizedBox(height: 12),
                        _buildActionButton(setupState, sipState, colorScheme),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (setupState.isEnrolling)
                  _buildLogsOverlay(setupState, colorScheme),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Sub-component widget builder methods ───────────────────────────────────

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildCompactField(context, _usernameCtrl, 'Username', false),
        const SizedBox(height: 6),
        _buildCompactField(context, _passwordCtrl, 'Password', true),
        const SizedBox(height: 6),
        _buildCompactField(context, _hostCtrl, 'Server IP', false),
      ],
    );
  }

  Widget _buildActionButton(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: sipState.isBusy
            ? null
            : (sipState.isRegistered
                  ? () => context.read<SipBloc>().add(
                      const UnregisterAndResetSip(),
                    )
                  : () => _submit(context)),
        style: ElevatedButton.styleFrom(
          backgroundColor: sipState.isRegistered
              ? colorScheme.error
              : colorScheme.primary,
          foregroundColor: sipState.isRegistered
              ? colorScheme.onError
              : colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: sipState.isBusy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: sipState.isRegistered
                      ? colorScheme.onError
                      : colorScheme.onPrimary,
                ),
              )
            : Text(
                sipState.isRegistered ? 'Unregister' : 'Save & Connect',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildLogsOverlay(SetupState setupState, ColorScheme colorScheme) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      alignment: Alignment.center,
      child: Card(
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Enrolling...',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...setupState.enrollmentLogs.map((log) {
                final isLast = setupState.enrollmentLogs.last == log;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    log,
                    style: TextStyle(
                      color: isLast
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Private builder helpers ───────────────────────────────────────────────

  Widget _buildCompactField(
    BuildContext context,
    TextEditingController controller,
    String label,
    bool obscure,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHigh.withValues(alpha: 0.2),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
