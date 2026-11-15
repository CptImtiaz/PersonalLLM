# Railway deployment (8B, CPU-only)

Deploys Ollama to Railway and auto-builds the `hack-assistant` alias from
the 8B model. **Railway has no GPU**, so inference runs on CPU at a few
tokens/second. The larger tiers are not practical here — use a GPU host
for those, or keep inference local and deploy only a UI (see below).

> Authorized lab / CTF use only. Deploying an uncensored model to a public
> URL exposes it to anyone who finds the endpoint — keep the domain private
> or put auth in front of it.

## What gets deployed

- **Service `ollama`** — this repo, built from `deploy/railway/Dockerfile`.
  On first boot it pulls `huihui_ai/qwen3-abliterated:8b-v2` and creates `hack-assistant`.
- **Volume** at `/root/.ollama` — persists the model so redeploys don't
  re-download ~4.5 GB.

## Deploy steps

1. New Railway project → **Deploy from GitHub repo** → `CptImtiaz/PersonalLLM`.
2. In the service's **Settings → Build**:
   - Builder: `Dockerfile`
   - Dockerfile Path: `deploy/railway/Dockerfile`
   - Root Directory: `/` (repo root — the Dockerfile COPYs `Modelfile`)
3. **Variables** (optional):
   - `BASE_MODEL` — override the model tag if the default 404s.
4. **Volumes** → add a volume, mount path `/root/.ollama`.
   Size it ≥ 8 GB (7B Q4 ≈ 4.5 GB + overhead).
5. **Settings → Networking** → Generate Domain (or keep internal-only).
6. Deploy. First boot is slow (model download) — the healthcheck timeout
   is set to 600s in `railway.json`.

## Using it

Ollama's API is OpenAI-compatible-ish and lives at your domain:

```bash
curl https://<your-app>.up.railway.app/api/generate \
  -d '{"model":"hack-assistant","prompt":"explain this nmap output: ...","stream":false}'
```

Point Open Interpreter at it from your laptop:

```bash
interpreter --model ollama/hack-assistant \
  --api_base https://<your-app>.up.railway.app
```

## Better option if you want speed: local GPU + UI on Railway

Keep Ollama on your own GPU machine and deploy only a chat UI
(e.g. Open WebUI) to Railway as a second service, with
`OLLAMA_BASE_URL` pointing back to your machine through a tunnel
(Cloudflare Tunnel / Tailscale Funnel). You get GPU speed and a hosted
front-end without shipping the model to CPU-only hosting.
