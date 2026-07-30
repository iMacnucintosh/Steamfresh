import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/steam_achievement.dart';
import '../models/steam_app_details.dart';
import '../models/steam_game.dart';
import '../services/steam_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/achievements_section.dart';
import '../widgets/steam_gradient_background.dart';
import 'screenshot_gallery_page.dart';

class GameDetailScreen extends StatefulWidget {
  const GameDetailScreen({
    super.key,
    required this.game,
    required this.steamId,
    this.inQueue = false,
    this.onToggleQueue,
  });

  final SteamGame game;
  final String steamId;
  final bool inQueue;
  final VoidCallback? onToggleQueue;

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  final _api = SteamApiService();

  SteamAppDetails? _details;
  SteamAchievementsProgress? _achievements;
  var _loadingDetails = true;
  var _loadingAchievements = true;
  String? _detailsError;
  String? _achievementsError;
  late bool _inQueue;

  @override
  void initState() {
    super.initState();
    _inQueue = widget.inQueue;
    _loadDetails();
    _loadAchievements();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loadingDetails = true;
      _detailsError = null;
    });

    try {
      final details = await _api.getAppDetails(widget.game.appId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _loadingDetails = false;
      });
    } on SteamApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _detailsError = e.message;
        _loadingDetails = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detailsError = 'No se pudieron cargar los detalles';
        _loadingDetails = false;
      });
    }
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _loadingAchievements = true;
      _achievementsError = null;
    });

    try {
      final progress = await _api.getAchievementsProgress(
        steamId: widget.steamId,
        appId: widget.game.appId,
      );
      if (!mounted) return;
      setState(() {
        _achievements = progress;
        _loadingAchievements = false;
      });
    } on SteamApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _achievementsError = e.message;
        _loadingAchievements = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _achievementsError = 'No se pudieron cargar los logros';
        _loadingAchievements = false;
      });
    }
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(
      'https://store.steampowered.com/app/${widget.game.appId}/',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatPlaytime(double hours) {
    if (hours < 1) return '${(hours * 60).round()} min';
    if (hours < 100) return '${hours.toStringAsFixed(1)} h';
    return '${hours.round()} h';
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final details = _details;
    final title = details?.name ?? game.name;
    final headerUrl =
        (details?.headerImage.isNotEmpty ?? false)
            ? details!.headerImage
            : game.headerUrl;
    final unlocked = _achievements?.unlockedCount;
    final total = _achievements?.totalCount;

    return Scaffold(
      body: SteamGradientBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 200,
              backgroundColor: AppTheme.steamNavy.withValues(alpha: 0.92),
              foregroundColor: AppTheme.steamText,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: headerUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      memCacheWidth:
                          (MediaQuery.sizeOf(context).width *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round()
                              .clamp(320, 1600),
                      placeholder: (_, _) =>
                          const ColoredBox(color: AppTheme.steamMid),
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: AppTheme.steamMid),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Color(0x99000000),
                            Color(0x00000000),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoChip(
                        icon: Icons.schedule,
                        label: _formatPlaytime(game.playtimeHours),
                        hint: 'totales',
                      ),
                      if (game.recentPlaytimeMinutes > 0)
                        _InfoChip(
                          icon: Icons.local_fire_department,
                          label: _formatPlaytime(
                            game.recentPlaytimeMinutes / 60,
                          ),
                          hint: '2 semanas',
                          accent: true,
                        ),
                      if (details?.metacriticScore != null)
                        _InfoChip(
                          icon: Icons.star_outline,
                          label: '${details!.metacriticScore}',
                          hint: 'Metacritic',
                        ),
                      if (unlocked != null &&
                          total != null &&
                          total > 0 &&
                          !_loadingAchievements)
                        _InfoChip(
                          icon: Icons.emoji_events_outlined,
                          label: '$unlocked/$total',
                          hint: 'logros',
                          accent: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_loadingDetails)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_detailsError != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _detailsError!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppTheme.steamMuted),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loadDetails,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    )
                  else ...[
                    if (details?.shortDescription.isNotEmpty ?? false) ...[
                      Text(
                        details!.shortDescription,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.45,
                              color: AppTheme.steamText,
                            ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (details?.genres.isNotEmpty ?? false) ...[
                      Text(
                        'Géneros',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: details!.genres
                            .map(
                              (g) => Chip(
                                label: Text(g),
                                backgroundColor: AppTheme.steamMid
                                    .withValues(alpha: 0.55),
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (details != null) ...[
                      _MetaRow(
                        label: 'Desarrollador',
                        value: details.developers.isEmpty
                            ? '—'
                            : details.developers.join(', '),
                      ),
                      _MetaRow(
                        label: 'Editor',
                        value: details.publishers.isEmpty
                            ? '—'
                            : details.publishers.join(', '),
                      ),
                      if (details.releaseDate.isNotEmpty)
                        _MetaRow(
                          label: 'Lanzamiento',
                          value: details.releaseDate,
                        ),
                      const SizedBox(height: 8),
                    ],
                    if (details?.screenshots.isNotEmpty ?? false) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Capturas',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: details!.screenshots.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final shot = details.screenshots[index];
                            return GestureDetector(
                              onTap: () => openScreenshotGallery(
                                context,
                                screenshots: details.screenshots,
                                initialIndex: index,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: shot.thumbnailUrl,
                                      height: 120,
                                      width: 200,
                                      fit: BoxFit.cover,
                                      fadeInDuration: Duration.zero,
                                      memCacheWidth: (200 *
                                              MediaQuery.devicePixelRatioOf(
                                                context,
                                              ))
                                          .round(),
                                      placeholder: (_, _) => const SizedBox(
                                        width: 200,
                                        child: ColoredBox(
                                          color: AppTheme.steamMid,
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      right: 6,
                                      bottom: 6,
                                      child: Icon(
                                        Icons.zoom_in,
                                        size: 18,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                  AchievementsSection(
                    progress: _achievements,
                    loading: _loadingAchievements,
                    error: _achievementsError,
                    onRetry: _loadAchievements,
                  ),
                  const SizedBox(height: 24),
                  if (widget.onToggleQueue != null) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        widget.onToggleQueue!();
                        setState(() => _inQueue = !_inQueue);
                      },
                      icon: Icon(
                        _inQueue
                            ? Icons.playlist_add_check
                            : Icons.playlist_add,
                      ),
                      label: Text(
                        _inQueue
                            ? 'Quitar de próximos'
                            : 'Añadir a próximos',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _openStore,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir en Steam'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.hint,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppTheme.steamGreen : AppTheme.steamAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.steamText,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            hint,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.steamMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.steamMuted,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openGameDetail(
  BuildContext context,
  SteamGame game, {
  required String steamId,
  bool inQueue = false,
  VoidCallback? onToggleQueue,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GameDetailScreen(
        game: game,
        steamId: steamId,
        inQueue: inQueue,
        onToggleQueue: onToggleQueue,
      ),
    ),
  );
}
