import 'platform_redirect_stub.dart'
    if (dart.library.html) 'platform_redirect_web.dart';

export 'platform_redirect_stub.dart'
    if (dart.library.html) 'platform_redirect_web.dart';

String getAuthReturnUrl() => getPlatformAuthReturnUrl();

void redirectToUrl(String url) => platformRedirectToUrl(url);

void cleanAuthCallbackFromUrl() => platformCleanAuthCallbackFromUrl();
