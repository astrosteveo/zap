# Feature Specification: Declarative Plugin Management

**Feature Branch**: `002-specify-scripts-bash`
**Created**: 2025-10-18
**Status**: Draft
**Input**: Revolutionary declarative plugin management system inspired by NixOS/Docker/Kubernetes patterns

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Declare Desired Plugin State (Priority: P1)

Users declare their desired plugin configuration in a simple array format, and Zap automatically loads all plugins on shell startup without requiring repetitive imperative commands.

**Why this priority**: This is the core value proposition - eliminating repetitive `zap load` commands and providing a single source of truth for plugin configuration. Without this, users cannot adopt the declarative paradigm.

**Independent Test**: Can be fully tested by creating a `plugins=()` array in `.zshrc`, sourcing `zap.zsh`, and verifying all declared plugins are loaded automatically.

**Acceptance Scenarios**:

1. **Given** an empty `.zshrc`, **When** user adds `plugins=('zsh-users/zsh-syntax-highlighting')` and sources `zap.zsh`, **Then** syntax highlighting plugin is automatically loaded
2. **Given** a plugins array with 5 plugins, **When** user starts a new shell, **Then** all 5 plugins are loaded in array order within the startup time budget
3. **Given** plugins array contains version-pinned plugins (`owner/repo@v1.0.0`), **When** shell starts, **Then** correct versions are loaded
4. **Given** plugins array contains subdirectory plugins (`ohmyzsh/ohmyzsh:plugins/git`), **When** shell starts, **Then** correct subdirectories are loaded
5. **Given** plugins array is empty, **When** shell starts, **Then** no plugins are loaded but shell remains functional

---

### User Story 2 - Experiment with Temporary Plugins (Priority: P1)

Users can try new plugins temporarily without modifying their configuration file, enabling fearless experimentation with the confidence they can return to their declared state.

**Why this priority**: Experimentation is critical for plugin discovery. Without this, users would either clutter their config with experiments or be afraid to try new plugins.

**Independent Test**: Can be fully tested by running `zap try owner/repo`, verifying the plugin loads, then running `zap sync` and confirming the experimental plugin is removed.

**Acceptance Scenarios**:

1. **Given** a declared plugin state, **When** user runs `zap try new/plugin`, **Then** plugin loads immediately and is marked as experimental
2. **Given** an experimental plugin is loaded, **When** user runs `zap status`, **Then** system shows experimental plugin separately from declared plugins
3. **Given** multiple experimental plugins loaded, **When** user restarts shell, **Then** experimental plugins are NOT automatically reloaded (ephemeral state)
4. **Given** experimental plugins loaded, **When** user runs `zap sync`, **Then** all experimental plugins are unloaded and only declared plugins remain
5. **Given** user runs `zap try` on already-declared plugin, **Then** system indicates plugin is already declared and takes no action

---

### User Story 3 - Reconcile to Declared State (Priority: P1)

Users can return their shell to the exact state defined in their configuration file with a single command, regardless of what experimental changes they've made during the session.

**Why this priority**: Reconciliation is the cornerstone of declarative systems. Without it, the declarative model breaks down and state drift occurs.

**Independent Test**: Can be fully tested by loading experimental plugins, running `zap sync`, and verifying runtime state matches config file exactly.

**Acceptance Scenarios**:

1. **Given** 3 declared plugins and 2 experimental plugins loaded, **When** user runs `zap sync`, **Then** experimental plugins unload and only 3 declared plugins remain
2. **Given** declared plugin was manually unloaded, **When** user runs `zap sync`, **Then** declared plugin is reloaded
3. **Given** config file was modified while shell running, **When** user runs `zap sync`, **Then** runtime state updates to match new config
4. **Given** no state drift (runtime matches config), **When** user runs `zap sync`, **Then** system reports "already synced" and takes no action
5. **Given** user runs `zap sync`, **When** command completes, **Then** summary shows what was added/removed and final state matches config

---

