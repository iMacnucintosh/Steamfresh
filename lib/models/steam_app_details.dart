class SteamScreenshot {
  const SteamScreenshot({
    required this.thumbnailUrl,
    required this.fullUrl,
  });

  final String thumbnailUrl;
  final String fullUrl;
}

class SteamAppDetails {
  const SteamAppDetails({
    required this.appId,
    required this.name,
    required this.shortDescription,
    required this.developers,
    required this.publishers,
    required this.genres,
    required this.releaseDate,
    required this.headerImage,
    this.metacriticScore,
    this.screenshots = const [],
  });

  final int appId;
  final String name;
  final String shortDescription;
  final List<String> developers;
  final List<String> publishers;
  final List<String> genres;
  final String releaseDate;
  final String headerImage;
  final int? metacriticScore;
  final List<SteamScreenshot> screenshots;

  factory SteamAppDetails.fromStoreJson(int appId, Map<String, dynamic> data) {
    final genres = (data['genres'] as List<dynamic>? ?? [])
        .map((g) => (g as Map<String, dynamic>)['description'] as String? ?? '')
        .where((g) => g.isNotEmpty)
        .toList();

    final screenshots = <SteamScreenshot>[];
    for (final item in data['screenshots'] as List<dynamic>? ?? []) {
      if (item is! Map<String, dynamic>) continue;
      final thumb = item['path_thumbnail'] as String? ?? '';
      final full = item['path_full'] as String? ?? thumb;
      if (thumb.isEmpty && full.isEmpty) continue;
      screenshots.add(
        SteamScreenshot(
          thumbnailUrl: thumb.isNotEmpty ? thumb : full,
          fullUrl: full.isNotEmpty ? full : thumb,
        ),
      );
    }

    final release = data['release_date'] as Map<String, dynamic>?;
    final metacritic = data['metacritic'] as Map<String, dynamic>?;

    return SteamAppDetails(
      appId: appId,
      name: data['name'] as String? ?? 'Juego desconocido',
      shortDescription: data['short_description'] as String? ?? '',
      developers: ((data['developers'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      publishers: ((data['publishers'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      genres: genres,
      releaseDate: release?['date'] as String? ?? '',
      headerImage: data['header_image'] as String? ?? '',
      metacriticScore: metacritic?['score'] as int?,
      screenshots: screenshots,
    );
  }
}
