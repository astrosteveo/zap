# Implementation Plan: Declarative Plugin Management

**Branch**: `002-specify-scripts-bash` | **Date**: 2025-10-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-specify-scripts-bash/spec.md`

## Summary

This feature implements revolutionary declarative plugin management for Zap, inspired by NixOS, Docker Compose, and Kubernetes. Users declare their desired plugin state in a `plugins=()` array, and Zap automatically reconciles the runtime state to match the configuration. This eliminates repetitive `zap load` commands, enables version-controlled dotfiles, supports fearless experimentation with `zap try`, and provides infrastructure-as-code semantics for shell plugin management.

**Technical Approach**:
- Text-based array parsing (no code execution for security)
- State metadata tracking in `$ZAP_DATA_DIR/state.zsh`
- Idempotent reconciliation via `zap sync` command
- Full shell reload (`exec zsh`) for v1 reconciliation
- AWK-based config file modification for `zap adopt`
- Separation of declared vs. experimental plugin states

## Technical Context

**Language/Version**: Zsh 5.0+ (shell scripting)
**Primary Dependencies**: Git, AWK, standard Unix utilities (cat, mv, date)
**Storage**: Filesystem (state metadata in `$ZAP_DATA_DIR/state.zsh`, config in `~/.zshrc`)
**Testing**: BATS (Bash Automated Testing System), contract tests, integration tests
**Target Platform**: Linux/macOS/BSD (any platform with Zsh 5.0+)
**Project Type**: Single (CLI tool, Zsh plugin manager)
**Performance Goals**:
- Shell startup: < 1s for 10 plugins, < 2s for 25 plugins
- `zap sync`: < 2s for 20 plugins
- `zap status`: < 100ms for 20 plugins
- `zap diff`: < 200ms for 20 plugins
- `zap adopt`: < 500ms

**Constraints**:
- No external dependencies beyond standard Unix tools
- Plugin errors must not block shell startup (FR-015)
- Backward compatibility with imperative `zap load` (FR-020)
- File operations must be atomic (prevent corruption)

**Scale/Scope**:
- Support 100+ plugins per configuration
- State metadata overhead < 1MB for 100 plugins
- Multi-machine sync via version-controlled dotfiles

## Constitution Check

*Re-evaluated after Phase 1 design completion*

Verify compliance with `.specify/memory/constitution.md`:

- [x] **Code Quality**: Architecture supports single responsibility; APIs will be documented; comments explain WHY not WHAT
  - ✅ Clear separation: `_zap_extract_plugins_array()`, `_zap_validate_plugin_spec()`, `_zap_calculate_drift()`, `_zap_write_state()`
  - ✅ All contracts include docstrings with purpose, parameters, returns
  - ✅ Research documents explain WHY (e.g., "full reload for v1 simplicity, incremental for v2 UX")

- [x] **Test-First**: Plan includes test phases before implementation phases
  - ✅ All contracts include comprehensive test cases (TC-SYNC-001 through TC-DIFF-006)
  - ✅ Contract tests, integration tests, security tests defined before implementation
  - ✅ 80%+ coverage requirement on reconciliation, state management, adopt logic

- [x] **UX Consistency**: User-facing changes align with existing patterns; platform-appropriate accessibility considered
  - ✅ Command naming follows infrastructure patterns (`sync`, `try`, `adopt`, `status`, `diff`)
  - ✅ All commands work in interactive and non-interactive shells
  - ✅ Progressive disclosure (`zap status` summary, `--verbose` for details)
  - ✅ Clear error messages with "what failed, why, how to fix"

- [x] **Performance**: Performance budgets defined appropriate to domain and platform; budgets are measurable and enforceable
  - ✅ All performance budgets defined in Technical Context above
  - ✅ Specific targets: sync < 2s, status < 100ms, diff < 200ms, adopt < 500ms
  - ✅ Test cases include performance verification (TC-SYNC-PERF-001, TC-STATUS-005, TC-DIFF-006)

- [x] **Documentation**: Docs organized in structured directories (specs/, docs/); no random .md files in root
  - ✅ All docs in `specs/002-specify-scripts-bash/`: plan.md, spec.md, research.md, data-model.md, quickstart.md
  - ✅ Contracts in `specs/002-specify-scripts-bash/contracts/` directory
  - ✅ No random files in repository root

- [x] **Security**: Input validation strategy defined; least privilege principle applied; secure defaults ensured
  - ✅ Strict validation: `_zap_validate_plugin_spec()` with regex, path traversal prevention
  - ✅ Text-based parsing (no code execution, no sourcing .zshrc during array extraction)
  - ✅ Atomic operations (temp file + mv) prevent corruption
  - ✅ Runs with user permissions (no root required)
  - ✅ Security test cases (TC-TRY-SEC-001 through TC-TRY-SEC-003)

- [x] **Observability**: Logging, error tracking, and debugging support planned; appropriate to platform
  - ✅ State changes logged to `$ZAP_DATA_DIR/state.log`
  - ✅ Plugin load failures logged with context (declared vs. experimental, error reason)
  - ✅ `zap status --verbose` shows detailed state (load times, versions, sources)
  - ✅ `zap diff` shows preview before applying changes

- [x] **Declarative Configuration**: If introducing configuration, follows declarative patterns; provides reconciliation; no hidden state
  - ✅ **THIS IS THE CORE FEATURE** - Full declarative paradigm implementation
  - ✅ `plugins=()` array is single source of truth (desired state)
  - ✅ Reconciliation via `zap sync` (idempotent, level-based)
  - ✅ Experimentation via `zap try` (ephemeral, clearly marked)
  - ✅ State transparency via `zap status` and `zap diff`
  - ✅ No hidden state (all behavior determined by array + explicit try commands)
  - ✅ Adoption workflow (`zap adopt`) to promote experiments to declared state

- [x] **Quality Gates**: Definition of Done criteria established; code review process defined
  - ✅ DoD: All acceptance scenarios validated, tests passing, contracts complete, quickstart documented
  - ✅ Code review: Standard Zap process applies (peer review before merge)
  - ✅ Performance budgets enforced in tests

**Result**: ✅ ALL GATES PASSED - No violations to document in Complexity Tracking

## Project Structure

### Documentation (this feature)

```
specs/002-specify-scripts-bash/
├── plan.md              # This file (/speckit.plan command output)
├── spec.md              # Feature specification (user stories, requirements, success criteria)
├── research.md          # Phase 0 output (declarative patterns, parsing, reconciliation)
├── data-model.md        # Phase 1 output (entities, relationships, state transitions)
├── quickstart.md        # Phase 1 output (user guide with examples)
├── contracts/           # Phase 1 output (command specifications)
│   ├── zap-sync.md      # Reconciliation command contract
│   ├── zap-try.md       # Experimental loading command contract
│   ├── zap-adopt.md     # Adoption command contract
│   ├── zap-status.md    # State inspection command contract
│   ├── zap-diff.md      # Drift preview command contract
│   └── state-file-format.md  # State metadata file format specification
└── checklists/          # Quality validation
    └── requirements.md  # Specification completeness checklist (all checks passed)
