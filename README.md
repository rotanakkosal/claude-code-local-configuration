# Claude Code + vLLM + Qwen3-Coder Local Setup

## Overview

Run Claude Code locally with Qwen3-Coder on your H200 GPU.
One command starts everything.

```
Claude Code (v1.0.88) → LiteLLM (:4000) → vLLM (:9000) → H200 GPU
```

---

## Files

Put all files in one folder (e.g. `~/claude-local/`):

```
~/claude-local/
├── docker-compose.yaml    # Runs vLLM + LiteLLM together
├── litellm_config.yaml    # LiteLLM routing config
├── settings.json          # Claude Code settings (copied to ~/.claude/ on start)
├── api-key-helper.sh      # API key script (copied to ~/.claude/ on start)
├── start-claude-local.sh  # One-command startup
└── stop-claude-local.sh   # One-command shutdown
```

The start script copies `settings.json` and `api-key-helper.sh` to `~/.claude/` automatically.

---

## One-Time Setup

### 1. Install Claude Code v1.0.88

```bash
npm install -g @anthropic-ai/claude-code@1.0.88
hash -r
claude --version  # Should show 1.0.88
```

### 2. Copy all files to ~/claude-local/

```bash
mkdir -p ~/claude-local
# Copy all 6 files into ~/claude-local/
chmod +x ~/claude-local/start-claude-local.sh
chmod +x ~/claude-local/stop-claude-local.sh
```

---

## Daily Usage

### Start everything:
```bash
cd ~/claude-local
./start-claude-local.sh
```

This will:
1. Write ~/.claude/settings.json automatically
2. Start vLLM container (loads model, ~2-5 min first time)
3. Start LiteLLM container (waits for vLLM health check)
4. Test the connection
5. Launch Claude Code

### Stop everything:
```bash
cd ~/claude-local
./stop-claude-local.sh
```

### View logs:
```bash
cd ~/claude-local
docker compose logs -f vllm     # vLLM logs
docker compose logs -f litellm  # LiteLLM logs
docker compose logs -f          # Both
```

---

## Key Details

| Component | Port | Role |
|-----------|------|------|
| vLLM | 9000 | Serves Qwen3-Coder, handles tool calling |
| LiteLLM | 4000 | Translates Anthropic API → OpenAI API |
| Claude Code | — | CLI client, talks to LiteLLM |

### Why each piece matters:
- **vLLM** runs the model on GPU with `--tool-call-parser qwen3_coder`
- **LiteLLM** is needed because Claude Code speaks Anthropic format, vLLM speaks OpenAI format
- **Claude Code v1.0.88** uses `/v1/messages` (v2.x uses `/v1/responses` which vLLM can't handle)

---

## Performance Tuning

After confirming everything works, edit `docker-compose.yaml` to increase context:

```yaml
# Change these in the vllm command section:
- --gpu-memory-utilization
- "0.50"        # was 0.35 — gives more KV cache
- --max-model-len
- "102400"      # was 51200 — enables 100K context
```

Then restart: `docker compose down && docker compose up -d`

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| vLLM won't start | Check `docker compose logs vllm` for CUDA errors |
| LiteLLM won't start | It waits for vLLM health — give it 5 min |
| Claude Code can't connect | Verify: `curl http://localhost:4000/health` |
| Tool calls show as raw text | Ensure `--tool-call-parser qwen3_coder` in docker-compose |
| 400 errors on 2nd message | Claude Code version too new — must be v1.0.88 |

---

## 🚀 Remote Access (aiclab Users)

If you want to connect to the aiclab server remotely (without running your own GPU):

### 1. Install Claude Code v1.0.88

```bash
npm install -g @anthropic-ai/claude-code@1.0.88
```

### 2. Create `~/.claude/settings.json`

Get the `TUNNEL_URL` and `USER_API_KEY` from the server admin.

**Linux/Mac:**
```bash
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "<TUNNEL_URL>",
    "ANTHROPIC_API_KEY": "<USER_API_KEY>",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-6"
  }
}
EOF
```

**Windows (PowerShell):**
```powershell
mkdir -Force "$env:USERPROFILE\.claude"
@'
{
  "env": {
    "ANTHROPIC_BASE_URL": "<TUNNEL_URL>",
    "ANTHROPIC_API_KEY": "<USER_API_KEY>",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-6"
  }
}
'@ | Out-File -Encoding UTF8 "$env:USERPROFILE\.claude\settings.json"
```

### 3. Run Claude Code

```bash
claude
```

### Troubleshooting Remote Access

If you get "Invalid API key" error:
1. Open `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows)
2. Find `"customApiKeyResponses"` section
3. Change it to:
```json
"customApiKeyResponses": {
  "approved": ["<USER_API_KEY>"],
  "rejected": []
}
```
4. Save and restart `claude`

---

**Powered by aiclab** 🚀