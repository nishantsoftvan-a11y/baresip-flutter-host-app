import 'dart:async';

import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/user_profiles/domain/models/user_profile.dart';

// ── SetupPendingAction ────────────────────────────────────────────────────────

enum SetupPendingAction { none, plainLogin, mtlsPem, csrEnroll }

// ── SetupEvent ────────────────────────────────────────────────────────────────

abstract class SetupEvent {
  const SetupEvent();
}

class SetupLoadFromConfig extends SetupEvent {
  final SipConfig config;
  const SetupLoadFromConfig(this.config);
}

/// Load all fields from a previously saved [UserProfile] into the form.
class SetupLoadFromProfile extends SetupEvent {
  final UserProfile profile;
  const SetupLoadFromProfile(this.profile);
}

class SetupToggleMtls extends SetupEvent {
  final bool value;
  const SetupToggleMtls(this.value);
}

class SetupToggleCsr extends SetupEvent {
  final bool value;
  const SetupToggleCsr(this.value);
}

class SetupToggleObscurePassword extends SetupEvent {
  const SetupToggleObscurePassword();
}

class SetupToggleAdvanced extends SetupEvent {
  const SetupToggleAdvanced();
}

class SetupToggleAdvancedNat extends SetupEvent {
  const SetupToggleAdvancedNat();
}

class SetupToggleAuthUsername extends SetupEvent {
  final bool value;
  const SetupToggleAuthUsername(this.value);
}

class SetupChangeTransport extends SetupEvent {
  final SipTransport transport;
  const SetupChangeTransport(this.transport);
}

class SetupChangeMediaNat extends SetupEvent {
  final MediaNat mediaNat;
  const SetupChangeMediaNat(this.mediaNat);
}

class SetupChangeMediaEnc extends SetupEvent {
  final MediaEncryption mediaEncryption;
  const SetupChangeMediaEnc(this.mediaEncryption);
}

class SetupToggleStunAllowPrivateAddress extends SetupEvent {
  final bool value;
  const SetupToggleStunAllowPrivateAddress(this.value);
}

class SetupToggleStunAllowPrivateServer extends SetupEvent {
  final bool value;
  const SetupToggleStunAllowPrivateServer(this.value);
}

class SetupToggleStunDnsSrv extends SetupEvent {
  final bool value;
  const SetupToggleStunDnsSrv(this.value);
}

class SetupToggleUseRportSignalling extends SetupEvent {
  final bool value;
  const SetupToggleUseRportSignalling(this.value);
}

class SetupToggleUseRportMedia extends SetupEvent {
  final bool value;
  const SetupToggleUseRportMedia(this.value);
}

class SetupToggleIceAggressiveNomination extends SetupEvent {
  final bool value;
  const SetupToggleIceAggressiveNomination(this.value);
}

class SetupToggleCodec extends SetupEvent {
  final AudioCodec codec;
  final bool enabled;
  const SetupToggleCodec(this.codec, this.enabled);
}

class SetupReorderCodecs extends SetupEvent {
  final int oldIndex;
  final int newIndex;
  const SetupReorderCodecs(this.oldIndex, this.newIndex);
}

class SetupSubmit extends SetupEvent {
  final String username;
  final String password;
  final String displayName;
  final String host;
  final String port;
  final String stunServer;
  final String stunPort;
  final String stunRefreshPeriod;
  final bool stunAllowPrivateAddress;
  final bool stunAllowPrivateServer;
  final bool stunDnsSrv;
  final bool useRportSignalling;
  final bool useRportMedia;
  final String authUsername;
  final String mtlsAlias;
  final String caCertPem;
  final String clientCertPem;
  final String privateKeyPem;
  final String enrollmentUrl;
  final String authToken;
  final String turnServer;
  final String turnPort;
  final String turnUsername;
  final String turnPassword;
  final bool iceAggressiveNomination;
  final String iceKeepAliveInterval;
  final String regint;
  final String rwait;

