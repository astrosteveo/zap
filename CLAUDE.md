# Zap Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-10-18 (Constitution v1.2.0)

## Project Overview

Zap is a lightweight Zsh plugin manager designed for speed, simplicity, and reliability. It provides a modern alternative to Antigen with sub-second startup times and comprehensive framework compatibility.

## Active Technologies
- **Zsh shell scripting** (Zsh 5.0+) - Core implementation language
- **Git** - For cloning and managing plugin repositories
- **BATS** - Bash Automated Testing System for integration tests
- **Standard Unix utilities** - curl/wget for downloads, basic shell tools

## Project Structure

```
zap/
├── zap.zsh              # Main entry point (sourced by .zshrc)
├── lib/
│   ├── parser.zsh       # Config file parsing and load order caching
│   ├── loader.zsh       # Plugin loading and sourcing
│   ├── downloader.zsh   # Git cloning and version pinning
│   ├── updater.zsh      # Update checking logic
│   ├── framework.zsh    # Oh-My-Zsh/Prezto compatibility
│   ├── defaults.zsh     # Default keybindings, completions, history (based on Oh-My-Zsh)
│   ├── compfix.zsh      # Completion security validation (from Oh-My-Zsh)
│   ├── termsupport.zsh  # Terminal title support (from Oh-My-Zsh)
│   ├── prompt.zsh       # Simple built-in prompt (vcs_info based)
│   └── utils.zsh        # Common utility functions
├── install.zsh          # Installer script
├── tests/
│   ├── contract/        # Contract tests for core functionality
│   ├── integration/     # End-to-end integration tests (BATS)
│   └── unit/            # Unit tests for individual modules
└── specs/001-zsh-plugin-manager/
    ├── spec.md          # Feature specification
    ├── plan.md          # Implementation plan
    ├── tasks.md         # Task breakdown
    ├── quickstart.md    # User documentation
    └── checklists/      # Quality checklists
```

## Oh-My-Zsh Inspired Features

Zap provides an Oh-My-Zsh-level experience out of the box with these features adapted from Oh-My-Zsh's `lib/` directory:

### 1. Smart History Search (from `key-bindings.zsh`)
- **Up/Down arrows**: Fuzzy history search - type "git" then Up → only git commands!
- **Page Up/Down**: Traditional full history navigation
- Based on `up-line-or-beginning-search` widget

### 2. Enhanced History Settings (from `history.zsh`)
- **50,000** command history (vs default 10,000)
- Timestamps in history (`extended_history`)
- Deduplication (`hist_expire_dups_first`, `hist_ignore_dups`)
- History verification (`hist_verify`) - shows `!!` expansion before running
- **Opt-in shared history**: Set `ZAP_SHARE_HISTORY=true` to sync across sessions

### 3. Directory Navigation (from `directories.zsh`)
- **Auto-pushd**: Directory stack automatically maintained
- **Quick navigation**: `...` for `../..`, `....` for `../../..`, `-` for `cd -`
- No duplicate directories in stack

### 4. Security Features (from `compfix.zsh` and `misc.zsh`)
- **Completion security**: Validates completion directories aren't world-writable
- **Bracketed paste**: Prevents accidental execution when pasting (e.g., `curl | sh` exploits)
- **URL auto-quoting**: Automatically quotes URLs

### 5. Terminal Title Support (from `termsupport.zsh`)
- **Auto-updating titles**: Tab shows "git push", window shows full command
- **OSC 7 support**: Enables "New Tab at Current Directory" in iTerm2/Terminal.app
- **Works with**: iTerm2, Terminal.app, Alacritty, Konsole, tmux, screen
- **Opt-out**: Set `DISABLE_AUTO_TITLE=true`

### 6. Built-in Prompt (custom, using vcs_info)
- **Simple and fast**: Pure Zsh, zero external dependencies
- **Git-aware**: Shows current branch using Zsh's built-in `vcs_info`
- **Color-coded**: Green prompt on success, red on failure
- **Smart user display**: Shows user@host only on SSH/remote or when root
- **Opt-out**: Set `ZAP_DISABLE_PROMPT=true` (use Starship or custom prompt)

