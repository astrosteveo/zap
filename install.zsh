#!/usr/bin/env zsh
#
# install.zsh - Zap installation script
#
# Usage: curl -sL https://raw.githubusercontent.com/astrosteveo/zap/main/install.zsh | zsh
#        OR: zsh install.zsh
#
# WHY: One-command installation enables quick onboarding (FR-001, SC-001)
#
# NOTE: When piped from curl, interactive prompts are skipped (stdin not available)
#       For clean install option, download and run: zsh install.zsh

# Ensure running under Zsh (not bash)
if [ -z "$ZSH_VERSION" ]; then
  echo "Error: This script requires Zsh. Please run with: zsh install.zsh" >&2
  echo "Or use: curl -sL https://raw.githubusercontent.com/astrosteveo/zap/main/install.zsh | zsh" >&2
  exit 1
fi

set -e  # Exit on error

# Colors for output (only if terminal supports it)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  NC='\033[0m' # No Color
else
  GREEN=''
  YELLOW=''
  RED=''
  NC=''
fi

print_success() {
  echo "${GREEN}✓${NC} $1"
}

print_info() {
  echo "  $1"
}

print_error() {
  echo "${RED}✗${NC} $1" >&2
}

print_warning() {
  echo "${YELLOW}⚠${NC} $1"
}

echo ""
echo "=== Zap Plugin Manager Installer ==="
echo ""

# Check prerequisites (FR-032, FR-001)
print_info "Checking prerequisites..."

# Check Zsh version
if ! command -v zsh >/dev/null 2>&1; then
  print_error "Zsh not found"
  print_info "Please install Zsh 5.0 or later and try again"
  exit 1
fi

ZSH_VERSION_NUM="${ZSH_VERSION%%[^0-9.]*}"
ZSH_MAJOR="${ZSH_VERSION_NUM%%.*}"
if (( ZSH_MAJOR < 5 )); then
  print_warning "Zsh version $ZSH_VERSION_NUM detected"
  print_info "Zap requires Zsh 5.0 or later for full functionality"

  # Only prompt if interactive
  if [[ -t 0 ]]; then
    read "REPLY?Continue anyway? [y/N] "
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
      exit 1
    fi
  else
    print_info "Continuing anyway (non-interactive mode)"
  fi
fi

# Check Git availability
if ! command -v git >/dev/null 2>&1; then
  print_error "Git not found"
  print_info "Please install Git 2.0 or later and try again"
  exit 1
fi

print_success "Prerequisites satisfied (Zsh $ZSH_VERSION_NUM, Git $(git --version | awk '{print $3}'))"
echo ""

# Determine installation directory
ZAP_INSTALL_DIR="${ZAP_DIR:-$HOME/.zap}"
ZAP_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zap"

# Check if already installed (FR-001: exit code 2 for already installed)
if [[ -d "$ZAP_INSTALL_DIR" && -f "$ZAP_INSTALL_DIR/zap.zsh" ]]; then
  print_warning "Zap already installed at $ZAP_INSTALL_DIR"
  echo ""

  # Check if stdin is available for interactive prompts
  # WHY: When piped from curl, stdin is used for script content, not user input
  if [[ ! -t 0 ]]; then
    # Non-interactive mode (piped from curl)
    print_info "Non-interactive mode: performing regular reinstall (keeping plugins and cache)"
    print_info "For clean install option, download and run directly: zsh install.zsh"
    echo ""
    rm -rf "$ZAP_INSTALL_DIR"
  else
    # Interactive mode (direct execution)
    read "REPLY?Reinstall? [y/N] "
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
      print_info "Installation cancelled"
      exit 2
    fi

    echo ""
    print_info "Choose installation type:"
    echo "  ${GREEN}1${NC}) Regular reinstall (keep plugins and cache)"
    echo "  ${GREEN}2${NC}) Clean install (remove everything, fresh start)"
    echo ""
    read "INSTALL_TYPE?Enter choice [1]: "
    INSTALL_TYPE="${INSTALL_TYPE:-1}"

    if [[ "$INSTALL_TYPE" == "2" ]]; then
      # Clean install - zap it all out!
      print_warning "Clean install will remove:"
      print_info "  • Installation: $ZAP_INSTALL_DIR"
      print_info "  • Data/cache:   $ZAP_DATA_DIR"
      print_info "  • All downloaded plugins and history"
      echo ""
      read "CONFIRM?Are you sure? [y/N] "
      if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 2
      fi
      print_info "Performing clean install..."

      # Backup .zshrc if it exists and contains zap configuration
      # WHY: Clean install may remove zap lines, preserve user's original config
      if [[ -f "$ZSHRC" ]] && grep -q "source.*zap.zsh" "$ZSHRC" 2>/dev/null; then
        local backup_file="${ZSHRC}.backup.clean.$(date +%Y%m%d%H%M%S)"
        cp "$ZSHRC" "$backup_file"
        print_info "Backed up .zshrc to: $backup_file"
      fi

      rm -rf "$ZAP_INSTALL_DIR"
      rm -rf "$ZAP_DATA_DIR"
      print_success "Cleaned installation and data directories"
    else
      # Regular reinstall - keep data
      print_info "Reinstalling (keeping plugins and cache)..."
      rm -rf "$ZAP_INSTALL_DIR"
    fi
  fi
