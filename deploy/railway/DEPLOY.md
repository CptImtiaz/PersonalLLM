# Full Railway Deployment Guide — Ollama + Open WebUI

This gives you a **web chat interface** (like ChatGPT), **document upload /
knowledge (RAG)**, and **tools / connectors**, all backed by your own model.
It's two Railway services in one project:

```
   Browser
     │  https
     ▼
┌─────────────────┐   private network    ┌──────────────────────┐
│  Open WebUI     │ ───────────────────► │  Ollama               │
│  (chat UI,      │  ollama.railway      │  (model inference)    │
│   uploads,      │  .internal:11434     │  volume: /root/.ollama│
│   tools,        │                      │  model: hack-assistant│
│   connectors)   │                      └──────────────────────┘
│  volume: /data  │
└─────────────────┘
```

> ⚠️ **Model reality on Railway:** Railway has **no GPU**. Only an **8B-class**
> model is practical here (CPU, a few tokens/sec). The 27B — even Q2_K — will
> be unusably slow or OOM. Keep 27B for a local GPU. Guide below uses the 8B
> abliterated Qwen3 (`huihui_ai/qwen3-abliterated:8b-v2`).
>
> Authorized lab / CTF use only. Put the chat UI behind a login (Open WebUI
> has one) and don't share the public URL.

---

## 0. Prerequisites
- This GitHub repo (`CptImtiaz/PersonalLLM`) — done.
- A Railway account with a plan that has enough RAM (7B needs ~6 GB; the
  free/Hobby tier is tight — Pro recommended).

> **Tip:** test the whole stack on your own machine first with
> `cd deploy && docker compose up`, then open http://localhost:3000. If it
> works locally, Railway will behave the same.

## 1. Create the project
1. Railway dashboard → **New Project** → **Empty Project**.
2. Name it e.g. `personal-llm`.

## 2. Service A — Ollama (the model backend)
1. In the project → **New** → **GitHub Repo** → pick `CptImtiaz/PersonalLLM`.
2. **Build is auto-configured.** The repo's root `railway.json` already sets
   the Dockerfile builder, path (`deploy/railway/Dockerfile`), start command,
   and the 600s healthcheck — so Railway detects it automatically. You do not
   need to touch Build settings.
3. **Settings → Variables**:
   - `PORT` = `11434`   (fixes the internal port so the UI can find it)
   - `BASE_MODEL` = `huihui_ai/qwen3-abliterated:8b-v2`
     (uncensored 8B Qwen3; ships its own template)
4. **Settings → Volumes** → add volume, mount path `/root/.ollama`, size ≥ 8 GB.
5. **Do NOT** generate a public domain for this service — keep it private.
6. Deploy. First boot downloads the model (~4.5 GB) — watch **Deploy Logs**
   until you see `'hack-assistant' ready`. (`railway.json` already sets a
   600s healthcheck.)

Its private address is now: `http://<ollama-service-name>.railway.internal:11434`

## 3. Service B — Open WebUI (the chat interface)
1. Project → **New** → **Docker Image**.
2. Image: `ghcr.io/open-webui/open-webui:main`
3. **Settings → Variables**:
   - `OLLAMA_BASE_URL` = `http://<ollama-service-name>.railway.internal:11434`
     (use the exact name of Service A)
   - `WEBUI_SECRET_KEY` = any long random string (keeps you logged in)
4. **Settings → Volumes** → add volume, mount path `/app/backend/data`
   (stores your account, chats, and uploaded documents).
5. **Settings → Networking → Public Networking** → **Generate Domain**, and
   set the target **port to `8080`** (Open WebUI listens on 8080).
6. Deploy.

> The Ollama service binds dual-stack (`[::]`) so Railway's private network
> (IPv6) reaches it automatically — no extra setup. If the UI still shows no
> models, double-check `OLLAMA_BASE_URL` uses Service A's exact name and port
> `11434`. As a last resort, give Service A a public domain and point
> `OLLAMA_BASE_URL` at that `https://...` URL — but then protect it.

## 4. First run
1. Open Service B's public URL.
2. Create the **admin account** (first user = admin).
3. Top-left model picker → select **`hack-assistant`** → start chatting.

## 5. Using the "upload / skill / connector" features (Open WebUI)
- **Chat:** normal chat with `hack-assistant`.
- **Upload / Knowledge (RAG):** left sidebar → **Workspace → Knowledge** →
  create a collection → upload PDFs, code, scan outputs. Then `#collection`
  in chat to ground answers on those files.
- **Tools:** **Workspace → Tools** → add Python tool functions the model can
  call (e.g. a helper that parses nmap XML). Enable per-chat.
- **Connections:** **Settings → Connections** → add other OpenAI-compatible
  endpoints (e.g. a second Ollama, or a hosted API) alongside your model.
- **Functions/Pipelines:** **Workspace → Functions** → filters and pipelines
  for custom request/response logic.

## 6. Cost & scaling
- Two always-on services + two volumes = steady monthly usage; watch the
  Railway metrics. Scale Service A's memory up if 7B OOMs.
- CPU inference stays slow no matter what — this is a convenience/access
  setup, not a performance one.

## 7. Faster alternative (recommended if you have a GPU PC)
Run **Ollama locally on your GPU** and deploy **only Open WebUI** to Railway:
- Skip Service A.
- Expose your local Ollama with a tunnel (Cloudflare Tunnel / Tailscale).
- Set Service B's `OLLAMA_BASE_URL` to the tunnel URL.
You get the hosted chat UI + uploads + tools, with **GPU speed** and the
freedom to run the 27B. Best of both.
