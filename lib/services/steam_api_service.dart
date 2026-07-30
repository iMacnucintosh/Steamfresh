import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/steam_config.dart';
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

  static bool _isVisibleInUi(SteamGame game) {
    final name = game.name.toLowerCase();
    for (final keyword in hiddenTitleKeywords) {
      if (name.contains(keyword.toLowerCase())) {
        return false;
      }
    }
    return true;
  }

  Future<http.Response> _get(Uri uri) async {
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

    if (response.statusCode != 200) {
      throw SteamApiException(
        'Error de Steam API (${response.statusCode})',
      );
    }
    return response;
  }
}
