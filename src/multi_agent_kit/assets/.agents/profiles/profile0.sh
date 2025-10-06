#!/bin/bash
# Profile 0: Top pane with bottom split into left/right panes
# Top: 50% height pane (pane 1)
# Bottom-left: 50% height pane (pane 2)
# Bottom-right: shares bottom row (pane 3)

# Layout configuration
BOTTOM_HEIGHT=50          # Bottom row height percentage (50/50 split)
BOTTOM_RIGHT_WIDTH=50     # Width percentage for bottom-right pane when split horizontally

# Special layout flag
LAYOUT_TYPE="two-pane-bottom-right"   # Two rows with bottom row split left/right

# This profile is sourced by start-agents.sh
