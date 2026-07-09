import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../bloc/setup_bloc.dart';
import '../bloc/sip_bloc.dart';
import '../constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/segment_control.dart';
import '../widgets/text_label_field.dart';
import '../utils/file_picker_helper.dart';

// ── SetupScreen entry ─────────────────────────────────────────────────────────

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SetupBloc>(
      create: (_) {
        final bloc = SetupBloc();
        // Pre-fill from existing SipBloc config if available
        final config = context.read<SipBloc>().state.config;
        if (config != null) {
          bloc.add(SetupLoadFromConfig(config));
        }
        return bloc;
      },
      child: const _SetupForm(),
    );
  }
}

// ── _SetupForm (StatefulWidget for controllers + form key only) ───────────────
class _SetupForm extends StatefulWidget {
  const _SetupForm();

  @override
  State<_SetupForm> createState() => _SetupFormState();
}

class _SetupFormState extends State<_SetupForm> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers — pure UI sync concern; all booleans/enums live in SetupBloc
  final _usernameCtrl = TextEditingController(
    text: AppConstants.defaultUsername,
  );
  final _passwordCtrl = TextEditingController(
    text: AppConstants.defaultPassword,
  );
  final _displayNameCtrl = TextEditingController(
    text: AppConstants.defaultDisplayName,
  );
  final _hostCtrl = TextEditingController(text: AppConstants.defaultHost);
  final _portCtrl = TextEditingController(text: AppConstants.defaultPort);
  final _stunCtrl = TextEditingController();
  final _stunPortCtrl = TextEditingController(text: '3478');
  final _stunRefreshPeriodCtrl = TextEditingController(text: '30');
  final _authUsernameCtrl = TextEditingController(
    text: AppConstants.defaultAuthUsername,
  );
  final _mtlsAliasCtrl = TextEditingController(
    text: AppConstants.defaultMtlsAlias,
  );
  final _enrollmentUrlCtrl = TextEditingController(
    text: AppConstants.defaultEnrollmentUrl,
  );
  final _authTokenCtrl = TextEditingController(
    text: AppConstants.defaultEnrollmentToken,
  );
  final _clientCertCtrl = TextEditingController(text: '');
  final _privateKeyCtrl = TextEditingController(text: '');
  final _caCertCtrl = TextEditingController(text: '');
  final _turnServerCtrl = TextEditingController();
  final _turnPortCtrl = TextEditingController(text: '3478');
  final _turnUsernameCtrl = TextEditingController();
  final _turnPasswordCtrl = TextEditingController();
  final _iceKeepAliveIntervalCtrl = TextEditingController(text: '15');

  // Track last synced token to avoid redundant controller updates
  int _lastSyncToken = 0;

  @override
  void dispose() {
    for (final c in [
      _usernameCtrl,
      _passwordCtrl,
      _displayNameCtrl,
      _hostCtrl,
      _portCtrl,
      _stunCtrl,
      _stunPortCtrl,
      _stunRefreshPeriodCtrl,
      _authUsernameCtrl,
      _mtlsAliasCtrl,
      _enrollmentUrlCtrl,
      _authTokenCtrl,
      _clientCertCtrl,
      _privateKeyCtrl,
      _caCertCtrl,
      _turnServerCtrl,
      _turnPortCtrl,
      _turnUsernameCtrl,
      _turnPasswordCtrl,
      _iceKeepAliveIntervalCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.phone].request();
  }

  // ── File Picker for PEM files ───────────────────────────────────────────────

  Future<void> _pickPemFile(TextEditingController controller) async {
    try {
      final result = await FilePickerHelper.pickAndReadFile(
        allowedExtensions: ['pem', 'crt', 'key', 'cer', 'txt', 'p12', 'pfx'],
      );

      if (result != null) {
        controller.text = result.content;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File loaded: ${result.fileName}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String?> _promptForPassword() async {
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final passwordCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Enter PKCS12 Password'),
          content: TextField(
            controller: passwordCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: 'Leave empty if none',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, passwordCtrl.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _extractAndFillPkcs12(Uint8List bytes, String fileName) async {
    try {
      Map<String, String>? parsed;
      try {
        parsed = await SipClient.instance.extractPemFromPkcs12(
          pkcs12Data: bytes,
          password: '',
        );
      } catch (e) {
        if (!mounted) return;
        final errStr = e.toString();
        if (errStr.contains('PASSWORD_REQUIRED') ||
            errStr.contains('invalid password') ||
            errStr.contains('SecImport') ||
            errStr.contains('auth')) {
          final password = await _promptForPassword();
          if (password == null) {
            return;
          }
          parsed = await SipClient.instance.extractPemFromPkcs12(
            pkcs12Data: bytes,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      if (parsed.containsKey('clientCert')) {
        _clientCertCtrl.text = parsed['clientCert']!;
      }
      if (parsed.containsKey('privateKey')) {
        _privateKeyCtrl.text = parsed['privateKey']!;
      }
      if (parsed.containsKey('caCert')) {
        _caCertCtrl.text = parsed['caCert']!;
      }

      final List<String> fields = [];
      if (parsed.containsKey('clientCert')) fields.add('Client Certificate');
      if (parsed.containsKey('privateKey')) fields.add('Private Key');
      if (parsed.containsKey('caCert')) fields.add('CA Certificate');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully extracted PKCS12 (${fields.join(", ")}) from $fileName',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error extracting PKCS12: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickAndAutoFillCombinedPem() async {
    try {
      final filePath = await FilePickerHelper.pickFile(
        allowedExtensions: ['pem', 'crt', 'key', 'cer', 'txt', 'p12', 'pfx'],
      );

      if (filePath == null) return;
      if (!mounted) return;

      final fileName = filePath.split('/').last;

      if (filePath.endsWith('.p12') || filePath.endsWith('.pfx')) {
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        await _extractAndFillPkcs12(bytes, fileName);
      } else {
        final content = await FilePickerHelper.readFileContent(filePath);
        if (content == null) return;
        if (!mounted) return;

        final parsed = FilePickerHelper.parseCombinedPem(content);
        if (parsed.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No valid PEM blocks found in the selected file.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        if (parsed.containsKey('clientCert')) {
          _clientCertCtrl.text = parsed['clientCert']!;
        }
        if (parsed.containsKey('privateKey')) {
          _privateKeyCtrl.text = parsed['privateKey']!;
        }
        if (parsed.containsKey('caCert')) {
          _caCertCtrl.text = parsed['caCert']!;
        }

        final List<String> fields = [];
        if (parsed.containsKey('clientCert')) fields.add('Client Certificate');
        if (parsed.containsKey('privateKey')) fields.add('Private Key');
        if (parsed.containsKey('caCert')) fields.add('CA Certificate');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported: ${fields.join(", ")} from $fileName',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ── Bloc listeners ──────────────────────────────────────────────────────────

  void _handleSetupBloc(BuildContext context, SetupState state) {
    // ── Sync controllers when syncToken changes ──────────────────────────────
    if (state.syncToken != _lastSyncToken) {
      _lastSyncToken = state.syncToken;
      if (state.syncUsername != null) {
        _usernameCtrl.text = state.syncUsername!;
      }
      if (state.syncPassword != null) {
        _passwordCtrl.text = state.syncPassword!;
      }
      if (state.syncDisplayName != null) {
        _displayNameCtrl.text = state.syncDisplayName!;
      }
      if (state.syncHost != null) {
        _hostCtrl.text = state.syncHost!;
      }
      if (state.syncPort != null) {
        _portCtrl.text = state.syncPort!;
      }
      if (state.syncStun != null) {
        _stunCtrl.text = state.syncStun!;
      }
      if (state.syncStunPort != null) {
        _stunPortCtrl.text = state.syncStunPort!;
      }
      if (state.syncStunRefreshPeriod != null) {
        _stunRefreshPeriodCtrl.text = state.syncStunRefreshPeriod!;
      }
      if (state.syncAuthUsername != null) {
        _authUsernameCtrl.text = state.syncAuthUsername!;
      }
      if (state.syncMtlsAlias != null) {
        _mtlsAliasCtrl.text = state.syncMtlsAlias!;
      }
      if (state.syncTurn != null) {
        _turnServerCtrl.text = state.syncTurn!;
      }
      if (state.syncTurnPort != null) {
        _turnPortCtrl.text = state.syncTurnPort!;
      }
      if (state.syncTurnUsername != null) {
        _turnUsernameCtrl.text = state.syncTurnUsername!;
      }
      if (state.syncTurnPassword != null) {
        _turnPasswordCtrl.text = state.syncTurnPassword!;
      }
      if (state.syncIceKeepAliveInterval != null) {
        _iceKeepAliveIntervalCtrl.text = state.syncIceKeepAliveInterval!;
      }
    }

    // ── Handle pending SIP action ────────────────────────────────────────────
    if (state.pendingAction != SetupPendingAction.none) {
      final sipBloc = context.read<SipBloc>();

      switch (state.pendingAction) {
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
          break;
        case SetupPendingAction.plainLogin:
          if (state.pendingConfig != null) {
            sipBloc.add(InitializeAndLoginSip(state.pendingConfig!));
            if (Navigator.canPop(context)) Navigator.pop(context);
          }
          break;
        case SetupPendingAction.none:
          break;
        default:
          break;
      }

      // Consume the pending action so we don't re-fire
      context.read<SetupBloc>().add(const SetupPendingConsumed());
    }
  }

  void _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    // Read bloc reference before the async gap
    final setupBloc = context.read<SetupBloc>();
    final setupState = setupBloc.state;
    await _requestPermissions();
    if (!mounted) return;

    setupBloc.add(
      SetupSubmit(
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
        displayName: _displayNameCtrl.text,
        host: _hostCtrl.text,
        port: _portCtrl.text,
        stunServer: _stunCtrl.text,
        stunPort: _stunPortCtrl.text,
        stunRefreshPeriod: _stunRefreshPeriodCtrl.text,
        stunAllowPrivateAddress: setupState.stunAllowPrivateAddress,
        stunAllowPrivateServer: setupState.stunAllowPrivateServer,
        stunDnsSrv: setupState.stunDnsSrv,
        useRportSignalling: setupState.useRportSignalling,
        useRportMedia: setupState.useRportMedia,
        authUsername: _authUsernameCtrl.text,
        mtlsAlias: _mtlsAliasCtrl.text,
        caCertPem: _caCertCtrl.text,
        clientCertPem: _clientCertCtrl.text,
        privateKeyPem: _privateKeyCtrl.text,
        enrollmentUrl: '',
        authToken: '',
        turnServer: _turnServerCtrl.text,
        turnPort: _turnPortCtrl.text,
        turnUsername: _turnUsernameCtrl.text,
        turnPassword: _turnPasswordCtrl.text,
        iceAggressiveNomination: setupState.iceAggressiveNomination,
        iceKeepAliveInterval: _iceKeepAliveIntervalCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<SetupBloc, SetupState>(
      listener: _handleSetupBloc,
      child: BlocBuilder<SetupBloc, SetupState>(
        builder: (context, setupState) {
          final sipState = context.watch<SipBloc>().state;

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('SIP Account Setup'),
            ),
            body: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeaderBanner(colorScheme, theme),
                        const SizedBox(height: 24),

                        _buildEndpointIdentityCard(
                          setupState,
                          sipState,
                          colorScheme,
                        ),
                        const SizedBox(height: 24),
                        _buildProtocolOptionsCard(
                          setupState,
                          sipState,
                          colorScheme,
                        ),
                        const SizedBox(height: 24),
                        _buildMtlsSecurityCard(
                          setupState,
                          sipState,
                          colorScheme,
                        ),
                        const SizedBox(height: 24),
                        _buildAdvancedCardToggle(setupState, colorScheme),
                        if (setupState.showAdvanced) ...[
                          const SizedBox(height: 12),
                          _buildAdvancedCard(setupState, sipState, colorScheme),
                        ],
                        const SizedBox(height: 36),
                        _buildActionButton(setupState, sipState, colorScheme),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Sub-component widget builder methods ───────────────────────────────────

  Widget _buildHeaderBanner(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_person, color: colorScheme.primary, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Set up your SIP endpoint credentials, TLS parameters, NAT options, or mutual TLS certs below.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndpointIdentityCard(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(AppConstants.sectionEndpointIdentity),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextLabelField(
                  controller: _usernameCtrl,
                  label: AppConstants.labelUsername,
                  icon: Icons.person_outline,
                  isRequired: true,
                  enabled: !sipState.isRegistered,
                ),
                const SizedBox(height: 16),
                _passwordField(context, sipState.isRegistered, setupState),
                const SizedBox(height: 16),
                TextLabelField(
                  controller: _hostCtrl,
                  label: AppConstants.labelHost,
                  icon: Icons.dns_outlined,
                  isRequired: true,
                  enabled: !sipState.isRegistered,
                  hint: AppConstants.hintHost,
                ),
                const SizedBox(height: 16),
                TextLabelField(
                  controller: _displayNameCtrl,
                  label: AppConstants.labelDisplayName,
                  icon: Icons.badge_outlined,
                  enabled: !sipState.isRegistered,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProtocolOptionsCard(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(AppConstants.sectionProtocolOptions),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _segmentLabel(AppConstants.labelTransportProtocol),
                SegmentControl(
                  options: AppConstants.transportOptions
                      .map((t) => t.wireName)
                      .toList(),
                  labels: AppConstants.transportOptions
                      .map((t) => t.label)
                      .toList(),
                  selected: setupState.transport.wireName,
                  enabled: !sipState.isRegistered,
                  onChanged: (val) => context.read<SetupBloc>().add(
                    SetupChangeTransport(SipTransport.fromString(val)),
                  ),
                ),
                const SizedBox(height: 20),
                _segmentLabel(AppConstants.labelNatTraversal),
                SegmentControl(
                  options: AppConstants.natOptions
                      .map((n) => n.wireName)
                      .toList(),
                  labels: AppConstants.natOptions.map((n) => n.label).toList(),
                  selected: setupState.mediaNat.wireName,
                  enabled: !sipState.isRegistered,
                  onChanged: (val) => context.read<SetupBloc>().add(
                    SetupChangeMediaNat(MediaNat.fromString(val)),
                  ),
                ),
                if (setupState.mediaNat != MediaNat.none) ...[
                  const SizedBox(height: 16),
                  _buildNatTraversalConfigArea(
                    setupState,
                    sipState,
                    colorScheme,
                  ),
                ],
                const SizedBox(height: 20),
                _segmentLabel(AppConstants.labelMediaEncryption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(AppConstants.mediaEncOptions.length, (
                    i,
                  ) {
                    final enc = AppConstants.mediaEncOptions[i];
                    final selected = setupState.mediaEncryption == enc;
                    return ChoiceChip(
                      label: Text(enc.label),
                      selected: selected,
                      onSelected: sipState.isRegistered
                          ? null
                          : (_) => context.read<SetupBloc>().add(
                              SetupChangeMediaEnc(enc),
                            ),
                      selectedColor: colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMtlsSecurityCard(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(AppConstants.sectionMtlsSecurity),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Enable Client Certificate Auth',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Presents custom client certs during secure handshake.',
                  ),
                  value: setupState.useMtls,
                  activeTrackColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  onChanged: sipState.isRegistered
                      ? null
                      : (val) =>
                            context.read<SetupBloc>().add(SetupToggleMtls(val)),
                ),
                if (setupState.useMtls) ...[
                  const Divider(height: 24),
                  TextLabelField(
                    controller: _mtlsAliasCtrl,
                    label: AppConstants.labelMtlsAlias,
                    icon: Icons.vpn_key_outlined,
                    isRequired: true,
                    enabled: !sipState.isRegistered,
                  ),
                  const SizedBox(height: 16),
                  if (!sipState.isRegistered) ...[
                    // ───────────────────────────────────────────────────
                    OutlinedButton.icon(
                      onPressed: _pickAndAutoFillCombinedPem,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Import .p12 and load the values'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextLabelField(
                    controller: _clientCertCtrl,
                    label: AppConstants.labelClientCert,
                    icon: Icons.description_outlined,
                    isRequired: true,
                    enabled: !sipState.isRegistered,
                    hint: AppConstants.hintCertPem,
                    maxLines: 4,
                    suffixIcon: !sipState.isRegistered
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.folder_open_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                                tooltip: 'Pick file',
                                onPressed: () => _pickPemFile(_clientCertCtrl),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.content_paste_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                                tooltip: 'Paste from clipboard',
                                onPressed: () async {
                                  final data = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  if (data?.text != null)
                                    _clientCertCtrl.text = data!.text!;
                                },
                              ),
                            ],
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextLabelField(
                    controller: _privateKeyCtrl,
                    label: AppConstants.labelClientKey,
                    icon: Icons.description_outlined,
                    isRequired: true,
                    enabled: !sipState.isRegistered,
                    hint: AppConstants.hintKeyPem,
                    maxLines: 4,
                    suffixIcon: !sipState.isRegistered
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.folder_open_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                                tooltip: 'Pick file',
                                onPressed: () => _pickPemFile(_privateKeyCtrl),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.content_paste_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                                tooltip: 'Paste from clipboard',
                                onPressed: () async {
                                  final data = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  if (data?.text != null)
                                    _privateKeyCtrl.text = data!.text!;
                                },
                              ),
                            ],
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextLabelField(
                    controller: _caCertCtrl,
                    label: AppConstants.labelCaCert,
                    icon: Icons.description_outlined,
                    isRequired: true,
                    enabled: !sipState.isRegistered,
                    hint: AppConstants.hintCertPem,
                    maxLines: 4,
                    suffixIcon: !sipState.isRegistered
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.folder_open_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                                tooltip: 'Pick file',
                                onPressed: () => _pickPemFile(_caCertCtrl),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.content_paste_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                                tooltip: 'Paste from clipboard',
                                onPressed: () async {
                                  final data = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  if (data?.text != null)
                                    _caCertCtrl.text = data!.text!;
                                },
                              ),
                            ],
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedCardToggle(
    SetupState setupState,
    ColorScheme colorScheme,
  ) {
    return GestureDetector(
      onTap: () => context.read<SetupBloc>().add(const SetupToggleAdvanced()),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              setupState.showAdvanced ? Icons.expand_less : Icons.expand_more,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'Advanced connection configurations',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedCard(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextLabelField(
              controller: _portCtrl,
              label: AppConstants.labelPort,
              icon: Icons.settings_ethernet,
              keyboardType: TextInputType.number,
              enabled: !sipState.isRegistered,
            ),
            const SizedBox(height: 16),
            _authUsernameTile(context, sipState.isRegistered, setupState),
            _buildMediaCodecsSection(
              setupState,
              sipState,
              colorScheme,
              Theme.of(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    return CustomButton(
      type: CustomButtonType.filled,
      backgroundColor: sipState.isRegistered
          ? colorScheme.error
          : colorScheme.primary,
      foregroundColor: sipState.isRegistered
          ? colorScheme.onError
          : colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(vertical: 16),
      onPressed: sipState.isBusy
          ? null
          : (sipState.isRegistered
                ? () =>
                      context.read<SipBloc>().add(const UnregisterAndResetSip())
                : () => _submit(context)),
      child: sipState.isBusy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: sipState.isRegistered
                    ? colorScheme.onError
                    : colorScheme.onPrimary,
              ),
            )
          : Text(
              sipState.isRegistered ? 'Unregister' : 'Save & Connect',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
    );
  }

  // ── Private builder helpers ───────────────────────────────────────────────

  Widget _passwordField(
    BuildContext context,
    bool isRegistered,
    SetupState setupState,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = !isRegistered && !setupState.useMtls;
    return TextLabelField(
      controller: _passwordCtrl,
      obscureText: setupState.obscurePassword,
      enabled: enabled,
      label: setupState.useMtls
          ? AppConstants.labelPasswordMtls
          : AppConstants.labelPassword,
      icon: Icons.lock_outline,
      hint: setupState.useMtls ? 'No password required' : null,
      suffixIcon: setupState.useMtls || isRegistered
          ? null
          : IconButton(
              icon: Icon(
                setupState.obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => context.read<SetupBloc>().add(
                const SetupToggleObscurePassword(),
              ),
            ),
      validator: (v) =>
          (!setupState.useMtls && !isRegistered && (v == null || v.isEmpty))
          ? 'Password is required'
          : null,
    );
  }

  Widget _authUsernameTile(
    BuildContext context,
    bool isRegistered,
    SetupState setupState,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = !isRegistered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: !enabled
              ? null
              : () => context.read<SetupBloc>().add(
                  SetupToggleAuthUsername(!setupState.useAuthUsername),
                ),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: setupState.useAuthUsername,
                    onChanged: !enabled
                        ? null
                        : (v) => context.read<SetupBloc>().add(
                            SetupToggleAuthUsername(v ?? false),
                          ),
                    activeColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PBX requires an authentication username',
                    style: TextStyle(
                      color: setupState.useAuthUsername
                          ? (enabled
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ))
                          : colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (setupState.useAuthUsername) ...[
          const SizedBox(height: 12),
          TextLabelField(
            controller: _authUsernameCtrl,
            enabled: enabled,
            label: AppConstants.labelAuthUsername,
            icon: Icons.manage_accounts_outlined,
            validator: setupState.useAuthUsername && enabled
                ? (v) => (v == null || v.trim().isEmpty)
                      ? 'Auth username is required when enabled'
                      : null
                : null,
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNatTraversalConfigArea(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    if (setupState.mediaNat == MediaNat.none) return const SizedBox.shrink();

    final String title;
    final String description;
    final IconData icon;

    switch (setupState.mediaNat) {
      case MediaNat.stun:
        title = "STUN Configuration";
        description =
            "STUN helps discover public IP and port addresses behind NAT firewalls.";
        icon = Icons.settings_input_antenna_outlined;
        break;
      case MediaNat.turn:
        title = "TURN Relay Configuration";
        description =
            "TURN relays voice packets through a media proxy server when direct connection is blocked.";
        icon = Icons.swap_calls_outlined;
        break;
      case MediaNat.ice:
        title = "ICE Negotiation Configuration";
        description =
            "ICE negotiates the optimal media traversal path dynamically using STUN and TURN candidates.";
        icon = Icons.waves_outlined;
        break;
      case MediaNat.none:
        return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // Render the fields based on Selected Mode
            if (setupState.mediaNat == MediaNat.stun)
              _buildStunFields(setupState, sipState, colorScheme),
            if (setupState.mediaNat == MediaNat.turn)
              _buildTurnFields(setupState, sipState, colorScheme),
            if (setupState.mediaNat == MediaNat.ice)
              _buildIceFields(setupState, sipState, colorScheme),

            // Render advanced NAT fields behind a toggle button
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                context.read<SetupBloc>().add(const SetupToggleAdvancedNat());
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          setupState.showAdvancedNat
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Advanced NAT & RPORT Settings",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.settings_outlined,
                      size: 14,
                      color: colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
            if (setupState.showAdvancedNat) ...[
              const SizedBox(height: 8),
              _buildAdvancedNatFields(setupState, sipState, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStunFields(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextLabelField(
            controller: _stunCtrl,
            label: "STUN Server",
            icon: Icons.dns_outlined,
            hint: "e.g. stun.l.google.com",
            enabled: !sipState.isRegistered,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'STUN server is required';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: TextLabelField(
            controller: _stunPortCtrl,
            label: "Port",
            icon: Icons.numbers_outlined,
            hint: "3478",
            keyboardType: TextInputType.number,
            enabled: !sipState.isRegistered,
            validator: (v) {
              if (v != null && v.isNotEmpty) {
                final val = int.tryParse(v);
                if (val == null || val < 1 || val > 65535) {
                  return 'Invalid';
                }
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTurnFields(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextLabelField(
                controller: _turnServerCtrl,
                label: "TURN Server",
                icon: Icons.dns_outlined,
                hint: "e.g. turn.example.com",
                enabled: !sipState.isRegistered,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'TURN server is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: TextLabelField(
                controller: _turnPortCtrl,
                label: "Port",
                icon: Icons.numbers_outlined,
                hint: "3478",
                keyboardType: TextInputType.number,
                enabled: !sipState.isRegistered,
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final val = int.tryParse(v);
                    if (val == null || val < 1 || val > 65535) {
                      return 'Invalid';
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextLabelField(
                controller: _turnUsernameCtrl,
                label: "TURN Username",
                icon: Icons.person_outline,
                enabled: !sipState.isRegistered,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Username is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextLabelField(
                controller: _turnPasswordCtrl,
                obscureText: true,
                label: "TURN Password",
                icon: Icons.lock_outline,
                enabled: !sipState.isRegistered,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Password is required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIceFields(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ICE uses STUN to gather candidate list
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextLabelField(
                controller: _stunCtrl,
                label: "ICE STUN Server",
                icon: Icons.dns_outlined,
                hint: "e.g. stun.l.google.com",
                enabled: !sipState.isRegistered,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'STUN server is required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: TextLabelField(
                controller: _stunPortCtrl,
                label: "Port",
                icon: Icons.numbers_outlined,
                hint: "3478",
                keyboardType: TextInputType.number,
                enabled: !sipState.isRegistered,
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final val = int.tryParse(v);
                    if (val == null || val < 1 || val > 65535) {
                      return 'Invalid';
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 20),

        // Optional TURN relay candidates for ICE
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Row(
            children: [
              Icon(Icons.swap_calls_outlined, size: 14, color: Colors.grey),
              SizedBox(width: 6),
              Text(
                "Optional TURN Relay (Recommended)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextLabelField(
                controller: _turnServerCtrl,
                label: "TURN Relay Server",
                icon: Icons.dns_outlined,
                hint: "e.g. turn.example.com",
                enabled: !sipState.isRegistered,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: TextLabelField(
                controller: _turnPortCtrl,
                label: "Port",
                icon: Icons.numbers_outlined,
                hint: "3478",
                keyboardType: TextInputType.number,
                enabled: !sipState.isRegistered,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextLabelField(
                controller: _turnUsernameCtrl,
                label: "TURN Username",
                icon: Icons.person_outline,
                enabled: !sipState.isRegistered,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextLabelField(
                controller: _turnPasswordCtrl,
                obscureText: true,
                label: "TURN Password",
                icon: Icons.lock_outline,
                enabled: !sipState.isRegistered,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        const Divider(height: 20),

        // ICE Specific settings
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Row(
            children: [
              Icon(Icons.waves_outlined, size: 14, color: Colors.grey),
              SizedBox(width: 6),
              Text(
                "ICE Negotiation Settings",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              _buildCompactSwitchRow(
                colorScheme: colorScheme,
                label: "ICE Aggressive Nomination",
                value: setupState.iceAggressiveNomination,
                onChanged: sipState.isRegistered
                    ? null
                    : (val) => context.read<SetupBloc>().add(
                        SetupToggleIceAggressiveNomination(val),
                      ),
              ),
              const Divider(),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "ICE Keep Alive Interval (s)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextLabelField(
                      controller: _iceKeepAliveIntervalCtrl,
                      label: "Interval",
                      icon: Icons.timer_outlined,
                      hint: "15",
                      keyboardType: TextInputType.number,
                      enabled: !sipState.isRegistered,
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final val = int.tryParse(v);
                          if (val == null || val <= 0) {
                            return 'Invalid';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedNatFields(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextLabelField(
                  controller: _stunRefreshPeriodCtrl,
                  label: "STUN Refresh Period (s)",
                  icon: Icons.refresh_outlined,
                  hint: "30",
                  keyboardType: TextInputType.number,
                  enabled: !sipState.isRegistered,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final val = int.tryParse(v);
                      if (val == null || val <= 0) {
                        return 'Must be > 0';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(),
          _buildCompactSwitchRow(
            colorScheme: colorScheme,
            label: "STUN allow on private address",
            value: setupState.stunAllowPrivateAddress,
            onChanged: sipState.isRegistered
                ? null
                : (val) => context.read<SetupBloc>().add(
                    SetupToggleStunAllowPrivateAddress(val),
                  ),
          ),
          const Divider(),
          _buildCompactSwitchRow(
            colorScheme: colorScheme,
            label: "STUN allow with private server",
            value: setupState.stunAllowPrivateServer,
            onChanged: sipState.isRegistered
                ? null
                : (val) => context.read<SetupBloc>().add(
                    SetupToggleStunAllowPrivateServer(val),
                  ),
          ),
          const Divider(),
          _buildCompactSwitchRow(
            colorScheme: colorScheme,
            label: "STUN DNS SRV request",
            value: setupState.stunDnsSrv,
            onChanged: sipState.isRegistered
                ? null
                : (val) =>
                      context.read<SetupBloc>().add(SetupToggleStunDnsSrv(val)),
          ),
          const Divider(),
          _buildCompactSwitchRow(
            colorScheme: colorScheme,
            label: "Use RPORT for Signalling",
            value: setupState.useRportSignalling,
            onChanged: sipState.isRegistered
                ? null
                : (val) => context.read<SetupBloc>().add(
                    SetupToggleUseRportSignalling(val),
                  ),
          ),
          const Divider(),
          _buildCompactSwitchRow(
            colorScheme: colorScheme,
            label: "Use RPORT for Media",
            value: setupState.useRportMedia,
            onChanged: sipState.isRegistered
                ? null
                : (val) => context.read<SetupBloc>().add(
                    SetupToggleUseRportMedia(val),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSwitchRow({
    required ColorScheme colorScheme,
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: colorScheme.primaryContainer,
          ),
        ],
      ),
    );
  }

  Widget _segmentLabel(String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMediaCodecsSection(
    SetupState setupState,
    SipState sipState,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        _segmentLabel('Audio Codecs (Drag handle to prioritize)'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: setupState.audioCodecs.length,
              onReorderItem: (oldIndex, newIndex) {
                if (sipState.isRegistered) return;
                context.read<SetupBloc>().add(
                  SetupReorderCodecs(oldIndex, newIndex),
                );
              },
              itemBuilder: (context, index) {
                final codec = setupState.audioCodecs[index];
                final isEnabled = setupState.enabledCodecs.contains(codec);
                final displayName = codec.label;

                return ListTile(
                  key: ValueKey(codec.wireName),
                  leading: sipState.isRegistered
                      ? const SizedBox(width: 24)
                      : ReorderableDragStartListener(
                          index: index,
                          child: Icon(
                            Icons.drag_handle,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: isEnabled
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isEnabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: Checkbox(
                    value: isEnabled,
                    activeColor: colorScheme.primary,
                    onChanged: sipState.isRegistered
                        ? null
                        : (val) {
                            if (val == false &&
                                setupState.enabledCodecs.length <= 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'At least one audio codec must be enabled.',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            context.read<SetupBloc>().add(
                              SetupToggleCodec(codec, val ?? false),
                            );
                          },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
