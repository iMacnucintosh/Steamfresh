import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/steam_config.dart';
import '../models/steam_achievement.dart';
import '../models/steam_app_details.dart';
import '../models/steam_game.dart';
import '../models/steam_user.dart';

class SteamApiException implements Exception {
  SteamApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SteamApiService {
  /// Titles containing any of these (case-insensitive) are hidden in the UI.
  static const hiddenTitleKeywords = ['freshwomen'];

  Future<SteamUser> getPlayerSummary(String steamId) async {
    final uri = Uri.parse(
      SteamConfig.steamApiUrl('/ISteamUser/GetPlayerSummaries/v0002/'),
    ).replace(queryParameters: {
      'key': SteamConfig.apiKey,
      'steamids': steamId,
    });

    final response = await _get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final players = (data['response'] as Map<String, dynamic>?)?['players']
        as List<dynamic>?;

    if (players == null || players.isEmpty) {
      throw SteamApiException('Perfil de Steam no encontrado');
    }

    return SteamUser.fromJson(players.first as Map<String, dynamic>);
  }

  Future<List<SteamGame>> getOwnedGames(String steamId) async {
    final uri = Uri.parse(
      SteamConfig.steamApiUrl('/IPlayerService/GetOwnedGames/v0001/'),
    ).replace(queryParameters: {
      'key': SteamConfig.apiKey,
      'steamid': steamId,
      'include_appinfo': '1',
      'include_played_free_games': '1',
      'format': 'json',
    });

    final response = await _get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final responseBody = data['response'] as Map<String, dynamic>?;

    if (responseBody == null) {
      throw SteamApiException('Respuesta inválida de la API de Steam');
    }

    final gameCount = responseBody['game_count'] as int? ?? 0;
    if (gameCount == 0) {
      return [];
    }

    final games = responseBody['games'] as List<dynamic>? ?? [];
    final parsed = games
        .map((g) => SteamGame.fromJson(g as Map<String, dynamic>))
        .where(_isVisibleInUi)
        .toList()
      ..sort((a, b) => b.playtimeMinutes.compareTo(a.playtimeMinutes));

    return parsed;
  }

  Future<SteamAppDetails?> getAppDetails(int appId) async {
    final uri = Uri.parse(
      SteamConfig.steamStoreUrl('/api/appdetails'),
    ).replace(queryParameters: {
      'appids': '$appId',
      'l': 'spanish',
    });

    final response = await _get(uri);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final entry = data['$appId'] as Map<String, dynamic>?;
    if (entry == null || entry['success'] != true) {
      return null;
    }

    final details = entry['data'] as Map<String, dynamic>?;
    if (details == null) return null;
    return SteamAppDetails.fromStoreJson(appId, details);
  }

  Future<SteamAchievementsProgress> getAchievementsProgress({
    required String steamId,
    required int appId,
  }) async {
    final playerFuture = _getPlayerAchievementsRaw(steamId, appId);
    final schemaFuture = _getGameSchemaAchievements(appId);
    final globalFuture = _getGlobalAchievementPercents(appId);

    final player = await playerFuture;
    final schema = await schemaFuture;
    final global = await globalFuture;

    if (player.error != null && schema.isEmpty) {
      return SteamAchievementsProgress(
        achievements: const [],
        unavailableReason: player.error,
      );
    }

    if (player.achievements.isEmpty && schema.isEmpty) {
      return SteamAchievementsProgress(
        achievements: const [],
        gameName: player.gameName,
        unavailableReason: player.error ?? 'Este juego no tiene logros',
      );
    }

    final playerByName = {
      for (final a in player.achievements) a.apiName: a,
    };
    final schemaNames = schema.keys.toSet();
    final allNames = {...schemaNames, ...playerByName.keys};

    final merged = <SteamAchievement>[];
    for (final name in allNames) {
      final meta = schema[name];
      final progress = playerByName[name];
      final achieved = progress?.achieved ?? false;
      final hidden = meta?.hidden ?? false;

      merged.add(
        SteamAchievement(
          apiName: name,
          displayName: meta?.displayName ?? name,
          description: meta?.description ?? '',
          iconUrl: meta?.iconUrl ?? '',
          iconGrayUrl: meta?.iconGrayUrl ?? meta?.iconUrl ?? '',
          achieved: achieved,
          hidden: hidden,
          unlockTime: progress?.unlockTime,
          globalPercent: global[name],
        ),
      );
    }

    merged.sort((a, b) {
      if (a.achieved != b.achieved) return a.achieved ? -1 : 1;
      final at = a.unlockTime;
      final bt = b.unlockTime;
      if (at != null && bt != null) return bt.compareTo(at);
      return a.visibleName.toLowerCase().compareTo(b.visibleName.toLowerCase());
    });

    return SteamAchievementsProgress(
      achievements: merged,
      gameName: player.gameName,
    );
  }

  Future<_PlayerAchievementsRaw> _getPlayerAchievementsRaw(
    String steamId,
    int appId,
  ) async {
    final uri = Uri.parse(
      SteamConfig.steamApiUrl('/ISteamUserStats/GetPlayerAchievements/v0001/'),
    ).replace(queryParameters: {
      'key': SteamConfig.apiKey,
      'steamid': steamId,
      'appid': '$appId',
      'l': 'spanish',
    });

    final response = await _get(uri, allowNonSuccessBody: true);
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const _PlayerAchievementsRaw(
        achievements: [],
        error: 'No se pudieron cargar los logros',
      );
    }
    final stats = data['playerstats'] as Map<String, dynamic>?;
    if (stats == null) {
      return const _PlayerAchievementsRaw(
        achievements: [],
        error: 'No se pudieron cargar los logros',
      );
    }

    if (stats['success'] != true) {
      final error = stats['error'] as String?;
      return _PlayerAchievementsRaw(
        achievements: const [],
        gameName: stats['gameName'] as String?,
        error: _mapAchievementError(error),
      );
    }

    final list = stats['achievements'] as List<dynamic>? ?? [];
    return _PlayerAchievementsRaw(
      gameName: stats['gameName'] as String?,
      achievements: [
        for (final item in list)
          _PlayerAchievementProgress.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  Future<Map<String, _SchemaAchievement>> _getGameSchemaAchievements(
    int appId,
  ) async {
    final uri = Uri.parse(
      SteamConfig.steamApiUrl('/ISteamUserStats/GetSchemaForGame/v2/'),
    ).replace(queryParameters: {
      'key': SteamConfig.apiKey,
      'appid': '$appId',
      'l': 'spanish',
    });

    try {
      final response = await _get(uri, allowNonSuccessBody: true);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final game = data['game'] as Map<String, dynamic>?;
      final available =
          game?['availableGameStats'] as Map<String, dynamic>?;
      final list = available?['achievements'] as List<dynamic>? ?? [];
      return {
        for (final item in list)
          if (item is Map<String, dynamic>)
            (item['name'] as String? ?? ''): _SchemaAchievement.fromJson(item),
      }..removeWhere((key, _) => key.isEmpty);
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, double>> _getGlobalAchievementPercents(int appId) async {
    final uri = Uri.parse(
      SteamConfig.steamApiUrl(
        '/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v0002/',
      ),
    ).replace(queryParameters: {
      'gameid': '$appId',
      'format': 'json',
    });

    try {
      final response = await _get(uri, allowNonSuccessBody: true);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['achievementpercentages']
              as Map<String, dynamic>?)?['achievements'] as List<dynamic>? ??
          [];
      final result = <String, double>{};
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final name = item['name'] as String?;
        final percent = item['percent'];
        if (name == null) continue;
        if (percent is num) result[name] = percent.toDouble();
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static String _mapAchievementError(String? error) {
    if (error == null || error.isEmpty) {
      return 'No hay logros disponibles para este juego';
    }
    final lower = error.toLowerCase();
    if (lower.contains('no stats') || lower.contains('no achievement')) {
      return 'Este juego no tiene logros de Steam';
    }
    if (lower.contains('private') || lower.contains('profile')) {
      return 'Los logros no son públicos en este perfil';
    }
    return error;
  }

  static bool _isVisibleInUi(SteamGame game) {
    final name = game.name.toLowerCase();
    for (final keyword in hiddenTitleKeywords) {
      if (name.contains(keyword.toLowerCase())) {
        return false;
      }
    }
    return true;
  }

  Future<http.Response> _get(
    Uri uri, {
    bool allowNonSuccessBody = false,
  }) async {
    late http.Response response;
    try {
      response = await http.get(uri);
    } catch (e) {
      if (kIsWeb) {
        throw SteamApiException(
          'No se pudo conectar con el proxy de Steam '
          '(${SteamConfig.proxyBase}).\n'
          'Arranca el proxy en otra terminal:\n'
          '  dart run tool/steam_proxy.dart',
        );
      }
      throw SteamApiException('Error de red: $e');
    }

    if (response.statusCode != 200 && !allowNonSuccessBody) {
      throw SteamApiException(
        'Error de Steam API (${response.statusCode})',
      );
    }
    return response;
  }
}

class _PlayerAchievementsRaw {
  const _PlayerAchievementsRaw({
    required this.achievements,
    this.gameName,
    this.error,
  });

  final List<_PlayerAchievementProgress> achievements;
  final String? gameName;
  final String? error;
}

class _PlayerAchievementProgress {
  const _PlayerAchievementProgress({
    required this.apiName,
    required this.achieved,
    this.unlockTime,
  });

  final String apiName;
  final bool achieved;
  final DateTime? unlockTime;

  factory _PlayerAchievementProgress.fromJson(Map<String, dynamic> json) {
    final unlock = json['unlocktime'] as int? ?? 0;
    return _PlayerAchievementProgress(
      apiName: json['apiname'] as String? ?? '',
      achieved: (json['achieved'] as int? ?? 0) == 1,
      unlockTime: unlock > 0
          ? DateTime.fromMillisecondsSinceEpoch(unlock * 1000)
          : null,
    );
  }
}

class _SchemaAchievement {
  const _SchemaAchievement({
    required this.displayName,
    required this.description,
    required this.iconUrl,
    required this.iconGrayUrl,
    required this.hidden,
  });

  final String displayName;
  final String description;
  final String iconUrl;
  final String iconGrayUrl;
  final bool hidden;

  factory _SchemaAchievement.fromJson(Map<String, dynamic> json) {
    return _SchemaAchievement(
      displayName: json['displayName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconUrl: json['icon'] as String? ?? '',
      iconGrayUrl: json['icongray'] as String? ?? '',
      hidden: (json['hidden'] as int? ?? 0) == 1,
    );
  }
}