  const SetupSubmit({
    required this.username,
    required this.password,
    required this.displayName,
    required this.host,
    required this.port,
    required this.stunServer,
    required this.stunPort,
    required this.stunRefreshPeriod,
    required this.stunAllowPrivateAddress,
    required this.stunAllowPrivateServer,
    required this.stunDnsSrv,
    required this.useRportSignalling,
    required this.useRportMedia,
    required this.authUsername,
    required this.mtlsAlias,
    required this.caCertPem,
    required this.clientCertPem,
    required this.privateKeyPem,
    required this.enrollmentUrl,
    required this.authToken,
    required this.turnServer,
    required this.turnPort,
    required this.turnUsername,
    required this.turnPassword,
    required this.iceAggressiveNomination,
    required this.iceKeepAliveInterval,
    this.regint = '60',
    this.rwait = '90',
  });
}

class SetupPendingConsumed extends SetupEvent {
  const SetupPendingConsumed();
}

class SetupEnrollmentDone extends SetupEvent {
  const SetupEnrollmentDone();
}

// ── SetupState ────────────────────────────────────────────────────────────────

class SetupState {
  final SipTransport transport;
  final MediaNat mediaNat;
  final MediaEncryption mediaEncryption;
  final bool useMtls;
  final bool useCsr;
  final bool obscurePassword;
  final bool showAdvanced;

  final bool showAdvancedNat;
  final bool useAuthUsername;
  final bool isEnrolling;
  final List<String> enrollmentLogs;
  final int syncToken;
  final List<AudioCodec> audioCodecs;
  final Set<AudioCodec> enabledCodecs;

  final int stunPort;
  final int stunRefreshPeriod;
  final bool stunAllowPrivateAddress;
  final bool stunAllowPrivateServer;
  final bool stunDnsSrv;
  final bool useRportSignalling;
  final bool useRportMedia;

  final int turnPort;
  final bool iceEnabled;
  final bool iceAggressiveNomination;
  final int iceKeepAliveInterval;
  final int regint;
  final int rwait;

  // Text values to sync to controllers on demand (when syncToken changes)
  final String? syncUsername;
  final String? syncPassword;
  final String? syncDisplayName;
  final String? syncHost;
  final String? syncPort;
  final String? syncStun;
  final String? syncStunPort;
  final String? syncStunRefreshPeriod;
  final String? syncAuthUsername;
  final String? syncMtlsAlias;
  final String? syncTurn;
  final String? syncTurnPort;
  final String? syncTurnUsername;
  final String? syncTurnPassword;
  final String? syncIceKeepAliveInterval;
  final String? syncRegint;
  final String? syncRwait;
  // PEM fields — only set when loading from a profile
  final String? syncClientCertPem;
  final String? syncPrivateKeyPem;
  final String? syncCaCertPem;
  final String? syncEnrollmentUrl;
  final String? syncAuthToken;

  final SetupPendingAction pendingAction;
  final SipConfig? pendingConfig;
  final CsrConfig? pendingCsrConfig;
  final MtlsConfig? pendingMtlsConfig;

