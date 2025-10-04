#!/bin/bash
# Profile 1: Left side full height, right side split into 3 panes
# Left pane: full height
# Right side: 3 panes stacked vertically (60%, 20%, 20%)

# Layout configuration
RIGHT_WIDTH=30           # Right column width percentage (left will be 70%)
TOP_RIGHT_HEIGHT=40      # Bottom 2 panes combined (40% of right side, leaving top at 60%)
MIDDLE_RIGHT_HEIGHT=50   # Middle pane height (50% of the bottom section = 20% of total)

# Special layout flag
LAYOUT_TYPE="full-left"  # Left side is one full pane

# This profile is sourced by start-agents.sh
