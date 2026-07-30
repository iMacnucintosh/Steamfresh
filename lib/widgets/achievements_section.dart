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

  /// Rare = <10% global, up to 6. If none, top 3 with known rarity.
  ({List<SteamAchievement> rare, List<SteamAchievement> rest}) _splitByRarity(
    List<SteamAchievement> filtered,
  ) {
    const rareThreshold = 10.0;
    const maxFeatured = 6;

    final byRarity = [
      for (final a in filtered)
        if (a.globalPercent != null) a,
    ]..sort((a, b) => a.globalPercent!.compareTo(b.globalPercent!));

    var rare = byRarity
        .where((a) => a.globalPercent! < rareThreshold)
        .take(maxFeatured)
        .toList();
    if (rare.isEmpty && byRarity.isNotEmpty) {
      rare = byRarity.take(3).toList();
    }

    final rareIds = {for (final a in rare) a.apiName};
    final rest = [
      for (final a in filtered)
        if (!rareIds.contains(a.apiName)) a,
    ];
    return (rare: rare, rest: rest);
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

              final split = _splitByRarity(filtered);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (split.rare.isNotEmpty) ...[
                    _RareAchievementsPanel(achievements: split.rare),
                    const SizedBox(height: 20),
                  ],
                  if (split.rest.isNotEmpty) ...[
                    Text(
                      split.rare.isEmpty ? 'Listado' : 'Resto de logros',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    for (final a in split.rest)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AchievementTile(achievement: a),
                      ),
                  ],
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

class _RareAchievementsPanel extends StatelessWidget {
  const _RareAchievementsPanel({required this.achievements});

  final List<SteamAchievement> achievements;

  static const _gold = Color(0xFFFFB74D);
  static const _goldDeep = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _goldDeep.withValues(alpha: 0.28),
            AppTheme.steamDark.withValues(alpha: 0.95),
            const Color(0xFF1A1208),
          ],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.18),
                  border: Border.all(color: _gold.withValues(alpha: 0.45)),
                ),
                child: const Icon(
                  Icons.diamond_outlined,
                  color: _gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Los más raros',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _gold,
                            letterSpacing: 0.3,
                          ),
                    ),
                    Text(
                      'Menos del 10% de jugadores · ordenados por rareza',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.steamMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < achievements.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _AchievementTile(
              achievement: achievements[i],
              featured: true,
              rank: i + 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    this.featured = false,
    this.rank,
  });

  final SteamAchievement achievement;
  final bool featured;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final dimmed = !a.achieved;
    const gold = Color(0xFFFFB74D);

    return Opacity(
      opacity: dimmed ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: featured
              ? Colors.black.withValues(alpha: 0.35)
              : AppTheme.steamDark.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: featured
                ? gold.withValues(alpha: 0.45)
                : a.achieved
                    ? AppTheme.steamGreen.withValues(alpha: 0.35)
                    : AppTheme.steamMid.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rank != null) ...[
              SizedBox(
                width: 28,
                child: Text(
                  '#$rank',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: gold,
                      ),
                ),
              ),
            ],
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
                        Container(
                          padding: featured
                              ? const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                )
                              : EdgeInsets.zero,
                          decoration: featured
                              ? BoxDecoration(
                                  color: gold.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(4),
                                )
                              : null,
                          child: Text(
                            '${_formatPercent(a.globalPercent!)}% jugadores',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: featured ? gold : AppTheme.steamMuted,
                                  fontWeight: featured
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
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

  String _formatPercent(double percent) {
    if (percent < 1) return percent.toStringAsFixed(2);
    return percent.toStringAsFixed(1);
  }

  String _formatUnlock(DateTime time) {
    final d = time.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return 'Desbloqueado $day/$month/${d.year}';
  }
}