### User Story 4 - Adopt Experiments (Priority: P2)

Users can promote successful experiments to their declared configuration with a single command, automatically updating their config file.

**Why this priority**: Reduces friction in the experiment-to-production workflow. Makes it easy to keep config file in sync with runtime state.

**Independent Test**: Can be fully tested by running `zap try plugin`, then `zap adopt plugin`, and verifying the plugin appears in the `.zshrc` plugins array.

**Acceptance Scenarios**:

1. **Given** experimental plugin loaded, **When** user runs `zap adopt plugin-name`, **Then** plugin is appended to `plugins=()` array in `.zshrc`
2. **Given** experimental plugin adopted, **When** user runs `zap status`, **Then** plugin now shows as "declared" not "experimental"
3. **Given** already-declared plugin, **When** user runs `zap adopt plugin-name`, **Then** system reports plugin already declared and takes no action
4. **Given** non-loaded plugin, **When** user runs `zap adopt plugin-name`, **Then** system reports plugin must be loaded first (via `zap try`)
5. **Given** user runs `zap adopt`, **When** multiple experimental plugins exist, **Then** system prompts which to adopt or adopts all with confirmation

---

### User Story 5 - Inspect State Drift (Priority: P2)

Users can view the difference between their declared configuration and current runtime state, understanding exactly what would change if they reconcile.

**Why this priority**: Transparency is key to user confidence. Users need to understand what `sync` will do before running it.

**Independent Test**: Can be fully tested by creating state drift, running `zap status` and `zap diff`, and verifying accurate reporting.

**Acceptance Scenarios**:

1. **Given** state drift exists, **When** user runs `zap status`, **Then** system shows declared plugins, experimental plugins, and drift clearly
2. **Given** state drift exists, **When** user runs `zap diff`, **Then** system shows what plugins would be added/removed if synced
3. **Given** no state drift, **When** user runs `zap status`, **Then** system reports "All plugins synced with config"
4. **Given** user runs `zap diff`, **When** user hasn't synced yet, **Then** diff shows preview without making changes
5. **Given** user runs `zap diff --verbose`, **When** state drift exists, **Then** system shows detailed information about each plugin (version, path, load time)

---

### User Story 6 - Multi-Machine Sync (Priority: P3)

Users maintain identical plugin configurations across multiple machines by syncing their dotfiles repository, with Zap automatically reconciling each machine to the declared state.

**Why this priority**: This enables the infrastructure-as-code model for shell configuration, valuable for power users and team environments.

**Independent Test**: Can be fully tested by pushing config to git from one machine, pulling on another, and running `zap sync` to verify state convergence.

**Acceptance Scenarios**:

1. **Given** machine A has plugins=('foo' 'bar'), **When** user adds 'baz' and pushes to git, **Then** machine B can pull and sync to match
2. **Given** different experimental plugins on each machine, **When** user runs `zap sync` on both, **Then** both machines have identical declared state
3. **Given** config file shared via dotfiles repo, **When** new team member clones and runs `zap sync`, **Then** all team-standard plugins install
4. **Given** user has machine-specific needs, **When** config uses conditional logic (`[[ $HOST == ... ]]`), **Then** each machine loads appropriate plugins
5. **Given** plugins are pinned to versions in config, **When** multiple machines sync, **Then** all machines use identical plugin versions

---

### Edge Cases

- What happens when a declared plugin repository doesn't exist (404)?
  - System logs error to error log, shows warning at shell startup, continues with other plugins
- What happens when user modifies plugins array while shell is running?
  - Changes take effect on next `zap sync` or next shell restart
- What happens when experimental plugin has same name as declared plugin?
  - Declared plugin takes precedence; experimental `zap try` is no-op with informational message
- What happens when git pull creates merge conflict in plugins array?
  - Standard git conflict resolution; user manually resolves array, then `zap sync`
- What happens when user runs `zap adopt` but `.zshrc` is read-only?
  - System reports permission error with clear message about file permissions
