FROM python:3.12-slim

# Install llm and plugins
RUN pip install --no-cache-dir llm llm-openrouter

# Install MCP tooling (with HTTP client dependencies)
RUN pip install --no-cache-dir mcp httpx httpx-sse

# Fetch and cache openrouter models at build time
RUN llm openrouter models > /dev/null && \
    mv /root/.config/io.datasette.llm/openrouter_models.json /openrouter_models.json

RUN mkdir -p /home/app/.config/io.datasette.llm && \
    chown -R 1000:1000 /home/app

COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENV HOME=/home/app
USER 1000:1000

ENTRYPOINT ["/entrypoint.sh"]
