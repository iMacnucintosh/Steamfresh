// Local CORS proxy for Steam Web API + OpenID validation.
// Run: dart run tool/steam_proxy.dart
//
// Flutter web cannot call steamcommunity.com / api.steampowered.com
// directly because those hosts do not send Access-Control-Allow-Origin.

import 'dart:convert';
import 'dart:io';

const _port = 8787;
const _steamApi = 'https://api.steampowered.com';
const _steamStore = 'https://store.steampowered.com';
const _steamOpenId = 'https://steamcommunity.com/openid/login';

final _cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

Future<void> main() async {
  final server = await _bindFixedPort(_port);
  stdout.writeln('SteamFresh proxy → http://localhost:$_port');
  stdout.writeln('  GET  /steam/<ISteamInterface>/...  → api.steampowered.com');
  stdout.writeln('  GET  /store/<path>?...             → store.steampowered.com');
  stdout.writeln('  POST /openid/validate              → OpenID check_authentication');

  await for (final request in server) {
    try {
      await _handle(request);
    } catch (e, st) {
      stderr.writeln('Proxy error: $e\n$st');
      if (!_responseClosed(request.response)) {
        _json(request.response, 500, {'error': e.toString()});
      }
    }
  }
}

/// Always listens on [_port]. If something already holds it (often a previous
/// proxy), free it and retry once.
Future<HttpServer> _bindFixedPort(int port) async {
  try {
    return await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } on SocketException catch (e) {
    if (!_isAddressInUse(e)) rethrow;
    stderr.writeln('Puerto $port ocupado — liberando proceso anterior…');
    await _freePort(port);
    return HttpServer.bind(InternetAddress.loopbackIPv4, port);
  }
}

bool _isAddressInUse(SocketException e) {
  final message = e.message.toLowerCase();
  return e.osError?.errorCode == 98 || // EADDRINUSE (Linux)
      message.contains('address already in use') ||
      message.contains('failed to create server socket');
}

Future<void> _freePort(int port) async {
  try {
    final result = await Process.run('fuser', ['-k', '$port/tcp']);
    if (result.exitCode != 0) {
      // fuser may be missing; try lsof as fallback
      final lsof = await Process.run('lsof', ['-t', '-iTCP:$port', '-sTCP:LISTEN']);
      final pids = (lsof.stdout as String)
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      for (final pid in pids) {
        await Process.run('kill', [pid]);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  } catch (_) {
    // Best-effort; bind will fail again with a clear error if still occupied.
  }
}

bool _responseClosed(HttpResponse response) {
  try {
    return response.connectionInfo == null;
  } catch (_) {
    return true;
  }
}

Future<void> _handle(HttpRequest request) async {
  final response = request.response;

  if (request.method == 'OPTIONS') {
    response.statusCode = 204;
    _cors.forEach(response.headers.set);
    await response.close();
    return;
  }

  final path = request.uri.path;

  if (request.method == 'GET' && path.startsWith('/steam/')) {
    await _proxySteamApi(request);
    return;
  }

  if (request.method == 'GET' && path.startsWith('/store/')) {
    await _proxySteamStore(request);
    return;
  }

  if (request.method == 'POST' && path == '/openid/validate') {
    await _validateOpenId(request);
    return;
  }

  _json(response, 404, {
    'error': 'Not found',
    'routes': [
      'GET /steam/<path>?query',
      'GET /store/<path>?query',
      'POST /openid/validate',
    ],
  });
}

Future<void> _proxySteamApi(HttpRequest request) async {
  final steamPath = request.uri.path.substring('/steam'.length);
  final target = Uri.parse('$_steamApi$steamPath').replace(
    queryParameters: request.uri.queryParameters,
  );
  await _proxyGet(request, target);
}

Future<void> _proxySteamStore(HttpRequest request) async {
  final storePath = request.uri.path.substring('/store'.length);
  final target = Uri.parse('$_steamStore$storePath').replace(
    queryParameters: request.uri.queryParameters,
  );
  await _proxyGet(request, target);
}

Future<void> _proxyGet(HttpRequest request, Uri target) async {
  final client = HttpClient();
  try {
    final upstream = await client.getUrl(target);
    upstream.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final upstreamResponse = await upstream.close();
    final body = await upstreamResponse.transform(utf8.decoder).join();

    request.response.statusCode = upstreamResponse.statusCode;
    _cors.forEach(request.response.headers.set);
    request.response.headers.contentType = ContentType.json;
    request.response.write(body);
    await request.response.close();
  } finally {
    client.close();
  }
}

Future<void> _validateOpenId(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  Map<String, String> params;

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _json(request.response, 400, {'error': 'Expected JSON object'});
      return;
    }
    params = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
  } catch (_) {
    _json(request.response, 400, {'error': 'Invalid JSON body'});
    return;
  }

  final claimedId = params['openid.claimed_id'];
  if (claimedId == null) {
    _json(request.response, 400, {'error': 'Missing openid.claimed_id'});
    return;
  }

  params['openid.mode'] = 'check_authentication';

  final client = HttpClient();
  try {
    final upstream = await client.postUrl(Uri.parse(_steamOpenId));
    upstream.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded');
    upstream.write(
      params.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}')
          .join('&'),
    );

    final upstreamResponse = await upstream.close();
    final body = await upstreamResponse.transform(utf8.decoder).join();
    final valid = body.contains('is_valid:true');

    const prefix = 'https://steamcommunity.com/openid/id/';
    final steamId =
        claimedId.startsWith(prefix) ? claimedId.substring(prefix.length) : null;

    _json(request.response, valid && steamId != null ? 200 : 401, {
      'valid': valid,
      'steamId': steamId,
    });
  } finally {
    client.close();
  }
}

void _json(HttpResponse response, int status, Map<String, Object?> data) {
  response.statusCode = status;
  _cors.forEach(response.headers.set);
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(data));
  response.close();
}
