#!/bin/bash
# Profile 0: Three horizontal panes stacked vertically (all agents, no root)
# Top: Agent 1
# Middle: Agent 2
# Bottom: Agent 3
#
# ┌──────────────────────────────┐
# │         Agent 1              │
# ├──────────────────────────────┤
# │         Agent 2              │
# ├──────────────────────────────┤
# │         Agent 3              │
# └──────────────────────────────┘

# Layout configuration
MIDDLE_HEIGHT=33          # Middle pane height (33% each)
BOTTOM_HEIGHT=50          # Bottom pane height (50% of remaining)

# Special layout flag
LAYOUT_TYPE="three-horizontal"   # Three panes stacked vertically

# This profile is sourced by start-agents.sh
