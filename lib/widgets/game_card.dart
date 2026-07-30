import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/steam_game.dart';
import '../theme/app_theme.dart';

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game});

  final SteamGame game;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final maxWidth = MediaQuery.sizeOf(context).width;
    final memWidth = (maxWidth * dpr).clamp(320, 1200).round();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 460 / 215,
              child: CachedNetworkImage(
                imageUrl: game.headerUrl,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                memCacheWidth: memWidth,
                placeholder: (_, _) => const ColoredBox(color: AppTheme.steamMid),
                errorWidget: (_, _, _) => ColoredBox(
                  color: AppTheme.steamMid,
                  child: Center(
                    child: game.iconHash.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: game.iconUrl,
                            width: 64,
                            height: 64,
                            memCacheWidth: (64 * dpr).round(),
                          )
                        : const Icon(Icons.videogame_asset, size: 48),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppTheme.steamMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatPlaytime(game.playtimeHours),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.steamMuted,
                            ),
                      ),
                      if (game.recentPlaytimeMinutes > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.steamGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(game.recentPlaytimeMinutes / 60).toStringAsFixed(1)} h (2 sem)',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppTheme.steamGreen),
                          ),
                        ),
                      ],
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

  String _formatPlaytime(double hours) {
    if (hours < 1) {
      return '${(hours * 60).round()} min';
    }
    if (hours < 100) {
      return '${hours.toStringAsFixed(1)} h';
    }
    return '${hours.round()} h';
  }
}
