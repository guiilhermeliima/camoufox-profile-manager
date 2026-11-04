
# ==========================================
# CAMOUFOX PROFILE MANAGER
# Multi-stage Docker build
# ARM64 / AMD64
# ==========================================


# ==========================================
# STAGE 1: BUILD WEB UI
# ==========================================

FROM node:20-slim AS webui

WORKDIR /web

COPY web/package.json web/package-lock.json ./

RUN npm ci

COPY web/ ./

ENV NEXT_EXPORT=1

RUN npm run build


# ==========================================
# STAGE 2: PYTHON APPLICATION
# ==========================================

FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive

# ==========================================
# SYSTEM DEPENDENCIES
# ==========================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    make \
    libzstd-dev \
    zlib1g-dev \
    libgtk-3-0 \
    libdbus-glib-1-2 \
    libxt6 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libnss3 \
    libxss1 \
    libpango-1.0-0 \
    libcairo2 \
    libfontconfig1 \
    libfreetype6 \
    libasound2 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libatspi2.0-0 \
    libxkbcommon0 \
    libwayland-client0 \
    libwayland-egl1 \
    libegl1 \
    libgl1 \
    xvfb \
    xauth \
    curl \
    ca-certificates \
    fonts-liberation \
    && test -f /usr/include/zstd.h \
    && rm -rf /var/lib/apt/lists/*


# ==========================================
# INSTALL UV
# ==========================================

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app


# ==========================================
# PYTHON APPLICATION
# ==========================================

COPY pyproject.toml uv.lock README.md ./

COPY src ./src

RUN uv sync --no-dev --frozen


# ==========================================
# COPY WEB UI
# ==========================================

COPY --from=webui /web/out ./src/camoufox_pm/webui


# ==========================================
# RUNTIME CONFIGURATION
# ==========================================

ENV CPM_HOST=0.0.0.0 \
    CPM_PORT=8000 \
    CPM_DB_PATH=/data/profiles.db \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DISPLAY=:99

VOLUME ["/data"]

EXPOSE 8000


# ==========================================
# STARTUP SCRIPT
# ==========================================

RUN printf '%s\n' \
    '#!/bin/sh' \
    'set -eu' \
    'cd /app' \
    'echo "[CPM] Verificando dependencias..."' \
    'command -v Xvfb >/dev/null 2>&1 || { echo "[CPM] ERRO: Xvfb nao encontrado"; exit 1; }' \
    'command -v uv >/dev/null 2>&1 || { echo "[CPM] ERRO: uv nao encontrado"; exit 1; }' \
    'mkdir -p /data' \
    'test -w /data || { echo "[CPM] ERRO: /data sem permissao de escrita"; exit 1; }' \
    'echo "[CPM] Iniciando servidor grafico virtual..."' \
    'Xvfb :99 -screen 0 1920x1080x24 -ac +extension RANDR -nolisten tcp &' \
    'XVFB_PID=$!' \
    'sleep 1' \
    'if ! kill -0 "$XVFB_PID" 2>/dev/null; then echo "[CPM] ERRO: Xvfb nao iniciou"; exit 1; fi' \
    'echo "[CPM] Xvfb iniciado com DISPLAY=$DISPLAY"' \
    'echo "[CPM] Iniciando Camoufox Profile Manager..."' \
    'exec uv run --no-sync camoufox-pm --host "${CPM_HOST}" --port "${CPM_PORT}" --no-browser' \
    > /usr/local/bin/start-cpm.sh \
    && chmod +x /usr/local/bin/start-cpm.sh


# ==========================================
# CONTAINER ENTRYPOINT
# ==========================================

ENTRYPOINT ["/usr/local/bin/start-cpm.sh"]
