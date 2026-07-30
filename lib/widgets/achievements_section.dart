import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/steam_achievement.dart';
import '../theme/app_theme.dart';

enum _AchievementFilter { all, unlocked, locked }

class AchievementsSection extends StatefulWidget {
  const AchievementsSection({
    super.key,
    required this.progress,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final SteamAchievementsProgress? progress;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<AchievementsSection> createState() => _AchievementsSectionState();
}

class _AchievementsSectionState extends State<AchievementsSection> {
  final _searchController = TextEditingController();
  _AchievementFilter _filter = _AchievementFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SteamAchievement> _filtered(List<SteamAchievement> all) {
    final query = _searchController.text.trim().toLowerCase();
    return [
      for (final a in all)
        if (_matchesFilter(a) && _matchesQuery(a, query)) a,
    ];
  }

  bool _matchesFilter(SteamAchievement a) {
    return switch (_filter) {
      _AchievementFilter.all => true,
      _AchievementFilter.unlocked => a.achieved,
      _AchievementFilter.locked => !a.achieved,
    };
  }

  bool _matchesQuery(SteamAchievement a, String query) {
    if (query.isEmpty) return true;
    return a.visibleName.toLowerCase().contains(query) ||
        a.visibleDescription.toLowerCase().contains(query) ||
        a.apiName.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logros',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        if (widget.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.error != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.steamMuted,
                    ),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onRetry,
                  child: const Text('Reintentar'),
                ),
              ],
            ],
          )
        else if (progress == null ||
            (!progress.hasAchievements &&
                progress.unavailableReason != null))
          Text(
            progress?.unavailableReason ?? 'Sin logros',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.steamMuted,
                ),
          )
        else ...[
          _ProgressHeader(progress: progress),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar logros...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Limpiar',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('Todos (${progress.totalCount})'),
                selected: _filter == _AchievementFilter.all,
                onSelected: (_) =>
                    setState(() => _filter = _AchievementFilter.all),
              ),
              ChoiceChip(
                label: Text('Desbloqueados (${progress.unlockedCount})'),
                selected: _filter == _AchievementFilter.unlocked,
                onSelected: (_) =>
                    setState(() => _filter = _AchievementFilter.unlocked),
              ),
              ChoiceChip(
                label: Text(
                  'Pendientes (${progress.totalCount - progress.unlockedCount})',
                ),
                selected: _filter == _AchievementFilter.locked,
                onSelected: (_) =>
                    setState(() => _filter = _AchievementFilter.locked),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final filtered = _filtered(progress.achievements);
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Ningún logro coincide con la búsqueda',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.steamMuted,
                        ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final a in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AchievementTile(achievement: a),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.progress});

  final SteamAchievementsProgress progress;

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.unlockedCount;
    final total = progress.totalCount;
    final ratio = progress.progressRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$unlocked / $total',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.steamAccent,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(ratio * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.steamMuted,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppTheme.steamMid.withValues(alpha: 0.5),
            color: AppTheme.steamGreen,
          ),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final SteamAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final dimmed = !a.achieved;

    return Opacity(
      opacity: dimmed ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.steamDark.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: a.achieved
                ? AppTheme.steamGreen.withValues(alpha: 0.35)
                : AppTheme.steamMid.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: a.displayIconUrl.isEmpty
                  ? ColoredBox(
                      color: AppTheme.steamMid,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          a.achieved ? Icons.emoji_events : Icons.lock_outline,
                          color: AppTheme.steamMuted,
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: a.displayIconUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      memCacheWidth:
                          (48 * MediaQuery.devicePixelRatioOf(context)).round(),
                      placeholder: (_, _) => const ColoredBox(
                        color: AppTheme.steamMid,
                        child: SizedBox(width: 48, height: 48),
                      ),
                      errorWidget: (_, _, _) => ColoredBox(
                        color: AppTheme.steamMid,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            a.achieved
                                ? Icons.emoji_events
                                : Icons.lock_outline,
                            color: AppTheme.steamMuted,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.visibleName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (a.visibleDescription.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      a.visibleDescription,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.steamMuted,
                            height: 1.35,
                          ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      if (a.achieved && a.unlockTime != null)
                        Text(
                          _formatUnlock(a.unlockTime!),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.steamGreen,
                                  ),
                        ),
                      if (a.globalPercent != null)
                        Text(
                          '${a.globalPercent!.toStringAsFixed(1)}% jugadores',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.steamMuted,
                                  ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatUnlock(DateTime time) {
    final d = time.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return 'Desbloqueado $day/$month/${d.year}';
  }
}