```

### Source Code (repository root)

```
zap/
├── zap.zsh              # Main entry point (modified to support declarative loading)
├── lib/
│   ├── declarative.zsh  # NEW: Declarative plugin management (array parsing, reconciliation)
│   ├── state.zsh        # NEW: State metadata tracking (read/write/query)
│   ├── parser.zsh       # MODIFIED: Add plugins=() array parsing
│   ├── loader.zsh       # MODIFIED: Support declarative load sources
│   ├── downloader.zsh   # REUSED: No changes needed
│   ├── updater.zsh      # MODIFIED: Respect version pins from state
│   ├── framework.zsh    # REUSED: No changes needed
│   ├── defaults.zsh     # REUSED: No changes needed
│   └── utils.zsh        # MODIFIED: Add utility functions for state management
├── tests/
│   ├── contract/
│   │   ├── test_declarative_array_parsing.zsh      # NEW
│   │   ├── test_declarative_reconciliation.zsh     # NEW
│   │   ├── test_declarative_experimentation.zsh    # NEW
│   │   ├── test_declarative_adoption.zsh           # NEW
│   │   ├── test_declarative_state_tracking.zsh     # NEW
│   │   └── test_declarative_security.zsh           # NEW
│   ├── integration/
│   │   ├── test_declarative_workflows.bats         # NEW
│   │   ├── test_sync_command.bats                  # NEW
│   │   ├── test_try_command.bats                   # NEW
│   │   ├── test_adopt_command.bats                 # NEW
│   │   ├── test_status_command.bats                # NEW
│   │   └── test_diff_command.bats                  # NEW
│   └── unit/
│       ├── test_state_metadata.zsh                 # NEW
│       ├── test_drift_calculation.zsh              # NEW
│       └── test_config_modification.zsh            # NEW
└── install.zsh          # MODIFIED: Explain declarative mode in installer
```

**Structure Decision**: Single project structure (Zsh CLI tool). All declarative logic isolated in `lib/declarative.zsh` and `lib/state.zsh` for clean separation from existing imperative code.

## Complexity Tracking

*No complexity violations - Constitution Check passed all gates*

## Phase 0: Research ✅ COMPLETE

**Objective**: Research declarative configuration patterns, Zsh array parsing, and plugin lifecycle management

**Research Completed**:
1. **Declarative Configuration Patterns** ([research.md](research.md) §1)
   - Studied NixOS, Terraform, Kubernetes, Docker Compose
   - Key findings: Desired vs. current state model, idempotent reconciliation, level-based reconciliation
   - Recommendation: Full reload (`exec zsh`) for v1, incremental unload for v2

2. **Zsh Array Parsing Techniques** ([research.md](research.md) §3)
   - Researched safe parsing strategies (no code execution)
   - Key findings: Text-based parsing with `(z)` flag, `(Q)` flag for unquoting, strict validation
   - Recommendation: Line-by-line parsing without sourcing .zshrc

3. **Plugin Unloading Strategies** ([research.md](research.md) §4)
   - Researched reconciliation approaches
   - Key findings: Full reload is simple, safe, and guarantees correct state for v1
   - Recommendation: `exec zsh` with history preservation via `INC_APPEND_HISTORY` + `fc -W`

**Key Decisions**:
- ✅ Use two-way merge for reconciliation (desired - current, current - desired)
- ✅ State metadata in `$ZAP_DATA_DIR/state.zsh` (Zsh associative array, sourceable)
- ✅ Plugin spec format: `owner/repo[@version][:subdir]`
- ✅ Pipe-delimited metadata: `state|spec|timestamp|path|version|source`
- ✅ AWK-based config modification for `zap adopt`
- ✅ Strict input validation (regex, path traversal prevention)

**Research Artifacts**:
- [research.md](research.md) - 500+ lines, comprehensive analysis
- Algorithm pseudocode for reconciliation
- Security threat model and mitigations
- Performance analysis and targets

## Phase 1: Design & Contracts ✅ COMPLETE

**Objective**: Define data model, API contracts, and user documentation

**Design Completed**:

1. **Data Model** ([data-model.md](data-model.md))
   - 5 core entities defined:
     - Plugin Specification (format, validation, parsing)
     - Declared Plugin (from `plugins=()` array)
     - Experimental Plugin (from `zap try`)
     - Plugin State Metadata (tracking info)
     - State Drift (diff calculation)
   - Entity relationships documented with diagrams
   - State transitions mapped (undeclared → experimental → declared)
   - Storage locations defined (`~/.zshrc`, `$ZAP_DATA_DIR/state.zsh`)
   - Edge cases covered (missing config, empty array, merge conflicts)

2. **API Contracts** ([contracts/](contracts/))
   - **zap-sync.md**: Reconciliation command (idempotent, full specification)
   - **zap-try.md**: Experimental loading (ephemeral, no persistence)
   - **zap-adopt.md**: Promotion to declared state (config modification)
   - **zap-status.md**: State inspection (declared vs. experimental)
   - **zap-diff.md**: Preview sync changes (drift detection)
   - **state-file-format.md**: Metadata file specification (parsing, writing, querying)

   Each contract includes:
   - Command signature and parameters
   - Preconditions and postconditions
   - Algorithm steps
   - Return codes and error handling
   - Output format (standard, verbose, machine-readable)
   - Performance requirements
   - Security considerations
   - Examples (5-6 per command)
   - Test cases (contract, performance, security)

3. **User Documentation** ([quickstart.md](quickstart.md))
   - 30-second quick start guide
   - Core concepts (declarative vs. imperative)
   - Common workflows (4 workflows with examples)
   - Plugin specification format
   - Commands reference (status, try, adopt, sync, diff)
   - Real-world examples (minimal, power user, conditional, experimentation)
   - Troubleshooting (6 common issues with fixes)
   - Migration guide (imperative → declarative)
   - Best practices (do's and don'ts)
   - Advanced usage (conditional loading, bulk management)
   - FAQ (9 questions)

**Constitution Check (Post-Design)**:
- ✅ Code Quality: Single responsibility architecture defined
- ✅ Test-First: All contracts include test cases before implementation
- ✅ UX Consistency: Command patterns, accessibility, error messages designed
- ✅ Performance: All budgets defined and measurable
- ✅ Documentation: Structured in specs/ directory
- ✅ Security: Input validation, atomic operations, no code execution
- ✅ Observability: Logging, debugging support, state transparency
- ✅ Declarative Configuration: Full declarative paradigm implemented
- ✅ Quality Gates: DoD criteria established

**Design Artifacts**:
- [data-model.md](data-model.md) - Complete entity model with diagrams
- [contracts/](contracts/) - 6 comprehensive contract specifications
- [quickstart.md](quickstart.md) - Full user guide with examples

## Phase 2: Task Generation

**Status**: NOT STARTED (requires `/speckit.tasks` command)

**Next Step**: Run `/speckit.tasks` to generate dependency-ordered implementation tasks from this plan.

The `/speckit.tasks` command will:
1. Read this plan, data model, and contracts
2. Break implementation into granular tasks
3. Establish task dependencies
4. Generate `tasks.md` with actionable work items
5. Follow TDD workflow (tests before implementation)

**Do NOT start implementation without running `/speckit.tasks` first.**

## Implementation Phases (for /speckit.tasks to expand)

### Phase 3: State Metadata System
- Implement `lib/state.zsh` (read, write, query state)
- Contract tests for state file format
- Integration tests for atomic operations

### Phase 4: Array Parsing & Validation
- Implement `_zap_extract_plugins_array()` in `lib/parser.zsh`
- Implement `_zap_validate_plugin_spec()` with security checks
- Contract tests for parsing (valid/invalid formats)
- Security tests for injection prevention

### Phase 5: Reconciliation Engine
- Implement `_zap_calculate_drift()` (two-way merge)
- Implement `zap sync` command
- Implement full reload strategy (`exec zsh`)
- Contract tests for idempotency
- Integration tests for reconciliation workflows

### Phase 6: Experimentation Support
- Implement `zap try` command
- Mark experimental plugins in state
- Contract tests for ephemeral behavior
- Integration tests for try → adopt → sync workflow

### Phase 7: Adoption Workflow
- Implement `zap adopt` command
- AWK-based config file modification
- Backup creation and atomic writes
- Contract tests for config modification
- Integration tests for adoption workflow

### Phase 8: State Inspection Commands
- Implement `zap status` command (standard, verbose, machine-readable)
- Implement `zap diff` command
- Contract tests for output formats
- Performance tests (< 100ms for status, < 200ms for diff)

### Phase 9: Integration & Backward Compatibility
- Modify `zap.zsh` to support declarative loading
- Ensure backward compatibility with `zap load` (FR-020)
- Mark legacy commands as experimental
- Integration tests for mixed mode (declarative + imperative)

### Phase 10: Documentation & Migration
- Update main README with declarative examples
- Create migration guide (imperative → declarative)
- Update `zap help` with new commands
- User acceptance testing

## Testing Strategy

### Test-Driven Development Workflow

**For each implementation phase**:
1. **RED**: Write failing contract test
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Improve while keeping tests green

### Test Coverage Requirements

- **Contract Tests** (57+ test cases):
  - `test_declarative_array_parsing.zsh` - Valid/invalid formats, security
  - `test_declarative_reconciliation.zsh` - Idempotency, drift calculation
  - `test_declarative_experimentation.zsh` - Ephemeral behavior, try command
  - `test_declarative_adoption.zsh` - Config modification, backups
  - `test_declarative_state_tracking.zsh` - Metadata read/write/query
  - `test_declarative_security.zsh` - Injection prevention, path traversal

- **Integration Tests** (62+ test cases):
  - `test_declarative_workflows.bats` - End-to-end user scenarios
  - `test_sync_command.bats` - Reconciliation, idempotency
  - `test_try_command.bats` - Experimental loading, no persistence
  - `test_adopt_command.bats` - Adoption, config updates
  - `test_status_command.bats` - State display, drift detection
  - `test_diff_command.bats` - Preview, no side effects

- **Performance Tests**:
  - `TC-SYNC-PERF-001`: 20 plugins < 2 seconds
  - `TC-STATUS-005`: 20 plugins < 100ms
  - `TC-DIFF-006`: 20 plugins < 200ms
  - `TC-ADOPT-PERF`: Config modification < 500ms

- **Security Tests**:
  - `TC-TRY-SEC-001`: Path traversal rejected
  - `TC-TRY-SEC-002`: Command injection rejected
  - `TC-TRY-SEC-003`: Absolute path rejected

**Target Coverage**: 80%+ on core business logic (reconciliation, state management, adoption)

## Success Criteria Validation

From [spec.md](spec.md):

- **SC-001**: ✅ Designed - `plugins=()` array as single source of truth
- **SC-002**: ✅ Designed - Performance budgets within 5% of imperative loading
- **SC-003**: ✅ Designed - `zap sync` < 2 seconds for 20 plugins
- **SC-004**: ✅ Designed - `zap adopt` with 95% success rate, < 500ms
- **SC-005**: ✅ Designed - `zap status` < 100ms for 20 plugins
- **SC-006**: ✅ Designed - Oh-My-Zsh-compatible syntax (zero learning curve)
- **SC-007**: ✅ Designed - Multi-machine sync < 30 seconds (git pull + zap sync)
- **SC-008**: ✅ Designed - Backward compatibility with existing zap commands
- **SC-009**: ✅ Designed - Increased confidence via try → adopt workflow
- **SC-010**: ✅ Designed - Reconciliation makes plugin removal obvious

**Validation**: All success criteria addressed in design. Implementation will verify via tests.

## Risk Assessment

### High-Priority Risks

1. **Performance Regression Risk**
   - **Concern**: Declarative loading might slow down shell startup
   - **Mitigation**: Performance budgets enforced in tests, research shows < 5% overhead
   - **Status**: Low risk (researched, budgets defined)

2. **Backward Compatibility Risk**
   - **Concern**: Existing `zap load` users might break
   - **Mitigation**: FR-020 requires simultaneous support, legacy commands marked experimental
   - **Status**: Managed (design supports both modes)

3. **Config Corruption Risk**
   - **Concern**: `zap adopt` might corrupt .zshrc
   - **Mitigation**: Backup creation, AWK-based text manipulation, atomic writes
   - **Status**: Low risk (robust design with safeguards)

### Medium-Priority Risks

4. **State Metadata Corruption Risk**
   - **Concern**: Concurrent writes to state.zsh
   - **Mitigation**: Atomic writes (temp + mv), process-specific temp files
   - **Status**: Low risk (atomic operations designed)

5. **User Adoption Risk**
   - **Concern**: Users might not migrate from imperative to declarative
   - **Mitigation**: Comprehensive quickstart, migration guide, both modes supported
   - **Status**: Managed (documentation complete, optional migration)

### Low-Priority Risks

6. **Plugin Compatibility Risk**
   - **Concern**: Some plugins might not work with full reload
   - **Mitigation**: Full reload preserves history, env vars, working dir; same as `exec zsh`
   - **Status**: Very low risk (standard Zsh behavior)

## Next Steps

**Before Starting Implementation**:
1. ✅ Phase 0 Research - COMPLETE
2. ✅ Phase 1 Design - COMPLETE
3. ⏳ **Run `/speckit.tasks`** to generate implementation tasks
4. ⏳ Review generated `tasks.md` for granular work items
5. ⏳ Begin TDD workflow (tests before implementation)

**After `/speckit.tasks`**:
- Follow task order (respects dependencies)
- Write tests first (TDD workflow)
- Implement minimum code to pass
- Refactor while keeping tests green
- Validate against success criteria after each phase

## Summary

**Planning Phase Status**: ✅ COMPLETE

**Generated Artifacts**:
- ✅ research.md (500+ lines, comprehensive)
- ✅ data-model.md (5 entities, relationships, state transitions)
- ✅ contracts/ (6 command specifications)
- ✅ quickstart.md (full user guide)
- ✅ plan.md (this file)

**Constitution Compliance**: ✅ ALL GATES PASSED

**Ready for**: `/speckit.tasks` command to generate implementation tasks

**Branch**: `002-specify-scripts-bash`
**Spec**: [spec.md](spec.md)
**Checklist**: [checklists/requirements.md](checklists/requirements.md) (all checks passed)
