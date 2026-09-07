# Sip Flutter Host App (`sipsdk_flutter_example`)

A production-grade Flutter reference VoIP application demonstrating the full capabilities of the **`sipsdk_flutter`** plugin on Android and iOS. Built using modern Flutter best practices, **flutter_bloc**, Material 3 design, and reactive audio/network pipelines.

---

## 📱 Features

### 1. SIP Account & Profile Management
- **Standard SIP**: Supports UDP, TCP, TLS, and WebSocket transports.
- **Mutual TLS (mTLS)**: Dedicated setup screen with PEM certificate/key import, PKCS#12 keystores (`.p12`/`.pfx`), and on-device CSR generation with HTTPS CA auto-enrollment.
- **Multi-Account Profiles**: Save, manage, and quickly switch between multiple SIP user accounts stored securely in local preferences.
- **Auto-Login**: Seamless credential restoration and automated re-registration on app launch.

### 2. Calling & In-Call Experience
- **Interactive Dialer**: Responsive numeric keypad with SIP URI format validation and quick extension dialing.
- **Call Session Control**: Answer, reject, hang up, microphone mute/unmute, and call hold/resume.
- **Multi-Call Handling**: Seamless incoming call banner alerts while already on a call, with one-tap call swapping and call transfer.
- **Smart Audio Route Selection**:
  - **With Bluetooth Headset**: Tapping the route button opens a popup menu anchored directly above the button with options: `Earpiece`, `Speaker`, and `Bluetooth` (reflecting native hardware status).
  - **Without Bluetooth**: Directly toggles between `Earpiece ↔ Speaker`.

### 3. Diagnostics & Quality Monitoring
- **Live RTP Stats HUD**: Real-time display of transmission/reception bitrate (kbps), packet loss, and jitter (ms).
- **Call Logging & Export**: Detailed session event logging with one-tap export to PDF reports and system share sheet.
- **SDK Stability Tester**: Integrated crash testing and recovery verification screen for native and JVM layers.
- **Adaptive Wear OS / Watch UI**: Specialized compact screens designed for wearable round/square displays.

---

## 📂 Project Structure

```
lib/
├── bloc/                          # Core BLoC state management
│   ├── sip_bloc.dart              # Main SIP client lifecycle & call controller
│   ├── home_bloc.dart             # Home & dialer UI state
│   └── setup_bloc.dart            # Registration & configuration form state
├── features/user_profiles/        # Multi-user profile management
│   ├── bloc/                      # Profile switching & storage logic
│   ├── data/                      # SharedPreferences repository
│   └── domain/models/             # UserProfile data models
├── screens/                       # Primary app views
│   ├── home_screen.dart           # Dialpad, active registration status, & call launcher
│   ├── setup_screen.dart          # Standard SIP credentials configuration
│   ├── mtls_setup_screen.dart     # Client certificate & CSR auto-enrollment setup
│   └── sdk_crash_test_screen.dart # Diagnostic stress & crash testing screen
├── widgets/                       # Reusable UI components
│   ├── call_screen.dart           # Full-screen active call view & audio route menu
│   ├── call_stats_widget.dart     # Live RTP stream bitrate/jitter HUD
│   ├── dialpad.dart               # Keypad buttons with DTMF feedback
│   └── reg_status_chip.dart       # Reactive online/offline status pill
├── utils/                         # Helper utilities
│   ├── call_log_service.dart      # In-memory and persisted call event logger
│   ├── pdf_report_generator.dart  # Formats call logs into exportable PDF summaries
│   └── file_picker_helper.dart    # Safely imports client certificates from device storage
├── watch_ui/                      # Wearable / Watch adaptive views
│   ├── watch_home_screen.dart     # Compact dialer for smartwatches
│   └── watch_setup_screen.dart    # Compact login screen for smartwatches
└── main.dart                      # App entry point & dependency injection
```

---

## 🚀 Getting Started

### 1. Prerequisites
- **Flutter SDK**: `>=3.19.0` (Dart `>=3.3.0`)
- **Android Studio** / **Xcode 15+**
- A connected physical Android device (API 29+) or iOS device (iOS 13.0+)

### 2. Android Build & Run

Ensure the compiled Android SDK AAR is present:
`sip_flutter_host_app/android/app/libs/sip_android_sdk-release.aar`

You can use the root automation script to build the SDK AAR and launch the app in one step:

```bash
# From repository root:
sh build_and_run_android.sh debug    # Debug mode
# or
sh build_and_run_android.sh profile  # Profile mode
# or
sh build_and_run_android.sh release  # Release mode
```

Alternatively, run standard Flutter CLI commands:
```bash
cd sip_flutter_host_app
flutter run -d <device-id>
```

### 3. iOS Build & Run

1. Build and copy the `SIPSDK.xcframework`:
   ```bash
   cd /Users/firdos/Documents/Working_Projects/iOS_baresip
   sh scripts/build-xcframework.sh && sh scripts/copy-xcframework.sh
   ```

2. Install CocoaPods dependencies in the host app:
   ```bash
   cd /Users/firdos/StudioProjects/BareSipFinal/sip_flutter_host_app/ios
   pod install
   ```

3. Launch on physical iPhone:
   ```bash
   cd /Users/firdos/StudioProjects/BareSipFinal/sip_flutter_host_app
   flutter run -d <ios-device-id>
   ```

---

## ⚙️ Configuration Guide

### 1. Standard SIP Configuration
Navigate to the **Settings / Setup** tab:
1. Enter your **Username / Extension** (e.g., `2001`).
2. Enter your **Password**.
3. Provide the **SIP Server Domain / Hostname** (e.g., `sip.example.com` — *do not include the port suffix*).
4. Set the **Port** (e.g., `5060` for UDP/TCP, `5061` for TLS).
5. Select the **Transport** (`TCP`, `UDP`, or `TLS`).
6. Tap **Save & Login**.

### 2. Mutual TLS (mTLS) Configuration
Tap **Advanced / mTLS Setup**:
- **PEM Mode**: Pick your `Client Certificate`, `Private Key`, and optional `CA Certificate` using the file picker.
- **PKCS#12 Mode**: Import a `.p12`/`.pfx` archive and enter the keystore password.
- **CSR Mode**: Specify your CA enrollment URL (e.g., `https://ca.example.com/api/v1/enroll`) and optional bearer auth token to generate and enroll keys automatically.

---

## 🎧 In-Call Audio Routing Architecture

The active call view ([call_screen.dart](lib/widgets/call_screen.dart)) uses a single source of truth for audio routes:
1. **Dynamic Hardware Detection**: Upon tapping the audio route button, the app inspects `client.getAvailableRoutes()`.
2. **With Bluetooth**: If a verified telephony Bluetooth device is connected, `showMenu<AudioRoute>` is anchored directly above the button, showing `Earpiece`, `Speaker`, and `Bluetooth` with checkmark indicators.
3. **Without Bluetooth**: The button directly switches between `Earpiece` and `Speaker`.
4. **Hardware Confirmation**: State is updated only when the native audio unit emits a confirmed `audioRouteStream` event (no optimistic desynchronization).

---

## 📄 License & Support

For issues, questions, or commercial licensing, please contact the development team.

**Version**: 2.0.0+16  
**Status**: ✅ Production Ready
