class SteamAchievement {
  const SteamAchievement({
    required this.apiName,
    required this.displayName,
    required this.description,
    required this.iconUrl,
    required this.iconGrayUrl,
    required this.achieved,
    required this.hidden,
    this.unlockTime,
    this.globalPercent,
  });

  final String apiName;
  final String displayName;
  final String description;
  final String iconUrl;
  final String iconGrayUrl;
  final bool achieved;
  final bool hidden;
  final DateTime? unlockTime;
  final double? globalPercent;

  String get visibleName {
    if (!achieved && hidden) return 'Logro oculto';
    return displayName.isNotEmpty ? displayName : apiName;
  }

  String get visibleDescription {
    if (!achieved && hidden) {
      return 'Sigue jugando para descubrir este logro.';
    }
    return description;
  }

  String get displayIconUrl => achieved ? iconUrl : iconGrayUrl;
}

class SteamAchievementsProgress {
  const SteamAchievementsProgress({
    required this.achievements,
    this.gameName,
    this.unavailableReason,
  });

  final List<SteamAchievement> achievements;
  final String? gameName;

  /// When Steam reports no stats / private profile / etc.
  final String? unavailableReason;

  bool get hasAchievements => achievements.isNotEmpty;

  int get unlockedCount => achievements.where((a) => a.achieved).length;

  int get totalCount => achievements.length;

  double get progressRatio =>
      totalCount == 0 ? 0 : unlockedCount / totalCount;
}
