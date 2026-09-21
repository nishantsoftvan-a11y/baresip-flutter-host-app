/// [DEMO_RECORDING_TEST_FEATURE]
/// Configuration and feature flags for in-call demo recording.
///
/// To completely disable and hide the demo recording feature when delivering:
/// Set [enabled] to `false`.
class DemoRecordingConfig {
  /// Master toggle for the in-call demo recording feature.
  /// Set to `false` prior to delivery to hide all recording UI and bypass all hooks.
  static const bool enabled = false;

  /// If `true`, calls will automatically begin recording as soon as established.
  static const bool autoRecordOnCall = false;
}
