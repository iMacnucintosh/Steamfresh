/**
 * SteamFresh CORS proxy for GitHub Pages / production web.
 *
 * Routes (same as tool/steam_proxy.dart):
 *   GET  /steam/<path>?...  → api.steampowered.com
 *   POST /openid/validate   → Steam OpenID check_authentication
 *
 * Deploy:
 *   cd proxy/cloudflare
 *   npx wrangler secret put STEAM_API_KEY   # optional; injects key if client omits it
 *   npx wrangler deploy
 *
 * Then set GitHub secret STEAM_PROXY to the workers.dev URL (no trailing slash).
 */

const STEAM_API = 'https://api.steampowered.com';
const STEAM_OPENID = 'https://steamcommunity.com/openid/login';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const url = new URL(request.url);

    try {
      if (request.method === 'GET' && url.pathname.startsWith('/steam/')) {
        return await proxySteamApi(url, env);
      }
      if (request.method === 'POST' && url.pathname === '/openid/validate') {
        return await validateOpenId(request);
      }
      return json(
        {
          error: 'Not found',
          routes: ['GET /steam/<path>?query', 'POST /openid/validate'],
        },
        404,
      );
    } catch (error) {
      return json({ error: String(error) }, 500);
    }
  },
};

async function proxySteamApi(url, env) {
  const steamPath = url.pathname.slice('/steam'.length);
  const target = new URL(`${STEAM_API}${steamPath}`);
  url.searchParams.forEach((value, key) => {
    target.searchParams.set(key, value);
  });

  // Prefer server-side key so the Pages build need not expose it in every request
  // (the client may still send one for local/dev compatibility).
  if (env.STEAM_API_KEY && !target.searchParams.get('key')) {
    target.searchParams.set('key', env.STEAM_API_KEY);
  }

  const upstream = await fetch(target.toString(), {
    headers: { Accept: 'application/json' },
  });
  const body = await upstream.text();

  return new Response(body, {
    status: upstream.status,
    headers: {
      ...corsHeaders,
      'Content-Type': upstream.headers.get('Content-Type') || 'application/json',
    },
  });
}

async function validateOpenId(request) {
  const params = await request.json();
  if (!params || typeof params !== 'object' || !params['openid.claimed_id']) {
    return json({ error: 'Missing openid.claimed_id' }, 400);
  }

  const claimedId = String(params['openid.claimed_id']);
  const form = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    form.set(key, String(value));
  }
  form.set('openid.mode', 'check_authentication');

  const upstream = await fetch(STEAM_OPENID, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form.toString(),
  });
  const text = await upstream.text();
  const valid = text.includes('is_valid:true');
  const prefix = 'https://steamcommunity.com/openid/id/';
  const steamId = claimedId.startsWith(prefix)
    ? claimedId.slice(prefix.length)
    : null;

  return json(
    { valid, steamId },
    valid && steamId ? 200 : 401,
  );
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
