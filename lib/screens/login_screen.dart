import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/steam_login_screen.dart';
import '../services/steam_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/steam_gradient_background.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.onLoggedIn,
    this.errorMessage,
  });

  final ValueChanged<String> onLoggedIn;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final authService = SteamAuthService();

    return Scaffold(
      body: SteamGradientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [AppTheme.steamAccent, AppTheme.steamMid],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.steamAccent.withValues(alpha: 0.35),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sports_esports,
                        size: 44,
                        color: AppTheme.steamNavy,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'SteamFresh',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tu biblioteca de Steam, visual y elegante. '
                      'Empieza iniciando sesión para ver todos tus juegos.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.steamMuted,
                            height: 1.5,
                          ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),
                    FilledButton.icon(
                      onPressed: () => _login(context, authService),
                      icon: const Icon(Icons.login),
                      label: const Text('Iniciar sesión con Steam'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Usamos OpenID de Steam. No almacenamos tu contraseña.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.steamMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login(BuildContext context, SteamAuthService authService) async {
    if (kIsWeb) {
      await authService.startWebLogin();
      return;
    }

    final steamId = await openSteamLogin(context);
    if (steamId != null) {
      onLoggedIn(steamId);
    }
  }
}
