#!/bin/sh
# Copy cached models to writable config dir
cp /openrouter_models.json /home/app/.config/io.datasette.llm/ 2>/dev/null || true
exec llm "$@"
