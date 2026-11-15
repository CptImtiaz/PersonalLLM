#!/usr/bin/env bash
#
# install.sh — set up a local, private offensive-security study
# assistant powered by Ollama + Open Interpreter.
#
# What it does:
#   1. Detects OS, GPU/VRAM (NVIDIA or Apple Silicon) and system RAM.
#   2. Recommends and pulls a model tier via Ollama.
#   3. Installs Ollama if missing.
#   4. Builds a custom `hack-assistant` alias from ./Modelfile.
#   5. Installs open-interpreter and writes its config.
#
# Authorized lab / CTF use only. See README.md.

set -euo pipefail

# ---------- colored status helpers ----------
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[0;33m'
  BLU=$'\033[0;34m'; BLD=$'\033[1m'; RST=$'\033[0m'
else
  RED=""; GRN=""; YLW=""; BLU=""; BLD=""; RST=""
fi
info()  { echo "${BLU}${BLD}[*]${RST} $*"; }
ok()    { echo "${GRN}${BLD}[+]${RST} $*"; }
warn()  { echo "${YLW}${BLD}[!]${RST} $*"; }
err()   { echo "${RED}${BLD}[x]${RST} $*" >&2; }
die()   { err "$*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELFILE="${SCRIPT_DIR}/Modelfile"
ALIAS="hack-assistant"

# ---------- model tiers ----------
MODEL_HIGH="hf.co/jsantillana/Qwen3.8-27B-abliterated-GGUF:Q4_K_M"
MODEL_MED="hf.co/jmainformatique/WhiteRabbitNeo-13B-v1-Q4_K_M-GGUF:Q4_K_M"
MODEL_LOW="hf.co/bartowski/WhiteRabbitNeo-7B-v1.5a-GGUF:Q4_K_M"

# ---------- 1. detect hardware ----------
OS="$(uname -s)"
VRAM_MB=0
RAM_MB=0
GPU_DESC="none"

detect_hardware() {
  info "Detecting hardware..."

  # System RAM
  if [[ "$OS" == "Darwin" ]]; then
    RAM_MB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 ))
  elif [[ -r /proc/meminfo ]]; then
    RAM_MB=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 1024 ))
  fi

  # GPU / VRAM
  if command -v nvidia-smi >/dev/null 2>&1; then
    # Largest single GPU's total memory, in MiB.
    VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits \
                | sort -nr | head -1 | tr -d '[:space:]' || echo 0)
    GPU_DESC="NVIDIA ($(nvidia-smi --query-gpu=name --format=csv,noheader | head -1))"
  elif [[ "$OS" == "Darwin" ]] && \
       sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -qi 'Apple'; then
    # Apple Silicon: unified memory acts as VRAM. Budget ~70% of RAM.
    VRAM_MB=$(( RAM_MB * 70 / 100 ))
    GPU_DESC="Apple Silicon (unified memory)"
  else
    warn "No supported GPU found. CPU inference only — expect slow tokens."
    VRAM_MB=0
  fi

  ok "OS:   ${OS}"
  ok "RAM:  ${RAM_MB} MB"
  ok "GPU:  ${GPU_DESC}"
  ok "VRAM budget: ${VRAM_MB} MB"
}

# ---------- 2. pick tier ----------
pick_model() {
  local vram_gb=$(( VRAM_MB / 1024 ))
  if (( vram_gb >= 16 )); then
    TIER="HIGH (>=16 GB)"; BASE_MODEL="$MODEL_HIGH"
  elif (( vram_gb >= 10 )); then
    TIER="MEDIUM (10-15 GB)"; BASE_MODEL="$MODEL_MED"
  else
    TIER="LOW (<10 GB)"; BASE_MODEL="$MODEL_LOW"
  fi
  info "Recommended tier: ${BLD}${TIER}${RST}"
  info "Base model:       ${BLD}${BASE_MODEL}${RST}"

  if [[ -t 0 ]]; then
    read -r -p "Proceed with this model? [Y/n] " reply
    [[ "${reply:-Y}" =~ ^[Nn] ]] && die "Aborted by user."
  fi
}

# ---------- 3. install Ollama ----------
install_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    ok "Ollama already installed: $(ollama --version 2>/dev/null | head -1)"
    return
  fi
  info "Installing Ollama..."
  if [[ "$OS" == "Darwin" ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install ollama
    else
      die "Install Homebrew or download Ollama from https://ollama.com/download"
    fi
  else
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  ok "Ollama installed."
}

ensure_ollama_running() {
  if ! curl -fsS http://localhost:11434/api/version >/dev/null 2>&1; then
    info "Starting Ollama daemon..."
    ollama serve >/tmp/ollama.log 2>&1 &
    for _ in $(seq 1 30); do
      curl -fsS http://localhost:11434/api/version >/dev/null 2>&1 && break
      sleep 1
    done
  fi
  curl -fsS http://localhost:11434/api/version >/dev/null 2>&1 \
    || die "Ollama daemon did not come up (see /tmp/ollama.log)."
  ok "Ollama daemon is up."
}

# ---------- 4. pull model + build alias ----------
pull_and_build() {
  info "Pulling base model (this can be several GB)..."
  ollama pull "$BASE_MODEL"

  info "Writing FROM line into Modelfile and creating '${ALIAS}'..."
  local tmp; tmp="$(mktemp)"
  sed "s|^FROM .*|FROM ${BASE_MODEL}|" "$MODELFILE" > "$tmp"
  ollama create "$ALIAS" -f "$tmp"
  rm -f "$tmp"
  ok "Model alias '${ALIAS}' created."
}

# ---------- 5. Open Interpreter ----------
install_open_interpreter() {
  info "Installing open-interpreter..."
  if command -v pipx >/dev/null 2>&1; then
    pipx install open-interpreter || pipx upgrade open-interpreter || true
  else
    python3 -m pip install --user --upgrade open-interpreter
  fi

  local cfg_dir="${HOME}/.openinterpreter"
  mkdir -p "$cfg_dir"
  if [[ -f "${SCRIPT_DIR}/configs/openinterpreter-config.toml" ]]; then
    cp "${SCRIPT_DIR}/configs/openinterpreter-config.toml" "${cfg_dir}/config.toml"
    ok "Open Interpreter config written to ${cfg_dir}/config.toml"
  else
    warn "configs/openinterpreter-config.toml not found; skipping config copy."
  fi
}

main() {
  echo "${BLD}=== Local Security-Lab Assistant installer ===${RST}"
  [[ -f "$MODELFILE" ]] || die "Modelfile not found next to install.sh."
  detect_hardware
  pick_model
  install_ollama
  ensure_ollama_running
  pull_and_build
  install_open_interpreter
  echo
  ok "Done. Launch with:  ./scripts/launch-agent.sh --interpreter"
  warn "Authorized lab / CTF use only."
}

main "$@"