### Environment Variables for Customization

```zsh
# In ~/.zshrc, BEFORE sourcing zap:

# Disable features
export ZAP_DISABLE_COMPFIX=true     # Skip completion security check
export ZAP_DISABLE_PROMPT=true      # Don't load built-in prompt (use Starship)
export DISABLE_AUTO_TITLE=true      # Don't set terminal titles
export DISABLE_MAGIC_FUNCTIONS=true # Disable bracketed-paste and url-quote

# Enable features
export ZAP_SHARE_HISTORY=true       # Share history across all sessions
```

## Commands

### User-Facing Commands
- `zap load <owner>/<repo>[@version] [path:subdir]` - Load a plugin
- `zap update [<plugin>]` - Update plugins to latest versions
- `zap list [--verbose]` - List installed plugins
- `zap clean [--all] [--yes]` - Clean plugin cache
- `zap doctor` - Run diagnostics
- `zap uninstall [--keep-cache] [--yes]` - Uninstall zap
- `zap help [command]` - Show help information

### Development Commands
- Run contract tests: `zsh tests/contract/test_*.zsh`
- Run integration tests: `bats tests/integration/test_*.bats`
- Check Zsh syntax: `zsh -n <file>`
- Profile startup: `ZAP_PROFILE=1 zsh -i -c exit`

## Code Style

### Zsh Shell Scripting Conventions
- **Function naming**: Prefix all functions with `_zap_` to avoid conflicts
- **Variable naming**: Use lowercase with underscores (e.g., `plugin_name`)
- **Environment variables**: Use uppercase (e.g., `ZAP_DIR`, `ZAP_DATA_DIR`)
- **Comments**: WHY not WHAT - explain design decisions, not code behavior
- **Error handling**: Always check return codes; never block shell startup
- **Quoting**: Always quote variables to prevent word splitting

### Code Quality Requirements
- **Single Responsibility**: Each function has one clear purpose
- **Documentation**: All public functions have docstrings with purpose, parameters, returns
- **WHY comments**: Explain rationale for non-obvious decisions
- **Graceful degradation**: Errors warn but don't block shell startup (FR-015)
- **Input validation**: Sanitize all user inputs per FR-027

### Example Function Structure

```zsh
#
# _zap_function_name - Brief description
#
# Purpose: Detailed explanation of what this does
# Parameters:
#   $1 - Description of first parameter
#   $2 - Description of second parameter
# Returns: 0 on success, 1 on error
#
# WHY: Explanation of design decision or rationale
#
_zap_function_name() {
  local param1="$1"
  local param2="$2"

  # Validate inputs
  if [[ -z "$param1" ]]; then
    _zap_error "Parameter required"
    return 1
  fi

  # Implementation
  # ...

  return 0
}
```

## User Experience Standards (Zsh CLI)

Zap follows UNIX principles and CLI best practices for consistent user experience:

### Command-Line Interface Design

- **UNIX Philosophy**: Do one thing well; compose with other tools via pipes
- **Silent Success**: Commands succeed silently (exit 0); only output on errors or when explicitly requested (`--verbose`)
- **Consistent Flags**: Use standard flag conventions (`-h`/`--help`, `-v`/`--verbose`, `-y`/`--yes` for confirmations)
- **Exit Codes**: Return 0 for success, non-zero for errors; use meaningful exit codes for different error types
- **Pipe-Friendly**: Output structured data (when appropriate) that can be parsed by other tools

### Error Message Format

- **Actionable**: Tell user what failed AND how to fix it
- **Contextual**: Include relevant details (plugin name, file path, command that failed)
- **Graceful Degradation**: Errors warn but NEVER block shell startup (FR-015)
- **Consistent Prefix**: Use `[zap]` prefix for all user-facing messages

