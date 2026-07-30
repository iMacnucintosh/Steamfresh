import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/steam_game.dart';
import '../models/steam_user.dart';
import '../services/steam_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_card.dart';
import '../widgets/steam_gradient_background.dart';

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

class _LibraryScreenState extends State<LibraryScreen> {
  final _api = SteamApiService();
  final _searchController = TextEditingController();

  SteamUser? _user;
  List<SteamGame> _games = [];
  List<SteamGame> _filteredGames = [];
  var _isLoading = true;
  String? _error;
  String _sortBy = 'playtime';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadLibrary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      ]);

      if (!mounted) return;

      setState(() {
        _user = results[0] as SteamUser;
        _games = results[1] as List<SteamGame>;
        _isLoading = false;
      });
      _applyFilters();
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

  int get _totalPlaytimeHours =>
      _games.fold<int>(0, (sum, g) => sum + g.playtimeMinutes) ~/ 60;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SteamGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _loadLibrary)
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader(context)),
                        SliverToBoxAdapter(child: _buildToolbar(context)),
                        if (_filteredGames.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text('No hay juegos que coincidan'),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverLayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.crossAxisExtent;
                                final crossAxisCount = width > 1200
                                    ? 4
                                    : width > 900
                                        ? 3
                                        : width > 600
                                            ? 2
                                            : 1;

                                // One column: natural card height (no forced empty space).
                                if (crossAxisCount == 1) {
                                  return SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => Padding(
                                        padding: EdgeInsets.only(
                                          bottom: index ==
                                                  _filteredGames.length - 1
                                              ? 0
                                              : 16,
                                        ),
                                        child: GameCard(
                                          game: _filteredGames[index],
                                        ),
                                      ),
                                      childCount: _filteredGames.length,
                                    ),
                                  );
                                }

                                // Grid: header is ~460:215 plus ~72px of text.
                                final cellWidth =
                                    (width - 16 * (crossAxisCount - 1)) /
                                        crossAxisCount;
                                final imageHeight = cellWidth * 215 / 460;
                                const textBlock = 72.0;
                                final cellHeight = imageHeight + textBlock;

                                return SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    mainAxisExtent: cellHeight,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => GameCard(
                                      game: _filteredGames[index],
                                    ),
                                    childCount: _filteredGames.length,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          final searchField = TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar en tu biblioteca...',
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
