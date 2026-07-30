import '../models/steam_achievement.dart';
import '../models/steam_game.dart';

class LibraryAchievementEntry {
  const LibraryAchievementEntry({
    required this.game,
    required this.achievement,
  });

  final SteamGame game;
  final SteamAchievement achievement;

  double get rarity => achievement.globalPercent ?? 100;
}

class LibraryAchievementsSummary {
  const LibraryAchievementsSummary({
    required this.unlockedCount,
    required this.totalAchievements,
    required this.libraryGameCount,
    required this.gamesWithAchievements,
    required this.unlockedByRarity,
  });

  final int unlockedCount;
  final int totalAchievements;
  final int libraryGameCount;
  final int gamesWithAchievements;
  final List<LibraryAchievementEntry> unlockedByRarity;

  double get progressRatio =>
      totalAchievements == 0 ? 0 : unlockedCount / totalAchievements;
}
