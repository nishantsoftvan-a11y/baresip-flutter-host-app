import 'package:flutter/material.dart';

import '../demo_recording_service.dart';

/// [DEMO_RECORDING_TEST_FEATURE]
/// Modal bottom sheet displaying recorded call audio files.
/// Provides native playback, sharing via share_plus, and deletion.
class RecordingsHistorySheet extends StatefulWidget {
  const RecordingsHistorySheet({super.key});

  @override
  State<RecordingsHistorySheet> createState() => _RecordingsHistorySheetState();
}

class _RecordingsHistorySheetState extends State<RecordingsHistorySheet> {
  final DemoRecordingService _service = DemoRecordingService.instance;

  @override
  void initState() {
    super.initState();
    _service.refreshRecordings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_none_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo Call Recordings',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '2-way Stereo WAV (Mic + Remote)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 16),

          // Content List
          Expanded(
            child: ValueListenableBuilder<List<RecordedCallItem>>(
              valueListenable: _service.recordings,
              builder: (context, items, _) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.audio_file_outlined,
                          size: 56,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No recordings yet',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "Record" during any active call to capture audio.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ValueListenableBuilder<bool>(
                  valueListenable: _service.isPlaying,
                  builder: (context, isPlaying, _) {
                    return ValueListenableBuilder<String?>(
                      valueListenable: _service.currentlyPlayingPath,
                      builder: (context, playingPath, _) {
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isThisPlaying =
                                isPlaying && playingPath == item.path;

                            return Card(
                              elevation: 0,
                              color: isThisPlaying
                                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isThisPlaying
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Play / Stop Button
                                    IconButton.filledTonal(
                                      onPressed: () {
                                        if (isThisPlaying) {
                                          _service.stopPlayback();
                                        } else {
                                          _service.playRecording(item.path);
                                        }
                                      },
                                      icon: Icon(
                                        isThisPlaying
                                            ? Icons.stop_rounded
                                            : Icons.play_arrow_rounded,
                                        color: isThisPlaying
                                            ? colorScheme.error
                                            : colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // File info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.peerUri,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.formattedDuration}  •  ${item.formattedSize}  •  ${_formatDate(item.timestamp)}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Share button
                                    IconButton(
                                      icon: const Icon(Icons.share_outlined, size: 20),
                                      tooltip: 'Share Recording',
                                      onPressed: () =>
                                          _service.shareRecording(context, item),
                                    ),

                                    // Delete button
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                        color: colorScheme.error,
                                      ),
                                      tooltip: 'Delete',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Recording?'),
                                            content: Text(
                                              'Are you sure you want to delete ${item.filename}?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      colorScheme.error,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await _service
                                              .deleteRecording(item.path);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return 'Today at $hour:$minute';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
