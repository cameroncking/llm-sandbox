#!/bin/sh
# Copy cached models to writable config dir
cp /openrouter_models.json /home/app/.config/io.datasette.llm/ 2>/dev/null || true

# Read stdin if available (non-blocking check)
input=""
if [ ! -t 0 ]; then
    input=$(cat)
fi

# Pass through to llm
if [ -n "$input" ]; then
    echo "$input" | exec llm "$@"
else
    exec llm "$@"
fi
