# hack-assistant — Local Private Security-Lab Assistant

A fully local, offline AI assistant for **authorized** penetration-testing
practice, CTF solving, and reverse engineering. Runs entirely on your own
machine with [Ollama](https://ollama.com) as the model backend and
[Open Interpreter](https://openinterpreter.com) (or Cline) as the agent
front-end. No data leaves your box.

> ⚠️ **Authorized lab use only.** This project is for learning on systems
> you own or have **explicit written permission** to test (home lab, CTF
> platforms, deliberately vulnerable VMs). Using it against systems you do
> not control is illegal. You are solely responsible for how you use it.

---

## Architecture

```
            ┌──────────────────────────────────────────────┐
            │                 Your machine                 │
            │                                              │
   you ───► │  Open Interpreter / Cline  ──►  Ollama API   │
            │   (agent + code runner)        :11434        │
            │          │                        │          │
            │          │                        ▼          │
            │          │              ┌──────────────────┐ │
            │          │              │  hack-assistant  │ │
            │          │              │  (GGUF model)    │ │
            │          ▼              └──────────────────┘ │
            │   local shell / python                       │
            │   (nmap, gdb, pwntools, Ghidra output ...)   │
            └──────────────────────────────────────────────┘
                     100% local · no cloud calls
```

## Hardware / VRAM requirements

| Tier   | VRAM / unified mem | System RAM | Model pulled (auto)                    |
|--------|--------------------|------------|-----------------------------------------|
| High   | ≥ 16 GB            | ≥ 32 GB    | `huihui_ai/Qwen3.8-abliterated` (27B)   |
| Medium | 10 – 15 GB         | ≥ 16 GB    | `huihui_ai/qwen3-abliterated:14b`       |
| Low    | < 10 GB            | ≥ 8 GB     | `huihui_ai/qwen3-abliterated:8b-v2`     |

All tiers are **huihui_ai abliterated (uncensored) Qwen3** models — proper
Ollama packages that ship their own ChatML template (so no format issues).
The 8B tier is also what the Railway deploy uses.

`install.sh` detects your GPU (NVIDIA via `nvidia-smi`, or Apple Silicon
unified memory) and RAM, then picks the tier for you. Apple Silicon budgets
~70% of unified memory as the VRAM figure.

> **Verify model tags before running.** Hugging Face GGUF repo paths change
> and some tags may not resolve as written. If `ollama pull` 404s, open the
> model on huggingface.co, copy the current `hf.co/...:QUANT` tag, and edit
> the `MODEL_*` variables near the top of `install.sh`.

## Quick start

```bash
git clone https://github.com/<your-username>/llm.git
cd llm
chmod +x install.sh scripts/launch-agent.sh
./install.sh                       # detect HW, install Ollama, build alias
./scripts/launch-agent.sh --interpreter
```

The installer:
1. Detects hardware and recommends a tier.
2. Installs Ollama if missing and starts the daemon.
3. `ollama pull`s the tier's base model.
4. Builds a `hack-assistant` alias from `Modelfile` (16K context, temp 0.2).
5. Installs Open Interpreter and writes `~/.openinterpreter/config.toml`.

## Usage examples

**Analyze an nmap scan**
```
> I ran `nmap -sV 10.10.10.5` in my lab. Here's the output: <paste>.
  What's the likely attack surface and what should I enumerate next?
```

**Debug a Python exploit (CTF)**
```
> This pwntools script segfaults before the shell pops. Here's the
  script and the target's checksec output — walk me through the offset.
```

**Read Ghidra-decompiled C**
```
> Explain what this decompiled function does and whether the strcpy at
  line 34 is exploitable: <paste decompiled C>.
```

Code execution is gated behind a confirmation prompt (`auto_run = false`).
Keep it that way unless you are in a throwaway VM.

## Repository layout

```
llm/
├── README.md
├── install.sh
├── Modelfile
├── .gitignore
├── configs/
│   └── openinterpreter-config.toml
└── scripts/
    └── launch-agent.sh
```

## Disclaimer

This tooling is provided for lawful security education and authorized
testing only. The authors accept no liability for misuse. Confirm you have
permission before touching any target.
