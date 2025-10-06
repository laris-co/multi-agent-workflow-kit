#!/bin/bash
# Setup script: Creates all agents and installs tmux plugins
# Usage: .agents/scripts/setup.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AGENT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$AGENT_ROOT/.." && pwd)
AGENTS_YAML="$AGENT_ROOT/agents.yaml"
TMUX_CONF_PATH="${TMUX_CONF:-$AGENT_ROOT/config/tmux.conf}"
TPM_DIR="$HOME/.tmux/plugins/tpm"

# ========================================
# Check direnv
# ========================================
echo "🔧 Checking direnv..."
if ! command -v direnv &> /dev/null; then
echo "⚠️  direnv not found. Install it for automatic tmux config loading:"
    echo "   brew install direnv  # or your package manager"
    echo ""
else
    echo "✅ direnv installed"
    if [ -f "$REPO_ROOT/.envrc" ]; then
        echo "💡 Run 'direnv allow' to enable project config auto-loading"
        echo "   Tip: also run 'direnv allow agents/*' so each agent worktree trusts the env."
    fi
fi
echo ""

# ========================================
# Install TPM and tmux-power if needed
# ========================================
echo "🎨 Checking tmux plugin manager (TPM)..."
if [ ! -d "$TPM_DIR" ]; then
    echo "📥 Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    echo "✅ TPM installed"
else
    echo "✅ TPM already installed"
fi

# Install plugins (reads from local tmux config via TMUX_CONF env var)
echo "📦 Installing tmux plugins (including tmux-power)..."
if [ -f "$TMUX_CONF_PATH" ]; then
    tmux start-server 2>/dev/null || true
    tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.tmux/plugins/" 2>/dev/null || true
    tmux source-file "$TMUX_CONF_PATH" 2>/dev/null || true
    TMUX_CONF="$TMUX_CONF_PATH" "$TPM_DIR/bin/install_plugins" 2>/dev/null || echo "⚠️  Plugin installation skipped (will auto-install in tmux session)"
    echo "✅ Tmux plugins configured"
else
    echo "⚠️  Tmux config not found at $TMUX_CONF_PATH"
    echo "    Create one in .agents/config/tmux.conf or set TMUX_CONF to a custom path before retrying."
fi
echo ""

# ========================================
# Sync shared prompts for Codex CLI (optional)
# ========================================
CLAUDE_PROMPTS_DIR="$REPO_ROOT/.claude/commands"
CODEX_PROMPTS_DIR="$REPO_ROOT/.codex/prompts"

if [ -d "$CLAUDE_PROMPTS_DIR" ]; then
    mkdir -p "$CODEX_PROMPTS_DIR"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --include '*/' --include '*.md' --exclude '*' "$CLAUDE_PROMPTS_DIR/" "$CODEX_PROMPTS_DIR/" >/dev/null
    else
        find "$CLAUDE_PROMPTS_DIR" -maxdepth 1 -name '*.md' -exec cp "{}" "$CODEX_PROMPTS_DIR/" \;
    fi
    echo "📄 Updated Codex prompt templates in .codex/prompts/ (mirrors .claude/commands)."
    if [ -z "${CODEX_HOME:-}" ]; then
        echo "   Export CODEX_HOME=$REPO_ROOT/.codex or allow .envrc to set it automatically."
    fi
    echo ""
fi

# ========================================
# Clean up stale worktrees
# ========================================
echo "🧹 Cleaning up stale worktrees..."
git -C "$REPO_ROOT" worktree prune -v
echo ""

# ========================================
# Create agent worktrees
# ========================================
if [ ! -f "$AGENTS_YAML" ]; then
    echo "❌ Error: $AGENTS_YAML not found"
    exit 1
fi

echo "🚀 Setting up all agents from agents.yaml..."
echo ""

# Get list of all agent names
AGENTS=$(yq e '.agents | keys | .[]' "$AGENTS_YAML")

if [ -z "$AGENTS" ]; then
    echo "❌ No agents found in agents.yaml"
    exit 1
fi

# Create each agent
for agent in $AGENTS; do
    echo "📦 Creating agent: $agent"
    "$SCRIPT_DIR/agents.sh" create "$agent"
done

echo ""
echo "✅ All agents created successfully!"
echo ""
echo "📋 Current worktrees:"
"$SCRIPT_DIR/agents.sh" list
echo ""
echo "💡 Tip: Restart tmux or run 'tmux source-file .agents/config/tmux.conf' to load plugins"