  const SetupState({
    this.transport = SipTransport.tls,
    this.mediaNat = MediaNat.none,
    this.mediaEncryption = MediaEncryption.srtp,
    this.useMtls = true,
    this.useCsr = false,
    this.obscurePassword = true,
    this.showAdvanced = false,

    this.showAdvancedNat = false,
    this.useAuthUsername = false,
    this.isEnrolling = false,
    this.enrollmentLogs = const [],
    this.syncToken = 0,
    this.audioCodecs = AudioCodec.defaultCodecs,
    this.enabledCodecs = const {
      AudioCodec.opus,
      AudioCodec.g722,
      AudioCodec.pcmu,
      AudioCodec.pcma,
      AudioCodec.g729,
    },
    this.stunPort = 3478,
    this.stunRefreshPeriod = 30,
    this.stunAllowPrivateAddress = true,
    this.stunAllowPrivateServer = true,
    this.stunDnsSrv = true,
    this.useRportSignalling = true,
    this.useRportMedia = false,
    this.turnPort = 3478,
    this.iceEnabled = true,
    this.iceAggressiveNomination = false,
    this.iceKeepAliveInterval = 15,
    this.regint = 60,
    this.rwait = 90,
    this.syncUsername,
    this.syncPassword,
    this.syncDisplayName,
    this.syncHost,
    this.syncPort,
    this.syncStun,
    this.syncStunPort,
    this.syncStunRefreshPeriod,
    this.syncAuthUsername,
    this.syncMtlsAlias,
    this.syncTurn,
    this.syncTurnPort,
    this.syncTurnUsername,
    this.syncTurnPassword,
    this.syncIceKeepAliveInterval,
    this.syncRegint,
    this.syncRwait,
    this.syncClientCertPem,
    this.syncPrivateKeyPem,
    this.syncCaCertPem,
    this.syncEnrollmentUrl,
    this.syncAuthToken,
    this.pendingAction = SetupPendingAction.none,
    this.pendingConfig,
    this.pendingCsrConfig,
    this.pendingMtlsConfig,
  });

