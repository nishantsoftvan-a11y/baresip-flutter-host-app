import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sipsdk_flutter/sipsdk_flutter.dart';

// ── SipState ─────────────────────────────────────────────────────────────────

class CallInfo {
  final int callId;
  final String peerUri;
  final CallState state;
  final bool isOnHold;
  const CallInfo({
    required this.callId,
    required this.peerUri,
    required this.state,
    this.isOnHold = false,
  });
}

class SipState {
  final SipConfig? config;
  final RegistrationState regState;
  final String regReason;
  final CallState? callState;
  final String callPeerUri;
  final int callId;
  final Duration callDuration;
  final AudioRoute currentRoute;
  final bool isMuted;
  final bool isOnHold;
  final bool networkConnected;
  final String? lastError;
  final bool isBusy;
  final String? callFailureReason;

  // Multi-call support
  final CallInfo? incomingCall;
  final List<CallInfo> heldCalls;
  final bool isCallMinimized;

  // mTLS
  final MtlsResult? lastMtlsResult;
  final CertificateInfo? mtlsCertInfo;
  final MtlsErrorEvent? lastMtlsError;
  final int? mtlsCertDaysRemaining;

  const SipState({
    this.config,
    this.regState = RegistrationState.offline,
    this.regReason = '',
    this.callState,
    this.callPeerUri = '',
    this.callId = 0,
    this.callDuration = Duration.zero,
    this.currentRoute = AudioRoute.earpiece,
    this.isMuted = false,
    this.isOnHold = false,
    this.networkConnected = true,
    this.lastError,
    this.isBusy = false,
    this.callFailureReason,
    this.incomingCall,
    this.heldCalls = const [],
    this.isCallMinimized = false,
    this.lastMtlsResult,
    this.mtlsCertInfo,
    this.lastMtlsError,
    this.mtlsCertDaysRemaining,
  });

  SipState copyWith({
    SipConfig? Function()? config,
    RegistrationState? regState,
    String? regReason,
    CallState? Function()? callState,
    String? callPeerUri,
    int? callId,
    Duration? callDuration,
    AudioRoute? currentRoute,
    bool? isMuted,
    bool? isOnHold,
    bool? networkConnected,
    String? Function()? lastError,
    bool? isBusy,
    String? Function()? callFailureReason,
    CallInfo? Function()? incomingCall,
    List<CallInfo>? heldCalls,
    bool? isCallMinimized,
    MtlsResult? Function()? lastMtlsResult,
    CertificateInfo? Function()? mtlsCertInfo,
    MtlsErrorEvent? Function()? lastMtlsError,
    int? Function()? mtlsCertDaysRemaining,
  }) {
    return SipState(
      config: config != null ? config() : this.config,
      regState: regState ?? this.regState,
      regReason: regReason ?? this.regReason,
      callState: callState != null ? callState() : this.callState,
      callPeerUri: callPeerUri ?? this.callPeerUri,
      callId: callId ?? this.callId,
      callDuration: callDuration ?? this.callDuration,
      currentRoute: currentRoute ?? this.currentRoute,
      isMuted: isMuted ?? this.isMuted,
      isOnHold: isOnHold ?? this.isOnHold,
      networkConnected: networkConnected ?? this.networkConnected,
      lastError: lastError != null ? lastError() : this.lastError,
      isBusy: isBusy ?? this.isBusy,
      callFailureReason: callFailureReason != null
          ? callFailureReason()
          : this.callFailureReason,
      incomingCall: incomingCall != null ? incomingCall() : this.incomingCall,
      heldCalls: heldCalls ?? this.heldCalls,
      isCallMinimized: isCallMinimized ?? this.isCallMinimized,
      lastMtlsResult: lastMtlsResult != null
          ? lastMtlsResult()
          : this.lastMtlsResult,
      mtlsCertInfo: mtlsCertInfo != null ? mtlsCertInfo() : this.mtlsCertInfo,
      lastMtlsError: lastMtlsError != null
          ? lastMtlsError()
          : this.lastMtlsError,
      mtlsCertDaysRemaining: mtlsCertDaysRemaining != null
          ? mtlsCertDaysRemaining()
          : this.mtlsCertDaysRemaining,
    );
  }

