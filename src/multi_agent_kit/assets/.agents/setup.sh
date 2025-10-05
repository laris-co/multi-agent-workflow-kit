#!/bin/bash
# Setup script: Creates all agents and installs tmux plugins
# Usage: .agents/setup.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
AGENTS_YAML="$SCRIPT_DIR/agents.yaml"
TPM_DIR="$HOME/.tmux/plugins/tpm"

# ========================================
# Check direnv
# ========================================
echo "🔧 Checking direnv..."
if ! command -v direnv &> /dev/null; then
    echo "⚠️  direnv not found. Install it for automatic .tmux.conf loading:"
    echo "   brew install direnv  # or your package manager"
    echo ""
else
    echo "✅ direnv installed"
if [ -f "$REPO_ROOT/.envrc" ]; then
        echo "💡 Run 'direnv allow' to enable project config auto-loading"
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

# Install plugins (reads from local .tmux.conf via TMUX_CONF env var)
echo "📦 Installing tmux plugins (including tmux-power)..."
# Start tmux server and set TMUX_PLUGIN_MANAGER_PATH globally
tmux start-server 2>/dev/null || true
tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.tmux/plugins/" 2>/dev/null || true
tmux source-file "$REPO_ROOT/.tmux.conf" 2>/dev/null || true
TMUX_CONF="$REPO_ROOT/.tmux.conf" "$TPM_DIR/bin/install_plugins" 2>/dev/null || echo "⚠️  Plugin installation skipped (will auto-install in tmux session)"
echo "✅ Tmux plugins configured"
echo ""

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
echo "💡 Tip: Restart tmux or run 'tmux source-file ~/.tmux.conf' to load plugins"
