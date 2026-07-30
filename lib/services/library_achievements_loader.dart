import '../models/library_achievements_summary.dart';
import '../models/steam_game.dart';
import 'steam_api_service.dart';

typedef AchievementsLoadProgress = void Function(int done, int total);
typedef AchievementsPartialCallback = void Function(
  LibraryAchievementsSummary summary,
);

/// Loads achievement progress for many games with limited concurrency.
class LibraryAchievementsLoader {
  LibraryAchievementsLoader({SteamApiService? api})
      : _api = api ?? SteamApiService();

  final SteamApiService _api;

  Future<LibraryAchievementsSummary> load({
    required String steamId,
    required List<SteamGame> games,
    AchievementsLoadProgress? onProgress,
    AchievementsPartialCallback? onPartial,
    bool Function()? isCancelled,
  }) async {
    final ordered = [...games]
      ..sort((a, b) => b.playtimeMinutes.compareTo(a.playtimeMinutes));

    final total = ordered.length;
    var done = 0;
    var unlockedCount = 0;
    var totalAchievements = 0;
    var gamesWithAchievements = 0;
    final unlocked = <LibraryAchievementEntry>[];

    LibraryAchievementsSummary snapshot() {
      final sorted = [...unlocked]..sort((a, b) {
          final rarityCmp = a.rarity.compareTo(b.rarity);
          if (rarityCmp != 0) return rarityCmp;
          return a.achievement.visibleName
              .toLowerCase()
              .compareTo(b.achievement.visibleName.toLowerCase());
        });
      return LibraryAchievementsSummary(
        unlockedCount: unlockedCount,
        totalAchievements: totalAchievements,
        libraryGameCount: games.length,
        gamesWithAchievements: gamesWithAchievements,
        unlockedByRarity: sorted,
      );
    }

    const concurrency = 4;
    var next = 0;

    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() ?? false) return;
        final index = next++;
        if (index >= ordered.length) return;

        final game = ordered[index];
        try {
          final progress = await _api.getAchievementsProgress(
            steamId: steamId,
            appId: game.appId,
          );
          if (isCancelled?.call() ?? false) return;

          if (progress.hasAchievements) {
            gamesWithAchievements++;
            totalAchievements += progress.totalCount;
            unlockedCount += progress.unlockedCount;
            for (final achievement in progress.achievements) {
              if (!achievement.achieved) continue;
              unlocked.add(
                LibraryAchievementEntry(game: game, achievement: achievement),
              );
            }
          }
        } catch (_) {
          // Skip games that fail (private stats, rate limits, etc.).
        } finally {
          done++;
          onProgress?.call(done, total);
          if (done == total || done % 3 == 0) {
            onPartial?.call(snapshot());
          }
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency; i++) worker(),
    ]);

    return snapshot();
  }
}
