import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/library_achievements_summary.dart';
import '../models/steam_game.dart';
import '../models/steam_user.dart';
import '../services/library_achievements_loader.dart';
import '../services/play_queue_service.dart';
import '../services/steam_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_card.dart';
import '../widgets/library_achievements_tab.dart';
import '../widgets/steam_gradient_background.dart';
import 'game_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.steamId,
    required this.onLogout,
  });

  final String steamId;
  final VoidCallback onLogout;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  final _api = SteamApiService();
  final _queueService = PlayQueueService();
  final _achievementsLoader = LibraryAchievementsLoader();
  final _searchController = TextEditingController();
  late final TabController _tabController;

  SteamUser? _user;
  List<SteamGame> _games = [];
  List<SteamGame> _filteredGames = [];
  List<int> _queueIds = [];
  var _isLoading = true;
  String? _error;
  String _sortBy = 'playtime';

  LibraryAchievementsSummary? _achievementsSummary;
  var _loadingAchievements = false;
  var _achievementsDone = 0;
  var _achievementsTotal = 0;
  String? _achievementsError;
  var _achievementsLoadGen = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(_applyFilters);
    _loadLibrary();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
    if (_tabController.index == 2) {
      _ensureAchievementsLoaded();
    }
  }

  @override
  void dispose() {
    _achievementsLoadGen++;
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Set<int> get _queueIdSet => _queueIds.toSet();

  List<SteamGame> get _queueGames {
    final byId = {for (final g in _games) g.appId: g};
    final query = _searchController.text.trim().toLowerCase();
    return [
      for (final id in _queueIds)
        if (byId[id] != null)
          if (query.isEmpty || byId[id]!.name.toLowerCase().contains(query))
            byId[id]!,
    ];
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getPlayerSummary(widget.steamId),
        _api.getOwnedGames(widget.steamId),
        _queueService.load(widget.steamId),
      ]);

      if (!mounted) return;

      final owned = results[1] as List<SteamGame>;
      final ownedIds = {for (final g in owned) g.appId};
      final savedQueue = results[2] as List<int>;
      final queue = savedQueue.where(ownedIds.contains).toList();

      setState(() {
        _user = results[0] as SteamUser;
        _games = owned;
        _queueIds = queue;
        _isLoading = false;
      });
      _applyFilters();
      if (queue.length != savedQueue.length) {
        await _queueService.save(widget.steamId, queue);
      }
    } on SteamApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error inesperado al cargar la biblioteca';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    var filtered = _games.where((game) {
      if (query.isEmpty) return true;
      return game.name.toLowerCase().contains(query);
    }).toList();

    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
      case 'recent':
        filtered.sort(
          (a, b) => b.recentPlaytimeMinutes.compareTo(a.recentPlaytimeMinutes),
        );
      case 'playtime':
      default:
        filtered.sort((a, b) => b.playtimeMinutes.compareTo(a.playtimeMinutes));
    }

    setState(() => _filteredGames = filtered);
  }

  Future<void> _persistQueue() async {
    await _queueService.save(widget.steamId, _queueIds);
  }

  Future<void> _toggleQueue(SteamGame game) async {
    final wasInQueue = _queueIdSet.contains(game.appId);
    setState(() {
      if (wasInQueue) {
        _queueIds = [..._queueIds]..remove(game.appId);
      } else {
        _queueIds = [..._queueIds, game.appId];
      }
    });
    await _persistQueue();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasInQueue
              ? '${game.name} quitado de próximos'
              : '${game.name} añadido a próximos',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _reorderQueue(int oldIndex, int newIndex) async {
    final visible = _queueGames;
    if (oldIndex < 0 ||
        oldIndex >= visible.length ||
        newIndex < 0 ||
        newIndex >= visible.length) {
      return;
    }

    final moved = visible[oldIndex];
    final reorderedVisible = [...visible]
      ..removeAt(oldIndex)
      ..insert(newIndex, moved);
    final visibleIds = {for (final g in reorderedVisible) g.appId};

    // Replace the filtered subsequence in-place; keep hidden ids where they were.
    final rebuilt = <int>[];
    var placedVisible = false;
    for (final id in _queueIds) {
      if (!visibleIds.contains(id)) {
        rebuilt.add(id);
      } else if (!placedVisible) {
        rebuilt.addAll(reorderedVisible.map((g) => g.appId));
        placedVisible = true;
      }
    }
    if (!placedVisible) {
      rebuilt.addAll(reorderedVisible.map((g) => g.appId));
    }

    setState(() => _queueIds = rebuilt);
    await _persistQueue();
  }

  int get _totalPlaytimeHours =>
      _games.fold<int>(0, (sum, g) => sum + g.playtimeMinutes) ~/ 60;

  void _openDetail(SteamGame game) {
    openGameDetail(
      context,
      game,
      steamId: widget.steamId,
      inQueue: _queueIdSet.contains(game.appId),
      onToggleQueue: () => _toggleQueue(game),
    );
  }

  Future<void> _ensureAchievementsLoaded({bool force = false}) async {
    if (_loadingAchievements) return;
    if (!force && _achievementsSummary != null) return;
    if (_games.isEmpty) {
      setState(() {
        _achievementsSummary = const LibraryAchievementsSummary(
          unlockedCount: 0,
          totalAchievements: 0,
          libraryGameCount: 0,
          gamesWithAchievements: 0,
          unlockedByRarity: [],
        );
      });
      return;
    }

    final gen = ++_achievementsLoadGen;
    setState(() {
      _loadingAchievements = true;
      _achievementsError = null;
      _achievementsDone = 0;
      _achievementsTotal = _games.length;
      if (force) _achievementsSummary = null;
    });

    try {
      final summary = await _achievementsLoader.load(
        steamId: widget.steamId,
        games: _games,
        isCancelled: () => gen != _achievementsLoadGen,
        onProgress: (done, total) {
          if (!mounted || gen != _achievementsLoadGen) return;
          setState(() {
            _achievementsDone = done;
            _achievementsTotal = total;
          });
        },
        onPartial: (partial) {
          if (!mounted || gen != _achievementsLoadGen) return;
          setState(() => _achievementsSummary = partial);
        },
      );
      if (!mounted || gen != _achievementsLoadGen) return;
      setState(() {
        _achievementsSummary = summary;
        _loadingAchievements = false;
      });
    } catch (_) {
      if (!mounted || gen != _achievementsLoadGen) return;
      setState(() {
        _loadingAchievements = false;
        _achievementsError = 'No se pudieron cargar los logros de la biblioteca';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SteamGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _loadLibrary)
                  : Column(
                      children: [
                        _buildHeader(context),
                        _buildToolbar(context),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: TabBar(
                            controller: _tabController,
                            indicatorColor: AppTheme.steamAccent,
                            labelColor: AppTheme.steamAccent,
                            unselectedLabelColor: AppTheme.steamMuted,
                            tabs: [
                              Tab(
                                text: _queueIds.isEmpty
                                    ? 'Próximos'
                                    : 'Próximos (${_queueIds.length})',
                              ),
                              Tab(text: 'Biblioteca (${_games.length})'),
                              Tab(
                                text: _achievementsSummary == null
                                    ? 'Logros'
                                    : 'Logros (${_achievementsSummary!.unlockedCount})',
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildQueueTab(context),
                              _buildLibraryTab(context),
                              LibraryAchievementsTab(
                                loading: _loadingAchievements,
                                done: _achievementsDone,
                                total: _achievementsTotal,
                                summary: _achievementsSummary,
                                error: _achievementsError,
                                searchQuery: _searchController.text,
                                onRetry: () =>
                                    _ensureAchievementsLoaded(force: true),
                                onOpenGame: _openDetail,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildQueueTab(BuildContext context) {
    final queue = _queueGames;
    if (_queueIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.queue_play_next,
                size: 56,
                color: AppTheme.steamMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'Tu cola está vacía',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Añade juegos desde la biblioteca con el icono de lista '
                'para planear a qué vas a jugar después.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.steamMuted,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.library_books),
                label: const Text('Ir a la biblioteca'),
              ),
            ],
          ),
        ),
      );
    }

    if (queue.isEmpty) {
      return const Center(child: Text('Ningún próximo coincide con la búsqueda'));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: queue.length,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 6,
          color: Colors.transparent,
          child: child,
        );
      },
      onReorderItem: _reorderQueue,
      itemBuilder: (context, index) {
        final game = queue[index];
        return Padding(
          key: ValueKey(game.appId),
          padding: EdgeInsets.only(bottom: index == queue.length - 1 ? 0 : 16),
          child: ReorderableDragStartListener(
            index: index,
            child: GameCard(
              game: game,
              queueIndex: index + 1,
              inQueue: true,
              showDragHandle: true,
              onToggleQueue: () => _toggleQueue(game),
              onTap: () => _openDetail(game),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLibraryTab(BuildContext context) {
    if (_filteredGames.isEmpty) {
      return const Center(child: Text('No hay juegos que coincidan'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 32;
        final crossAxisCount = width > 1200
            ? 4
            : width > 900
                ? 3
                : width > 600
                    ? 2
                    : 1;

        if (crossAxisCount == 1) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _filteredGames.length,
            itemBuilder: (context, index) {
              final game = _filteredGames[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == _filteredGames.length - 1 ? 0 : 16,
                ),
                child: GameCard(
                  game: game,
                  inQueue: _queueIdSet.contains(game.appId),
                  onToggleQueue: () => _toggleQueue(game),
                  onTap: () => _openDetail(game),
                ),
              );
            },
          );
        }

        final cellWidth =
            (width - 16 * (crossAxisCount - 1)) / crossAxisCount;
        final imageHeight = cellWidth * 215 / 460;
        const textBlock = 72.0;
        final cellHeight = imageHeight + textBlock;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: cellHeight,
          ),
          itemCount: _filteredGames.length,
          itemBuilder: (context, index) {
            final game = _filteredGames[index];
            return GameCard(
              game: game,
              inQueue: _queueIdSet.contains(game.appId),
              onToggleQueue: () => _toggleQueue(game),
              onTap: () => _openDetail(game),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = _user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null && user.avatarUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: user.avatarUrl,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.steamMid,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person, size: 36),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.personaName ?? 'Tu biblioteca',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _StatChip(
                      icon: Icons.videogame_asset,
                      label: '${_games.length} juegos',
                    ),
                    _StatChip(
                      icon: Icons.timer,
                      label: '$_totalPlaytimeHours h totales',
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final tabIndex = _tabController.index;
    final onLibraryTab = tabIndex == 1;
    final onAchievementsTab = tabIndex == 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          final searchField = TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: onAchievementsTab
                  ? 'Buscar logros o juegos...'
                  : onLibraryTab
                      ? 'Buscar en tu biblioteca...'
                      : 'Buscar en próximos...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
          );
          final sortField = DropdownButtonFormField<String>(
            initialValue: _sortBy,
            decoration: const InputDecoration(
              labelText: 'Ordenar por',
            ),
            items: const [
              DropdownMenuItem(
                value: 'playtime',
                child: Text('Tiempo jugado'),
              ),
              DropdownMenuItem(
                value: 'recent',
                child: Text('Recientes (2 sem)'),
              ),
              DropdownMenuItem(
                value: 'name',
                child: Text('Nombre'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _sortBy = value);
              _applyFilters();
            },
          );

          if (!onLibraryTab) {
            return searchField;
          }

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                SizedBox(width: 220, child: sortField),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 12),
              sortField,
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.steamMid.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.steamAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Asegúrate de que tu perfil de Steam sea público '
              'o que la visibilidad de juegos esté activada.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.steamMuted,
                  ),
            ),
            const SizedBox(height: 20),
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
}
