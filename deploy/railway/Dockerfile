# Railway image: Ollama server that self-provisions the hack-assistant
# 7B model on first boot. CPU-only inference (Railway has no GPU) — expect
# a few tokens/sec. Build context is the REPO ROOT so we can COPY Modelfile.
#
#   Railway build settings:
#     Builder:        Dockerfile
#     Dockerfile path: deploy/railway/Dockerfile
#   Attach a Volume mounted at /root/.ollama so the model persists
#   across deploys (otherwise it re-downloads ~4.5 GB every time).

FROM ollama/ollama:latest

# curl is needed by the entrypoint healthcheck loop.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY Modelfile /root/Modelfile
COPY deploy/railway/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Ollama stores models here; mount a Railway volume at this path.
ENV OLLAMA_MODELS=/root/.ollama

# The base image sets ENTRYPOINT ["ollama"]; override it with our script.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
