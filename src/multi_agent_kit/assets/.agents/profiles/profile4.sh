#!/bin/bash
# Profile 4: Like profile1 but only 3 panes (no bottom-right)
# Left column: 70% width, split top/bottom
# Right column: 30% width, one full pane

# Layout configuration
RIGHT_WIDTH=30           # Right column width percentage
TOP_RIGHT_HEIGHT=100     # Top-right pane full height
BOTTOM_HEIGHT=30         # Bottom-left pane height percentage

# Special layout flag
LAYOUT_TYPE="three-pane" # 3 panes only

# This profile is sourced by start-agents.sh
