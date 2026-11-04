
# One image, one process: FastAPI serves the REST API and the built web UI.
# The UI is built in the first stage and copied into the runtime image.

FROM node:20-slim AS webui

WORKDIR /web

COPY web/package.json web/package-lock.json ./
RUN npm ci

COPY web/ ./

ENV NEXT_EXPORT=1
RUN npm run build


FROM python:3.12-slim

# System dependencies required to compile Python packages on ARM64.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    make \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# uv for fast, reproducible installs.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Install dependencies first (better layer caching).
COPY pyproject.toml uv.lock README.md ./
COPY src ./src

# Install Python dependencies.
RUN uv sync --no-dev --frozen

# Copy the static web interface.
COPY --from=webui /web/out ./src/camoufox_pm/webui

ENV CPM_HOST=0.0.0.0 \
    CPM_PORT=8000 \
    CPM_DB_PATH=/data/profiles.db

VOLUME ["/data"]

EXPOSE 8000

# Start the API and web interface.
CMD ["uv", "run", "camoufox-pm", "--host", "0.0.0.0", "--port", "8000", "--no-browser"]
