#!/usr/bin/env bash
#
# Railway entrypoint: start Ollama bound to $PORT, then pull the 7B model
# and build the hack-assistant alias once (skipped if the volume already
# has it). CPU-only on Railway — first boot downloads ~4.5 GB and can take
# several minutes; give the service a generous healthcheck timeout.

set -euo pipefail

PORT="${PORT:-11434}"
# Server listens on all interfaces so Railway can route to it.
export OLLAMA_HOST="0.0.0.0:${PORT}"
# Client commands connect over loopback.
CLIENT="127.0.0.1:${PORT}"

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

echo "[+] Serving. API: http://<your-railway-domain>/api  (model: ${ALIAS})"
# Keep the container alive on the server process.
wait "$SERVER_PID"
