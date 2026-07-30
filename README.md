# SteamFresh

App Flutter para **web** y **Android** que te permite iniciar sesión con Steam y explorar tu biblioteca de juegos con una interfaz visual inspirada en Steam.

## Requisitos

- Flutter SDK 3.12+
- Una [Steam Web API Key](https://steamcommunity.com/dev/apikey)
- Perfil de Steam con visibilidad de juegos activada (público o visible para amigos según tu configuración)

## Configuración

1. Copia el archivo de entorno:

```bash
cp .env.example .env
```

2. Edita `.env` y añade tu API key:

```
STEAM_API_KEY=tu_api_key_aqui
```

Alternativa sin archivo `.env`:

```bash
flutter run --dart-define=STEAM_API_KEY=tu_api_key_aqui
```

## Despliegue (GitHub Pages)

La web se publica en:
**https://imacnucintosh.github.io/Steamfresh/**

GitHub Pages no puede hablar con Steam directamente (CORS), así que hace falta un proxy pequeño en Cloudflare Workers.

### 1. Proxy (una sola vez)

```bash
cd proxy/cloudflare
npx wrangler login
npx wrangler deploy
npx wrangler secret put STEAM_API_KEY   # opcional pero recomendado
```

Anota la URL del worker, p. ej. `https://steamfresh-proxy.xxx.workers.dev`.

### 2. Secrets del repositorio

En GitHub → Settings → Secrets and variables → Actions:

| Secret | Valor |
|--------|--------|
| `STEAM_API_KEY` | Tu API key de Steam |
| `STEAM_PROXY` | URL del worker (sin `/` final) |

O con CLI:

```bash
gh secret set STEAM_API_KEY
gh secret set STEAM_PROXY
```

### 3. Activar Pages

Settings → Pages → **Source: GitHub Actions**.

Cada push a `main` ejecuta `.github/workflows/deploy-pages.yml` y publica el build.

### 4. Probar

Abre https://imacnucintosh.github.io/Steamfresh/ — login Steam y biblioteca.

Detalle del proxy: [proxy/cloudflare/README.md](proxy/cloudflare/README.md).

## Ejecutar

### Web (local)

El navegador bloquea las llamadas directas a Steam (CORS). Hay que arrancar el proxy local:

```bash
# Terminal 1 — proxy CORS
dart run tool/steam_proxy.dart

# Terminal 2 — app
flutter run -d chrome
```

O en un solo comando:

```bash
chmod +x scripts/run_web.sh
./scripts/run_web.sh
```

El login redirige a Steam y vuelve a la misma URL. En desarrollo siempre es `http://localhost:8080`.

### PWA (Progressive Web App)

La web está configurada como PWA instalable:

- `web/manifest.json` — nombre, iconos, tema standalone
- `web/sw.js` — service worker propio (caché del shell; la API de Steam no se cachea)
- Metadatos iOS/Android para “Añadir a pantalla de inicio”

Para probarla en local:

```bash
flutter build web
dart run tool/steam_proxy.dart   # sigue haciendo falta el proxy para la API
python3 -m http.server 8080 --directory build/web
```

Abre `http://localhost:8080` e instálala desde el icono ⊕ del navegador (Chrome/Edge) o “Añadir a pantalla de inicio” en móvil. En un dispositivo real hace falta **HTTPS** (o un túnel tipo Cloudflare/ngrok).

### Android

```bash
flutter run -d android
```

El login abre un WebView con OpenID de Steam.

## Funcionalidades actuales

- Inicio de sesión con Steam (OpenID)
- Listado de juegos de tu biblioteca
- Portadas, tiempo jugado y búsqueda
- Ordenación por tiempo jugado, actividad reciente o nombre
- Tema oscuro estilo Steam
- PWA instalable (web)
- Deploy automático a GitHub Pages

## Próximos pasos

- Logros y estadísticas
- Vista de detalle por juego
- Filtros por género, estado de instalación, etc.

## Seguridad

No subas tu API key al repositorio. El archivo `.env` está en `.gitignore`. Para producción, considera un backend que oculte la clave.
