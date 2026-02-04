#!/bin/sh
# Copy cached models to writable config dir
cp /openrouter_models.json /home/app/.config/io.datasette.llm/ 2>/dev/null || true

# Read stdin if available (non-blocking check)
input=""
if [ ! -t 0 ]; then
    input=$(cat)
fi

# Check for /new or /clear command in args or stdin
is_new_cmd=0
for arg in "$@"; do
    if [ "$arg" = "/new" ] || [ "$arg" = "/clear" ]; then
        is_new_cmd=1
        break
    fi
done
# Trim trailing whitespace/newlines for comparison
input_trimmed=$(printf '%s' "$input" | tr -d '\n\r ')
if [ "$input_trimmed" = "/new" ] || [ "$input_trimmed" = "/clear" ]; then
    is_new_cmd=1
    input=""
fi

if [ $is_new_cmd -eq 1 ]; then
    # Find the database path from args
    db_path=""
    next_is_db=0
    for a in "$@"; do
        if [ $next_is_db -eq 1 ]; then
            db_path="$a"
            break
        fi
        if [ "$a" = "-d" ] || [ "$a" = "--database" ]; then
            next_is_db=1
        fi
    done
    
    if [ -n "$db_path" ]; then
        # Find the model from args
        model=""
        next_is_model=0
        for a in "$@"; do
            if [ $next_is_model -eq 1 ]; then
                model="$a"
                break
            fi
            if [ "$a" = "-m" ] || [ "$a" = "--model" ]; then
                next_is_model=1
            fi
        done
        
        python3 -c "
import sqlite_utils
import ulid
import sys

db = sqlite_utils.Database(sys.argv[1])
db['conversations'].insert({
    'id': str(ulid.ULID()).lower(),
    'name': 'New conversation',
    'model': sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
})
" "$db_path" "$model"
        
        echo "Starting new conversation."
        exit 0
    fi
fi

# Pass through to llm
if [ -n "$input" ]; then
    echo "$input" | exec llm "$@"
else
    exec llm "$@"
fi
