FROM python:3.12-slim
WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY pyproject.toml uv.lock* ./
RUN uv sync --frozen --no-dev

COPY src ./src
COPY scripts ./scripts

ENV PYTHONPATH=/app/src
CMD ["uv", "run", "python", "scripts/score_segments.py"]
