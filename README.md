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

## Ejecutar

### Web

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

El login redirige a Steam y vuelve a la misma URL. En desarrollo suele ser `http://localhost:XXXX`.

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

## Próximos pasos

- Logros y estadísticas
- Vista de detalle por juego
- Filtros por género, estado de instalación, etc.

## Seguridad

No subas tu API key al repositorio. El archivo `.env` está en `.gitignore`. Para producción, considera un backend que oculte la clave.
