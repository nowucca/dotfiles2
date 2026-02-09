#!/bin/bash
# Sync Hammerspoon configuration from dotfiles to ~/.hammerspoon
# This copies code files but preserves user data (workspace-notes.json, space-profiles/)

set -e

DOTFILES_HS="$HOME/Work/dotfiles/.hammerspoon"
TARGET_HS="$HOME/.hammerspoon"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Syncing Hammerspoon configuration...${NC}"

# Ensure target directory exists
mkdir -p "$TARGET_HS"
mkdir -p "$TARGET_HS/modules"

# Copy init.lua
echo "  Copying init.lua..."
cp "$DOTFILES_HS/init.lua" "$TARGET_HS/init.lua"

# Copy all module files
echo "  Copying modules..."
cp "$DOTFILES_HS/modules/"*.lua "$TARGET_HS/modules/"

# List what was synced
echo -e "${GREEN}Synced files:${NC}"
echo "  init.lua"
for f in "$TARGET_HS/modules/"*.lua; do
  echo "  modules/$(basename "$f")"
done

# Preserve these data files (don't overwrite):
# - workspace-notes.json (space labels)
# - space-profiles/ (saved profiles)

if [ ! -f "$TARGET_HS/workspace-notes.json" ]; then
  echo '{"labels":{},"spaces":{}}' > "$TARGET_HS/workspace-notes.json"
  echo -e "${YELLOW}Created empty workspace-notes.json${NC}"
fi

if [ ! -d "$TARGET_HS/space-profiles" ]; then
  mkdir -p "$TARGET_HS/space-profiles"
  echo -e "${YELLOW}Created space-profiles directory${NC}"
fi

echo -e "${GREEN}Done! Reload Hammerspoon to apply changes.${NC}"
echo ""
echo "Tip: Run 'hs -c \"hs.reload()\"' or use the Hammerspoon menu"
