# Contributing to Zap

Thank you for your interest in contributing to Zap! This document provides guidelines and best practices for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Quality Standards](#code-quality-standards)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Architecture Overview](#architecture-overview)
- [Resources](#resources)

## Code of Conduct

We are committed to providing a welcoming and inclusive experience for everyone. By participating in this project, you agree to:

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

- **Zsh 5.0+** - Required for development and testing
- **Git** - For version control
- **BATS** - Bash Automated Testing System for integration tests
  ```bash
  # Install BATS (example for macOS)
  brew install bats-core

  # Install BATS (example for Ubuntu/Debian)
  sudo apt install bats
  ```

### Development Setup

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/zap.git
   cd zap
   ```

2. **Create a development branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Test your local installation**
   ```bash
   # In a test shell, source the local zap
   source /path/to/your/zap/zap.zsh
   ```

4. **Run tests to ensure everything works**
   ```bash
   # Run contract tests
   zsh tests/contract/test_*.zsh

   # Run integration tests
   bats tests/integration/test_*.bats

   # Check syntax
   zsh -n zap.zsh lib/*.zsh
   ```

## Development Workflow

Zap follows a strict development workflow based on our [project constitution](.specify/memory/constitution.md):

### Test-Driven Development (TDD) - NON-NEGOTIABLE

**All code changes MUST follow the Red-Green-Refactor workflow:**

1. **🔴 RED**: Write a failing test first
   - Identify the behavior you want to implement
   - Write a test that validates this behavior
   - Run the test and verify it **fails** (if it passes, your test is wrong!)

2. **🟢 GREEN**: Make the test pass
   - Implement the minimum code necessary to make the test pass
   - Run the test and verify it **passes**
   - Don't worry about code quality yet

3. **🔵 REFACTOR**: Improve the code
   - Clean up the implementation while keeping tests green
   - Run tests after each change to ensure nothing broke

**Example:**

```zsh
# Step 1: RED - Write failing test in tests/contract/test_loader.zsh
test_load_plugin_from_github() {
  # Setup
  local plugin="zsh-users/zsh-autosuggestions"

  # Execute
  zap load "$plugin"

  # Assert
  assert_plugin_loaded "$plugin"
}

# Step 2: GREEN - Implement in lib/loader.zsh
_zap_load_plugin() {
  local plugin="$1"
  # Minimal implementation to make test pass...
}

# Step 3: REFACTOR - Improve while keeping tests green
_zap_load_plugin() {
  local plugin="$1"
  # Add error handling, validation, etc.
}
```

### Adding New Features

1. **Update specification** (`specs/001-zsh-plugin-manager/spec.md`)
   - Add user story with acceptance criteria
   - Define functional requirements

2. **Write tests first** (TDD workflow)
   - Contract tests for API boundaries
   - Integration tests for user journeys

3. **Implement feature** in appropriate `lib/` module
   - Follow code quality standards (see below)
   - Add WHY comments for design decisions

4. **Run all tests** to ensure no regressions
   ```bash
   bats tests/integration/*.bats
   zsh tests/contract/test_*.zsh
   ```

5. **Update documentation**
   - Update `README.md` for user-facing changes
   - Update `specs/001-zsh-plugin-manager/quickstart.md` with examples

### Making Changes to Existing Code

1. **Read existing tests** to understand current behavior
2. **Write new tests** for desired behavior
3. **Modify implementation**
4. **Ensure all tests pass** (no regressions)
5. **Run full test suite** before committing

## Code Quality Standards

### Zsh Shell Scripting Conventions

- **Function naming**: Prefix all functions with `_zap_` to avoid conflicts
  ```zsh
  # ✅ GOOD
  _zap_load_plugin() { ... }

  # ❌ BAD
  load_plugin() { ... }  # Could conflict with user functions
  ```

- **Variable naming**: Use lowercase with underscores
  ```zsh
  # ✅ GOOD
  local plugin_name="$1"
  local plugin_dir="$ZAP_DIR/plugins/$plugin_name"

  # ❌ BAD
  local pluginName="$1"
  local PLUGIN_DIR="$ZAP_DIR/plugins/$pluginName"
  ```

- **Environment variables**: Use uppercase (e.g., `ZAP_DIR`, `ZAP_DATA_DIR`)

- **Quoting**: Always quote variables to prevent word splitting
  ```zsh
  # ✅ GOOD
  if [[ -d "$plugin_dir" ]]; then
    source "$plugin_dir/$init_file"
  fi

  # ❌ BAD
  if [[ -d $plugin_dir ]]; then
    source $plugin_dir/$init_file
  fi
  ```

### Comments: WHY Not WHAT

**Comments MUST explain design decisions, not code behavior:**

```zsh
# ❌ BAD - Restates what the code does
# Set plugin_dir to the ZAP_DIR/plugins directory
local plugin_dir="$ZAP_DIR/plugins/$plugin_name"

# ✅ GOOD - Explains why this design decision was made
# WHY: Plugins are cached in user data directory to avoid requiring
# root permissions and to enable per-user plugin isolation (FR-027)
local plugin_dir="$ZAP_DIR/plugins/$plugin_name"
```

### Function Documentation

All public functions MUST include docstrings:

```zsh
#
# _zap_load_plugin - Load and source a Zsh plugin
#
# Purpose: Downloads plugin from GitHub (if needed), sources initialization
#          files, and registers plugin in load order cache
# Parameters:
#   $1 - Plugin specification (owner/repo[@version] [path:subdir])
# Returns: 0 on success, 1 on error
#
# WHY: Central loading function enables version pinning, caching, and
#      graceful error handling per FR-001, FR-015
#
_zap_load_plugin() {
  # Implementation...
}
```

### Error Handling

- **Always check return codes** for external commands
- **Never block shell startup** on errors (FR-015)
- **Log errors** to `$ZAP_ERROR_LOG` for debugging
- **Provide actionable error messages**

```zsh
# ✅ GOOD
if ! git clone "https://github.com/${repo}.git" "$dest_dir" 2>&1 | tee -a "$ZAP_ERROR_LOG"; then
  _zap_error "[zap] Failed to clone plugin '$repo'"
  _zap_error "  Check your internet connection or plugin name"
  return 1  # Return error but don't exit shell
fi

# ❌ BAD
git clone "https://github.com/${repo}.git" "$dest_dir" || exit 1  # NEVER exit!
```

### Security Requirements

**All user inputs MUST be validated and sanitized:**

```zsh
# ✅ GOOD - Validate repository format
if [[ ! "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
  _zap_error "Invalid repository format: $repo"
  return 1
fi

# ✅ GOOD - Prevent path traversal
if [[ "$user_input" =~ \.\. ]]; then
  _zap_error "Invalid path: $user_input (path traversal detected)"
  return 1
fi

# ❌ BAD - Command injection vulnerability
eval "git clone $user_input"  # NEVER use eval on user input!
```

## Testing Requirements

### Test Coverage

- **Contract tests**: Verify API boundaries and data contracts (required)
- **Integration tests**: Validate component interactions and user journeys (required)
- **Unit tests**: Test individual functions in isolation (optional unless specified)
- **Target coverage**: 80%+ on core business logic

### Running Tests

```bash
# Run all contract tests
for test in tests/contract/test_*.zsh; do
  zsh "$test"
done

# Run all integration tests
bats tests/integration/test_*.bats

# Run specific test file
bats tests/integration/test_load.bats

# Check Zsh syntax
zsh -n zap.zsh lib/*.zsh

# Profile startup performance
ZAP_PROFILE=1 zsh -i -c exit
```

### Writing Tests

**Contract Test Example** (`tests/contract/test_loader.zsh`):

```zsh
#!/usr/bin/env zsh

# Test: Plugin loading from GitHub
test_load_plugin_from_github() {
  local plugin="zsh-users/zsh-autosuggestions"

  # Execute
  zap load "$plugin"

  # Assert plugin was cloned
  [[ -d "$ZAP_DIR/plugins/zsh-users/zsh-autosuggestions" ]] || {
    echo "FAIL: Plugin directory not created"
    return 1
  }

  echo "PASS: test_load_plugin_from_github"
}

test_load_plugin_from_github
```

**Integration Test Example** (`tests/integration/test_load.bats`):

```bash
#!/usr/bin/env bats

@test "zap load downloads and sources plugin" {
  # Setup
  export ZAP_DIR="$BATS_TEST_TMPDIR/zap"
  source "$BATS_TEST_DIRNAME/../../zap.zsh"

  # Execute
  run zap load zsh-users/zsh-autosuggestions

  # Assert
  [ "$status" -eq 0 ]
  [ -d "$ZAP_DIR/plugins/zsh-users/zsh-autosuggestions" ]
}
```

## Pull Request Process

### Before Submitting

- [ ] **All tests pass** (contract + integration)
- [ ] **Code follows style guidelines** (function naming, quoting, WHY comments)
- [ ] **New features have tests** (TDD workflow followed)
- [ ] **Documentation updated** (README.md, quickstart.md if user-facing)
- [ ] **No decrease in test coverage**
- [ ] **Security review completed** (if touching input validation or file operations)
- [ ] **Performance implications considered** (profiling for data-heavy paths)

### Commit Messages

Use clear, descriptive commit messages:

```
feat: add support for GitLab repositories

- Extend parser to recognize gitlab.com URLs
- Add integration tests for GitLab plugin loading
- Update documentation with GitLab examples

Closes #123
```

**Commit message format:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Adding or updating tests
- `refactor:` - Code refactoring
- `perf:` - Performance improvements
- `chore:` - Maintenance tasks

### Pull Request Template

When creating a PR, include:

1. **Description**: What does this PR do and why?
2. **Related Issues**: Link to issues this PR addresses
3. **Testing**: How was this tested? (include test output)
4. **Breaking Changes**: List any breaking changes
5. **Checklist**: Confirm all requirements met (see above)

### Code Review Standards

All PRs must meet these criteria:

- Follows Core Principles (Code Quality, TDD, UX, Performance, Security, Observability)
- Tests pass in CI (if configured) or local environment
- Code is readable and self-documenting
- Comments explain WHY, not WHAT
- No unaddressed review comments
- Security implications reviewed
- Performance benchmarks included (if applicable)

## Architecture Overview

### Project Structure

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
    └── quickstart.md    # User documentation
```

### Key Design Principles

1. **Graceful Degradation** (FR-015): Plugin failures NEVER block shell startup
2. **Performance First**: Sub-second startup time with 10 plugins
3. **Security by Default**: All user inputs validated, no eval on untrusted data
4. **Framework Compatibility**: Works with Oh-My-Zsh and Prezto plugins
5. **Standard Keybindings**: Respect terminal conventions (Ctrl-D = EOF, never rebind)
6. **Mode Flexibility**: Support both emacs and vi keymaps; respect user preference

### Module Responsibilities

- **parser.zsh**: Parse plugin specs, manage load order cache
- **loader.zsh**: Source plugins, handle initialization
- **downloader.zsh**: Clone repos, handle version pinning
- **updater.zsh**: Check for updates, update plugins
- **framework.zsh**: Detect and configure Oh-My-Zsh/Prezto compatibility
- **defaults.zsh**: Provide sensible keybindings and completion system
- **utils.zsh**: Shared functions (logging, error handling, validation)

## Resources

- **[Project Constitution](.specify/memory/constitution.md)** - Core principles and governance
- **[Development Guidelines](CLAUDE.md)** - AI agent guidance (also useful for humans)
- **[Feature Specification](specs/001-zsh-plugin-manager/spec.md)** - User stories and requirements
- **[Implementation Plan](specs/001-zsh-plugin-manager/plan.md)** - Technical design and architecture
- **[Quickstart Guide](specs/001-zsh-plugin-manager/quickstart.md)** - User documentation

## Questions or Issues?

- **Bug Reports**: [Open an issue](https://github.com/astrosteveo/zap/issues) with reproduction steps
- **Feature Requests**: [Open an issue](https://github.com/astrosteveo/zap/issues) describing the use case
- **Questions**: Check existing issues or start a discussion

---

**Thank you for contributing to Zap!** Your efforts help make Zsh faster and easier for everyone.
