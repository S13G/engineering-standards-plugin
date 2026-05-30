#!/bin/sh
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print beautiful banner
printf "${BLUE}${BOLD}"
printf "====================================================\n"
printf "  Engineering Standards Installer         \n"
printf "====================================================\n"
printf "${NC}\n"

# Parse arguments
IS_GLOBAL=false
FORCE=false

for arg in "$@"; do
  case $arg in
    -g|--global)
      IS_GLOBAL=true
      shift
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    -h|--help)
      printf "Usage: curl -fsSL <install-url> | sh -s -- [options]\n\n"
      printf "Options:\n"
      printf "  -g, --global    Install globally to ~/.engineering-standards\n"
      printf "  -f, --force     Overwrite existing files\n"
      printf "  -h, --help      Show this help message\n"
      exit 0
      ;;
  esac
done

# Define directories
if [ "$IS_GLOBAL" = true ]; then
  TARGET_DIR="$HOME/.engineering-standards"
  printf "Mode: ${BOLD}Global${NC}\n"
else
  TARGET_DIR="$(pwd)"
  printf "Mode: ${BOLD}Local (Project)${NC}\n"
fi

printf "Target directory: ${BLUE}${TARGET_DIR}${NC}\n\n"

# Setup target directory
mkdir -p "$TARGET_DIR"

# Create a temporary directory for extraction
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'eng-std')
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Download and extract tarball
printf "Downloading latest standards from GitHub...\n"
if ! curl -sSL https://github.com/S13G/engineering-standards-plugin/archive/refs/heads/main.tar.gz | tar -xz -C "$TMP_DIR"; then
  printf "${RED}✗ Error: Failed to download and extract standard files.${NC}\n"
  exit 1
fi

# Find the extracted folder (GitHub tarball nests inside engineering-standards-plugin-main or similar)
EXTRACTED_DIR=$(find "$TMP_DIR" -maxdepth 1 -name "*engineering-standards-plugin*" | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
  printf "${RED}✗ Error: Extracted directory not found.${NC}\n"
  exit 1
fi

# Files and directories to install
ITEMS="AGENTS.md CLAUDE.md GEMINI.md .cursorrules skills .cursor .github"

copy_item() {
  src="$1"
  dest="$2"
  
  if [ -e "$dest" ] && [ "$FORCE" != true ]; then
    printf "${YELLOW}⚠ Skipped (already exists):${NC} $(basename "$dest")\n"
    return
  fi

  rm -rf "$dest"
  cp -R "$src" "$dest"
  printf "${GREEN}✔ Installed:${NC} $(basename "$dest")\n"
}

# Copy files
for item in $ITEMS; do
  if [ -e "$EXTRACTED_DIR/$item" ]; then
    copy_item "$EXTRACTED_DIR/$item" "$TARGET_DIR/$item"
  else
    printf "${RED}⚠ Warning: Source item $item not found in archive.${NC}\n"
  fi
done

# If global, set up AI agent references
if [ "$IS_GLOBAL" = true ]; then
  printf "\n${BOLD}Setting up global AI agent references...${NC}\n"
  
  # 1. Claude Code
  CLAUDE_DIR="$HOME/.claude"
  CLAUDE_FILE="$CLAUDE_DIR/CLAUDE.md"
  
  mkdir -p "$CLAUDE_DIR"
  
  SHOULD_WRITE_CLAUDE=true
  if [ -f "$CLAUDE_FILE" ]; then
    if grep -q "engineering-standards" "$CLAUDE_FILE"; then
      printf "${YELLOW}⚠ Global Claude Code rules already contain a reference to engineering-standards.${NC}\n"
      SHOULD_WRITE_CLAUDE=false
    fi
  fi
  
  if [ "$SHOULD_WRITE_CLAUDE" = true ]; then
    printf "\n# Engineering Standards\n\nThis workspace uses the global engineering standards plugin.\nTo load domain references, refer to rules inside \`$TARGET_DIR\`.\n\n@$TARGET_DIR/AGENTS.md\n" >> "$CLAUDE_FILE"
    printf "${GREEN}✔ Added reference to global CLAUDE.md at:${NC} $CLAUDE_FILE\n"
  fi

  # 2. Gemini CLI
  GEMINI_DIR="$HOME/.gemini"
  GEMINI_FILE="$GEMINI_DIR/GEMINI.md"
  
  mkdir -p "$GEMINI_DIR"
  
  SHOULD_WRITE_GEMINI=true
  if [ -f "$GEMINI_FILE" ]; then
    if grep -q "engineering-standards" "$GEMINI_FILE"; then
      printf "${YELLOW}⚠ Global Gemini CLI rules already contain a reference to engineering-standards.${NC}\n"
      SHOULD_WRITE_GEMINI=false
    fi
  fi
  
  if [ "$SHOULD_WRITE_GEMINI" = true ]; then
    printf "\n# Engineering Standards\n\nThis workspace uses the global engineering standards plugin.\nTo load domain references, refer to rules inside \`$TARGET_DIR\`.\n\n@$TARGET_DIR/AGENTS.md\n" >> "$GEMINI_FILE"
    printf "${GREEN}✔ Added reference to global GEMINI.md at:${NC} $GEMINI_FILE\n"
  fi
fi

printf "\n${GREEN}${BOLD}★ Installation completed successfully!${NC}\n"
if [ "$IS_GLOBAL" = false ]; then
  printf "Standards are now local to this project and will be read automatically by your AI agents.\n\n"
else
  printf "Standards are now globally installed. Your AI agents have been configured to use them.\n\n"
fi
