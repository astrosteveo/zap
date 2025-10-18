# Zap Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-10-18

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
│   ├── defaults.zsh     # Default keybindings and completions
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
