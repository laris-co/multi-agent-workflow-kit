#!/bin/bash
# Profile 0: Three horizontal panes stacked vertically (all agents, no root)
# All panes start in root directory, then auto-warp to agent directories using 'maw warp'
# Agents can navigate between directories with: maw warp <agent> or maw warp root
#
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

# Layout configuration (creates 40-30-30 split)
MIDDLE_HEIGHT=60          # First split: 40% top, 60% for middle+bottom
BOTTOM_HEIGHT=50          # Second split: splits the 60% into two 30% panes

# Special layout flag
LAYOUT_TYPE="three-horizontal"   # Three panes stacked vertically

# This profile is sourced by start-agents.sh
