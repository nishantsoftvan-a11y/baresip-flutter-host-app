import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sipsdk_flutter/sipsdk_flutter.dart';
import '../utils/call_log_service.dart';

/// Real-time RTP statistics display widget for monitoring call quality.
///
/// Displays TX/RX bitrates, packet counts, loss, and jitter metrics.
/// Updates automatically every second during an active call.
class CallStatsWidget extends StatefulWidget {
  /// Whether to show the stats widget.
  final bool visible;

  /// Refresh interval in milliseconds. Defaults to 1000ms (1 second).
  final int refreshIntervalMs;

  const CallStatsWidget({
    Key? key,
    this.visible = true,
    this.refreshIntervalMs = 1000,
  }) : super(key: key);

  @override
  State<CallStatsWidget> createState() => _CallStatsWidgetState();
}

class _CallStatsWidgetState extends State<CallStatsWidget> {
  Timer? _timer;
  CallStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _startPolling();
    }
  }

  @override
  void didUpdateWidget(CallStatsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _startPolling();
    } else if (!widget.visible && oldWidget.visible) {
      _stopPolling();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    _fetchStats();
    _timer = Timer.periodic(
      Duration(milliseconds: widget.refreshIntervalMs),
      (_) => _fetchStats(),
    );
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await SipClient.instance.getCallStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
        // Feed each snapshot into the call log
        if (stats != null) {
          CallLogService.instance.logStats(stats);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stats = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Loading stats...', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_stats == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'No call stats available',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      );
    }

    final quality = _stats!.isGoodQuality
        ? 'Good'
        : _stats!.isPoorQuality
            ? 'Poor'
            : 'Fair';
    final qualityColor = _stats!.isGoodQuality
        ? Colors.green
        : _stats!.isPoorQuality
            ? Colors.red
            : Colors.orange;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, size: 16, color: qualityColor),
                const SizedBox(width: 6),
                Text(
                  'Call Quality: $quality',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: qualityColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildStatRow(
              'Bitrate',
              '↑ ${_stats!.txBitrate.toStringAsFixed(1)} kbps',
              '↓ ${_stats!.rxBitrate.toStringAsFixed(1)} kbps',
            ),
            const SizedBox(height: 6),
            _buildStatRow(
              'Packets',
              '↑ ${_stats!.txPackets}',
              '↓ ${_stats!.rxPackets}',
            ),
            const SizedBox(height: 6),
            _buildStatRow(
              'Loss',
              '↑ ${_stats!.txLost} (${_stats!.txLossPercentage.toStringAsFixed(2)}%)',
              '↓ ${_stats!.rxLost} (${_stats!.rxLossPercentage.toStringAsFixed(2)}%)',
              warningThreshold: 2.0,
              txNumericValue: _stats!.txLossPercentage,
              rxNumericValue: _stats!.rxLossPercentage,
            ),
            const SizedBox(height: 6),
            _buildStatRow(
              'Jitter',
              '↑ ${_stats!.txJitter.toStringAsFixed(1)} ms',
              '↓ ${_stats!.rxJitter.toStringAsFixed(1)} ms',
              warningThreshold: 30.0,
              txNumericValue: _stats!.txJitter,
              rxNumericValue: _stats!.rxJitter,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String txLabel,
    String rxLabel, {
    double? warningThreshold,
    double? txNumericValue,
    double? rxNumericValue,
  }) {
    final showTxWarning = warningThreshold != null &&
        txNumericValue != null &&
        txNumericValue >= warningThreshold;
    final showRxWarning = warningThreshold != null &&
        rxNumericValue != null &&
        rxNumericValue >= warningThreshold;

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              if (showTxWarning)
                const Icon(Icons.warning_amber, size: 12, color: Colors.orange),
              if (showTxWarning) const SizedBox(width: 4),
              Flexible(
                child: Text(
                  txLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: showTxWarning ? Colors.orange : Colors.black87,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              if (showRxWarning)
                const Icon(Icons.warning_amber, size: 12, color: Colors.orange),
              if (showRxWarning) const SizedBox(width: 4),
              Flexible(
                child: Text(
                  rxLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: showRxWarning ? Colors.orange : Colors.black87,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
