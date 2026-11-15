#!/usr/bin/env bash
#
# Railway entrypoint: start Ollama, then pull the model and build the
# hack-assistant alias once (skipped if the volume already has it).
#
# Binds to [::] (dual-stack) so Railway PRIVATE networking — which resolves
# <service>.railway.internal over IPv6 — can reach it from the Open WebUI
# service. CPU-only on Railway; first boot downloads the model.

set -euo pipefail

PORT="${PORT:-11434}"
# Server listens on all IPv6 + IPv4 (dual-stack) so both the public proxy
# and private networking can reach it.
export OLLAMA_HOST="[::]:${PORT}"
# Client/healthcheck talk over loopback by name.
CLIENT="localhost:${PORT}"

MODEL="${BASE_MODEL:-hf.co/bartowski/WhiteRabbitNeo-7B-v1.5a-GGUF:Q4_K_M}"
ALIAS="hack-assistant"

echo "[*] Starting ollama serve on ${OLLAMA_HOST} ..."
ollama serve &
SERVER_PID=$!

echo "[*] Waiting for Ollama API ..."
for _ in $(seq 1 60); do
  if curl -fsS "http://${CLIENT}/api/version" >/dev/null 2>&1; then break; fi
  sleep 2
done
curl -fsS "http://${CLIENT}/api/version" >/dev/null 2>&1 \
  || { echo "[x] Ollama did not start"; exit 1; }
echo "[+] Ollama API is up."

if OLLAMA_HOST="$CLIENT" ollama list 2>/dev/null | awk '{print $1}' | grep -q "^${ALIAS}"; then
  echo "[+] '${ALIAS}' already present (volume cache). Skipping build."
else
  echo "[*] Pulling base model: ${MODEL} (first boot only) ..."
  OLLAMA_HOST="$CLIENT" ollama pull "$MODEL"
  echo "[*] Building '${ALIAS}' from Modelfile ..."
  sed "s|^FROM .*|FROM ${MODEL}|" /root/Modelfile > /tmp/Modelfile
  OLLAMA_HOST="$CLIENT" ollama create "$ALIAS" -f /tmp/Modelfile
  echo "[+] '${ALIAS}' ready."
fi

echo "[+] Serving model '${ALIAS}' on port ${PORT}."
# Keep the container alive on the server process.
wait "$SERVER_PID"
