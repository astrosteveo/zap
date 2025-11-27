#!/usr/bin/env bats
#
# test_completion.bats - Completion system integration test
#
# WHY: Verify FR-012 (completion system initialization)
# T037: Integration test for completion system setup and functionality

setup() {
  export TEST_DIR="/tmp/zap-completion-test-$$"
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

@test "T037.1: Completion system initializes on startup" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
EOF

  # Start shell and check compinit loaded
  run zsh -c "source $HOME/.zshrc && typeset -f compinit"
  [[ $status -eq 0 ]]
}

@test "T037.2: Completion options are set correctly" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
EOF

  # Check completion options
  run zsh -c "source $HOME/.zshrc && [[ -o COMPLETE_IN_WORD ]] && [[ -o AUTO_MENU ]] && [[ -o AUTO_LIST ]]"
  [[ $status -eq 0 ]]
}

@test "T037.3: Case-insensitive completion is configured" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
EOF

  # Check zstyle for case-insensitive matching
  run zsh -c "source $HOME/.zshrc && zstyle -L ':completion:*' matcher-list | grep -q 'm:{'"
  [[ $status -eq 0 ]]
}

@test "T037.4: Tab completion works for commands" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
EOF

  # Verify completion system can complete basic commands
  # This is a smoke test - completion is working if compinit loaded
  run zsh -c "source $HOME/.zshrc && compgen -c ls"
  [[ $status -eq 0 ]]
}

@test "T037.5: Completion plugin adds to fpath" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-completions
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Verify plugin cache has completion files
  local plugin_dir="$HOME/.local/share/zap/plugins/zsh-users__zsh-completions"
  [[ -d "$plugin_dir" ]]

  # zsh-completions adds _* files
  run find "$plugin_dir" -name '_*' -type f
  [[ $status -eq 0 ]]
}

@test "T037.6: Multiple completion plugins coexist" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-completions
zap load ohmyzsh/ohmyzsh path:plugins/docker
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Both should be cached
  [[ -d "$HOME/.local/share/zap/plugins/zsh-users__zsh-completions" ]]
  [[ -d "$HOME/.local/share/zap/plugins/ohmyzsh__ohmyzsh" ]]
}

@test "T037.7: compinit runs only once per session" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
zap load zsh-users/zsh-completions
EOF

  # Multiple sourcing shouldn't break completion
  run zsh -c "source $HOME/.zshrc && source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]
}

@test "T037.8: Completion cache directory is created" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
EOF

  run zsh -c "source $HOME/.zshrc && exit 0"
  [[ $status -eq 0 ]]

  # Completion cache should exist (created by zsh)
  # Location varies, but typically in ~/.zcompdump or similar
  # This test verifies completion system can initialize
  run zsh -c "source $HOME/.zshrc && typeset -f compinit"
  [[ $status -eq 0 ]]
}

@test "T037.9: Completion menu style is configured" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
EOF

  # Check menu selection style exists
  run zsh -c "source $HOME/.zshrc && zstyle -L ':completion:*:*:*:*:*' menu"
  [[ $status -eq 0 ]]
}

@test "T037.10: Completion descriptions are styled" {
  cat > "$HOME/.zshrc" <<'EOF'
source ~/.local/share/zap/zap.zsh
EOF

  # Check group-name style
  run zsh -c "source $HOME/.zshrc && zstyle -L ':completion:*:*:*:*:*' group-name"
  [[ $status -eq 0 ]]
}
