# Zap Test Suite

This directory contains the test suite for Zap, organized by test type.

## Test Structure

- `contract/` - Contract tests for API boundaries and data contracts
- `integration/` - Integration tests for full user journeys and workflows
- `unit/` - Unit tests for individual functions in isolation

## Running Tests

### Prerequisites

Install BATS (Bash Automated Testing System):

```bash
# macOS
brew install bats-core

# Linux
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Run All Tests

```bash
# From repository root
bats tests/integration/*.bats

# Run specific test file
bats tests/integration/test_install.bats
```

### Run Unit Tests

```bash
# Unit tests use Zsh test framework
zsh tests/unit/test_parser.zsh
zsh tests/unit/test_loader.zsh
```

## Test Fixtures

The `fixtures/` directory contains sample plugin repositories for testing:

- `fixtures/simple-plugin/` - Basic plugin with .plugin.zsh file
- `fixtures/multi-file-plugin/` - Plugin with multiple source files
- `fixtures/framework-plugin/` - Oh-My-Zsh style plugin

## Writing Tests

Follow TDD workflow (per constitution):
1. **RED**: Write test, verify it fails
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Improve code while keeping tests green

All tests should be independent and runnable in any order.
