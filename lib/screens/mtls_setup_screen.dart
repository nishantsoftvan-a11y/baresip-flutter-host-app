import 'dart:io';
import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../bloc/setup_bloc.dart';
import '../bloc/sip_bloc.dart';
import '../constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/text_label_field.dart';
import '../utils/file_picker_helper.dart';

// ── MtlsSetupScreen ───────────────────────────────────────────────────────────

class MtlsSetupScreen extends StatelessWidget {
  const MtlsSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SetupBloc>(
      create: (_) {
        final bloc = SetupBloc();
        bloc.add(const SetupToggleMtls(true));
        bloc.add(const SetupToggleCsr(false));
        return bloc;
      },
      child: const _MtlsSetupForm(),
    );
  }
}

// ── _MtlsSetupForm ────────────────────────────────────────────────────────────

class _MtlsSetupForm extends StatefulWidget {
  const _MtlsSetupForm();

  @override
  State<_MtlsSetupForm> createState() => _MtlsSetupFormState();
}

class _MtlsSetupFormState extends State<_MtlsSetupForm> {
  final _formKey = GlobalKey<FormState>();

  final _aliasCtrl = TextEditingController(text: AppConstants.defaultMtlsAlias);
  final _usernameCtrl = TextEditingController(
    text: AppConstants.defaultUsername,
  );
  final _displayCtrl = TextEditingController(
    text: AppConstants.defaultDisplayName,
  );
  final _hostCtrl = TextEditingController(text: AppConstants.defaultHost);
  final _portCtrl = TextEditingController(text: AppConstants.defaultMtlsPort);
  final _clientCertCtrl = TextEditingController(text: '');
  final _privateKeyCtrl = TextEditingController(text: '');
  final _caCertCtrl = TextEditingController(text: '');

  // Track last syncToken to avoid redundant controller updates
  int _lastSyncToken = 0;

  @override
  void dispose() {
    for (final c in [
      _aliasCtrl,
      _usernameCtrl,
      _displayCtrl,
      _hostCtrl,
      _portCtrl,
      _clientCertCtrl,
      _privateKeyCtrl,
      _caCertCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.phone].request();
  }

  // ── File Picker ─────────────────────────────────────────────────────────────

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
    if (state.syncToken == _lastSyncToken) return;
    _lastSyncToken = state.syncToken;
    if (state.syncMtlsAlias != null) _aliasCtrl.text = state.syncMtlsAlias!;
    if (state.syncUsername != null) _usernameCtrl.text = state.syncUsername!;
    if (state.syncDisplayName != null)
      _displayCtrl.text = state.syncDisplayName!;
    if (state.syncHost != null) _hostCtrl.text = state.syncHost!;
    if (state.syncPort != null) _portCtrl.text = state.syncPort!;
  }

