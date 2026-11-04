
# ==========================================
# CAMOUFOX PROFILE MANAGER
# Multi-stage Docker build
# ARM64 / AMD64
# ==========================================

# Stage 1: Build Web UI
FROM node:20-slim AS webui

WORKDIR /web

COPY web/package.json web/package-lock.json ./
RUN npm ci

COPY web/ ./

ENV NEXT_EXPORT=1

RUN npm run build


# ==========================================
# Stage 2: Python application
# ==========================================

FROM python:3.12-slim

# System dependencies:
# - Build tools for Python packages
# - Zstandard development headers
# - GTK and X11 libraries for Camoufox
# - Font and rendering dependencies

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
    curl \
    ca-certificates \
    fonts-liberation \
    && test -f /usr/include/zstd.h \
    && rm -rf /var/lib/apt/lists/*


# Install uv package manager.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app


# Copy Python project files.
COPY pyproject.toml uv.lock README.md ./
COPY src ./src


# Install Python dependencies.
RUN uv sync --no-dev --frozen


# Copy built Web UI.
COPY --from=webui /web/out ./src/camoufox_pm/webui


# ==========================================
# Application configuration
# ==========================================

ENV CPM_HOST=0.0.0.0 \
    CPM_PORT=8000 \
    CPM_DB_PATH=/data/profiles.db

# Persistent profile and database storage.
VOLUME ["/data"]

EXPOSE 8000


# ==========================================
# Start application
# ==========================================

CMD ["uv", "run", "camoufox-pm", "--host", "0.0.0.0", "--port", "8000", "--no-browser"]