  SetupState copyWith({
    SipTransport? transport,
    MediaNat? mediaNat,
    MediaEncryption? mediaEncryption,
    bool? useMtls,
    bool? useCsr,
    bool? obscurePassword,
    bool? showAdvanced,

    bool? showAdvancedNat,
    bool? useAuthUsername,
    bool? isEnrolling,
    List<String>? enrollmentLogs,
    int? syncToken,
    List<AudioCodec>? audioCodecs,
    Set<AudioCodec>? enabledCodecs,
    int? stunPort,
    int? stunRefreshPeriod,
    bool? stunAllowPrivateAddress,
    bool? stunAllowPrivateServer,
    bool? stunDnsSrv,
    bool? useRportSignalling,
    bool? useRportMedia,
    int? turnPort,
    bool? iceEnabled,
    bool? iceAggressiveNomination,
    int? iceKeepAliveInterval,
    int? regint,
    int? rwait,
    String? Function()? syncUsername,
    String? Function()? syncPassword,
    String? Function()? syncDisplayName,
    String? Function()? syncHost,
    String? Function()? syncPort,
    String? Function()? syncStun,
    String? Function()? syncStunPort,
    String? Function()? syncStunRefreshPeriod,
    String? Function()? syncAuthUsername,
    String? Function()? syncMtlsAlias,
    String? Function()? syncTurn,
    String? Function()? syncTurnPort,
    String? Function()? syncTurnUsername,
    String? Function()? syncTurnPassword,
    String? Function()? syncIceKeepAliveInterval,
    String? Function()? syncRegint,
    String? Function()? syncRwait,
    String? Function()? syncClientCertPem,
    String? Function()? syncPrivateKeyPem,
    String? Function()? syncCaCertPem,
    String? Function()? syncEnrollmentUrl,
    String? Function()? syncAuthToken,
    SetupPendingAction? pendingAction,
    SipConfig? Function()? pendingConfig,
    CsrConfig? Function()? pendingCsrConfig,
    MtlsConfig? Function()? pendingMtlsConfig,
  }) {
    return SetupState(
      transport: transport ?? this.transport,
      mediaNat: mediaNat ?? this.mediaNat,
      mediaEncryption: mediaEncryption ?? this.mediaEncryption,
      useMtls: useMtls ?? this.useMtls,
      useCsr: useCsr ?? this.useCsr,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      showAdvanced: showAdvanced ?? this.showAdvanced,

      showAdvancedNat: showAdvancedNat ?? this.showAdvancedNat,
      useAuthUsername: useAuthUsername ?? this.useAuthUsername,
      isEnrolling: isEnrolling ?? this.isEnrolling,
      enrollmentLogs: enrollmentLogs ?? this.enrollmentLogs,
      syncToken: syncToken ?? this.syncToken,
      audioCodecs: audioCodecs ?? this.audioCodecs,
      enabledCodecs: enabledCodecs ?? this.enabledCodecs,
      stunPort: stunPort ?? this.stunPort,
      stunRefreshPeriod: stunRefreshPeriod ?? this.stunRefreshPeriod,
      stunAllowPrivateAddress:
          stunAllowPrivateAddress ?? this.stunAllowPrivateAddress,
      stunAllowPrivateServer:
          stunAllowPrivateServer ?? this.stunAllowPrivateServer,
      stunDnsSrv: stunDnsSrv ?? this.stunDnsSrv,
      useRportSignalling: useRportSignalling ?? this.useRportSignalling,
      useRportMedia: useRportMedia ?? this.useRportMedia,
      turnPort: turnPort ?? this.turnPort,
      iceEnabled: iceEnabled ?? this.iceEnabled,
      iceAggressiveNomination:
          iceAggressiveNomination ?? this.iceAggressiveNomination,
      iceKeepAliveInterval: iceKeepAliveInterval ?? this.iceKeepAliveInterval,
      regint: regint ?? this.regint,
      rwait: rwait ?? this.rwait,
      syncUsername: syncUsername != null ? syncUsername() : this.syncUsername,
      syncPassword: syncPassword != null ? syncPassword() : this.syncPassword,
      syncDisplayName: syncDisplayName != null
          ? syncDisplayName()
          : this.syncDisplayName,
      syncHost: syncHost != null ? syncHost() : this.syncHost,
      syncPort: syncPort != null ? syncPort() : this.syncPort,
      syncStun: syncStun != null ? syncStun() : this.syncStun,
      syncStunPort: syncStunPort != null ? syncStunPort() : this.syncStunPort,
      syncStunRefreshPeriod: syncStunRefreshPeriod != null
          ? syncStunRefreshPeriod()
          : this.syncStunRefreshPeriod,
      syncAuthUsername: syncAuthUsername != null
          ? syncAuthUsername()
          : this.syncAuthUsername,
      syncMtlsAlias: syncMtlsAlias != null
          ? syncMtlsAlias()
          : this.syncMtlsAlias,
      syncTurn: syncTurn != null ? syncTurn() : this.syncTurn,
      syncTurnPort: syncTurnPort != null ? syncTurnPort() : this.syncTurnPort,
      syncTurnUsername: syncTurnUsername != null
          ? syncTurnUsername()
          : this.syncTurnUsername,
      syncTurnPassword: syncTurnPassword != null
          ? syncTurnPassword()
          : this.syncTurnPassword,
      syncIceKeepAliveInterval: syncIceKeepAliveInterval != null
          ? syncIceKeepAliveInterval()
          : this.syncIceKeepAliveInterval,
      syncRegint: syncRegint != null ? syncRegint() : this.syncRegint,
      syncRwait: syncRwait != null ? syncRwait() : this.syncRwait,
      syncClientCertPem: syncClientCertPem != null
          ? syncClientCertPem()
          : this.syncClientCertPem,
      syncPrivateKeyPem: syncPrivateKeyPem != null
          ? syncPrivateKeyPem()
          : this.syncPrivateKeyPem,
      syncCaCertPem: syncCaCertPem != null
          ? syncCaCertPem()
          : this.syncCaCertPem,
      syncEnrollmentUrl: syncEnrollmentUrl != null
          ? syncEnrollmentUrl()
          : this.syncEnrollmentUrl,
      syncAuthToken: syncAuthToken != null
          ? syncAuthToken()
          : this.syncAuthToken,
      pendingAction: pendingAction ?? this.pendingAction,
      pendingConfig: pendingConfig != null
          ? pendingConfig()
          : this.pendingConfig,
      pendingCsrConfig: pendingCsrConfig != null
          ? pendingCsrConfig()
          : this.pendingCsrConfig,
      pendingMtlsConfig: pendingMtlsConfig != null
          ? pendingMtlsConfig()
          : this.pendingMtlsConfig,
    );
  }
}

