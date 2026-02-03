# llm-sandbox

A Docker-based sandbox template for running [llm](https://llm.datasette.io/) with OpenRouter support. Designed to be customized for your specific use case.

**This is a template** - fork it and adapt the Dockerfile, entrypoint, and configuration for your needs.

> **Note**: This is not designed for high-performance, high-security, or enterprise production use. It's intended for power users who want convenient control over their LLM sandboxes.

This project follows the **Unix philosophy**: small tools that do one job well, using standardized POSIX-friendly interfaces (stdio, command-line arguments, environment variables, exit codes). This makes it easy to compose with other tools using pipes, scripts, and standard shell patterns.

## Features

- **Sandboxed execution**: Read-only root filesystem, runs as non-root user
- **MCP tooling**: Model Context Protocol support pre-installed
- **Flexible data mounting**:
  - `/sysdata`: System prompts, scripts, and configuration
  - `/userdata`: User-specific data, conversation logs, outputs (the only writable location)
- **OpenRouter integration**: Access hundreds of models through a single API

## Container Filesystem

The LLM can read everything in the container, but can only write to `/userdata`:

| Path | Access | Persists | Purpose |
|------|--------|----------|--------|
| `/sysdata` | read-only | n/a | System prompts, Python scripts, configuration |
| `/userdata` | read-write | **yes** | Conversation logs, outputs, user data |
| `/tmp` | read-write | no | Temporary files (tmpfs, cleared on exit) |
| Everything else | read-only | n/a | System files, installed packages |

## Quick Start

1. Copy the example environment file and add your API key:

```bash
cp .env.example .env
# Edit .env with your API key(s)
```

2. Run a prompt:

```bash
./llm-sandbox -m openrouter/openrouter/auto "Your prompt here"
```

The Docker image will be built automatically on first run.

## Configuration

Create a `.env` file in the same directory as `llm-sandbox` with your API keys:

```bash
# OpenRouter (https://openrouter.ai/keys)
OPENROUTER_KEY=your-openrouter-api-key

# OpenAI (optional)
OPENAI_API_KEY=your-openai-api-key

# Anthropic (optional)
ANTHROPIC_API_KEY=your-anthropic-api-key
```

## Usage Examples

### Basic prompt

```bash
./llm-sandbox -m openrouter/openrouter/auto "Explain quantum computing briefly"
```

### Pipe input via stdin

```bash
# Prompt from stdin
echo "What is the capital of France?" | ./llm-sandbox -m openrouter/openrouter/auto

# File contents as prompt
./llm-sandbox -m openrouter/openrouter/auto < question.txt

# Provide context via stdin with an instruction as argument
cat document.txt | ./llm-sandbox -m openrouter/openrouter/auto "Summarize this"

# Here-doc for multi-line prompts
./llm-sandbox -m openrouter/openrouter/auto << 'EOF'
Write a haiku about:
- programming
- coffee
- late nights
EOF
```

### List available models

```bash
./llm-sandbox models
./llm-sandbox openrouter models
```

### Using system data

Provide system prompts, Python scripts, or other context via `/sysdata`:

```bash
# Create a directory with your system data
mkdir -p ./system
cat > ./system/prompt.txt << 'EOF'
You are a helpful coding assistant. Always provide clear explanations
and include example usage for any code you write.
EOF

# Mount and use with -f (fragment) flag to include file contents
SANDBOX_SYSDATA=./system ./llm-sandbox -m openrouter/openrouter/auto \
  -f /sysdata/prompt.txt "Help me write a Python function to parse JSON"
```

### Custom tools via Python functions

Define tools as Python functions in `/sysdata` and reference them with `--functions`:

```bash
# Create a tool that fetches weather data
mkdir -p ./system
cat > ./system/tools.py << 'EOF'
import json

def get_weather(location: str) -> str:
    """Get the current weather for a location.
    
    Args:
        location: City name or zip code
    """
    # In a real implementation, this would call a weather API
    return json.dumps({
        "location": location,
        "temperature": "72°F",
        "condition": "Sunny"
    })

def calculate(expression: str) -> str:
    """Evaluate a mathematical expression.
    
    Args:
        expression: A mathematical expression like '2 + 2' or 'sqrt(16)'
    """
    import math
    allowed = {"__builtins__": {}, "math": math, "sqrt": math.sqrt, "pow": pow, "abs": abs}
    return str(eval(expression, allowed))
EOF

# Use the tools
SANDBOX_SYSDATA=./system ./llm-sandbox -m openrouter/openrouter/auto \
  --functions /sysdata/tools.py \
  "What's the weather in Seattle and what's the square root of 144?"
```

### Using user data (read-write)

Store conversation logs and user-specific data:

```bash
# Start a conversation
echo "My name is Alice" | SANDBOX_USERDATA=./alice ./llm-sandbox \
  -m openrouter/openrouter/auto -d /userdata/log.db

# Continue the conversation (uses -c flag)
echo "What is my name?" | SANDBOX_USERDATA=./alice ./llm-sandbox \
  -m openrouter/openrouter/auto -d /userdata/log.db -c
# Output: Your name is Alice.
```

### Multiple users/sessions

```bash
# User 1
SANDBOX_USERDATA=./user1 ./llm-sandbox -m openrouter/openrouter/auto \
  -d /userdata/log.db "Hello, I'm Bob"

# User 2 (separate conversation history)
SANDBOX_USERDATA=./user2 ./llm-sandbox -m openrouter/openrouter/auto \
  -d /userdata/log.db "Hello, I'm Carol"
```

### Combining system and user data

```bash
SANDBOX_SYSDATA=./system SANDBOX_USERDATA=./user1 ./llm-sandbox \
  -m openrouter/openrouter/auto -d /userdata/log.db \
  -s "$(cat ./system/prompt.txt)" "Your prompt here"
```

## Environment Variables

### Host environment (set in your shell)

| Variable | Description |
|----------|-------------|
| `SANDBOX_USERDATA` | Host path to bind-mount as `/userdata` (read-write) inside the container |
| `SANDBOX_SYSDATA` | Host path to bind-mount as `/sysdata` (read-only) inside the container |

### Container environment (set in `.env` file)

API keys and other variables passed to the container are read from `.env` file (see Configuration above).

## Customization

This template is meant to be customized. Common modifications:

### Adding Python scripts

Place Python scripts in your sysdata directory and reference them from the container:

```bash
# ./system/analyze.py
SANDBOX_SYSDATA=./system ./llm-sandbox ... 
# Script available at /sysdata/analyze.py
```

### Adding more LLM plugins

Edit the Dockerfile to install additional [llm plugins](https://llm.datasette.io/en/stable/plugins/directory.html):

```dockerfile
RUN pip install --no-cache-dir llm llm-openrouter llm-claude-3 llm-gemini
```

### Adding system dependencies

Install additional packages in the Dockerfile:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    curl \
    && rm -rf /var/lib/apt/lists/*
```

### Custom entrypoint logic

Modify `entrypoint.sh` to add preprocessing, environment setup, or custom commands.

## Security Features

- **Read-only root filesystem**: Container cannot modify system files
- **Non-root user**: Runs as uid/gid 1000
- **Tmpfs for /tmp**: Temporary files are memory-only with noexec,nosuid
- **Isolated config volume**: LLM config stored in named Docker volume
- **Read-only sysdata**: System configuration cannot be modified by the container

## Manual Build

To rebuild the Docker image manually:

```bash
docker build -t llm-sandbox:latest .
```

## Files

- `Dockerfile` - Container definition with llm, llm-openrouter, and mcp installed
- `entrypoint.sh` - Wrapper script that executes llm
- `llm-sandbox` - Host shell script for running the container
- `.env` - Your API keys (not tracked in git)
- `.env.example` - Example environment file

## License

ISC License - see [LICENSE](LICENSE) for details.
