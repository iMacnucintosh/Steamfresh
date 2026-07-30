import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/library_achievements_summary.dart';
import '../models/steam_game.dart';
import '../theme/app_theme.dart';

class LibraryAchievementsTab extends StatelessWidget {
  const LibraryAchievementsTab({
    super.key,
    required this.loading,
    required this.done,
    required this.total,
    required this.summary,
    required this.error,
    required this.searchQuery,
    required this.onRetry,
    required this.onOpenGame,
  });

  final bool loading;
  final int done;
  final int total;
  final LibraryAchievementsSummary? summary;
  final String? error;
  final String searchQuery;
  final VoidCallback onRetry;
  final ValueChanged<SteamGame> onOpenGame;

  @override
  Widget build(BuildContext context) {
    if (error != null && summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (summary == null && loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              total == 0
                  ? 'Preparando logros…'
                  : 'Escaneando juegos $done / $total',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.steamMuted,
                  ),
            ),
          ],
        ),
      );
    }

    final data = summary!;
    final query = searchQuery.trim().toLowerCase();
    final entries = [
      for (final e in data.unlockedByRarity)
        if (query.isEmpty ||
            e.achievement.visibleName.toLowerCase().contains(query) ||
            e.game.name.toLowerCase().contains(query) ||
            e.achievement.visibleDescription.toLowerCase().contains(query))
          e,
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SummaryHeader(
            summary: data,
            loading: loading,
            done: done,
            total: total,
          );
        }
        final entry = entries[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _UnlockedAchievementTile(
            entry: entry,
            onTap: () => onOpenGame(entry.game),
          ),
        );
      },
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.summary,
    required this.loading,
    required this.done,
    required this.total,
  });

  final LibraryAchievementsSummary summary;
  final bool loading;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${summary.unlockedCount} / ${summary.libraryGameCount}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.steamAccent,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'logros obtenidos / juegos en la biblioteca',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.steamMuted,
                ),
          ),
          const SizedBox(height: 12),
          if (summary.totalAchievements > 0) ...[
            Text(
              '${summary.unlockedCount} de ${summary.totalAchievements} logros '
              '(${(summary.progressRatio * 100).round()}%) en '
              '${summary.gamesWithAchievements} juegos con logros',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.steamMuted,
                  ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.progressRatio,
                minHeight: 8,
                backgroundColor: AppTheme.steamMid.withValues(alpha: 0.5),
                color: AppTheme.steamGreen,
              ),
            ),
          ],
          if (loading) ...[
            const SizedBox(height: 12),
            Text(
              'Actualizando… $done / $total',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.steamAccent,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Desbloqueados por rareza',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Primero los más raros (menor % de jugadores)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.steamMuted,
                ),
          ),
          if (!loading && summary.unlockedByRarity.isEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Aún no hay logros desbloqueados en la biblioteca escaneada.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.steamMuted,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnlockedAchievementTile extends StatelessWidget {
  const _UnlockedAchievementTile({
    required this.entry,
    required this.onTap,
  });

  final LibraryAchievementEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = entry.achievement;
    final percent = a.globalPercent;

    return Material(
      color: AppTheme.steamDark.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.steamGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: a.displayIconUrl.isEmpty
                    ? const ColoredBox(
                        color: AppTheme.steamMid,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.emoji_events,
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
                            (48 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
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
                    const SizedBox(height: 2),
                    Text(
                      entry.game.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.steamAccent,
                          ),
                    ),
                    if (a.visibleDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        a.visibleDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.steamMuted,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    percent == null
                        ? '—'
                        : '${percent < 1 ? percent.toStringAsFixed(2) : percent.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _rarityColor(percent),
                        ),
                  ),
                  Text(
                    'rareza',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.steamMuted,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _rarityColor(double? percent) {
    if (percent == null) return AppTheme.steamMuted;
    if (percent < 5) return const Color(0xFFFFB74D);
    if (percent < 20) return AppTheme.steamAccent;
    return AppTheme.steamGreen;
  }
}