// ── SetupBloc ─────────────────────────────────────────────────────────────────

class SetupBloc extends Bloc<SetupEvent, SetupState> {
  SetupBloc() : super(const SetupState()) {
    on<SetupLoadFromConfig>((event, emit) {
      final config = event.config;
      final hasMtls =
          config.mtlsAlias != null && config.mtlsAlias!.trim().isNotEmpty;
      final nat = config.natConfig;

      // Compute the full codec list: enabled first, then any remaining.
      final loadedCodecs = config.audioCodecs;
      final fullList = [
        ...loadedCodecs,
        ...AudioCodec.defaultCodecs.where((c) => !loadedCodecs.contains(c)),
        // Include G729 if not already present
        if (!loadedCodecs.contains(AudioCodec.g729) &&
            !AudioCodec.defaultCodecs.contains(AudioCodec.g729))
          AudioCodec.g729,
      ];
      final enabledSet = Set<AudioCodec>.from(loadedCodecs);

      // Infer MediaNat from stored NatConfig
      MediaNat inferredNat = MediaNat.none;
      if (nat != null) {
        if (nat.turnServer.trim().isNotEmpty) {
          inferredNat = MediaNat.turn;
        } else if (nat.iceEnabled) {
          inferredNat = MediaNat.ice;
        } else if (nat.stunServer.trim().isNotEmpty) {
          inferredNat = MediaNat.stun;
        }
      }

      emit(
        state.copyWith(
          transport: config.transport,
          mediaNat: inferredNat,
          mediaEncryption: config.mediaEncryption,
          useMtls: hasMtls,
          useCsr: false,
          useAuthUsername: config.authUsername.isNotEmpty,
          audioCodecs: fullList,
          enabledCodecs: enabledSet,
          syncToken: state.syncToken + 1,
          syncUsername: () => config.username,
          syncPassword: () => config.password,
          syncDisplayName: () => config.displayName,
          syncHost: () => config.host,
          syncPort: () => config.port.toString(),
          syncStun: () => nat != null ? nat.stunServer : '',
          syncStunPort: () => nat != null ? nat.stunPort.toString() : '3478',
          syncStunRefreshPeriod: () =>
              nat != null ? nat.stunRefreshPeriod.toString() : '30',
          syncAuthUsername: () => config.authUsername,
          syncMtlsAlias: () => config.mtlsAlias ?? '',
          stunPort: nat != null ? nat.stunPort : 3478,
          stunRefreshPeriod: nat != null ? nat.stunRefreshPeriod : 30,
          stunAllowPrivateAddress: nat != null
              ? nat.stunAllowPrivateAddress
              : true,
          stunAllowPrivateServer: nat != null
              ? nat.stunAllowPrivateServer
              : true,
          stunDnsSrv: nat != null ? nat.stunDnsSrv : true,
          useRportSignalling: config.useRportSignalling,
          useRportMedia: config.useRportMedia,
          turnPort: nat != null ? nat.turnPort : 3478,
          iceEnabled: nat != null ? nat.iceEnabled : true,
          iceAggressiveNomination: nat != null
              ? nat.iceAggressiveNomination
              : false,
          iceKeepAliveInterval: nat != null ? nat.iceKeepAliveInterval : 15,
          syncTurn: () => nat != null ? nat.turnServer : '',
          syncTurnPort: () => nat != null ? nat.turnPort.toString() : '3478',
          syncTurnUsername: () => nat != null ? nat.turnUsername : '',
          syncTurnPassword: () => nat != null ? nat.turnPassword : '',
          syncIceKeepAliveInterval: () =>
              nat != null ? nat.iceKeepAliveInterval.toString() : '15',
          regint: config.regint,
          rwait: config.rwait,
          syncRegint: () => config.regint.toString(),
          syncRwait: () => config.rwait.toString(),
        ),
      );
    });

    on<SetupLoadFromProfile>((event, emit) {
      final p = event.profile;

      // Parse transport enum
      final transport = SipTransport.fromString(p.transport);

      // Parse media nat
      final mediaNat = MediaNat.values.firstWhere(
        (e) => e.name.toLowerCase() == p.mediaNat.toLowerCase(),
        orElse: () => MediaNat.none,
      );

      // Parse media enc
      final mediaEnc = MediaEncryption.values.firstWhere(
        (e) => e.name.toLowerCase() == p.mediaEncryption.toLowerCase(),
        orElse: () => MediaEncryption.none,
      );

      // Codecs mapping
      final loadedCodecs = p.audioCodecs
          .map((c) => AudioCodec.fromString(c))
          .whereType<AudioCodec>()
          .toList();
      final fullList = [
        ...loadedCodecs,
        ...AudioCodec.defaultCodecs.where((c) => !loadedCodecs.contains(c)),
      ];
      final enabledSet = Set<AudioCodec>.from(loadedCodecs.isEmpty ? AudioCodec.defaultCodecs : loadedCodecs);

      emit(
        state.copyWith(
          transport: transport,
          mediaNat: mediaNat,
          mediaEncryption: mediaEnc,
          useMtls: p.useMtls,
          useCsr: p.useCsr,
          useAuthUsername: p.authUsername.isNotEmpty,
          audioCodecs: fullList,
          enabledCodecs: enabledSet,
          stunPort: p.stunPort,
          stunRefreshPeriod: p.stunRefreshPeriod,
          stunAllowPrivateAddress: p.stunAllowPrivateAddress,
          stunAllowPrivateServer: p.stunAllowPrivateServer,
          stunDnsSrv: p.stunDnsSrv,
          useRportSignalling: p.useRportSignalling,
          useRportMedia: p.useRportMedia,
          turnPort: p.turnPort,
          iceEnabled: p.iceEnabled,
          iceAggressiveNomination: p.iceAggressiveNomination,
          iceKeepAliveInterval: p.iceKeepAliveInterval,
          syncToken: state.syncToken + 1,
          syncUsername: () => p.username,
          syncPassword: () => p.password,
          syncDisplayName: () => p.displayName,
          syncHost: () => p.host,
          syncPort: () => p.port.toString(),
          syncAuthUsername: () => p.authUsername,
          syncMtlsAlias: () => p.mtlsAlias,
          syncStun: () => p.stunServer,
          syncStunPort: () => p.stunPort.toString(),
          syncStunRefreshPeriod: () => p.stunRefreshPeriod.toString(),
          syncTurn: () => p.turnServer,
          syncTurnPort: () => p.turnPort.toString(),
          syncTurnUsername: () => p.turnUsername,
          syncTurnPassword: () => p.turnPassword,
          syncIceKeepAliveInterval: () => p.iceKeepAliveInterval.toString(),
          syncClientCertPem: () => p.clientCertPem,
          syncPrivateKeyPem: () => p.privateKeyPem,
          syncCaCertPem: () => p.caCertPem,
          syncEnrollmentUrl: () => p.enrollmentUrl,
          syncAuthToken: () => p.authToken,
        ),
      );
    });

    on<SetupToggleMtls>((event, emit) {
      if (event.value) {
        emit(
          state.copyWith(
            useMtls: true,
            transport: SipTransport.tls,
            syncToken: state.syncToken + 1,
            syncPort: () => '5061',
          ),
        );
      } else {
        emit(state.copyWith(useMtls: false));
      }
    });

    on<SetupToggleCsr>((event, emit) {
      emit(state.copyWith(useCsr: event.value));
    });

    on<SetupToggleObscurePassword>((event, emit) {
      emit(state.copyWith(obscurePassword: !state.obscurePassword));
    });

    on<SetupToggleAdvanced>((event, emit) {
      emit(state.copyWith(showAdvanced: !state.showAdvanced));
    });

    on<SetupToggleAdvancedNat>((event, emit) {
      emit(state.copyWith(showAdvancedNat: !state.showAdvancedNat));
    });

    on<SetupToggleStunAllowPrivateAddress>((event, emit) {
      emit(state.copyWith(stunAllowPrivateAddress: event.value));
    });

    on<SetupToggleStunAllowPrivateServer>((event, emit) {
      emit(state.copyWith(stunAllowPrivateServer: event.value));
    });

    on<SetupToggleStunDnsSrv>((event, emit) {
      emit(state.copyWith(stunDnsSrv: event.value));
    });

    on<SetupToggleUseRportSignalling>((event, emit) {
      emit(state.copyWith(useRportSignalling: event.value));
    });

    on<SetupToggleUseRportMedia>((event, emit) {
      emit(state.copyWith(useRportMedia: event.value));
    });

    on<SetupToggleIceAggressiveNomination>((event, emit) {
      emit(state.copyWith(iceAggressiveNomination: event.value));
    });

    on<SetupToggleAuthUsername>((event, emit) {
      if (event.value) {
        emit(state.copyWith(useAuthUsername: true));
      } else {
        emit(
          state.copyWith(
            useAuthUsername: false,
            syncToken: state.syncToken + 1,
            syncAuthUsername: () => '',
          ),
        );
      }
    });

    on<SetupChangeTransport>((event, emit) {
      if (event.transport == SipTransport.tls) {
        emit(
          state.copyWith(
            transport: SipTransport.tls,
            syncToken: state.syncToken + 1,
            syncPort: () => '5061',
          ),
        );
      } else {
        emit(
          state.copyWith(
            transport: event.transport,
            syncToken: state.syncToken + 1,
            syncPort: () => '5061',
          ),
        );
      }
    });

    on<SetupChangeMediaNat>((event, emit) {
      emit(state.copyWith(mediaNat: event.mediaNat));
    });

    on<SetupChangeMediaEnc>((event, emit) {
      emit(state.copyWith(mediaEncryption: event.mediaEncryption));
    });

    on<SetupToggleCodec>((event, emit) {
      final updatedEnabled = Set<AudioCodec>.from(state.enabledCodecs);
      if (event.enabled) {
        updatedEnabled.add(event.codec);
      } else {
        updatedEnabled.remove(event.codec);
      }
      emit(state.copyWith(enabledCodecs: updatedEnabled));
    });

    on<SetupReorderCodecs>((event, emit) {
      final updatedCodecs = List<AudioCodec>.from(state.audioCodecs);
      final item = updatedCodecs.removeAt(event.oldIndex);
      updatedCodecs.insert(event.newIndex, item);
      emit(state.copyWith(audioCodecs: updatedCodecs));
    });

    on<SetupSubmit>(_onSetupSubmit);

    on<SetupPendingConsumed>((event, emit) {
      emit(
        state.copyWith(
          pendingAction: SetupPendingAction.none,
          pendingConfig: () => null,
          pendingCsrConfig: () => null,
          pendingMtlsConfig: () => null,
        ),
      );
    });

    on<SetupEnrollmentDone>((event, emit) {
      emit(state.copyWith(isEnrolling: false, enrollmentLogs: const []));
    });
  }