**Examples**:
```zsh
# ❌ BAD - Not actionable
echo "Error: failed"

# ✅ GOOD - Actionable with context
_zap_error "[zap] Failed to clone plugin 'zsh-users/zsh-autosuggestions'"
_zap_error "  Reason: Git not found in PATH"
_zap_error "  Fix: Install git with your package manager"
```

### Help Text Standards

- **Concise**: One-line command description at top
- **Usage**: Show command syntax with required and [optional] parameters
- **Examples**: Include 1-3 common examples
- **Consistency**: Follow same structure across all commands

**Example**:
```zsh
zap help load

Usage: zap load <owner>/<repo>[@version] [path:subdir]

Load a Zsh plugin from GitHub.

Examples:
  zap load zsh-users/zsh-autosuggestions
  zap load zsh-users/zsh-syntax-highlighting@v0.7.1
  zap load ohmyzsh/ohmyzsh path:plugins/git
```

### Progress & Feedback

- **Fast Operations (<1s)**: Silent unless error
- **Medium Operations (1-5s)**: Show spinner or status message
- **Long Operations (>5s)**: Show progress bar or incremental updates
- **Interruptible**: Respect Ctrl-C; clean up partial state

## Default Keybindings & Behaviors

Zap's `lib/defaults.zsh` provides sensible keybindings that **respect standard terminal conventions** and **support both emacs and vi modes**. Users should never be surprised by unexpected keybinding behavior.

### Mode Flexibility (Emacs vs Vi)

Zap respects the user's keymap preference:

- **Default Mode**: Emacs mode (if user hasn't set a preference)
  - Provides Ctrl-A, Ctrl-E, Ctrl-R, Ctrl-U, Ctrl-K, Ctrl-W, etc.
  - Most common for new users and matches readline behavior
- **Vi Mode**: Fully supported if user sets `bindkey -v` before sourcing zap
  - Navigation keys (Home, End, Page Up/Down, arrows) work in both insert and command modes
  - Standard vi keybindings (hjkl, w/b/e) available in command mode
- **Detection**: Zap checks `$ZLE_KEYMAP` and only sets emacs mode if no preference exists

**How to use vi mode:**
```zsh
# In your ~/.zshrc, BEFORE sourcing zap:
bindkey -v
source ~/.zap/zap.zsh
```

### Standard Terminal Keybindings (MUST Preserve)

The following keybindings MUST behave as users expect from standard terminal applications (work in both modes):

- **Ctrl-D**: Send EOF (exit shell when line is empty); DO NOT rebind to delete-char or other functions
- **Ctrl-C**: Send SIGINT (interrupt current command); NEVER override
- **Ctrl-L**: Clear screen; standard across all terminals
- **Ctrl-R**: Reverse incremental history search (search backward) - provided by emacs mode
- **Ctrl-S**: Forward incremental history search (search forward) - enabled via `stty -ixon`
- **Ctrl-Z**: Suspend current process (SIGTSTP); NEVER override

**Rationale**: These are muscle memory for experienced terminal users. Overriding them breaks expectations and creates frustration.

### Navigation Keybindings (Work in Both Modes)

Zap provides these common navigation keybindings that work in both emacs and vi modes:

- **Home**: Move to beginning of line (also Ctrl-A in emacs mode)
- **End**: Move to end of line (also Ctrl-E in emacs mode)
- **Ctrl-Left**: Move backward one word (also Alt-B in emacs mode, supplements w/b in vi mode)
- **Ctrl-Right**: Move forward one word (also Alt-F in emacs mode, supplements w/e in vi mode)
- **Page Up**: Move up in history
- **Page Down**: Move down in history
- **Arrow Keys**: Navigate history (Up/Down) and cursor position (Left/Right)

**Implementation**: These keys are bound to all relevant keymaps (main, viins, vicmd) using the `_zap_bindkey_all` helper.

**Rationale**: These are expected in most GUI and terminal applications. Providing them in both modes ensures a complete "everyday driver" experience regardless of user preference.

### Editing Keybindings (Mode-Specific)

**Emacs mode provides:**
- **Ctrl-A / Ctrl-E**: Beginning/end of line
- **Ctrl-U**: Delete from cursor to beginning of line (standard UNIX)
- **Ctrl-K**: Delete from cursor to end of line (standard UNIX)
- **Ctrl-W**: Delete word backward (standard UNIX)
- **Alt-D**: Delete word forward
- **Ctrl-Y**: Yank (paste) last killed text
- **Ctrl-X Ctrl-E**: Edit command line in $EDITOR

**Vi mode provides:**
- **Esc** or **Ctrl-[**: Enter command mode
- **i / a / I / A**: Enter insert mode (various positions)
- **hjkl**: Navigate in command mode
- **w / b / e**: Word movement in command mode
- **dd / cc / yy**: Delete/change/yank line
- **v**: Enter visual mode for selection

**Rationale**: Each mode has its own rich set of editing commands. Zap respects both traditions.

### Completion System Keybindings (Both Modes)

Zap initializes the completion system with standard behaviors that work in both modes:

- **Tab**: Complete current word; cycle through completions on repeated presses
- **Shift-Tab**: Reverse cycle through completions (if supported)
- **Ctrl-Space**: Accept current completion suggestion (for zsh-autosuggestions plugin, if installed)

### Forbidden Overrides

Zap's `defaults.zsh` MUST NOT override these without explicit user opt-in:

- **Ctrl-D**: MUST remain EOF/exit (NEVER rebind to delete-char)
- **Ctrl-C**: MUST remain SIGINT (NEVER rebind)
- **Ctrl-Z**: MUST remain SIGTSTP (NEVER rebind)
- **Standard readline bindings**: Avoid breaking compatibility with bash/readline muscle memory

### Full Keybinding Reference

**lib/defaults.zsh** is based on Oh-My-Zsh's `key-bindings.zsh` with Zap enhancements:

**Smart History (Most Important Feature!):**
- **Up/Down Arrows**: Fuzzy history search (type "git" then Up shows only git commands!)
- **Page Up/Down**: Traditional full history navigation
- **Ctrl-R**: Reverse incremental search

**Navigation:**
- **Home / End**: Beginning/end of line
- **Ctrl-Left / Ctrl-Right**: Move by word
- **Arrow Keys**: Navigate cursor and history

**Editing:**
- **Delete / Backspace**: Delete character forward/backward
- **Ctrl-Delete**: Kill word forward (GUI-style)
- **Ctrl-U / Ctrl-K**: Kill line backward/forward (standard UNIX)
- **Ctrl-W**: Kill word backward
- **Alt-W**: Kill region (emacs-style)
- **Alt-M**: Copy previous shell word
- **Space**: Magic space (no history expansion)

**Advanced:**
- **Ctrl-X Ctrl-E**: Edit command in $EDITOR
- **Shift-Tab**: Reverse completion menu

**Tab Completion:**
- **Tab**: Complete and cycle forward
- **Shift-Tab**: Cycle backward
- Case-insensitive matching
- Menu selection for multiple matches

### Testing Expectations

When testing `lib/defaults.zsh`:

```zsh
# Test smart history search
# Type "git " then press Up arrow - should only show git commands

# Test Ctrl-D on empty line exits shell
# Test Ctrl-C interrupts running command
# Test Home/End move to line boundaries
# Test Ctrl-R opens reverse search
# Test Tab triggers completion with menu
# Test Shift-Tab reverses completion menu
# Test Ctrl-Delete kills word forward
# Test Ctrl-X Ctrl-E opens editor
# Test Page Up/Down navigate full history
# Test Space prevents history expansion (!foo stays literal)
```

**Implementation Location**: `lib/defaults.zsh:1-291`

## Security Practices (Zsh Shell Scripting)

Shell scripts are high-risk environments; security MUST be built in from the start:

### Input Validation (FR-027)

- **Sanitize ALL inputs**: User arguments, environment variables, file contents
- **Path Traversal Prevention**: Reject `..` in paths; validate against expected directories
- **Command Injection Prevention**: NEVER use `eval` on user input; quote all variable expansions
- **Repository Names**: Validate `owner/repo` format; reject shell metacharacters

**Examples**:
```zsh
# ❌ BAD - Command injection vulnerability
eval "git clone $user_input"

# ✅ GOOD - Safe quoting and validation
if [[ ! "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
  _zap_error "Invalid repository format: $repo"
  return 1
fi
git clone "https://github.com/${repo}.git" "$dest_dir"

# ❌ BAD - Path traversal vulnerability
local plugin_dir="$ZAP_DIR/plugins/$user_input"

# ✅ GOOD - Path traversal prevention
if [[ "$user_input" =~ \.\. ]]; then
  _zap_error "Invalid path: $user_input (path traversal detected)"
  return 1
fi
local plugin_dir="$ZAP_DIR/plugins/${user_input}"
```

### Least Privilege

- **Never require root**: Zap MUST run as regular user
- **File Permissions**: Plugin cache is user-owned (`~/.local/share/zap`); no world-writable files
- **Environment Isolation**: Don't pollute global environment; use `local` for all function variables

### Secure Defaults

- **Git HTTPS**: Clone via HTTPS, not git:// protocol (prevents MITM)
- **Version Pinning**: Respect `@version`, `@commit`, `@branch` pins; don't auto-upgrade pinned plugins
- **Signature Verification**: Future enhancement - verify plugin signatures

### Dependency Security

- **Git Availability**: Check for `git` command; fail gracefully if missing
- **Network Errors**: Handle GitHub downtime without breaking shell
- **Malicious Plugins**: Document risk of sourcing untrusted code; provide `zap doctor` diagnostics

## Observability (Zsh Plugin Manager)

Debugging shell startup issues is critical; Zap provides comprehensive observability:

### Logging Strategy

- **Error Log**: All errors logged to `$ZAP_ERROR_LOG` (`~/.local/share/zap/error.log`)
- **Structured Context**: Include timestamp, plugin name, operation, error message
- **Rotation**: Keep last 100 errors; rotate on size limit (future enhancement)

**Example**:
```zsh
_zap_log_error() {
  local plugin="$1"
  local operation="$2"
  local message="$3"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # WHY: Structured logging enables parsing for `zap doctor` diagnostics
  echo "[$timestamp] [$operation] plugin=$plugin error=\"$message\"" >> "$ZAP_ERROR_LOG"
}
```

### Error Tracking

- **User-Facing Errors**: Display to stderr with `[zap]` prefix
- **Background Errors**: Log silently; surface in `zap doctor` output
- **Exit Codes**: Return meaningful codes (0=success, 1=general error, 2=invalid input, 127=command not found)

### Debugging Support

- **Verbose Mode**: `ZAP_VERBOSE=1 zsh` shows all operations
- **Profiling Mode**: `ZAP_PROFILE=1 zsh -i -c exit` shows startup timing breakdown
- **Doctor Command**: `zap doctor` runs diagnostics (checks git, conflicts, disk space, error log)

**Example**:
```zsh
# WHY: Profiling requires timing each operation to identify bottlenecks
if [[ -n "$ZAP_PROFILE" ]]; then
  local start_time=$(date +%s%N)
fi

_zap_load_plugin "$@"

if [[ -n "$ZAP_PROFILE" ]]; then
  local end_time=$(date +%s%N)
  local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to ms
  echo "[zap profile] load $1: ${duration}ms" >&2
fi
```

### Operational Transparency

- **Status Commands**: `zap list` shows installed plugins; `zap list --verbose` shows versions and paths
- **Health Checks**: `zap doctor` verifies system health and configuration
- **Version Information**: All error logs include `zap --version` output for debugging

## Performance Requirements

- **Shell startup**: < 1 second with 10 plugins, < 2 seconds with 25 plugins
- **Update check**: < 5 seconds for 10 plugins
- **Memory overhead**: < 10MB compared to bare Zsh
- **Plugin download**: < 30 seconds for typical plugin (< 5MB)

## Testing Strategy

### Test-Driven Development (TDD)
1. **RED**: Write failing test first
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Improve while keeping tests green

### Test Coverage Requirements
- **Contract tests**: API boundaries and data contracts (57+ test cases)
- **Integration tests**: End-to-end user scenarios (62+ test cases)
- **Unit tests**: Individual function behavior (3 test files)
- **Target coverage**: 80%+ on core business logic

### Critical Test Scenarios
- **Error handling**: Plugin failures never block startup (FR-015)
- **Input validation**: Path traversal, command injection prevention (FR-027)
- **Concurrent safety**: Atomic file operations (FR-035)
- **Framework compatibility**: Oh-My-Zsh and Prezto integration
- **Version pinning**: Respect @version, @commit, @branch pins

## Recent Changes

### 2025-10-18
- ✅ **Phase 9 Complete**: CLI commands (zap clean, doctor, uninstall)
- ✅ **Phase 10 Complete**: Zsh version detection, plugin manager conflict warnings
- ✅ **Phase 11 Complete**: Comprehensive README, migration guides, troubleshooting
- ✅ **Test Coverage**: 119+ test cases across contract, integration, and unit tests
- ✅ **Analysis**: Pre-release requirements audit (172-item checklist)

### 2025-10-17
- ✅ **Phases 1-8 Complete**: Core implementation, error handling, performance optimization
- ✅ **Implementation**: All 7 lib modules, zap.zsh entry point, install.zsh
- ✅ **Testing**: Contract tests for all user stories, performance benchmarks

## Development Workflow

### Adding New Features
1. Update `specs/001-zsh-plugin-manager/spec.md` with new requirements
2. Run `/speckit.plan` to generate implementation plan
3. Run `/speckit.tasks` to break down into tasks
4. Write tests first (TDD workflow)
5. Implement feature in appropriate lib/ module
6. Run tests to verify
7. Update documentation (README.md, quickstart.md)

### Making Changes to Existing Code
1. Read existing tests to understand current behavior
2. Write new tests for desired behavior
3. Modify implementation
4. Ensure all tests pass
5. Check for regressions with full test suite

### Before Committing
- Run all tests: `bats tests/integration/*.bats`
- Check for syntax errors: `zsh -n zap.zsh lib/*.zsh`
- Verify WHY comments explain design decisions
- Update CLAUDE.md if adding new patterns or technologies

## Common Pitfalls

### ❌ Don't
- Block shell startup on errors (violates FR-015)
- Use `eval` on user input (security risk)
- Hard-code paths (use `$ZAP_DIR`, `$ZAP_DATA_DIR`)
- Write tests after implementation (violates TDD)
- Forget to quote variables (`$var` → `"$var"`)

### ✅ Do
- Validate and sanitize all inputs (FR-027)
- Log errors to `$ZAP_ERROR_LOG`
- Use atomic file operations for cache writes (FR-035)
- Provide helpful error messages (FR-013)
- Test edge cases (version pins, missing dirs, network failures)

## Resources

- **Specification**: `specs/001-zsh-plugin-manager/spec.md`
- **Quickstart**: `specs/001-zsh-plugin-manager/quickstart.md`
- **Tasks**: `specs/001-zsh-plugin-manager/tasks.md`
- **Constitution**: `.specify/memory/constitution.md`
- **Data Model**: `specs/001-zsh-plugin-manager/data-model.md`

<!-- MANUAL ADDITIONS START -->
<!-- Add project-specific notes, tips, or guidelines here -->
<!-- MANUAL ADDITIONS END -->
