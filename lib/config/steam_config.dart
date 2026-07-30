import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SteamConfig {
  static const openIdEndpoint = 'https://steamcommunity.com/openid/login';
  static const apiBase = 'https://api.steampowered.com';
  static const storeBase = 'https://store.steampowered.com';

  /// CORS proxy base URL for Flutter web.
  /// Local: `dart run tool/steam_proxy.dart` → http://localhost:8787
  /// Production: Cloudflare Worker URL via --dart-define=STEAM_PROXY=...
  static const proxyBase = String.fromEnvironment(
    'STEAM_PROXY',
    defaultValue: 'http://localhost:8787',
  );

  static String get apiKey {
    final fromEnv = dotenv.env['STEAM_API_KEY'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }
    const fromDefine = String.fromEnvironment('STEAM_API_KEY');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    throw StateError(
      'STEAM_API_KEY no configurada. Copia .env.example a .env o usa '
      '--dart-define=STEAM_API_KEY=...',
    );
  }

  /// On web, Steam hosts block browser CORS — route through the local proxy.
  static String steamApiUrl(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    if (kIsWeb) {
      return '$proxyBase/steam$normalized';
    }
    return '$apiBase$normalized';
  }

  static String steamStoreUrl(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    if (kIsWeb) {
      return '$proxyBase/store$normalized';
    }
    return '$storeBase$normalized';
  }

  static String get openIdValidateUrl {
    if (kIsWeb) {
      return '$proxyBase/openid/validate';
    }
    return openIdEndpoint;
  }
}
