# Feature Specification: Zsh Plugin Manager

**Feature Branch**: `001-zsh-plugin-manager`
**Created**: 2025-10-17
**Status**: Draft
**Input**: User description: "Create a plugin manager engine for Zsh that is robust, lightweight, and easy to use. Aiming to be a modern Antigen alternative with minimal complexity, providing a working terminal out of the box with basic autocomplete, sensible keybindings, and minimal completion system."

## Clarifications

### Session 2025-10-17

- Q: When two plugins define conflicting keybindings or completions, how should the system behave? → A: Last plugin wins (load order determines priority); later plugins override earlier ones
- Q: Where should the plugin manager store downloaded plugin repositories? → A: ~/.local/share/zap/ (follows XDG Base Directory specification)
- Q: How should the system manage plugins that have dependencies on other plugins? → A: Automatically detect and install framework dependencies (Oh-My-Zsh/Prezto base libraries) when framework plugins are requested; handle transparently without user intervention
- Q: What happens when a specified plugin repository doesn't exist or is unreachable? → A: Skip the plugin with warning message on startup; shell continues to load
- Q: How does the system handle version pins that reference non-existent tags/commits? → A: Show warning about invalid pin, fall back to latest version, continue loading

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Initial Setup and Configuration (Priority: P1)

A developer wants to set up their Zsh environment quickly without reading extensive documentation or learning complex syntax. They need to install the plugin manager and add a few essential plugins with minimal effort.

**Why this priority**: This is the first experience users have with the system. If setup is complex or confusing, users will abandon the tool. A smooth installation and first-time configuration is critical for adoption.

**Independent Test**: Can be fully tested by running the installer, adding 2-3 plugins to a configuration file, and verifying the shell starts successfully with those plugins loaded.

**Acceptance Scenarios**:

1. **Given** a fresh system with Zsh installed, **When** user runs the installer, **Then** the plugin manager is installed and ready to use within 60 seconds
2. **Given** the plugin manager is installed, **When** user adds a plugin specification to their config file, **Then** the plugin is downloaded and loaded on next shell startup
3. **Given** user specifies multiple plugins, **When** shell starts, **Then** all plugins load in the correct order without manual intervention

---

### User Story 2 - Plugin Management (Priority: P1)

A user wants to add, remove, and update plugins easily. They need to pin specific versions when stability is required and update to latest versions when desired, all without complex commands or syntax.

**Why this priority**: Core functionality of a plugin manager. Users must be able to manage plugins effortlessly or the tool fails its primary purpose.

**Independent Test**: Can be tested by adding plugins, removing them, pinning versions, and checking for updates. Success means each operation works with simple, intuitive commands or configuration changes.

**Acceptance Scenarios**:

1. **Given** a plugin is specified in config, **When** user removes that specification, **Then** the plugin is no longer loaded on next shell startup
2. **Given** a plugin with version pinning (e.g., "repo@v1.2.3"), **When** shell starts, **Then** that specific version is loaded, not the latest
3. **Given** plugins are installed, **When** user checks for updates, **Then** system shows which plugins have newer versions available
4. **Given** a plugin specifies a subdirectory path (e.g., "ohmyzsh/ohmyzsh path:plugins/kubectl"), **When** shell loads, **Then** only that specific subdirectory is loaded as the plugin

---

### User Story 3 - Sensible Default Experience (Priority: P2)

A new Zsh user wants a functional terminal immediately after installation without configuring anything. The system should provide working autocomplete, intuitive keyboard shortcuts, and a minimal but functional completion system out of the box.

**Why this priority**: Differentiates this manager from complex alternatives. Provides immediate value and reduces barrier to entry for less technical users.

**Independent Test**: Can be tested by installing with default configuration and verifying standard keyboard shortcuts work (Delete, Home, End, Page Up/Down) and basic tab completion functions.

**Acceptance Scenarios**:

