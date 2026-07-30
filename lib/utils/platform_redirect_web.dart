// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String getPlatformAuthReturnUrl() {
  final uri = Uri.parse(html.window.location.href);
  return uri.replace(queryParameters: {}).toString();
}

void platformRedirectToUrl(String url) {
  html.window.location.href = url;
}

void platformCleanAuthCallbackFromUrl() {
  final uri = Uri.parse(html.window.location.href);
  if (!uri.queryParameters.containsKey('openid.mode')) {
    return;
  }
  html.window.history.replaceState(
    null,
    '',
    uri.replace(queryParameters: {}).toString(),
  );
}
