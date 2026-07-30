{{flutter_js}}
{{flutter_build_config}}

// Custom PWA service worker (Flutter's default SW is deprecated).
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
}).then(function () {
  if (!('serviceWorker' in navigator)) {
    return;
  }
  navigator.serviceWorker.register('sw.js').catch(function (error) {
    console.warn('SteamFresh SW registration failed:', error);
  });
});