fi

# Clone repository
print_info "Installing Zap to $ZAP_INSTALL_DIR..."

if [[ -n "${ZAP_REPO_URL:-}" ]]; then
  # Custom repository URL (for testing or forks)
  git clone --depth 1 "$ZAP_REPO_URL" "$ZAP_INSTALL_DIR" >/dev/null 2>&1
elif [[ -f "$(dirname "$0")/zap.zsh" ]]; then
  # Local installation (running install.zsh from repository)
  print_info "Installing from local repository..."
  cp -r "$(dirname "$0")" "$ZAP_INSTALL_DIR"
else
  # Default: clone from GitHub
  git clone --depth 1 https://github.com/astrosteveo/zap.git "$ZAP_INSTALL_DIR" >/dev/null 2>&1
fi

print_success "Cloned Zap to $ZAP_INSTALL_DIR"

# Create data directory (FR-001, XDG spec)
mkdir -p "$ZAP_DATA_DIR/plugins" 2>/dev/null

print_success "Created data directory at $ZAP_DATA_DIR"

# Update .zshrc (FR-033)
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

# Create .zshrc if it doesn't exist
if [[ ! -f "$ZSHRC" ]]; then
  touch "$ZSHRC"
  print_info "Created $ZSHRC"
fi

# Check if already sourced in .zshrc
if grep -q "source.*zap.zsh" "$ZSHRC" 2>/dev/null; then
  print_warning "Zap already configured in $ZSHRC"
else
  # Add initialization from template (FR-033)
  print_info "Adding Zap initialization to $ZSHRC..."

  # Create backup
  cp "$ZSHRC" "${ZSHRC}.backup.$(date +%Y%m%d%H%M%S)"
  print_info "Created backup: ${ZSHRC}.backup.*"

  # WHY: Use template for consistent, comprehensive configuration
  # Read template and replace placeholders
  local zshrc_template="$ZAP_INSTALL_DIR/config/zshrc.template"

  if [[ -f "$zshrc_template" ]]; then
    # Append template with substituted values (preserve existing content per FR-033)
    {
      echo ""
      sed -e "s|__INSTALL_DATE__|$(date +"%Y-%m-%d %H:%M:%S")|g" \
          -e "s|__ZAP_INSTALL_DIR__|$ZAP_INSTALL_DIR|g" \
          "$zshrc_template"
    } >> "$ZSHRC"
  else
    # Fallback to minimal configuration if template is missing
    print_warning "Template not found, using minimal configuration"
    cat >> "$ZSHRC" <<EOF

# === Zap Plugin Manager ===
# Installed: $(date +"%Y-%m-%d %H:%M:%S")
source "$ZAP_INSTALL_DIR/zap.zsh"

# Add your plugins here:
# plugins=(
#   'zsh-users/zsh-syntax-highlighting'
#   'zsh-users/zsh-autosuggestions'
# )

EOF
  fi

  print_success "Updated $ZSHRC"
fi

# Optionally create ~/.zaprc configuration file
ZAPRC="${ZDOTDIR:-$HOME}/.zaprc"

if [[ ! -f "$ZAPRC" ]]; then
  # Only prompt if interactive
  if [[ -t 0 ]]; then
    echo ""
    print_info "Zap can be customized via zstyle settings in ~/.zaprc"
    read "REPLY?Create ~/.zaprc with example configurations? [Y/n] "
    REPLY="${REPLY:-y}"

    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      cp "$ZAP_INSTALL_DIR/config/zaprc.template" "$ZAPRC"
      print_success "Created $ZAPRC"
      print_info "Edit $ZAPRC to customize Zap behavior"
    fi
  else
    # Non-interactive: skip zaprc creation
    print_info "Skipping ~/.zaprc creation (run 'cp ~/.zap/config/zaprc.template ~/.zaprc' to create later)"
  fi
fi

# Installation complete
echo ""
print_success "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Restart your shell:    ${GREEN}exec zsh${NC}"
echo "  2. Add plugins to $ZSHRC:"
echo "     ${GREEN}plugins=('zsh-users/zsh-syntax-highlighting')${NC}"
echo "  3. Run 'zap help' for more commands"
echo ""
echo "Example plugins:"
echo "  'zsh-users/zsh-syntax-highlighting'"
echo "  'zsh-users/zsh-autosuggestions@v0.7.0'"
echo "  'ohmyzsh/ohmyzsh:plugins/git'"
echo ""
echo "Documentation: https://github.com/astrosteveo/zap"
echo ""
