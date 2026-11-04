
# ==========================================
# CAMOUFOX PROFILE MANAGER
# Multi-stage Docker build
# ARM64 compatible
# ==========================================

# Stage 1: Build Web UI
FROM node:20-slim AS webui

WORKDIR /web

COPY web/package.json web/package-lock.json ./
RUN npm ci

COPY web/ ./

ENV NEXT_EXPORT=1
RUN npm run build


# Stage 2: Python application
FROM python:3.12-slim

# Install compiler and development libraries.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libzstd-dev \
    zlib1g-dev \
    curl \
    ca-certificates \
    && test -f /usr/include/zstd.h \
    && rm -rf /var/lib/apt/lists/*

# Install uv.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Copy Python project files.
COPY pyproject.toml uv.lock README.md ./
COPY src ./src

# Install Python dependencies.
RUN uv sync --no-dev --frozen

# Copy the built Web UI.
COPY --from=webui /web/out ./src/camoufox_pm/webui

# Application environment.
ENV CPM_HOST=0.0.0.0 \
    CPM_PORT=8000 \
    CPM_DB_PATH=/data/profiles.db

VOLUME ["/data"]

EXPOSE 8000

# Start application.
CMD ["uv", "run", "camoufox-pm", "--host", "0.0.0.0", "--port", "8000", "--no-browser"]
