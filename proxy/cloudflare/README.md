# SteamFresh CORS proxy (Cloudflare Worker)

GitHub Pages cannot call the Steam API from the browser (CORS). This worker
mirrors `tool/steam_proxy.dart` for production.

## Deploy

1. Install Wrangler and log in:

```bash
npm i -g wrangler
wrangler login
```

2. From this folder:

```bash
cd proxy/cloudflare
npx wrangler deploy
```

3. Optional — keep the API key only on the worker:

```bash
npx wrangler secret put STEAM_API_KEY
```

4. Copy the workers.dev URL (no trailing slash), e.g.
   `https://steamfresh-proxy.<your-subdomain>.workers.dev`

5. Add GitHub Actions secrets on the repo:

| Secret | Value |
|--------|--------|
| `STEAM_API_KEY` | Your Steam Web API key |
| `STEAM_PROXY` | The worker URL from step 4 |

6. Push to `main` (or run the **Deploy GitHub Pages** workflow).

App URL: `https://imacnucintosh.github.io/Steamfresh/`
