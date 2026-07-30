import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/steam_config.dart';
import '../utils/platform_redirect.dart';

class SteamAuthService {
  static const _steamIdKey = 'steam_id';

  Uri buildLoginUrl() {
    final returnTo = getAuthReturnUrl();
    final realm = _realmFromReturnTo(returnTo);

    return Uri.parse(SteamConfig.openIdEndpoint).replace(
      queryParameters: {
        'openid.ns': 'http://specs.openid.net/auth/2.0',
        'openid.mode': 'checkid_setup',
        'openid.return_to': returnTo,
        'openid.realm': realm,
        'openid.identity': 'http://specs.openid.net/auth/2.0/identifier_select',
        'openid.claimed_id': 'http://specs.openid.net/auth/2.0/identifier_select',
      },
    );
  }

  Future<String?> getSavedSteamId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_steamIdKey);
  }

  Future<void> saveSteamId(String steamId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_steamIdKey, steamId);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_steamIdKey);
  }

  Future<String?> handleCallbackUri(Uri uri) async {
    if (uri.queryParameters['openid.mode'] != 'id_res') {
      return null;
    }

    final steamId = await _validateAndExtractSteamId(uri);
    if (steamId != null) {
      await saveSteamId(steamId);
      if (kIsWeb) {
        cleanAuthCallbackFromUrl();
      }
    }
    return steamId;
  }

  Future<void> startWebLogin() async {
    if (!kIsWeb) {
      throw UnsupportedError('startWebLogin solo está disponible en web');
    }
    redirectToUrl(buildLoginUrl().toString());
  }

  String? extractSteamIdFromClaimedId(String claimedId) {
    const prefix = 'https://steamcommunity.com/openid/id/';
    if (!claimedId.startsWith(prefix)) {
      return null;
    }
    return claimedId.substring(prefix.length);
  }

  Future<String?> _validateAndExtractSteamId(Uri callbackUri) async {
    final params = Map<String, String>.from(callbackUri.queryParameters);
    final claimedId = params['openid.claimed_id'];
    if (claimedId == null) {
      return null;
    }

    if (kIsWeb) {
      return _validateViaProxy(params, claimedId);
    }

    return _validateDirect(params, claimedId);
  }

  Future<String?> _validateViaProxy(
    Map<String, String> params,
    String claimedId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(SteamConfig.openIdValidateUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(params),
      );

      if (response.statusCode != 200) {
        return extractSteamIdFromClaimedId(claimedId);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['valid'] == true && data['steamId'] is String) {
        return data['steamId'] as String;
      }
      return extractSteamIdFromClaimedId(claimedId);
    } catch (_) {
      return extractSteamIdFromClaimedId(claimedId);
    }
  }

  Future<String?> _validateDirect(
    Map<String, String> params,
    String claimedId,
  ) async {
    params['openid.mode'] = 'check_authentication';

    final response = await http.post(
      Uri.parse(SteamConfig.openIdEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: params.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}')
          .join('&'),
    );

    if (response.statusCode != 200 ||
        !response.body.contains('is_valid:true')) {
      return null;
    }

    return extractSteamIdFromClaimedId(claimedId);
  }

  String _realmFromReturnTo(String returnTo) {
    final uri = Uri.parse(returnTo);
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return uri.origin;
    }
    return '${uri.scheme}://${uri.host}';
  }
}
