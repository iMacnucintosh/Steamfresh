String getPlatformAuthReturnUrl() => 'steamfresh://auth/callback';

void platformRedirectToUrl(String url) {
  throw UnsupportedError('redirectToUrl solo está soportado en web');
}

void platformCleanAuthCallbackFromUrl() {}
