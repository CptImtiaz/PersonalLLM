#!/usr/bin/env bash
#
# launch-agent.sh — verify the stack and start a front-end.
#
#   ./scripts/launch-agent.sh --interpreter   # Open Interpreter CLI
#   ./scripts/launch-agent.sh --cline         # Cline setup (see note)
#
# Authorized lab / CTF use only.

set -euo pipefail

if [[ -t 1 ]]; then
  GRN=$'\033[0;32m'; YLW=$'\033[0;33m'; RED=$'\033[0;31m'
  BLU=$'\033[0;34m'; BLD=$'\033[1m'; RST=$'\033[0m'
else
  GRN=""; YLW=""; RED=""; BLU=""; BLD=""; RST=""
fi
info() { echo "${BLU}${BLD}[*]${RST} $*"; }
ok()   { echo "${GRN}${BLD}[+]${RST} $*"; }
warn() { echo "${YLW}${BLD}[!]${RST} $*"; }
die()  { echo "${RED}${BLD}[x]${RST} $*" >&2; exit 1; }

ALIAS="hack-assistant"
OLLAMA_URL="http://localhost:11434"

FRONTEND=""
for arg in "$@"; do
  case "$arg" in
    --interpreter) FRONTEND="interpreter" ;;
    --cline)       FRONTEND="cline" ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown flag: $arg (use --interpreter or --cline)" ;;
  esac
done
[[ -n "$FRONTEND" ]] || die "Pick a front-end: --interpreter or --cline"

# ---------- ensure the Ollama daemon is running ----------
ensure_daemon() {
  if curl -fsS "${OLLAMA_URL}/api/version" >/dev/null 2>&1; then
    ok "Ollama daemon already running."
    return
  fi
  # Prefer a managed service if present.
  if command -v systemctl >/dev/null 2>&1 && \
     systemctl list-unit-files 2>/dev/null | grep -q '^ollama.service'; then
    info "Starting ollama.service via systemd..."
    sudo systemctl start ollama || true
  fi
  if ! curl -fsS "${OLLAMA_URL}/api/version" >/dev/null 2>&1; then
    info "Starting 'ollama serve' in the background..."
    ollama serve >/tmp/ollama.log 2>&1 &
  fi
  for _ in $(seq 1 30); do
    curl -fsS "${OLLAMA_URL}/api/version" >/dev/null 2>&1 && break
    sleep 1
  done
  curl -fsS "${OLLAMA_URL}/api/version" >/dev/null 2>&1 \
    || die "Ollama daemon failed to start (see /tmp/ollama.log)."
  ok "Ollama daemon is up."
}

# ---------- ensure the model alias exists ----------
ensure_model() {
  if ollama list 2>/dev/null | awk '{print $1}' | grep -q "^${ALIAS}\b"; then
    ok "Model '${ALIAS}' is available."
  else
    die "Model '${ALIAS}' not found. Run ./install.sh first."
  fi
}

ensure_daemon
ensure_model

case "$FRONTEND" in
  interpreter)
    command -v interpreter >/dev/null 2>&1 \
      || die "'interpreter' not installed. Run ./install.sh."
    info "Launching Open Interpreter against ${ALIAS}..."
    exec interpreter --model "ollama/${ALIAS}" --api_base "${OLLAMA_URL}"
    ;;
  cline)
    # NOTE: Cline is primarily a VS Code / JetBrains extension, not an
    # Ollama subcommand. There is no stable `ollama launch cline`. If a
    # `cline` CLI is on PATH we try it; otherwise we print the setup the
    # extension needs to talk to this local model.
    if command -v cline >/dev/null 2>&1; then
      info "Launching cline CLI against ${ALIAS}..."
      exec cline --model "${ALIAS}"
    fi
    cat <<EOF
${YLW}${BLD}Cline runs as an IDE extension.${RST} To point it at this model:

  1. Install the "Cline" extension in VS Code.
  2. Open Cline settings -> API Provider: ${BLD}Ollama${RST}
  3. Base URL:   ${OLLAMA_URL}
  4. Model ID:   ${ALIAS}

The Ollama daemon is already running, so Cline will detect it.
EOF
    ;;
esac
