class SteamUser {
  const SteamUser({
    required this.steamId,
    required this.personaName,
    required this.avatarUrl,
    required this.profileUrl,
  });

  final String steamId;
  final String personaName;
  final String avatarUrl;
  final String profileUrl;

  factory SteamUser.fromJson(Map<String, dynamic> json) {
    return SteamUser(
      steamId: json['steamid'] as String,
      personaName: json['personaname'] as String? ?? 'Jugador',
      avatarUrl: json['avatarfull'] as String? ?? '',
      profileUrl: json['profileurl'] as String? ?? '',
    );
  }
}
