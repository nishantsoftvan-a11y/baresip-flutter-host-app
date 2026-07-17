import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sipsdk_flutter/sipsdk_flutter.dart';

/// A log entry capturing one call-state transition.
class _StateEntry {
  final DateTime timestamp;
  final String state;
  _StateEntry(this.timestamp, this.state);
}

/// A log entry capturing a single RTP stats snapshot.
class _StatsEntry {
  final DateTime timestamp;
  final CallStats stats;
  _StatsEntry(this.timestamp, this.stats);
}

/// Accumulates call-state transitions and real-time RTP stats for a single
/// call session and can export them as a shareable `.txt` file.
///
/// ## Filename format
/// ```
/// <HHmmss>-call-<to_or_from>-<direction>-logs.txt
/// ```
/// Example: `143022-call-bob-outgoing-logs.txt`
///
/// ## Usage
/// ```dart
/// // At call start (e.g. outgoing):
/// CallLogService.instance.startSession(
///   peerUri: 'sip:bob@example.com',
///   direction: 'outgoing',
/// );
///
/// // On each CallState change:
/// CallLogService.instance.logState(newState.name);
///
/// // On each stats tick (pass stats from CallStatsWidget / getCallStats):
/// CallLogService.instance.logStats(stats);
///
/// // When the call ends — share the log:
/// await CallLogService.instance.shareLog(context);
/// ```
class CallLogService {
  CallLogService._();
  static final CallLogService instance = CallLogService._();

  DateTime? _sessionStart;
  String _peerUri = '';
  String _direction = 'unknown';
  final List<_StateEntry> _stateLog = [];
  final List<_StatsEntry> _statsLog = [];

  // ── Session control ────────────────────────────────────────────────────────

  /// Starts a new log session for the call to/from [peerUri].
  ///
  /// [direction] should be `"outgoing"` or `"incoming"`.
  void startSession({required String peerUri, required String direction}) {
    _sessionStart = DateTime.now();
    _peerUri = peerUri;
    _direction = direction;
    _stateLog.clear();
    _statsLog.clear();
    logState('SESSION_START');
  }

  /// Records a call-state label (e.g. `"established"`, `"closed"`).
  void logState(String stateLabel) {
    _stateLog.add(_StateEntry(DateTime.now(), stateLabel));
  }

  /// Records a real-time [CallStats] snapshot from the polling timer.
  void logStats(CallStats stats) {
    _statsLog.add(_StatsEntry(DateTime.now(), stats));
  }

  /// Appends a final `SESSION_END` marker — call this just before sharing.
  void endSession() => logState('SESSION_END');

  // ── Export ─────────────────────────────────────────────────────────────────