- What happens when plugin loads successfully but crashes shell later?
  - Plugin remains in config; user can remove from array and sync, or comment out temporarily

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support declarative plugin configuration via a `plugins=()` array in user's `.zshrc`
- **FR-002**: System MUST automatically load all plugins from the declared array on shell startup without imperative commands
- **FR-003**: System MUST support plugin specifications in format `owner/repo`, `owner/repo@version`, `owner/repo:subdir`, `owner/repo@version:subdir`
- **FR-004**: Users MUST be able to experiment with plugins using `zap try owner/repo` command without modifying configuration file
- **FR-005**: System MUST distinguish experimental plugins from declared plugins in all state tracking and commands
- **FR-006**: Users MUST be able to reconcile runtime state to declared state using `zap sync` command
- **FR-007**: Reconciliation MUST be idempotent (safe to run multiple times with same result)
- **FR-008**: Users MUST be able to promote experimental plugins to declared state using `zap adopt plugin-name` command
- **FR-009**: System MUST automatically update `.zshrc` plugins array when user adopts an experimental plugin
- **FR-010**: Users MUST be able to view current state vs. declared state using `zap status` command
- **FR-011**: Users MUST be able to preview sync changes using `zap diff` command
- **FR-012**: System MUST track plugin state (declared vs. experimental) in metadata file
- **FR-013**: System MUST preserve plugin load order as defined in plugins array
- **FR-014**: Experimental plugins MUST NOT persist across shell restarts (ephemeral by design)
- **FR-015**: System MUST NOT modify configuration file without explicit user command (`zap adopt`)
- **FR-016**: System MUST support conditional plugin loading via standard Zsh syntax (if/case statements modifying plugins array)
- **FR-017**: System MUST work with version-controlled dotfiles (plugins array is the only source of truth)
- **FR-018**: Errors loading individual plugins MUST NOT prevent other plugins from loading
- **FR-019**: System MUST maintain backward compatibility with existing zap functionality (update, list, clean, doctor commands)
- **FR-020**: System MUST support both declared (array) and imperative (`zap load`) modes simultaneously for migration period

### Key Entities

- **Plugin Specification**: A string defining a plugin in format `owner/repo[@version][:subdir]`
  - Attributes: owner, repository name, optional version, optional subdirectory
  - Must be parseable and validatable

- **Declared Plugin**: A plugin listed in the `plugins=()` array in `.zshrc`
  - State: declared
  - Persists across shell sessions
  - Source of truth for configuration

- **Experimental Plugin**: A plugin loaded via `zap try` command
  - State: experimental
  - Ephemeral (not reloaded on shell restart)
  - Can be promoted to declared via `zap adopt`

- **Plugin State Metadata**: Tracked information about each loaded plugin
  - Attributes: name, state (declared/experimental), load timestamp, version, source (array vs. command)
  - Persisted in `$ZAP_DATA_DIR/state.zsh`

- **State Drift**: Difference between declared configuration and runtime state
  - Calculated by comparing plugins array to currently loaded plugins
  - Resolved by reconciliation command

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can configure all their plugins in a single `plugins=()` array without any repetitive commands
- **SC-002**: Shell startup time with declarative plugin loading is within 5% of current imperative loading performance
- **SC-003**: Users can experiment with 10 different plugins and return to declared state in under 2 seconds via `zap sync`
- **SC-004**: 95% of `zap adopt` commands successfully update `.zshrc` without manual file editing
- **SC-005**: State drift detection (`zap status`) completes in under 100ms for typical configurations (< 20 plugins)
- **SC-006**: Zero learning curve for users already familiar with Oh-My-Zsh's `plugins=()` array syntax
- **SC-007**: Multi-machine sync workflow (git pull + `zap sync`) converges to identical state in under 30 seconds
- **SC-008**: 100% of existing zap commands (update, list, clean, doctor) continue to work with declarative configuration
- **SC-009**: Users report increased confidence in plugin experimentation (measured via user survey post-launch)
- **SC-010**: Support requests related to "how do I remove a plugin" decrease by 80% (reconciliation makes it obvious)

