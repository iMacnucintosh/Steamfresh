import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/steam_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/steam_gradient_background.dart';

class SteamLoginScreen extends StatefulWidget {
  const SteamLoginScreen({super.key, required this.onSuccess});

  final ValueChanged<String> onSuccess;

  @override
  State<SteamLoginScreen> createState() => _SteamLoginScreenState();
}

class _SteamLoginScreenState extends State<SteamLoginScreen> {
  final _authService = SteamAuthService();
  late final WebViewController _controller;
  var _isValidating = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadRequest(_authService.buildLoginUrl());
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.parse(request.url);
    if (uri.queryParameters['openid.mode'] == 'id_res' && !_isValidating) {
      _completeLogin(uri);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _completeLogin(Uri uri) async {
    setState(() => _isValidating = true);
    final steamId = await _authService.handleCallbackUri(uri);
    if (!mounted) return;

    if (steamId != null) {
      widget.onSuccess(steamId);
      Navigator.of(context).pop(steamId);
    } else {
      setState(() => _isValidating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo validar el inicio de sesión con Steam'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SteamGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                    Text(
                      'Iniciar sesión con Steam',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (_isValidating)
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.steamMid),
              Expanded(
                child: WebViewWidget(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> openSteamLogin(BuildContext context) {
  if (kIsWeb) {
    throw UnsupportedError('En web usa SteamAuthService.startWebLogin()');
  }
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => SteamLoginScreen(onSuccess: (_) {})),
  );
}