  /// Builds the `.txt` log content and returns it as a [String].
  String buildLogContent() {
    final start = _sessionStart ?? DateTime.now();
    final peer = _cleanPeer(_peerUri);
    final buf = StringBuffer();

    // ── Header ──
    buf.writeln('=' * 60);
    buf.writeln('  CALL LOG');
    buf.writeln('=' * 60);
    buf.writeln('Date       : ${_fmtDate(start)}');
    buf.writeln('Time       : ${_fmtTime(start)}');
    buf.writeln('Peer       : $peer');
    buf.writeln('Direction  : $_direction');
    buf.writeln('=' * 60);
    buf.writeln();

    // ── State timeline ──
    buf.writeln('── CALL STATE TIMELINE ─────────────────────────────────');
    for (final e in _stateLog) {
      buf.writeln('[${_fmtTimestamp(e.timestamp)}]  ${e.state}');
    }
    buf.writeln();

    // ── RTP stats ──
    if (_statsLog.isNotEmpty) {
      buf.writeln('── RTP STATS SNAPSHOTS ──────────────────────────────────');
      buf.writeln(
        '  Time      │ TXkbps │ RXkbps │ TXpkts │ RXpkts │ TXlost │ RXlost │ TXjit(ms) │ RXjit(ms)',
      );
      buf.writeln('  ' + '-' * 95);
      for (final e in _statsLog) {
        final s = e.stats;
        buf.writeln(
          '  ${_fmtTimestamp(e.timestamp)}'
          ' │ ${s.txBitrate.toStringAsFixed(1).padLeft(6)}'
          ' │ ${s.rxBitrate.toStringAsFixed(1).padLeft(6)}'
          ' │ ${s.txPackets.toString().padLeft(6)}'
          ' │ ${s.rxPackets.toString().padLeft(6)}'
          ' │ ${s.txLost.toString().padLeft(6)}'
          ' │ ${s.rxLost.toString().padLeft(6)}'
          ' │ ${s.txJitter.toStringAsFixed(1).padLeft(9)}'
          ' │ ${s.rxJitter.toStringAsFixed(1).padLeft(9)}',
        );
      }
      buf.writeln();

      // ── Summary ──
      final avgTxBr =
          _statsLog.map((e) => e.stats.txBitrate).reduce((a, b) => a + b) /
          _statsLog.length;
      final avgRxBr =
          _statsLog.map((e) => e.stats.rxBitrate).reduce((a, b) => a + b) /
          _statsLog.length;
      final last = _statsLog.last.stats;
      buf.writeln('── SUMMARY ──────────────────────────────────────────────');
      buf.writeln('  Avg TX bitrate : ${avgTxBr.toStringAsFixed(1)} kbps');
      buf.writeln('  Avg RX bitrate : ${avgRxBr.toStringAsFixed(1)} kbps');
      buf.writeln('  Total TX pkts  : ${last.txPackets}');
      buf.writeln('  Total RX pkts  : ${last.rxPackets}');
      buf.writeln(
        '  TX lost        : ${last.txLost}  (${last.txLossPercentage.toStringAsFixed(2)}%)',
      );
      buf.writeln(
        '  RX lost        : ${last.rxLost}  (${last.rxLossPercentage.toStringAsFixed(2)}%)',
      );
      buf.writeln('  Final TX jitter: ${last.txJitter.toStringAsFixed(1)} ms');
      buf.writeln('  Final RX jitter: ${last.rxJitter.toStringAsFixed(1)} ms');
      buf.writeln(
        '  Quality        : ${last.isGoodQuality
            ? "Good ✓"
            : last.isPoorQuality
            ? "Poor ✗"
            : "Fair ~"}',
      );
    } else {
      buf.writeln('── RTP STATS ─────────────────────────────────────────────');
      buf.writeln('  (no stats captured — call may not have been established)');
    }

    buf.writeln();
    buf.writeln('=' * 60);
    buf.writeln(
      '  Generated: ${_fmtDate(DateTime.now())} ${_fmtTime(DateTime.now())}',
    );
    buf.writeln('=' * 60);

    return buf.toString();
  }

  /// Writes the log to a temp file and opens the native share sheet.
  ///
  /// The file name follows the pattern:
  /// `HHmmss-call-<peer>-<direction>-logs.txt`
  Future<void> shareLog([BuildContext? context]) async {
    Rect? sharePositionOrigin;
    if (context != null) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }
    }

    final start = _sessionStart ?? DateTime.now();
    final peer = _cleanPeer(_peerUri).replaceAll(RegExp(r'[^\w\-]'), '_');
    final timeStr =
        '${start.hour.toString().padLeft(2, '0')}'
        '${start.minute.toString().padLeft(2, '0')}'
        '${start.second.toString().padLeft(2, '0')}';
    final fileName = '$timeStr-call-$peer-${_direction}-logs.txt';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buildLogContent());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/plain')],
      subject: 'Call Log – $peer',
      text: 'Call log for $_direction call with $peer on ${_fmtDate(start)}.',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _cleanPeer(String uri) {
    return uri.replaceAll(RegExp(r'^sip(s)?:'), '').split('@').first;
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  static String _fmtTimestamp(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}'
      '.${(dt.millisecond ~/ 100)}';
}
