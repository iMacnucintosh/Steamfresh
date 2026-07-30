import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/library_screen.dart';
import 'screens/login_screen.dart';
import 'services/steam_auth_service.dart';
import 'theme/app_theme.dart';
import 'utils/platform_redirect.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final authService = SteamAuthService();
  String? steamId;
  String? authError;

  if (kIsWeb) {
    if (Uri.base.queryParameters['openid.mode'] == 'id_res') {
      try {
        final callbackResult = await authService.handleCallbackUri(Uri.base);
        if (callbackResult != null) {
          steamId = callbackResult;
        } else {
          authError = 'No se pudo completar el inicio de sesión con Steam';
          cleanAuthCallbackFromUrl();
        }
      } catch (e) {
        authError = 'Error al iniciar sesión: $e';
        cleanAuthCallbackFromUrl();
      }
    }
  }

  steamId ??= await authService.getSavedSteamId();

  runApp(SteamFreshApp(initialSteamId: steamId, authError: authError));
}

class SteamFreshApp extends StatefulWidget {
  const SteamFreshApp({
    super.key,
    this.initialSteamId,
    this.authError,
  });

  final String? initialSteamId;
  final String? authError;

  @override
  State<SteamFreshApp> createState() => _SteamFreshAppState();
}

class _SteamFreshAppState extends State<SteamFreshApp> {
  final _authService = SteamAuthService();
  String? _steamId;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _steamId = widget.initialSteamId;
    _authError = widget.authError;
  }

  Future<void> _logout() async {
    await _authService.clearSession();
    setState(() {
      _steamId = null;
      _authError = null;
    });
  }

  void _onLoggedIn(String steamId) {
    setState(() {
      _steamId = steamId;
      _authError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SteamFresh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: _steamId == null
          ? LoginScreen(
              onLoggedIn: _onLoggedIn,
              errorMessage: _authError,
            )
          : LibraryScreen(
              steamId: _steamId!,
              onLogout: _logout,
            ),
    );
  }
}
