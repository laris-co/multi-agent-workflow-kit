#!/bin/bash
# Profile 0: Three horizontal panes stacked vertically
# Top: Agent 1
# Middle: Agent 2
# Bottom: Root (always, for supervision)
#
# ┌──────────────────────────────┐
# │         Agent 1 (top)        │
# ├──────────────────────────────┤
# │       Agent 2 (middle)       │
# ├──────────────────────────────┤
# │        Root (bottom)         │
# └──────────────────────────────┘

# Layout configuration
MIDDLE_HEIGHT=33          # Middle pane height percentage (33% each)
BOTTOM_HEIGHT=50          # Bottom pane height percentage (50% of remaining)

# Special layout flag
LAYOUT_TYPE="three-horizontal"   # Three panes stacked vertically

# This profile is sourced by start-agents.sh
