import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/user_profiles_bloc.dart';
import '../domain/models/user_profile.dart';

export '../bloc/user_profiles_bloc.dart';
export '../domain/models/user_profile.dart';

/// Callback invoked when the user taps **Load** on a saved profile.
typedef OnProfileLoad = void Function(UserProfile profile);

/// Expandable card that lists all saved SIP user profiles.
///
/// Place this at the top of the Setup Screen. When a profile is tapped,
/// [onLoad] is called with the selected [UserProfile] so the parent can
/// populate its text controllers.
class UserProfilesPanel extends StatefulWidget {
  final OnProfileLoad onLoad;

  const UserProfilesPanel({super.key, required this.onLoad});

  @override
  State<UserProfilesPanel> createState() => _UserProfilesPanelState();
}

class _UserProfilesPanelState extends State<UserProfilesPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocBuilder<UserProfilesBloc, UserProfilesState>(
      builder: (context, state) {
        final profiles = state.profiles;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ────────────────────────────────────────────────────
              InkWell(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                  bottom: Radius.circular(16),
                ),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.people_alt_rounded,
                          color: cs.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saved Profiles',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              profiles.isEmpty
                                  ? 'No saved profiles'
                                  : '${profiles.length} profile${profiles.length == 1 ? '' : 's'} saved',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (profiles.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${profiles.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Profile list ───────────────────────────────────────────────
              if (_expanded) ...[
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (profiles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 40,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No saved profiles yet.\nFill in the form and connect to save your first profile.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: profiles.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      return _ProfileTile(
                        profile: profiles[index],
                        onLoad: () {
                          widget.onLoad(profiles[index]);
                          setState(() => _expanded = false);
                        },
                        onDelete: () => _confirmDelete(
                          context,
                          profiles[index],
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, UserProfile profile) {
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text(
          'Remove "${profile.displayName.isNotEmpty ? profile.displayName : profile.id}" from saved profiles?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context
                  .read<UserProfilesBloc>()
                  .add(UserProfileDelete(profile.id));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── _ProfileTile ──────────────────────────────────────────────────────────────

class _ProfileTile extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const _ProfileTile({
    required this.profile,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final identity =
        profile.displayName.isNotEmpty ? profile.displayName : profile.username;
    final subtitle =
        '${profile.username.isNotEmpty ? profile.username : profile.mtlsAlias}@${profile.host}:${profile.port}';
    final hasMtls = profile.useMtls;
    final savedAgo = _timeAgo(profile.savedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.primaryContainer,
            child: Text(
              identity.isNotEmpty ? identity[0].toUpperCase() : '?',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        identity,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasMtls) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified_user_rounded,
                        size: 14,
                        color: cs.primary,
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  savedAgo,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          // Actions
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: cs.error, size: 20),
            tooltip: 'Delete profile',
            onPressed: onDelete,
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onLoad,
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return 'Saved ${diff.inDays}d ago';
    if (diff.inHours > 0) return 'Saved ${diff.inHours}h ago';
    if (diff.inMinutes > 0) return 'Saved ${diff.inMinutes}m ago';
    return 'Just saved';
  }
}
