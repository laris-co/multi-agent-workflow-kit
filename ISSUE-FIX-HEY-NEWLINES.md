# Issue: Excessive Newlines in maw.hey Command

## Problem Description
The `hey.sh` script sends multiple Enter key variations, causing excessive blank lines when sending messages to agents.

### Current Behavior
The script sends ALL of these Enter variations in sequence:
1. `Enter` - Standard Enter key
2. `C-m` - Carriage return (Enter)
3. `C-j` - Line feed
4. `$'\r'` - Raw carriage return byte
5. `$'\n'` - Raw newline byte

This results in:
- **Claude Code**: Extra blank lines in the interface
- **Codex**: Potential extra newlines (though less visible)
- **Other clients**: Unpredictable behavior

### Affected Code
File: `.agents/scripts/hey.sh` (lines 241-255, 189-203, 167-170)

```bash
ENTER_KEYS=(
    Enter   # standard Enter key name recognised by tmux
    C-m     # carriage return (Enter)
    C-j     # line feed
    $'\r'   # raw carriage return byte
    $'\n'   # raw newline byte
)

for enter_key in "${ENTER_KEYS[@]}"; do
    tmux send-keys -t "$TARGET_PANE" "$enter_key"
    sleep 0.05
done
```

## Agent Configuration
Current setup:
- **Agent 1**: Codex (with specific parameters)
- **Agent 2**: Claude Code (Opus 4.1)
- **Agent 3**: Claude Code (Opus 4.1)

## Testing Results
Both Codex and Claude Code work correctly with a single `Enter` key:
- ✅ `tmux send-keys -t pane "message" Enter` works for both clients
- ❌ Multiple Enter variations cause extra blank lines

## Root Cause
After extensive testing, NO SINGLE Enter key variation works reliably:
- `Enter` - does NOT submit to Codex
- `C-m` - does NOT submit to Codex
- `C-j` - does NOT submit
- `$'\r'` - exits Codex when sent after Ctrl+C
- `$'\n'` - does NOT submit
- Paste-buffer approach - does NOT submit

## Final Solution: 5-Key Loop (ONLY Working Approach)

The ONLY solution that works with both Codex and Claude Code is sending ALL 5 Enter variations:

```bash
ENTER_KEYS=(
    Enter   # standard Enter key name recognised by tmux
    C-m     # carriage return (Enter)
    C-j     # line feed
    $'\r'   # raw carriage return byte
    $'\n'   # raw newline byte
)

echo "📤 Sending to agent '$AGENT_TARGET' (pane $PANE_INDEX): $MESSAGE"
tmux send-keys -t "$TARGET_PANE" "$MESSAGE"

for enter_key in "${ENTER_KEYS[@]}"; do
    tmux send-keys -t "$TARGET_PANE" "$enter_key"
    sleep 0.05
done
```

### Trade-off
This approach creates extra blank lines in the interface, but it's the ONLY method that reliably submits messages to both:
- ✅ Codex (gpt-5-codex)
- ✅ Claude Code (Sonnet 4.5)

The blank lines are an acceptable trade-off for reliable cross-client compatibility.

### Solution 2: Client Detection (Advanced)
Detect the client type and use appropriate Enter key:

```bash
detect_client_type() {
    local pane_id=$1
    local pane_content=$(tmux capture-pane -t "$pane_id" -p -S - | head -50)

    if echo "$pane_content" | grep -q "Claude Code"; then
        echo "claude"
    elif echo "$pane_content" | grep -q "codex"; then
        echo "codex"
    else
        echo "unknown"
    fi
}

send_message() {
    local target_pane=$1
    local message=$2
    local client_type=$(detect_client_type "$target_pane")

    tmux send-keys -t "$target_pane" "$message"

    # Use appropriate Enter for client type
    case "$client_type" in
        claude|codex|*)
            tmux send-keys -t "$target_pane" Enter
            ;;
    esac
}
```

## Implementation Files to Update

1. **Main hey.sh script**: `.agents/scripts/hey.sh`
2. **Source template**: `src/multi_agent_kit/assets/.agents/scripts/hey.sh`

## Quick Fix Commands

```bash
# Backup current script
cp .agents/scripts/hey.sh .agents/scripts/hey.sh.backup

# Apply fix (replace multi-enter with single Enter)
sed -i.bak '241,247d; 189,195d; 167,170d' .agents/scripts/hey.sh
sed -i '250s/.*/tmux send-keys -t "$TARGET_PANE" "$MESSAGE" Enter/' .agents/scripts/hey.sh
sed -i '198s/.*/tmux send-keys -t "$TARGET_PANE" "$MESSAGE" Enter/' .agents/scripts/hey.sh
sed -i '166s/.*/tmux send-keys -t "$TARGET_PANE" "$MESSAGE" Enter/' .agents/scripts/hey.sh
```

## Benefits of Fix
- ✅ Clean message sending without extra blank lines
- ✅ Works consistently across Codex and Claude Code
- ✅ Simpler code, easier to maintain
- ✅ Better user experience

## Next Steps
1. Apply the fix to both installed and source versions
2. Test with all three agents
3. Commit the changes
4. Update documentation if needed