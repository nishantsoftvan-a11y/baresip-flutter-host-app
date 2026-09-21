import 'package:flutter/material.dart';

import '../demo_recording_config.dart';
import '../demo_recording_service.dart';
import 'recordings_history_sheet.dart';

/// [DEMO_RECORDING_TEST_FEATURE]
/// In-call Record Button with pulsing indicator and live duration timer.
class RecordCallButton extends StatefulWidget {
  final String peerUri;
  final int callId;

  const RecordCallButton({super.key, required this.peerUri, this.callId = 0});

  @override
  State<RecordCallButton> createState() => _RecordCallButtonState();
}

class _RecordCallButtonState extends State<RecordCallButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleToggle() async {
    final service = DemoRecordingService.instance;
    if (!service.isRecording.value) {
      final started = await service.startRecording(
        peerUri: widget.peerUri,
        callId: widget.callId,
      );
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start call recording (Android only)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      final savedItem = await service.stopRecording();
      if (savedItem != null && mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recording saved: ${savedItem.formattedDuration} (${savedItem.formattedSize})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View / Share',
              textColor: Colors.amberAccent,
              onPressed: () {
                showModalBottomSheet(
                  context: nav.context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const RecordingsHistorySheet(),
                );
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DemoRecordingConfig.enabled) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final service = DemoRecordingService.instance;

    return ValueListenableBuilder<bool>(
      valueListenable: service.isRecording,
      builder: (context, recording, _) {
        return ValueListenableBuilder<int>(
          valueListenable: service.recordingDurationSeconds,
          builder: (context, duration, _) {
            final minutes = (duration ~/ 60).toString().padLeft(2, '0');
            final seconds = (duration % 60).toString().padLeft(2, '0');
            final timerText = '$minutes:$seconds';

            return GestureDetector(
              onTap: _handleToggle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: recording
                          ? Colors.red.shade900.withValues(alpha: 0.35)
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                      border: Border.all(
                        color: recording
                            ? Colors.redAccent
                            : colorScheme.outline.withValues(alpha: 0.25),
                        width: recording ? 2.5 : 1.5,
                      ),
                      boxShadow: recording
                          ? [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: recording
                          ? ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent,
                                ),
                                child: const Icon(
                                  Icons.stop_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.fiber_manual_record_rounded,
                              color: Colors.redAccent,
                              size: 26,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recording ? 'REC $timerText' : 'Record',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: recording
                          ? Colors.redAccent
                          : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