  Future<void> _onSetupSubmit(
    SetupSubmit event,
    Emitter<SetupState> emit,
  ) async {
    final alias = event.mtlsAlias.trim();

    // Only pass enabled codecs in user-defined priority order
    final enabledPriorityCodecs = state.audioCodecs
        .where((c) => state.enabledCodecs.contains(c))
        .toList();

    final hasNat = state.mediaNat != MediaNat.none;
    final natConfig = hasNat
        ? NatConfig(
            stunServer: event.stunServer.trim(),
            stunPort: int.tryParse(event.stunPort.trim()) ?? 3478,
            stunRefreshPeriod:
                int.tryParse(event.stunRefreshPeriod.trim()) ?? 30,
            stunDnsSrv: event.stunDnsSrv,
            stunAllowPrivateAddress: event.stunAllowPrivateAddress,
            stunAllowPrivateServer: event.stunAllowPrivateServer,
            turnServer: event.turnServer.trim(),
            turnPort: int.tryParse(event.turnPort.trim()) ?? 3478,
            turnUsername: event.turnUsername.trim(),
            turnPassword: event.turnPassword,
            iceEnabled: state.mediaNat == MediaNat.ice,
            iceAggressiveNomination: event.iceAggressiveNomination,
            iceKeepAliveInterval:
                int.tryParse(event.iceKeepAliveInterval.trim()) ?? 15,
          )
        : null;

    final config = SipConfig(
      username: event.username.trim(),
      password: event.password,
      displayName: event.displayName.trim().isEmpty
          ? (state.useMtls && event.username.trim().isEmpty
                ? alias
                : event.username.trim())
          : event.displayName.trim(),
      host: event.host.trim(),
      port: int.tryParse(event.port.trim()) ?? 5061,
      transport: state.transport,
      useRportSignalling: event.useRportSignalling,
      useRportMedia: event.useRportMedia,
      authUsername: state.useAuthUsername ? event.authUsername.trim() : '',
      mediaEncryption: state.mediaEncryption,
      mtlsAlias: state.useMtls ? alias : null,
      audioCodecs: enabledPriorityCodecs.isEmpty
          ? [AudioCodec.opus]
          : enabledPriorityCodecs,
      natConfig: natConfig,
      regint: int.tryParse(event.regint.trim()) ?? 60,
      rwait: int.tryParse(event.rwait.trim()) ?? 90,
    );

    if (state.useMtls) {
      if (state.useCsr) {
        emit(
          state.copyWith(
            isEnrolling: true,
            enrollmentLogs: [
              '🔑 Generating Cryptographic EC Keypair (secp256r1)...',
            ],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 600));
        emit(
          state.copyWith(
            enrollmentLogs: [
              ...state.enrollmentLogs,
              '📄 Constructing PKCS#10 Certificate Signing Request...',
            ],
          ),
        );

        await Future.delayed(const Duration(milliseconds: 600));
        emit(
          state.copyWith(
            enrollmentLogs: [
              ...state.enrollmentLogs,
              '🌐 Connecting to CA Enrollment Service at ${event.enrollmentUrl.trim()}...',
            ],
          ),
        );

        final csrConfig = CsrConfig(
          certAlias: alias,
          username: event.username.trim().isEmpty
              ? alias
              : event.username.trim(),
          enrollmentUrl: event.enrollmentUrl.trim(),
          caCertPem: event.caCertPem.trim(),
          extraHeaders: {'Authorization': 'Bearer ${event.authToken.trim()}'},
          verifyServer: true,
        );

        emit(
          state.copyWith(
            pendingAction: SetupPendingAction.csrEnroll,
            pendingConfig: () => config,
            pendingCsrConfig: () => csrConfig,
          ),
        );
      } else {
        final mtlsConfig = MtlsConfig.pem(
          certAlias: alias,
          clientCertPem: event.clientCertPem.trim(),
          privateKeyPem: event.privateKeyPem.trim(),
          caCertPem: event.caCertPem.trim(),
          verifyServer: true,
        );

        emit(
          state.copyWith(
            pendingAction: SetupPendingAction.mtlsPem,
            pendingConfig: () => config,
            pendingMtlsConfig: () => mtlsConfig,
          ),
        );
      }
    } else {
      emit(
        state.copyWith(
          pendingAction: SetupPendingAction.plainLogin,
          pendingConfig: () => config,
        ),
      );
    }
  }
}
