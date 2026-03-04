#!/bin/bash
# start-claude-local.sh
# Starts vLLM + LiteLLM + Claude Code in one command
# Usage: ./start-claude-local.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Local Claude Code Startup ===${NC}"
echo ""

# ── Step 0: Load environment variables ──
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
    echo -e "${GREEN}Loaded .env file${NC}"
else
    echo -e "${RED}Error: .env file not found. Copy .env.example to .env and fill in your values.${NC}"
    exit 1
fi

# ── Step 1: Check prerequisites ──
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker not found. Install Docker first.${NC}"
    exit 1
fi

if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: claude not found. Run: npm install -g @anthropic-ai/claude-code@1.0.88${NC}"
    exit 1
fi

CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1)
echo "  Claude Code: $CLAUDE_VERSION"

# ── Step 2: Ensure config files exist ──
echo -e "${YELLOW}[2/5] Setting up config files...${NC}"

# Claude Code settings (uses env var from .env)
mkdir -p ~/.claude
cat > ~/.claude/settings.json << SETTINGS
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000",
    "ANTHROPIC_API_KEY": "${LITELLM_MASTER_KEY}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-6"
  }
}
SETTINGS

# API key helper (uses env var from .env)
cat > ~/.claude/api-key-helper.sh << APIKEY
#!/bin/bash
echo "${LITELLM_MASTER_KEY}"
APIKEY
chmod +x ~/.claude/api-key-helper.sh

echo "  ~/.claude/settings.json ✓"
echo "  ~/.claude/api-key-helper.sh ✓"

# ── Step 3: Stop existing containers ──
echo -e "${YELLOW}[3/5] Stopping existing containers...${NC}"
cd "$SCRIPT_DIR"
docker compose down 2>/dev/null || true
echo "  Cleaned up ✓"

# ── Step 4: Start vLLM + LiteLLM ──
echo -e "${YELLOW}[4/5] Starting vLLM + LiteLLM...${NC}"
echo "  This will take 2-5 minutes (model loading + warmup)"
echo ""
docker compose up -d

# Wait for vLLM health
echo ""
echo -n "  Waiting for vLLM to be ready"
for i in $(seq 1 60); do
    if curl -sf http://localhost:9000/health > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 5
done

# Wait for LiteLLM
echo -n "  Waiting for LiteLLM to be ready"
for i in $(seq 1 30); do
    if curl -sf http://localhost:4000/health > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 3
done

# Quick test
echo ""
echo -e "${YELLOW}[5/5] Testing connection...${NC}"
RESPONSE=$(curl -s http://localhost:4000/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${LITELLM_MASTER_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 20,
    "stream": false,
    "messages": [{"role": "user", "content": "Say ok"}]
  }' 2>/dev/null | head -c 200)

if echo "$RESPONSE" | grep -q "content"; then
    echo -e "  LiteLLM → vLLM: ${GREEN}Working ✓${NC}"
else
    echo -e "  LiteLLM → vLLM: ${YELLOW}May still be warming up, try in a minute${NC}"
fi

# ── Launch Claude Code ──
echo ""
echo -e "${GREEN}=== Ready! Launching Claude Code ===${NC}"
echo ""
claude