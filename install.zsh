#!/usr/bin/env zsh
#
# install.zsh - Zap installation script
#
# Usage: curl -sL https://raw.githubusercontent.com/user/zap/main/install.zsh | zsh
#        OR: zsh install.zsh
#
# WHY: One-command installation enables quick onboarding (FR-001, SC-001)

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
  read "REPLY?Continue anyway? [y/N] "
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    exit 1
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

# Check if already installed (FR-001: exit code 2 for already installed)
if [[ -d "$ZAP_INSTALL_DIR" && -f "$ZAP_INSTALL_DIR/zap.zsh" ]]; then
  print_warning "Zap already installed at $ZAP_INSTALL_DIR"
  read "REPLY?Reinstall? [y/N] "
  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled"
    exit 2
  fi
  print_info "Removing existing installation..."
  rm -rf "$ZAP_INSTALL_DIR"
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
  git clone --depth 1 https://github.com/user/zap.git "$ZAP_INSTALL_DIR" >/dev/null 2>&1
fi

print_success "Cloned Zap to $ZAP_INSTALL_DIR"

# Create data directory (FR-001, XDG spec)
ZAP_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zap"
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
  # Add initialization line with marker comment (FR-033)
  print_info "Adding Zap initialization to $ZSHRC..."

  # Create backup
  cp "$ZSHRC" "${ZSHRC}.backup.$(date +%Y%m%d%H%M%S)"
  print_info "Created backup: ${ZSHRC}.backup.*"

  # Append initialization (preserve existing content per FR-033)
  cat >> "$ZSHRC" <<EOF

# === Zap Plugin Manager ===
# Installed: $(date +"%Y-%m-%d %H:%M:%S")
source "$ZAP_INSTALL_DIR/zap.zsh"

# Add your plugins here:
# zap load zsh-users/zsh-syntax-highlighting
# zap load zsh-users/zsh-autosuggestions

EOF

  print_success "Updated $ZSHRC"
fi

# Installation complete
echo ""
print_success "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Restart your shell:    ${GREEN}exec zsh${NC}"
echo "  2. Add plugins to $ZSHRC:"
echo "     ${GREEN}zap load zsh-users/zsh-syntax-highlighting${NC}"
echo "  3. Run 'zap help' for more commands"
echo ""
echo "Example plugins:"
echo "  zap load zsh-users/zsh-syntax-highlighting"
echo "  zap load zsh-users/zsh-autosuggestions@v0.7.0"
echo "  zap load ohmyzsh/ohmyzsh path:plugins/git"
echo ""
echo "Documentation: https://github.com/user/zap"
echo ""
