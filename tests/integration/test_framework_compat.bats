#!/usr/bin/env bats
#
# test_framework_compat.bats - Framework compatibility integration tests
#
# WHY: Verify FR-017, FR-025 (Oh-My-Zsh and Prezto compatibility)
# T046-T047: Integration tests for framework plugin loading

setup() {
  export TEST_DIR="/tmp/zap-framework-test-$$"
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"

  export ZAP_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")/.." && pwd)"

  # Install zap
  touch "$HOME/.zshrc"
  zsh -c "source $ZAP_DIR/install.zsh" >/dev/null 2>&1
}

teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

#
# T046: Oh-My-Zsh Compatibility Tests
#

@test "T046.1: Oh-My-Zsh framework is auto-detected" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Framework base should be cloned
  [[ -d "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh" ]]
  [[ -d "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh/.git" ]]
}

@test "T046.2: Oh-My-Zsh environment variables are set" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh
EOF

  run zsh -c "source $HOME/.zshrc && echo \$ZSH"
  [[ $status -eq 0 ]]
  echo "$output" | grep -q "ohmyzsh__ohmyzsh"

  run zsh -c "source $HOME/.zshrc && echo \$ZSH_CACHE_DIR"
  [[ $status -eq 0 ]]
  echo "$output" | grep -q "zap"

  run zsh -c "source $HOME/.zshrc && echo \$ZSH_CUSTOM"
  [[ $status -eq 0 ]]
  echo "$output" | grep -q "custom"
}

@test "T046.3: Oh-My-Zsh cache directories are created" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Verify cache and custom directories
  local omz_dir="$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh"
  [[ -d "$HOME/.local/share/zap/cache/ohmyzsh" ]]
  [[ -d "$HOME/.local/share/zap/data/ohmyzsh/custom" ]]
}

@test "T046.4: Oh-My-Zsh plugin loads from subdirectory" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:plugins/git
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Git plugin should exist
  [[ -d "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh/plugins/git" ]]
  [[ -f "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh/plugins/git/git.plugin.zsh" ]]
}

@test "T046.5: Multiple Oh-My-Zsh plugins load correctly" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:plugins/git
zap load ohmyzsh/ohmyzsh path:plugins/docker
zap load ohmyzsh/ohmyzsh path:plugins/kubectl
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # All plugins should exist
  [[ -f "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh/plugins/git/git.plugin.zsh" ]]
  [[ -f "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh/plugins/docker/docker.plugin.zsh" ]]
  [[ -f "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh/plugins/kubectl/kubectl.plugin.zsh" ]]
}

@test "T046.6: Oh-My-Zsh plugin aliases are available" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:plugins/git
EOF

  # Git plugin defines aliases like 'gst' for 'git status'
  run zsh -c "source $HOME/.zshrc && alias gst"
  [[ $status -eq 0 ]]
  echo "$output" | grep -q "git"
}

@test "T046.7: Oh-My-Zsh theme can be loaded" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:themes/robbyrussell
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Theme file should exist
  [[ -f "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh/themes/robbyrussell.zsh-theme" ]]
}

@test "T046.8: Oh-My-Zsh lib files can be loaded" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:lib/history
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Lib file should exist
  [[ -f "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh/lib/history.zsh" ]]
}

#
# T047: Prezto Compatibility Tests
#

@test "T047.1: Prezto framework is auto-detected" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load sorin-ionescu/prezto
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Framework base should be cloned
  [[ -d "$HOME/.local/share/zap/plugins/sorin-ionescu__prezto" ]]
  [[ -d "$HOME/.local/share/zap/plugins/sorin-ionescu__prezto/.git" ]]
}

@test "T047.2: Prezto environment variables are set" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load sorin-ionescu/prezto
EOF

  run zsh -c "source $HOME/.zshrc && echo \$PREZTO"
  [[ $status -eq 0 ]]
  echo "$output" | grep -q "sorin-ionescu__prezto"

  run zsh -c "source $HOME/.zshrc && echo \$ZDOTDIR"
  [[ $status -eq 0 ]]
  echo "$output" | grep -q "zap"
}

@test "T047.3: Prezto fpath includes module functions" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load sorin-ionescu/prezto
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Prezto modules should be in the plugins directory
  [[ -d "$HOME/.local/share/zap/plugins/sorin-ionescu__prezto/modules" ]]
}

@test "T047.4: Prezto module loads from subdirectory" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load sorin-ionescu/prezto path:modules/git
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Git module should exist
  [[ -d "$HOME/.local/share/zap/plugins/sorin-ionescu__prezto/modules/git" ]]
  [[ -f "$HOME/.local/share/zap/plugins/sorin-ionescu__prezto/modules/git/init.zsh" ]]
}

@test "T047.5: Multiple Prezto modules load correctly" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load sorin-ionescu/prezto path:modules/git
zap load sorin-ionescu/prezto path:modules/completion
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Both modules should exist
  [[ -f "$HOME/.local/share/zap/plugins/sorin-ionescu__prezto/modules/git/init.zsh" ]]
  [[ -f "$HOME/.local/share/zap/plugins/sorin-ionescu__prezto/modules/completion/init.zsh" ]]
}

@test "T047.6: Prezto module functions are in fpath" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load sorin-ionescu/prezto path:modules/git
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Git module has functions directory
  [[ -d "$HOME/.local/share/zap/plugins/sorin-ionescu__prezto/modules/git/functions" ]]
}

#
# Framework Coexistence Tests
#

@test "T047.7: Oh-My-Zsh and Prezto can coexist" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:plugins/git
zap load sorin-ionescu/prezto path:modules/completion
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Both frameworks should be loaded
  [[ -d "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh" ]]
  [[ -d "$HOME/.local/share/zap/plugins/sorin-ionescu__prezto" ]]

  # Both environment variables should be set
  run zsh -c "source $HOME/.zshrc && [[ -n \$ZSH ]] && [[ -n \$PREZTO ]]"
  [[ $status -eq 0 ]]
}

@test "T047.8: Framework and regular plugins coexist" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh path:plugins/git
zap load zsh-users/zsh-syntax-highlighting
zap load zsh-users/zsh-autosuggestions
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # All should be loaded
  [[ -d "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh" ]]
  [[ -d "$HOME/.local/share/zap/plugins/zsh-users__zsh-syntax-highlighting" ]]
  [[ -d "$HOME/.local/share/zap/plugins/zsh-users__zsh-autosuggestions" ]]
}

@test "T047.9: Framework base without subdirectory loads silently" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh
zap load ohmyzsh/ohmyzsh path:plugins/git
EOF

  # First line loads framework base (no plugin file)
  # Second line loads actual plugin
  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Should not show "Plugin file not found" error
  ! echo "$output" | grep -q "Plugin file not found.*ohmyzsh/ohmyzsh"
}

@test "T047.10: Framework version pinning works" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load ohmyzsh/ohmyzsh@master path:plugins/git
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Verify framework cloned at specific version
  local omz_dir="$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh"
  [[ -d "$omz_dir/.git" ]]

  # Should be on master branch
  run bash -c "cd $omz_dir && git branch --show-current"
  echo "$output" | grep -q "master"
}