  void _handleSetupBlocAction(BuildContext context, SetupState state) {
    if (state.pendingAction == SetupPendingAction.none) return;

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
      default:
        break;
    }
    context.read<SetupBloc>().add(const SetupPendingConsumed());
  }

  void _handleSipBloc(BuildContext context, SipState sipState) {
    final setupBloc = context.read<SetupBloc>();
    if (!setupBloc.state.isEnrolling) return;
    if (sipState.lastError != null) {
      setupBloc.add(const SetupEnrollmentDone());
      _showErrorDialog(context, sipState.lastError!);
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 26),
            const SizedBox(width: 10),
            const Text('mTLS Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SipBloc>().add(const ClearErrorSip());
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  void _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please correct the validation errors in the form (scroll down to check).",
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    final setupBloc = context.read<SetupBloc>();
    final setupState = setupBloc.state;
    await _requestPermissions();
    if (!mounted) return;

    setupBloc.add(
      SetupSubmit(
        username: _usernameCtrl.text,
        password: '',
        displayName: _displayCtrl.text,
        host: _hostCtrl.text,
        port: _portCtrl.text,
        mtlsAlias: _aliasCtrl.text,
        clientCertPem: _clientCertCtrl.text,
        privateKeyPem: _privateKeyCtrl.text,
        caCertPem: _caCertCtrl.text,
        enrollmentUrl: '',
        authToken: '',
        stunServer: '',
        stunPort: '3478',
        stunRefreshPeriod: '30',
        stunAllowPrivateAddress: setupState.stunAllowPrivateAddress,
        stunAllowPrivateServer: setupState.stunAllowPrivateServer,
        stunDnsSrv: setupState.stunDnsSrv,
        useRportSignalling: setupState.useRportSignalling,
        useRportMedia: setupState.useRportMedia,
        authUsername: '',
        turnServer: '',
        turnPort: '3478',
        turnUsername: '',
        turnPassword: '',
        iceAggressiveNomination: setupState.iceAggressiveNomination,
        iceKeepAliveInterval: '15',
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MultiBlocListener(
      listeners: [
        BlocListener<SetupBloc, SetupState>(listener: _handleSetupBloc),
        BlocListener<SetupBloc, SetupState>(listener: _handleSetupBlocAction),
        BlocListener<SipBloc, SipState>(listener: _handleSipBloc),
      ],
      child: BlocBuilder<SetupBloc, SetupState>(
        builder: (context, setupState) {
          final sipState = context.watch<SipBloc>().state;
          final isBusy = sipState.isBusy;
          final isLocked = sipState.isRegistered;

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Manual mTLS Setup'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'What is mTLS?',
                  onPressed: () => _showHelpSheet(context, colorScheme, theme),
                ),
              ],
            ),
            body: Stack(
              children: [
                Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    children: [
                      _buildCnWarningBanner(colorScheme, theme),
                      const SizedBox(height: 20),
                      _buildConnectionCard(colorScheme, theme, isLocked),
                      const SizedBox(height: 20),
                      _buildMediaEncCard(
                        context,
                        setupState,
                        colorScheme,
                        isLocked,
                      ),
                      const SizedBox(height: 20),
                      _buildPemCard(colorScheme, theme, isLocked),
                      const SizedBox(height: 20),
                      _buildServerRequirementsCard(colorScheme, theme),
                    ],
                  ),
                ),
                // Sticky bottom button
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomBar(
                    context,
                    colorScheme,
                    sipState,
                    isBusy,
                    isLocked,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── CN Warning Banner ───────────────────────────────────────────────────────

  Widget _buildCnWarningBanner(ColorScheme cs, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.error.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certificate CN must match your SIP username',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The server rejects registrations where the CN in your client cert '
                  'does not exactly match the SIP username field below.\n'
                  'Example: username = 1001  →  cert CN = 1001',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onErrorContainer,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showCnCommandSheet(context, cs, theme),
                  child: Text(
                    'Show how to generate a correct cert →',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
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

  // ── Connection Card ─────────────────────────────────────────────────────────

  Widget _buildConnectionCard(ColorScheme cs, ThemeData theme, bool isLocked) {
    return _sectionCard(
      cs: cs,
      header: 'Connection & Identity',
      icon: Icons.account_circle_outlined,
      children: [
        TextLabelField(
          controller: _aliasCtrl,
          label: 'Certificate Alias',
          icon: Icons.vpn_key_outlined,
          isRequired: true,
          enabled: !isLocked,
          hint: 'e.g. 1001',
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Alias is required' : null,
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Used as the filename prefix for stored cert files. '
            'Typically the same as the SIP username.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        TextLabelField(
          controller: _usernameCtrl,
          label: 'SIP Username  (= cert CN)',
          icon: Icons.person_outline,
          isRequired: true,
          enabled: !isLocked,
          hint: 'e.g. 1001',
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Username is required' : null,
        ),
        const SizedBox(height: 14),
        TextLabelField(
          controller: _displayCtrl,
          label: 'Display Name',
          icon: Icons.badge_outlined,
          enabled: !isLocked,
          hint: 'e.g. Alice',
        ),
        const SizedBox(height: 14),
        TextLabelField(
          controller: _hostCtrl,
          label: 'SIP Server',
          icon: Icons.dns_outlined,
          isRequired: true,
          enabled: !isLocked,
          hint: 'e.g. 100.48.139.58',
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Server is required' : null,
        ),
        const SizedBox(height: 14),
        TextLabelField(
          controller: _portCtrl,
          label: 'TLS Port',
          icon: Icons.settings_ethernet,
          enabled: !isLocked,
          hint: '5061',
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final p = int.tryParse(v.trim());
            if (p == null || p < 1 || p > 65535) return 'Invalid port';
            return null;
          },
        ),
      ],
    );
  }

  // ── Media Encryption Card ───────────────────────────────────────────────────

  Widget _buildMediaEncCard(
    BuildContext context,
    SetupState setupState,
    ColorScheme cs,
    bool isLocked,
  ) {
    final options = AppConstants.mediaEncOptions;

    return _sectionCard(
      cs: cs,
      header: 'Media Encryption',
      icon: Icons.lock_outlined,
      children: [
        Text(
          'SRTP is strongly recommended with mTLS to encrypt both signalling and media.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(options.length, (i) {
            final enc = options[i];
            final selected = setupState.mediaEncryption == enc;
            return ChoiceChip(
              label: Text(enc.label),
              selected: selected,
              onSelected: isLocked
                  ? null
                  : (_) =>
                        context.read<SetupBloc>().add(SetupChangeMediaEnc(enc)),
              selectedColor: cs.primaryContainer,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── PEM Certificates Card ───────────────────────────────────────────────────

  Widget _buildPemCard(ColorScheme cs, ThemeData theme, bool isLocked) {
    return _sectionCard(
      cs: cs,
      header: 'PEM Credentials',
      icon: Icons.description_outlined,
      children: [
        // ────────────────────────────────────────────────────────────────
        if (!isLocked) ...[
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
        _pemFieldWithPaste(
          context: context,
          ctrl: _clientCertCtrl,
          label: 'Client Certificate (PEM)',
          hint: '-----BEGIN CERTIFICATE-----',
          icon: Icons.verified_outlined,
          enabled: !isLocked,
          extraNote: 'CN in this cert must match the SIP username above.',
          cs: cs,
          theme: theme,
        ),
        const SizedBox(height: 16),
        _pemFieldWithPaste(
          context: context,
          ctrl: _privateKeyCtrl,
          label: 'Client Private Key (PEM)',
          hint: '-----BEGIN PRIVATE KEY-----',
          icon: Icons.key_outlined,
          enabled: !isLocked,
          extraNote: 'PKCS#8 format. Must match the certificate above.',
          cs: cs,
          theme: theme,
        ),
        const SizedBox(height: 16),
        _pemFieldWithPaste(
          context: context,
          ctrl: _caCertCtrl,
          label: 'Root CA Certificate (PEM)',
          hint: '-----BEGIN CERTIFICATE-----',
          icon: Icons.workspace_premium_outlined,
          enabled: !isLocked,
          extraNote:
              'The CA that signed the server certificate. '
              'Used to verify the server during the TLS handshake.',
          cs: cs,
          theme: theme,
        ),
      ],
    );
  }

  /// Text area with paste-from-clipboard and file picker buttons.
  Widget _pemFieldWithPaste({
    required BuildContext context,
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    required bool enabled,
    required String extraNote,
    required ColorScheme cs,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextLabelField(
          controller: ctrl,
          label: label,
          icon: icon,
          isRequired: true,
          enabled: enabled,
          hint: hint,
          maxLines: 5,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return '$label is required';
            if (!v.trim().startsWith('-----BEGIN')) {
              return 'Must be a valid PEM block starting with -----BEGIN';
            }
            return null;
          },
          suffixIcon: enabled
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.folder_open_rounded,
                        color: cs.primary,
                        size: 18,
                      ),
                      tooltip: 'Pick file',
                      onPressed: () => _pickPemFile(ctrl),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.content_paste_rounded,
                        color: cs.primary,
                        size: 18,
                      ),
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (data?.text != null) ctrl.text = data!.text!;
                      },
                    ),
                  ],
                )
              : null,
        ),
        if (extraNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              extraNote,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  // ── Server Requirements Card ────────────────────────────────────────────────

  Widget _buildServerRequirementsCard(ColorScheme cs, ThemeData theme) {
    const rows = [
      _InfoRow(
        Icons.vpn_lock_outlined,
        'TLS_REQUIRE_CLIENT_CERT',
        'Set to "true" or "optional" in server .env. '
            '"false" disables client-cert verification entirely.',
      ),
      _InfoRow(
        Icons.security_outlined,
        'Server TLS port',
        'Default is 5061. Kamailio listens on this port for TLS connections.',
      ),
      _InfoRow(
        Icons.check_circle_outline,
        'CA trust',
        'The CA that signed your client cert must be loaded as ca_list in kamailio/tls.cfg.',
      ),
      _InfoRow(
        Icons.no_accounts_outlined,
        'No SIP password needed',
        'With a valid client cert, Kamailio bypasses digest auth entirely (passwordless login).',
      ),
      _InfoRow(
        Icons.sync_outlined,
        'Re-registration',
        'Cert-based sessions re-register every 60 s. '
            'Expired certs cause a 403 after the cert validity window closes.',
      ),
    ];

    return _sectionCard(
      cs: cs,
      header: 'Server Requirements',
      icon: Icons.checklist_outlined,
      children: [
        ...rows.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(r.icon, size: 18, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: '${r.title}  ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: r.body),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Bottom action bar ───────────────────────────────────────────────────────

  Widget _buildBottomBar(
    BuildContext context,
    ColorScheme cs,
    SipState sipState,
    bool isBusy,
    bool isLocked,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: isLocked
          ? CustomButton(
              type: CustomButtonType.filled,
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              padding: const EdgeInsets.symmetric(vertical: 16),
              icon: Icons.logout,
              onPressed: isBusy
                  ? null
                  : () => context.read<SipBloc>().add(
                      const UnregisterAndResetSip(),
                    ),
              child: const Text(
                'Unregister',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          : CustomButton(
              type: CustomButtonType.filled,
              padding: const EdgeInsets.symmetric(vertical: 16),
              icon: isBusy ? null : Icons.lock,
              onPressed: isBusy ? null : () => _submit(context),
              child: isBusy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Text(
                      'Connect with mTLS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
    );
  }

  // ── Bottom sheets ───────────────────────────────────────────────────────────

  void _showCnCommandSheet(
    BuildContext context,
    ColorScheme cs,
    ThemeData theme,
  ) {
    const command =
        'openssl req -new -newkey rsa:2048 -nodes \\\n'
        '  -keyout client_1001.key \\\n'
        '  -out client_1001.csr \\\n'
        '  -subj "/CN=1001/O=YourOrg"\n\n'
        'openssl x509 -req \\\n'
        '  -in client_1001.csr \\\n'
        '  -CA ca.crt -CAkey ca.key \\\n'
        '  -CAcreateserial \\\n'
        '  -out client_1001.crt \\\n'
        '  -days 365 \\\n'
        '  -extfile <(echo "extendedKeyUsage=clientAuth")';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Generate a per-user client certificate',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Run on your CA server. Replace 1001 with the actual SIP username.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      command,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, size: 18, color: cs.primary),
                    tooltip: 'Copy command',
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: command));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'After signing, paste client_1001.crt into "Client Certificate", '
              'client_1001.key into "Client Private Key", and ca.crt into '
              '"Root CA Certificate" above.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context, ColorScheme cs, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.35,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.security, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  'What is Manual mTLS?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _helpParagraph(
              theme,
              cs,
              'Mutual TLS (mTLS) is a two-way certificate handshake. Both the client (your phone) '
              'and the server present X.509 certificates, so each side can verify the other\'s identity.',
            ),
            _helpParagraph(
              theme,
              cs,
              'In Manual mode you supply three PEM blocks yourself:\n'
              '  • Client Certificate — identifies your device\n'
              '  • Client Private Key  — proves you own the cert\n'
              '  • Root CA Certificate — lets the app verify the server',
            ),
            _helpParagraph(
              theme,
              cs,
              'When the server validates your cert, SIP digest authentication is bypassed completely. '
              'You do not need to set a password.',
            ),
            _helpParagraph(
              theme,
              cs,
              'The key constraint: the CN field in your client certificate must exactly match '
              'the SIP username. The server enforces this with a 403 otherwise.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpParagraph(ThemeData theme, ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          height: 1.55,
        ),
      ),
    );
  }

  // ── Shared card shell ───────────────────────────────────────────────────────

  Widget _sectionCard({
    required ColorScheme cs,
    required String header,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                header,
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Card(
          elevation: 0,
          color: cs.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Simple data class for server requirements rows ────────────────────────────

class _InfoRow {
  final IconData icon;
  final String title;
  final String body;
  const _InfoRow(this.icon, this.title, this.body);
}