  bool get isRegistered => regState == RegistrationState.registered;
  bool get isCallAlive =>
      (callState != null) || incomingCall != null || heldCalls.isNotEmpty;
  bool get isInCall => isCallAlive;
  bool get isCallActive => callState == CallState.established;
  bool get hasIncoming =>
      callState == CallState.incoming || incomingCall != null;
  bool get hasHeldCall => heldCalls.isNotEmpty;
  bool get hasCallFailure =>
      callFailureReason != null && callFailureReason!.isNotEmpty;

  String get regLabel {
    switch (regState) {
      case RegistrationState.registering:
        return 'Registering';
      case RegistrationState.registered:
        return 'Registered';
      case RegistrationState.failed:
        return 'Unregistered';
      case RegistrationState.unregistering:
        return 'Unregistered';
      case RegistrationState.offline:
        return 'Idle';
    }
  }

  String get callLabel {
    if (hasCallFailure) {
      return callFailureReason!;
    }
    switch (callState) {
      case CallState.incoming:
        return 'Incoming call';
      case CallState.outgoing:
        return 'Calling…';
      case CallState.ringing:
        return 'Ringing…';
      case CallState.established:
        return _formatDuration(callDuration);
      case CallState.held:
        return 'On hold';
      case CallState.closed:
        return 'Call ended';
      case null:
        return '';
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── SipEvent ─────────────────────────────────────────────────────────────────

abstract class SipEvent {
  const SipEvent();
}

class InitializeSip extends SipEvent {
  final SipConfig config;
  const InitializeSip(this.config);
}

class InitializeAndLoginSip extends SipEvent {
  final SipConfig config;
  const InitializeAndLoginSip(this.config);
}

/// Initializes the SDK, optionally provisions mTLS credentials, then logs in.
/// This ensures cert files are written to disk before the SIP service starts.
class InitializeWithMtlsAndLoginSip extends SipEvent {
  final SipConfig config;
  final MtlsConfig? mtlsConfig;
  const InitializeWithMtlsAndLoginSip(this.config, {this.mtlsConfig});
}

class InitializeWithCsrAndLoginSip extends SipEvent {
  final SipConfig config;
  final CsrConfig csrConfig;
  const InitializeWithCsrAndLoginSip(this.config, this.csrConfig);
}

class LoginSip extends SipEvent {
  const LoginSip();
}

class LogoutSip extends SipEvent {
  const LogoutSip();
}

class GoOfflineSip extends SipEvent {
  const GoOfflineSip();
}

class GoOnlineSip extends SipEvent {
  const GoOnlineSip();
}

class UnregisterAndResetSip extends SipEvent {
  const UnregisterAndResetSip();
}

class StartCallSip extends SipEvent {
  final String peerUri;
  const StartCallSip(this.peerUri);
}

class AnswerCallSip extends SipEvent {
  final int? callId;
  const AnswerCallSip([this.callId]);
}

class RejectCallSip extends SipEvent {
  final int? callId;
  const RejectCallSip([this.callId]);
}

class HangupCallSip extends SipEvent {
  final int? callId;
  const HangupCallSip([this.callId]);
}

class SwapCallsSip extends SipEvent {
  const SwapCallsSip();
}

class ToggleMuteSip extends SipEvent {
  const ToggleMuteSip();
}

class ToggleHoldSip extends SipEvent {
  const ToggleHoldSip();
}

class ToggleSpeakerSip extends SipEvent {
  const ToggleSpeakerSip();
}

class ConfigureMtlsSip extends SipEvent {
  final MtlsConfig config;
  const ConfigureMtlsSip(this.config);
}

class RemoveMtlsCredentialsSip extends SipEvent {
  final String alias;
  const RemoveMtlsCredentialsSip(this.alias);
}

class LoadMtlsCertInfoSip extends SipEvent {
  final String alias;
  const LoadMtlsCertInfoSip(this.alias);
}

class ClearErrorSip extends SipEvent {
  const ClearErrorSip();
}

class RequestPermissionsSip extends SipEvent {
  const RequestPermissionsSip();
}

class CheckActiveCallSip extends SipEvent {
  const CheckActiveCallSip();
}

class MinimizeCallSip extends SipEvent {
  const MinimizeCallSip();
}

class RestoreCallSip extends SipEvent {
  const RestoreCallSip();
}

// Stream updates
class _OnRegistrationStateChanged extends SipEvent {
  final RegistrationStateEvent event;
  const _OnRegistrationStateChanged(this.event);
}

class _OnCallStateChanged extends SipEvent {
  final CallStateEvent event;
  const _OnCallStateChanged(this.event);
}

class _OnAudioRouteChanged extends SipEvent {
  final AudioRouteEvent event;
  const _OnAudioRouteChanged(this.event);
}

class _OnNetworkStateChanged extends SipEvent {
  final NetworkStateEvent event;
  const _OnNetworkStateChanged(this.event);
}

class _OnErrorOccurred extends SipEvent {
  final SdkErrorEvent event;
  const _OnErrorOccurred(this.event);
}

class _OnMtlsErrorOccurred extends SipEvent {
  final MtlsErrorEvent event;
  const _OnMtlsErrorOccurred(this.event);
}

class _OnMtlsCertExpiring extends SipEvent {
  final MtlsCertExpiringEvent event;
  const _OnMtlsCertExpiring(this.event);
}

class _TickDurationSip extends SipEvent {
  const _TickDurationSip();
}

class _OnDismissCallFailureSip extends SipEvent {
  const _OnDismissCallFailureSip();
}

// ── SipBloc ──────────────────────────────────────────────────────────────────

class SipBloc extends Bloc<SipEvent, SipState> {
  final _client = SipClient.instance;
  final List<StreamSubscription> _subs = [];
  Timer? _durationTimer;

  SipBloc() : super(const SipState()) {
    on<InitializeSip>(_onInitialize);
    on<InitializeAndLoginSip>(_onInitializeAndLogin);
    on<InitializeWithMtlsAndLoginSip>(_onInitializeWithMtlsAndLogin);
    on<InitializeWithCsrAndLoginSip>(_onInitializeWithCsrAndLogin);
    on<LoginSip>(_onLogin);
    on<LogoutSip>(_onLogout);
    on<GoOfflineSip>(_onGoOffline);
    on<GoOnlineSip>(_onGoOnline);
    on<UnregisterAndResetSip>(_onUnregisterAndReset);
    on<StartCallSip>(_onStartCall);
    on<AnswerCallSip>(_onAnswerCall);
    on<RejectCallSip>(_onRejectCall);
    on<HangupCallSip>(_onHangupCall);
    on<SwapCallsSip>(_onSwapCalls);
    on<ToggleMuteSip>(_onToggleMute);
    on<ToggleHoldSip>(_onToggleHold);
    on<ToggleSpeakerSip>(_onToggleSpeaker);
    on<ConfigureMtlsSip>(_onConfigureMtls);
    on<RemoveMtlsCredentialsSip>(_onRemoveMtlsCredentials);
    on<LoadMtlsCertInfoSip>(_onLoadMtlsCertInfo);
    on<ClearErrorSip>(_onClearError);
    on<RequestPermissionsSip>(_onRequestPermissions);
    on<CheckActiveCallSip>(_onCheckActiveCall);
    on<MinimizeCallSip>(
      (event, emit) => emit(state.copyWith(isCallMinimized: true)),
    );
    on<RestoreCallSip>(
      (event, emit) => emit(state.copyWith(isCallMinimized: false)),
    );

    // Internal updates
    on<_OnRegistrationStateChanged>(_onRegistrationStateChanged);
    on<_OnDismissCallFailureSip>(_onDismissCallFailure);

    on<_OnCallStateChanged>(_onCallStateUpdated);
    on<_OnAudioRouteChanged>(
      (event, emit) => emit(state.copyWith(currentRoute: event.event.route)),
    );
    on<_OnNetworkStateChanged>((event, emit) {
      final isConnected = event.event.connected;
      if (!isConnected) {
        emit(
          state.copyWith(
            networkConnected: false,
            regState: RegistrationState.failed,
            regReason: 'Network Offline',
          ),
        );
      } else {
        emit(state.copyWith(networkConnected: true));
      }
    });
    on<_OnErrorOccurred>(_onErrorOccurred);
    on<_OnMtlsErrorOccurred>(
      (event, emit) => emit(
        state.copyWith(
          lastMtlsError: () => event.event,
          lastError: () =>
              '[mTLS ${event.event.code}] ${event.event.alias}: ${event.event.message}',
        ),
      ),
    );
    on<_OnMtlsCertExpiring>(
      (event, emit) => emit(
        state.copyWith(mtlsCertDaysRemaining: () => event.event.daysRemaining),
      ),
    );
    on<_TickDurationSip>(
      (event, emit) {
        if (_callStartTime != null) {
          emit(
            state.copyWith(
              callDuration: DateTime.now().difference(_callStartTime!),
            ),
          );
        } else {
          emit(
            state.copyWith(
              callDuration: state.callDuration + const Duration(seconds: 1),
            ),
          );
        }
      },
    );

    // Subscribe to client event streams
    _subs.addAll([
      _client.registrationStateStream.listen(
        (e) => add(_OnRegistrationStateChanged(e)),
      ),
      _client.callStateStream.listen((e) => add(_OnCallStateChanged(e))),
      _client.audioRouteStream.listen((e) => add(_OnAudioRouteChanged(e))),
      _client.networkStateStream.listen((e) => add(_OnNetworkStateChanged(e))),
      _client.errorStream.listen((e) => add(_OnErrorOccurred(e))),
      _client.mtlsErrorStream.listen((e) => add(_OnMtlsErrorOccurred(e))),
      _client.mtlsCertExpiringStream.listen((e) => add(_OnMtlsCertExpiring(e))),
    ]);

    // Check for ongoing active call on startup
    add(const CheckActiveCallSip());
  }

  Future<void> _onRequestPermissions(
    RequestPermissionsSip event,
    Emitter<SipState> emit,
  ) async {
    try {
      // Request runtime permissions safely after UI frame has rendered
      await [Permission.microphone, Permission.notification].request();
    } catch (e) {
      // Non-fatal permission request error
    }
  }

  Future<void> _onInitialize(
    InitializeSip event,
    Emitter<SipState> emit,
  ) async {
    emit(state.copyWith(isBusy: true));
    try {
      await _client.initialize(event.config);
      emit(state.copyWith(config: () => event.config));
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onInitializeAndLogin(
    InitializeAndLoginSip event,
    Emitter<SipState> emit,
  ) async {
    emit(state.copyWith(isBusy: true));
    try {
      // BUG FIX: On subsequent app launches when saved credentials already existed, the BLoC previously bypassed
      // initialize() and called login() directly, assuming the native layer would start the engine as a fallback inside register().
      // This caused the app to load into the dialer screen and immediately fail with a "Sip not initialized / SDK not running"
      // error due to the new strict native guards.
      // FIX: Ensure initialize() is always called to start the Sip engine before calling login(), even if config exists.
      await _client.initialize(event.config);
      emit(state.copyWith(config: () => event.config));
      await _client.login();
      add(const CheckActiveCallSip());
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  /// Initializes the SDK, provisions mTLS credentials (if provided), then logs in.
  /// The order is critical: initialize → configureMtls → login.
  /// configureMtls writes cert PEM files to filesDir; Sip reads them at startup.
  /// Calling configureMtls before initialize would fail (SDK not initialized) and
  /// leave the cert files missing, causing ua_init() to fail with error 22.
  Future<void> _onInitializeWithMtlsAndLogin(
    InitializeWithMtlsAndLoginSip event,
    Emitter<SipState> emit,
  ) async {
    emit(state.copyWith(isBusy: true));
    try {
      // Step 1: Initialize SDK (writes config/accounts files, sets filesDir)
      await _client.initialize(event.config);
      emit(state.copyWith(config: () => event.config));

      // Step 2: Provision mTLS cert files AFTER initialize so filesDir is ready
      if (event.mtlsConfig != null) {
        final result = await _client.configureMtls(event.mtlsConfig!);
        emit(state.copyWith(lastMtlsResult: () => result));
        if (!result.isSuccess) {
          emit(
            state.copyWith(
              lastError: () => 'mTLS setup failed: ${result.message}',
              isBusy: false,
            ),
          );
          return;
        }
        final info = await _client.getMtlsCertificateInfo(
          event.mtlsConfig!.certAlias,
        );
        emit(state.copyWith(mtlsCertInfo: () => info));
      }

      // Step 3: Start the SIP service — cert files are now on disk
      await _client.login();
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onInitializeWithCsrAndLogin(
    InitializeWithCsrAndLoginSip event,
    Emitter<SipState> emit,
  ) async {
    emit(state.copyWith(isBusy: true));
    try {
      // Step 1: Initialize SDK
      await _client.initialize(event.config);
      emit(state.copyWith(config: () => event.config));

      // Step 2: Provision CSR mTLS cert files AFTER initialize
      final result = await _client.configureCsrMtls(event.csrConfig);
      emit(state.copyWith(lastMtlsResult: () => result));
      if (!result.isSuccess) {
        emit(
          state.copyWith(
            lastError: () => 'CSR mTLS enrollment failed: ${result.message}',
            isBusy: false,
          ),
        );
        return;
      }
      final info = await _client.getMtlsCertificateInfo(
        event.csrConfig.certAlias,
      );
      emit(state.copyWith(mtlsCertInfo: () => info));

      // Step 3: Start the SIP service
      await _client.login();
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onLogin(LoginSip event, Emitter<SipState> emit) async {
    emit(state.copyWith(isBusy: true));
    try {
      await _client.login();
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onLogout(LogoutSip event, Emitter<SipState> emit) async {
    emit(state.copyWith(isBusy: true));
    try {
      await _client.logout();
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onGoOffline(GoOfflineSip event, Emitter<SipState> emit) async {
    emit(state.copyWith(isBusy: true));
    try {
      await _client.goOffline();
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onGoOnline(GoOnlineSip event, Emitter<SipState> emit) async {
    emit(state.copyWith(isBusy: true));
    try {
      await _client.goOnline();
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onUnregisterAndReset(
    UnregisterAndResetSip event,
    Emitter<SipState> emit,
  ) async {
    emit(state.copyWith(isBusy: true));
    try {
      await _client.logout(clearCredentials: true);
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
    _stopTimer();
    emit(const SipState()); // Reset everything to default/unconfigured
  }

  Future<void> _onStartCall(StartCallSip event, Emitter<SipState> emit) async {
    _failureDismissTimer?.cancel();

    // Verify microphone permission before initiating call / sending SIP INVITE
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final reqResult = await Permission.microphone.request();
      if (!reqResult.isGranted) {
        const reason =
            'Microphone permission is required to place calls. Please grant permission in Settings.';
        emit(
          state.copyWith(
            callState: () => CallState.closed,
            callFailureReason: () => reason,
            lastError: () => 'Microphone permission denied.',
          ),
        );
        _scheduleFailureDismissTimer();
        return; // Abort call attempt before sending SIP INVITE
      }
    }

    final uri = _buildSipUri(event.peerUri);
    emit(
      state.copyWith(
        callState: () => CallState.outgoing,
        callPeerUri: uri,
        callFailureReason: () => null,
        isBusy: true,
      ),
    );
    try {
      await _client.startCall(uri);
    } catch (e) {
      final reason = _formatCallFailureReason(e.toString());
      emit(
        state.copyWith(
          callState: () => CallState.closed,
          callFailureReason: () => reason,
        ),
      );
      _scheduleFailureDismissTimer();
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onAnswerCall(
    AnswerCallSip event,
    Emitter<SipState> emit,
  ) async {
    try {
      final targetId =
          event.callId ??
          (state.callState == CallState.incoming ? state.callId : null);
      await _client.answerCall(callId: targetId);
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    }
  }

  Future<void> _onRejectCall(
    RejectCallSip event,
    Emitter<SipState> emit,
  ) async {
    try {
      final targetId =
          event.callId ??
          state.incomingCall?.callId ??
          (state.callState == CallState.incoming ? state.callId : null);
      if (state.incomingCall != null &&
          (targetId == null || targetId == state.incomingCall!.callId)) {
        emit(state.copyWith(incomingCall: () => null));
      }
      await _client.rejectCall(callId: targetId);
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    }
  }

  Future<void> _onHangupCall(
    HangupCallSip event,
    Emitter<SipState> emit,
  ) async {
    _failureDismissTimer?.cancel();
    _stopTimer();
    emit(
      state.copyWith(
        callState: () => null,
        callPeerUri: '',
        callId: 0,
        callDuration: Duration.zero,
        isMuted: false,
        isOnHold: false,
        callFailureReason: () => null,
      ),
    );
    try {
      await _client.hangup(callId: event.callId);
    } catch (_) {}
  }

  Future<void> _onSwapCalls(SwapCallsSip event, Emitter<SipState> emit) async {
    if (state.heldCalls.isEmpty) return;
    final currentCall = CallInfo(
      callId: state.callId,
      peerUri: state.callPeerUri,
      state: CallState.held,
      isOnHold: true,
    );
    final targetCall = state.heldCalls.last;
    final newHeldList = List<CallInfo>.from(
      state.heldCalls.sublist(0, state.heldCalls.length - 1),
    )..add(currentCall);

    try {
      await _client.hold(true, callId: state.callId);
      await _client.hold(false, callId: targetCall.callId);
      emit(
        state.copyWith(
          callState: () => CallState.established,
          callPeerUri: targetCall.peerUri,
          callId: targetCall.callId,
          isOnHold: false,
          heldCalls: newHeldList,
        ),
      );
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    }
  }

  Future<void> _onToggleMute(
    ToggleMuteSip event,
    Emitter<SipState> emit,
  ) async {
    final target = !state.isMuted;
    try {
      await _client.mute(target);
      emit(state.copyWith(isMuted: target));
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    }
  }

  Future<void> _onToggleHold(
    ToggleHoldSip event,
    Emitter<SipState> emit,
  ) async {
    final target = !state.isOnHold;
    try {
      await _client.hold(target);
      emit(state.copyWith(isOnHold: target));
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    }
  }

  Future<void> _onToggleSpeaker(
    ToggleSpeakerSip event,
    Emitter<SipState> emit,
  ) async {
    final next = state.currentRoute == AudioRoute.speaker
        ? AudioRoute.earpiece
        : AudioRoute.speaker;
    try {
      await _client.setAudioRoute(next);
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    }
  }

  Future<void> _onConfigureMtls(
    ConfigureMtlsSip event,
    Emitter<SipState> emit,
  ) async {
    emit(state.copyWith(isBusy: true));
    try {
      final result = await _client.configureMtls(event.config);
      emit(state.copyWith(lastMtlsResult: () => result));
      if (result.isSuccess) {
        final info = await _client.getMtlsCertificateInfo(
          event.config.certAlias,
        );
        emit(state.copyWith(mtlsCertInfo: () => info));
      }
    } catch (e) {
      emit(
        state.copyWith(
          lastError: () => e.toString(),
          lastMtlsResult: () =>
              MtlsResult.fromMap({'success': false, 'message': e.toString()}),
        ),
      );
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onRemoveMtlsCredentials(
    RemoveMtlsCredentialsSip event,
    Emitter<SipState> emit,
  ) async {
    emit(state.copyWith(isBusy: true));
    try {
      await _client.removeMtlsCredentials(event.alias);
      emit(
        state.copyWith(mtlsCertInfo: () => null, lastMtlsResult: () => null),
      );
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  Future<void> _onLoadMtlsCertInfo(
    LoadMtlsCertInfoSip event,
    Emitter<SipState> emit,
  ) async {
    try {
      final info = await _client.getMtlsCertificateInfo(event.alias);
      emit(state.copyWith(mtlsCertInfo: () => info));
    } catch (_) {}
  }

  DateTime? _callStartTime;

  Future<void> _onCheckActiveCall(
    CheckActiveCallSip event,
    Emitter<SipState> emit,
  ) async {
    try {
      final active = await _client.getActiveCall();
      if (active != null && active.state != CallState.closed) {
        final isEstablished = active.state == CallState.established;
        if (isEstablished && _callStartTime == null) {
          _callStartTime = active.connectedDateTime ?? DateTime.now();
        }
        emit(
          state.copyWith(
            callState: () => active.state,
            callPeerUri: active.peerUri,
            callId: active.callId,
            isOnHold: active.isOnHold,
            isCallMinimized: false,
            callFailureReason: () => null,
          ),
        );
        if (isEstablished) {
          _startTimer();
        }
      }
    } catch (_) {}
  }

  void _onClearError(ClearErrorSip event, Emitter<SipState> emit) {
    emit(state.copyWith(lastError: () => null));
  }

  // ── Registration state handler ─────────────────────────────────────────────

  /// Returns true if [reason] indicates iOS killed the TCP socket (errno 32 EPIPE).
  bool _isBrokenPipeReason(String reason) =>
      reason.contains('Broken pipe') || reason.contains('[32]');

  Future<void> _onRegistrationStateChanged(
    _OnRegistrationStateChanged event,
    Emitter<SipState> emit,
  ) async {
    emit(
      state.copyWith(
        regState: event.event.state,
        regReason: event.event.reason,
      ),
    );

    // iOS silently kills TCP sockets when backgrounded / screen-locked.
    // Baresip only detects the dead socket when the 60-second re-register
    // timer fires, producing errno 32 (EPIPE / "Broken pipe").
    //
    // WHY login() and NOT goOffline()+goOnline():
    //   goOffline = unregister, goOnline = register — both reuse the SAME
    //   dead baresip TCP transport and fail again with Broken pipe.
    //   login() calls start() which first calls stop() (tears down the
    //   broken transport entirely), then creates a fresh TCP connection
    //   and re-registers.
    if (event.event.state == RegistrationState.failed &&
        _isBrokenPipeReason(event.event.reason)) {
      // Brief delay so in-flight REGISTER_FAIL events finish processing.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!isClosed) add(const LoginSip());
    }
  }

  void _onCallStateUpdated(_OnCallStateChanged event, Emitter<SipState> emit) {
    final e = event.event;

    if (e.state == CallState.closed) {
      _stopTimer();
      _callStartTime = null;
      final rawReason = e.peerUri.trim();
      final reason = _formatCallFailureReason(rawReason);
      emit(
        state.copyWith(
          callState: () => CallState.closed,
          callFailureReason: () => reason,
          isCallMinimized: false,
          isMuted: false,
          isOnHold: false,
          callDuration: Duration.zero,
        ),
      );
      _scheduleFailureDismissTimer();
    } else if (e.state == CallState.held) {
      _failureDismissTimer?.cancel();
      emit(
        state.copyWith(
          callState: () => CallState.held,
          callPeerUri: e.peerUri.isNotEmpty ? e.peerUri : state.callPeerUri,
          callId: e.callId != 0 ? e.callId : state.callId,
          isOnHold: true,
          callFailureReason: () => null,
        ),
      );
    } else {
      _failureDismissTimer?.cancel();
      final isNowEstablished = e.state == CallState.established;
      if (isNowEstablished && _callStartTime == null) {
        _callStartTime = e.connectedDateTime ?? DateTime.now();
      }
      emit(
        state.copyWith(
          callState: () => e.state,
          callPeerUri: e.peerUri.isNotEmpty ? e.peerUri : state.callPeerUri,
          callId: e.callId != 0 ? e.callId : state.callId,
          isOnHold: isNowEstablished ? false : state.isOnHold,
          callFailureReason: () => null,
        ),
      );
      if (isNowEstablished) {
        _startTimer();
      }
    }
  }

  void _onErrorOccurred(_OnErrorOccurred event, Emitter<SipState> emit) {
    emit(
      state.copyWith(
        lastError: () => '[${event.event.code}] ${event.event.message}',
      ),
    );

    // Clear call locally if error drops it
    if (state.isCallAlive &&
        (state.callState == CallState.outgoing ||
            state.callState == CallState.ringing ||
            state.callState == CallState.incoming)) {
      _stopTimer();
      final reason = _formatCallFailureReason(event.event.message);
      emit(
        state.copyWith(
          callState: () => CallState.closed,
          callFailureReason: () => reason,
        ),
      );
      _scheduleFailureDismissTimer();
    }
  }

  String _formatCallFailureReason(String raw) =>
      SipErrorConstants.formatReason(raw);

  Timer? _failureDismissTimer;

  void _scheduleFailureDismissTimer() {
    _failureDismissTimer?.cancel();
    _failureDismissTimer = Timer(const Duration(seconds: 3), () {
      if (!isClosed) {
        add(const _OnDismissCallFailureSip());
      }
    });
  }

  void _onDismissCallFailure(
    _OnDismissCallFailureSip event,
    Emitter<SipState> emit,
  ) {
    if (state.callState == CallState.closed) {
      _stopTimer();
      emit(
        state.copyWith(
          callState: () => null,
          callPeerUri: '',
          callId: 0,
          callDuration: Duration.zero,
          isMuted: false,
          isOnHold: false,
          callFailureReason: () => null,
        ),
      );
    }
  }

  // ── URI builder helper ─────────────────────────────────────────────────────

  String _buildSipUri(String input) {
    var trimmed = input.trim();
    if (trimmed.startsWith('sips:')) {
      trimmed = 'sip:${trimmed.substring(5)}';
    }
    if (trimmed.startsWith('sip:')) {
      return trimmed;
    }

    final cfg = state.config;
    if (cfg != null) {
      final sanitized = trimmed.replaceAll(RegExp(r'\s+'), '');
      final cleanHost = cfg.host.split(':').first;
      const scheme = 'sip';
      return '$scheme:$sanitized@$cleanHost:5061';
    }
    return trimmed;
  }

  // ── Timer management ───────────────────────────────────────────────────────

  void _startTimer() {
    _stopTimer();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const _TickDurationSip());
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  @override
  Future<void> close() {
    _failureDismissTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _stopTimer();
    return super.close();
  }
}
