import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'demo_recording_config.dart';

/// [DEMO_RECORDING_TEST_FEATURE]
/// Model representing a captured demo call recording.
class RecordedCallItem {
  final String path;
  final String filename;
  final int durationSeconds;
  final int sizeBytes;
  final DateTime timestamp;
  final String peerUri;

  RecordedCallItem({
    required this.path,
    required this.filename,
    required this.durationSeconds,
    required this.sizeBytes,
    required this.timestamp,
    required this.peerUri,
  });

  factory RecordedCallItem.fromMap(Map<dynamic, dynamic> map) {
    final rawTs = map['timestamp'];
    DateTime dt;
    if (rawTs is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      dt = DateTime.now();
    }

    return RecordedCallItem(
      path: map['path'] as String? ?? '',
      filename: map['filename'] as String? ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      timestamp: dt,
      peerUri: map['peerUri'] as String? ?? 'Call',
    );
  }

  String get formattedDuration {
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// [DEMO_RECORDING_TEST_FEATURE]
/// Service coordinating native call recording, playback, and sharing.
class DemoRecordingService {
  DemoRecordingService._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final DemoRecordingService instance = DemoRecordingService._();

  static const MethodChannel _channel = MethodChannel(
    'com.sip.sip_sdk_flutter_example/demo_recording',
  );

  final ValueNotifier<bool> isRecording = ValueNotifier<bool>(false);
  final ValueNotifier<int> recordingDurationSeconds = ValueNotifier<int>(0);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<String?> currentlyPlayingPath = ValueNotifier<String?>(null);
  final ValueNotifier<List<RecordedCallItem>> recordings =
      ValueNotifier<List<RecordedCallItem>>([]);

  Timer? _durationTimer;
  DateTime? _recordingStartTime;

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPlaybackStateChanged':
        final args = call.arguments as Map<dynamic, dynamic>?;
        final playing = args?['isPlaying'] as bool? ?? false;
        isPlaying.value = playing;
        if (!playing) {
          currentlyPlayingPath.value = null;
        }
        break;
      case 'onPlaybackCompleted':
        isPlaying.value = false;
        currentlyPlayingPath.value = null;
        break;
    }
  }

  /// Checks if the host platform supports native call recording.
  Future<bool> isSupported() async {
    if (!DemoRecordingConfig.enabled) return false;
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts demo recording for the active call.
  Future<bool> startRecording({String peerUri = 'Call', int callId = 0}) async {
    if (!DemoRecordingConfig.enabled) return false;
    if (isRecording.value) return true;

    try {
      final started = await _channel.invokeMethod<bool>('startRecording', {
        'peerUri': peerUri,
        'callId': callId,
      });

      if (started == true) {
        isRecording.value = true;
        _recordingStartTime = DateTime.now();
        recordingDurationSeconds.value = 0;
        _durationTimer?.cancel();
        _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_recordingStartTime != null) {
            recordingDurationSeconds.value =
                DateTime.now().difference(_recordingStartTime!).inSeconds;
          }
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[DemoRecordingService] startRecording error: $e');
      return false;
    }
  }

  /// Stops active demo recording and returns metadata for the saved file.
  Future<RecordedCallItem?> stopRecording() async {
    if (!DemoRecordingConfig.enabled) return null;
    if (!isRecording.value) return null;

    _durationTimer?.cancel();
    _durationTimer = null;
    isRecording.value = false;

    try {
      final res = await _channel.invokeMethod<dynamic>('stopRecording');
      recordingDurationSeconds.value = 0;
      _recordingStartTime = null;

      if (res is Map) {
        final item = RecordedCallItem.fromMap(res);
        await refreshRecordings();
        return item;
      }
      await refreshRecordings();
      return null;
    } catch (e) {
      debugPrint('[DemoRecordingService] stopRecording error: $e');
      return null;
    }
  }

  /// Fetches existing demo recordings from disk.
  Future<List<RecordedCallItem>> refreshRecordings() async {
    if (!DemoRecordingConfig.enabled || !Platform.isAndroid) {
      recordings.value = [];
      return [];
    }

    try {
      final list = await _channel.invokeListMethod<dynamic>('getRecordings');
      if (list != null) {
        final items = list
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => RecordedCallItem.fromMap(m))
            .toList();
        recordings.value = items;
        return items;
      }
    } catch (e) {
      debugPrint('[DemoRecordingService] refreshRecordings error: $e');
    }
    return recordings.value;
  }

  /// Plays a recorded WAV file using native audio player.
  Future<bool> playRecording(String path) async {
    try {
      final played = await _channel.invokeMethod<bool>('playRecording', {'path': path});
      if (played == true) {
        isPlaying.value = true;
        currentlyPlayingPath.value = path;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[DemoRecordingService] playRecording error: $e');
      return false;
    }
  }

  /// Stops current playback.
  Future<bool> stopPlayback() async {
    try {
      final stopped = await _channel.invokeMethod<bool>('stopPlayback');
      isPlaying.value = false;
      currentlyPlayingPath.value = null;
      return stopped ?? true;
    } catch (e) {
      debugPrint('[DemoRecordingService] stopPlayback error: $e');
      return false;
    }
  }

  /// Deletes a recorded call file.
  Future<bool> deleteRecording(String path) async {
    try {
      if (currentlyPlayingPath.value == path) {
        await stopPlayback();
      }
      final deleted =
          await _channel.invokeMethod<bool>('deleteRecording', {'path': path});
      await refreshRecordings();
      return deleted ?? false;
    } catch (e) {
      debugPrint('[DemoRecordingService] deleteRecording error: $e');
      return false;
    }
  }

  /// Shares a recorded file with external apps (Slack, Gmail, Files, WhatsApp, etc.)
  Future<void> shareRecording(BuildContext context, RecordedCallItem item) async {
    try {
      final file = XFile(item.path);
      final box = context.findRenderObject() as RenderBox?;
      final originRect = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await Share.shareXFiles(
        [file],
        text: 'Call Recording with ${item.peerUri} (${item.formattedDuration})',
        subject: 'Call Recording - ${item.filename}',
        sharePositionOrigin: originRect,
      );
    } catch (e) {
      debugPrint('[DemoRecordingService] shareRecording error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share recording: $e')),
        );
      }
    }
  }
}