## Quality Requirements *(reference constitution)*

### Performance Budgets

- **Shell Startup**: Declarative loading must complete within same performance budget as imperative loading (< 1s for 10 plugins)
- **Sync Command**: `zap sync` must complete in under 2 seconds for 20 plugins
- **Status Command**: `zap status` must complete in under 100ms
- **Diff Command**: `zap diff` must complete in under 200ms
- **Adopt Command**: `zap adopt` must complete (including file write) in under 500ms
- **Memory**: State metadata overhead must not exceed 1MB for 100 plugins

### UX & Accessibility

- **Consistency**: Command naming follows declarative infrastructure patterns (sync/try/adopt vs. apply/test/promote)
- **Accessibility**: All commands must work in both interactive and non-interactive shells (script-friendly)
- **Response Feedback**: State changes must show summary of what was added/removed before and after
- **Error Handling**: Error messages must explain what failed, why, and how to fix (e.g., "Plugin foo/bar not found - check repository name")
- **Progressive Disclosure**: `zap status` shows summary; `zap status --verbose` shows detailed information

### Testing Requirements

- **Test-First**: TDD workflow required (tests written before implementation)
- **Coverage**: Minimum 80% coverage on state management, reconciliation, and adopt logic
- **Test Types**:
  - Contract tests: Plugin specification parsing, state file format, config file parsing
  - Integration tests: Full workflows (declare → try → adopt → sync), multi-machine scenarios
  - Unit tests: Individual functions for state comparison, drift detection, file updates

### Code Quality Standards

- **Documentation**: All public commands (`sync`, `try`, `adopt`, `status`, `diff`) must have docstrings and usage examples
- **Review**: All code changes require peer review before merging
- **Maintainability**: Declarative plugin loading logic must be isolated from imperative loading logic for clean migration

### Security Requirements

- **Input Validation**: Plugin specifications must be validated before use (prevent path traversal, command injection)
- **Permissions**: `.zshrc` modifications must preserve file ownership and permissions
- **Secure Defaults**: Experimental plugins must not modify declared configuration without explicit user consent
- **Secrets Management**: N/A (no secrets involved in plugin configuration)
- **Dependencies**: Existing dependency security practices apply (git, core utils)

### Observability Requirements

- **Logging**: Log state changes (sync operations, adoptions) to `$ZAP_DATA_DIR/state.log` with timestamps
- **Error Tracking**: All plugin load failures must be logged with context (declared vs. experimental, error reason)
- **Monitoring**: N/A (no production monitoring needed for CLI tool)
- **Debugging Support**: `zap status --verbose` must show detailed state including load times, versions, sources
- **Operational Transparency**:
  - `zap status` shows current vs. declared state
  - `zap diff` shows what sync would change
  - `zap sync` shows summary of changes made

### Declarative Configuration Requirements

- **Configuration Model**:
  - Plugins declared in `plugins=()` array represent desired end state
  - Array is the single source of truth for plugin configuration
  - Array supports standard Zsh syntax (conditionals, variable expansion)

- **Reconciliation**:
  - `zap sync` command reconciles runtime state to declared state
  - Idempotent (safe to run multiple times)
  - Shows summary of changes (added/removed plugins)

- **Experimentation**:
  - `zap try plugin-name` loads plugin as experimental (ephemeral state)
  - Experimental plugins clearly marked in `zap status` output
  - Experimental plugins do not persist across shell restarts

- **State Transparency**:
  - `zap status` shows declared vs. experimental vs. drift
  - `zap diff` shows preview of sync changes
  - State metadata tracks source of each loaded plugin

- **No Hidden State**:
  - All plugin loading via array or explicit experimental commands
  - Legacy `zap load` command still works but marked as temporary/experimental
  - System behavior fully determined by plugins array + explicit try commands