1. **Given** a fresh installation with no user config, **When** user presses Delete key, **Then** character under cursor is deleted
2. **Given** default configuration, **When** user presses Home/End keys, **Then** cursor moves to beginning/end of line respectively
3. **Given** default configuration, **When** user types a partial command and presses Tab, **Then** system provides relevant completions
4. **Given** default configuration, **When** user presses Page Up/Down, **Then** system scrolls through command history

---

### User Story 4 - Framework Compatibility (Priority: P2)

A user who has existing Oh-My-Zsh or Prezto plugins wants to use them with this plugin manager without rewriting or adapting their configuration significantly.

**Why this priority**: Enables migration from existing solutions and access to existing plugin ecosystems. Increases utility and adoption potential.

**Independent Test**: Can be tested by loading Oh-My-Zsh and Prezto plugins, verifying they function correctly without modification.

**Acceptance Scenarios**:

1. **Given** a user specifies an Oh-My-Zsh plugin, **When** shell loads, **Then** the plugin functions identically to how it works in Oh-My-Zsh
2. **Given** a user specifies a Prezto module, **When** shell loads, **Then** the module functions correctly
3. **Given** plugins from different frameworks are specified, **When** shell loads, **Then** all plugins coexist without conflicts

---

### User Story 5 - Performance and Startup Speed (Priority: P3)

A user with many plugins installed expects their shell to start quickly (under 1 second) and remain responsive. The plugin manager should not introduce significant overhead.

**Why this priority**: Performance is important but users can tolerate slightly longer startup for feature-rich configurations. Prioritized after core functionality.

**Independent Test**: Can be tested by measuring shell startup time with 10+ plugins and verifying it remains under 1 second on modern hardware.

**Acceptance Scenarios**:

1. **Given** 10 plugins are configured, **When** user opens a new shell, **Then** startup completes in under 1 second
2. **Given** plugins are loaded, **When** user interacts with the shell, **Then** all commands respond immediately without lag
3. **Given** plugin manager is running, **When** monitoring system resources, **Then** memory usage remains stable and minimal (under 10MB overhead)

---

### Edge Cases

