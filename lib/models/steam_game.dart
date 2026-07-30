class SteamGame {
  const SteamGame({
    required this.appId,
    required this.name,
    required this.playtimeMinutes,
    required this.iconHash,
    required this.logoHash,
    this.recentPlaytimeMinutes = 0,
  });

  final int appId;
  final String name;
  final int playtimeMinutes;
  final int recentPlaytimeMinutes;
  final String iconHash;
  final String logoHash;

  double get playtimeHours => playtimeMinutes / 60;

  String get iconUrl =>
      'https://media.steampowered.com/steamcommunity/public/images/apps/'
      '$appId/$iconHash.jpg';

  String get headerUrl =>
      'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg';

  factory SteamGame.fromJson(Map<String, dynamic> json) {
    return SteamGame(
      appId: json['appid'] as int,
      name: json['name'] as String? ?? 'Juego desconocido',
      playtimeMinutes: json['playtime_forever'] as int? ?? 0,
      recentPlaytimeMinutes: json['playtime_2weeks'] as int? ?? 0,
      iconHash: json['img_icon_url'] as String? ?? '',
      logoHash: json['img_logo_url'] as String? ?? '',
    );
  }
}
