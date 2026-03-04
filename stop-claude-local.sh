#!/bin/bash
# stop-claude-local.sh
# Stops vLLM + LiteLLM containers
# Usage: ./stop-claude-local.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping vLLM + LiteLLM..."
docker compose down
echo "Done ✓"