- When a specified plugin repository doesn't exist or is unreachable, system skips the plugin with warning message on startup; shell continues to load
- When version pins reference non-existent tags/commits, system shows warning about invalid pin, falls back to latest version, continues loading
- When a subdirectory path specified for a plugin doesn't exist, system skips plugin with warning showing expected absolute path; shell continues to load (FR-037)
- When two plugins define conflicting keybindings or completions, last plugin wins (load order determines priority); later plugins override earlier ones
- When a plugin update breaks compatibility with the current configuration: version pinning mitigates this risk; users can pin to stable versions (out of scope for automatic detection in MVP)
- System handles partial failures by skipping failed plugins with warnings; successful plugins still load
- When disk space runs out during plugin download, system checks available space before download and fails with clear error if insufficient (< 100MB free); continues with remaining plugins (FR-038)
- System automatically detects and installs framework dependencies (Oh-My-Zsh/Prezto base libraries) when framework plugins are requested

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a simple installer that sets up the plugin manager with a single command
- **FR-002**: System MUST allow users to specify plugins using a simple text-based configuration format
- **FR-003**: System MUST support loading plugins from Git repositories (GitHub, GitLab, Bitbucket, etc.)
- **FR-004**: System MUST support version pinning using Git tags, commits, or branch names
- **FR-005**: System MUST support path annotations to load plugins from subdirectories (e.g., "repo path:subdir")
- **FR-006**: System MUST automatically download and install plugins on first use
- **FR-007**: System MUST provide a command to check if installed plugins have updates available
- **FR-008**: System MUST load plugins in a deterministic order based on configuration sequence
- **FR-009**: System MUST be compatible with Oh-My-Zsh plugins without modification
- **FR-010**: System MUST be compatible with Prezto modules without modification
- **FR-011**: System MUST provide sensible default keybindings (Delete, Home, End, Page Up/Down) out of the box
- **FR-012**: System MUST include a functional tab completion system by default
- **FR-013**: System MUST display clear, actionable error messages when plugin loading fails
- **FR-014**: System MUST allow users to disable or skip specific plugins without removing them from configuration (implemented by commenting out plugin lines in config; documented in quickstart.md)
- **FR-015**: System MUST handle plugin loading failures gracefully without preventing shell startup
- **FR-016**: When plugins define conflicting keybindings or completions, system MUST use last-loaded (later in config) plugin's bindings
- **FR-017**: System MUST automatically detect when Oh-My-Zsh or Prezto plugins are requested and install required framework base libraries transparently
- **FR-018**: When a plugin repository is unreachable or doesn't exist, system MUST skip that plugin with a warning message and continue loading remaining plugins
- **FR-019**: When a version pin references a non-existent tag/commit, system MUST show a warning, fall back to latest version, and continue loading the plugin
- **FR-020**: Configuration file format MUST support: flexible whitespace between tokens, comments starting with `#` at line start, no escape sequences required, one plugin specification per line
- **FR-021**: Plugin file sourcing MUST follow priority order: `<name>.plugin.zsh`, `<name>.zsh`, `init.zsh`, `<repo>.plugin.zsh`, `<repo>.zsh` (first match wins); when path annotation specified, search only within that subdirectory
- **FR-022**: Minimal completion system MUST provide: command completion (PATH commands), file/directory completion, option completion for common commands, history-based completion; run `compinit` once after all plugins loaded
- **FR-023**: System MUST provide uninstallation command that removes installation directory, optionally removes cache (with user confirmation), and removes initialization line from .zshrc
- **FR-024**: Plugin downloads MUST occur synchronously during first shell startup after plugin addition, with progress indicator displayed; subsequent startups load from cache
- **FR-025**: Framework detection MUST be repository-based: recognize `ohmyzsh/ohmyzsh` as Oh-My-Zsh and `sorin-ionescu/prezto` as Prezto; configure appropriate environment variables when detected
- **FR-026**: Graceful failure handling MUST: never prevent shell startup, display clear warning message, log error to errors.log, continue loading remaining plugins, mark failed plugin status in metadata, provide diagnostic command
- **FR-027**: Input validation MUST sanitize: repository names (only allow alphanumeric, dash, underscore, slash), version strings (valid Git refs), subdirectory paths (relative paths only, no `..` traversal)
- **FR-028**: Error logging MUST: write to `~/.local/share/zap/errors.log`, include timestamp (ISO 8601), log level (ERROR/WARN/INFO), plugin identifier, reason, and resolution steps; retain last 100 entries
- **FR-029**: Git operation failures MUST be handled specifically: clone failures (network/auth/not found), checkout failures (invalid ref), fetch failures (network timeout); each with actionable error messages
- **FR-030**: Network operations MUST implement 10-second timeout per plugin; display timeout warning and continue with remaining plugins
- **FR-031**: Cache corruption recovery MUST detect corrupted cache files (invalid metadata.zsh, missing .git directory), remove corrupted cache, re-download plugin on next load
- **FR-032**: System MUST support Zsh versions 5.0, 5.8, 5.9; document minimum version requirement; check version on installation and warn if unsupported
- **FR-033**: Installer MUST detect existing .zshrc and append initialization line safely (preserve existing content, add after last line, use unique marker comment)
- **FR-034**: System MUST detect conflicts with other plugin managers (Antigen, zinit, zplug) and warn user; allow coexistence but document potential issues
- **FR-035**: Concurrent shell startup MUST be safe: use atomic file operations for cache writes, skip cache update if lock detected, never corrupt metadata during concurrent access
- **FR-036**: System MUST provide mechanism for test fixtures: support local filesystem plugins (file:// URLs), mock plugin repositories, deterministic test environments
- **FR-037**: When a subdirectory path specified for a plugin doesn't exist, system MUST skip that plugin with a warning message showing the expected absolute path and continue loading remaining plugins
- **FR-038**: System MUST check available disk space before plugin download; if insufficient space (< 100MB free), fail download with clear error message and continue with remaining plugins

### Key Entities

- **Plugin Specification**: Defines a plugin with repository source, optional version pin, optional subdirectory path, and load order
- **Plugin Cache**: Local storage of downloaded plugin repositories at `~/.local/share/zap/` (follows XDG Base Directory specification)
- **Configuration File**: User-editable file listing desired plugins and settings
- **Default Configuration**: Built-in sensible defaults for keybindings and completions

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: New users can install and configure their first plugin within 5 minutes without reading documentation
- **SC-002**: Shell startup time with 10 plugins loaded completes in under 1 second on modern hardware
- **SC-003**: 95% of plugin specifications work on first attempt without syntax errors or configuration debugging
- **SC-004**: Users can check for plugin updates and identify outdated plugins in under 10 seconds
- **SC-005**: Compatibility rate with existing Oh-My-Zsh and Prezto plugins exceeds 90%
- **SC-006**: Default keyboard shortcuts work immediately after installation for 100% of standard keys (Delete, Home, End, Page Up/Down)
- **SC-007**: Tab completion provides relevant suggestions for at least 80% of common commands without additional configuration
- **SC-008**: System memory overhead remains under 10MB compared to bare Zsh installation

## Quality Requirements *(reference constitution)*

### Performance Budgets

- **Shell Startup Time**: Initial shell startup with 10 plugins < 1 second; with 25 plugins < 2 seconds
- **Plugin Update Check**: Checking 10 plugins for updates < 5 seconds
- **Memory**: RSS growth < 10MB overhead compared to bare Zsh; no memory leaks over 24-hour session
- **Disk I/O**: Plugin installation download and extraction < 30 seconds for typical plugin (< 5MB)

### UX & Accessibility

- **Consistency**: Configuration syntax should be uniform and predictable (same pattern for all plugin types)
- **Accessibility**: Terminal-based interface must work with screen readers and support high-contrast themes
- **Response Feedback**: Plugin operations acknowledge immediately; long operations (downloads) show progress indicators
- **Error Handling**: Error messages must state what failed, why it failed, and how to fix it (e.g., "Plugin 'user/repo' not found. Check repository name or network connection.")

### Testing Requirements

- **Test-First**: TDD workflow required (tests written before implementation)
- **Coverage**: Minimum 80% coverage for core plugin loading, version pinning, and update checking logic
- **Test Types**: Contract tests for plugin specification parsing + Integration tests for full plugin installation and loading workflows required; unit tests for utility functions

### Code Quality Standards

- **Documentation**: Public functions must include docstrings explaining purpose, parameters, return values, and error conditions
- **Review**: All code changes require peer review before merging
- **Maintainability**: Code must follow single responsibility principle; complex plugin loading logic must be broken into focused functions with clear purposes
- **Comments Explain WHY**: Comments should explain rationale for design decisions, not restate code (per constitution principle I)

## Assumptions

1. **Target Platform**: Assumes Zsh version 5.0 or later is installed
2. **Network Access**: Assumes internet connectivity for downloading plugins from Git repositories
3. **Git Availability**: Assumes Git is installed and accessible in PATH
4. **Filesystem Permissions**: Assumes user has write permissions to home directory for storing plugin cache
5. **Default Shell**: Assumes Zsh is set as user's default shell or user knows how to invoke it
6. **Update Frequency**: Plugin update checks are manual (user-initiated), not automatic background processes
7. **Plugin Naming**: Assumes standard Git hosting conventions (GitHub user/repo format)
8. **Configuration Location**: Assumes configuration file in standard Zsh config directory (~/.zshrc or similar)
9. **Cache Location**: Plugin cache stored at `~/.local/share/zap/` following XDG Base Directory specification
