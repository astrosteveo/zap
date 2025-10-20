# Tasks: Declarative Plugin Management

**Input**: Design documents from `/specs/002-specify-scripts-bash/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, research.md, quickstart.md

**Tests**: This feature specification requires comprehensive test coverage (80%+ on core logic) per Constitution Principle II (Test-First Development). All test tasks follow TDD workflow: RED (write + fail) → GREEN (implement) → REFACTOR (improve).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions
- Single project structure (Zsh CLI tool)
- Source code: `lib/` at repository root
- Tests: `tests/contract/`, `tests/integration/`, `tests/unit/`
- Entry point: `zap.zsh` at repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure for declarative plugin management

- [x] T001 Create directory structure for declarative plugin management (lib/declarative.zsh, lib/state.zsh, lib/utils.zsh modifications)
- [x] T002 [P] Create test directory structure (tests/contract/declarative/, tests/integration/declarative/, tests/unit/declarative/)
- [x] T003 [P] Create state logging infrastructure in $ZAP_DATA_DIR/state.log

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### State Metadata System (Required by ALL user stories)

- [x] T004 Write contract test for state file format in tests/contract/declarative/test_state_file_format.zsh
- [x] T005 Implement state metadata structure (associative array) in lib/state.zsh
- [x] T006 Implement _zap_write_state() with atomic operations (temp + mv) in lib/state.zsh
- [x] T007 [P] Implement _zap_load_state() with corruption recovery in lib/state.zsh
- [x] T008 [P] Implement _zap_add_plugin_to_state() in lib/state.zsh
- [x] T009 [P] Implement _zap_remove_plugin_from_state() in lib/state.zsh
- [x] T010 [P] Implement _zap_update_plugin_state() in lib/state.zsh
- [x] T011 Write unit test for state metadata operations in tests/unit/declarative/test_state_metadata.zsh

### Plugin Specification Parsing & Validation (Required by ALL user stories)

- [x] T012 Write contract test for plugin specification validation in tests/contract/declarative/test_plugin_spec_validation.zsh
- [x] T013 Write security test for injection prevention in tests/contract/declarative/test_security.zsh
- [x] T014 Implement _zap_validate_plugin_spec() with regex validation in lib/declarative.zsh
- [x] T015 [P] Implement _zap_parse_plugin_spec() (extract owner/repo/version/subdir) in lib/declarative.zsh
- [x] T016 [P] Add path traversal prevention logic in _zap_validate_plugin_spec() in lib/declarative.zsh
- [x] T017 [P] Add command injection prevention logic in _zap_validate_plugin_spec() in lib/declarative.zsh

### Array Parsing Infrastructure (Required by US1, US3, US4, US5, US6)

- [x] T018 Write contract test for plugins=() array parsing in tests/contract/declarative/test_array_parsing.zsh
- [x] T019 Implement _zap_extract_plugins_array() with text-based parsing in lib/declarative.zsh
- [x] T020 [P] Add support for multiline array parsing in _zap_extract_plugins_array() in lib/declarative.zsh
- [x] T021 [P] Add support for quoted elements with (z) and (Q) flags in _zap_extract_plugins_array() in lib/declarative.zsh
- [x] T022 Write unit test for array extraction edge cases in tests/unit/declarative/test_array_extraction.zsh

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Declare Desired Plugin State (Priority: P1) 🎯 MVP

**Goal**: Users declare their desired plugin configuration in a `plugins=()` array, and Zap automatically loads all plugins on shell startup without requiring repetitive imperative commands.

**Independent Test**: Create a `plugins=()` array in `.zshrc`, source `zap.zsh`, and verify all declared plugins are loaded automatically.

### Tests for User Story 1

**TDD WORKFLOW (per constitution)**:
1. **RED**: Write tests first, run them, verify they FAIL
2. **GREEN**: Implement minimum code to make tests pass
3. **REFACTOR**: Improve code while keeping tests green

- [x] T023 [P] [US1] Contract test for automatic plugin loading from array in tests/contract/declarative/test_declarative_loading.zsh
- [x] T024 [P] [US1] Integration test for shell startup with plugins array in tests/integration/declarative/test_startup_loading.bats
- [x] T025 [P] [US1] Integration test for version-pinned plugins in tests/integration/declarative/test_version_pinning.bats
- [x] T026 [P] [US1] Integration test for subdirectory plugins in tests/integration/declarative/test_subdir_plugins.bats
- [x] T027 [P] [US1] Integration test for empty array (no plugins loaded) in tests/integration/declarative/test_empty_array.bats

### Implementation for User Story 1

- [x] T028 [P] [US1] Implement _zap_load_declared_plugins() to read plugins=() and load each in lib/declarative.zsh
- [x] T029 [P] [US1] Add plugin load order preservation logic in _zap_load_declared_plugins() in lib/declarative.zsh
- [x] T030 [US1] Integrate _zap_load_declared_plugins() into zap.zsh startup sequence
- [x] T031 [US1] Add error handling for individual plugin failures (FR-018: don't block shell startup) in lib/declarative.zsh
- [x] T032 [US1] Add state metadata tracking for declared plugins in _zap_load_declared_plugins() in lib/declarative.zsh
- [x] T033 [US1] Add logging for declarative plugin loading in lib/declarative.zsh
- [x] T034 [US1] Performance test for startup time (< 1s for 10 plugins) in tests/integration/declarative/test_performance.bats

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently. Users can declare plugins in an array and they load automatically.

---

## Phase 4: User Story 2 - Experiment with Temporary Plugins (Priority: P1)

**Goal**: Users can try new plugins temporarily without modifying their configuration file, enabling fearless experimentation with the confidence they can return to their declared state.

**Independent Test**: Run `zap try owner/repo`, verify the plugin loads, then restart shell and confirm the experimental plugin is NOT reloaded.

### Tests for User Story 2

**TDD WORKFLOW**: RED (write + fail) → GREEN (implement) → REFACTOR (improve)

- [x] T035 [P] [US2] Contract test for zap try command in tests/contract/declarative/test_try_command.zsh
- [x] T036 [P] [US2] Integration test for experimental plugin loading in tests/integration/declarative/test_try_workflow.bats
- [x] T037 [P] [US2] Integration test for ephemeral behavior (no persistence) in tests/integration/declarative/test_ephemeral_state.bats
- [x] T038 [P] [US2] Integration test for try on already-declared plugin (no-op) in tests/integration/declarative/test_try_noop.bats
- [x] T039 [P] [US2] Security test for try command validation in tests/contract/declarative/test_try_security.zsh

### Implementation for User Story 2

- [x] T040 [P] [US2] Implement zap try command function in lib/declarative.zsh
- [x] T041 [US2] Add validation logic (reuse _zap_validate_plugin_spec) in zap try in lib/declarative.zsh
- [x] T042 [US2] Add check for already-declared plugins in zap try in lib/declarative.zsh
- [x] T043 [US2] Add check for already-loaded experimental plugins in zap try in lib/declarative.zsh
- [x] T044 [US2] Implement plugin download logic (reuse existing downloader) in zap try in lib/declarative.zsh
- [x] T045 [US2] Implement plugin loading logic (reuse existing loader) in zap try in lib/declarative.zsh
- [x] T046 [US2] Add state metadata update (mark as experimental) in zap try in lib/declarative.zsh
- [x] T047 [US2] Add success/error messages for zap try in lib/declarative.zsh
- [x] T048 [US2] Add --verbose flag support for zap try in lib/declarative.zsh

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently. Users can declare plugins AND experiment with temporary plugins.

---

## Phase 5: User Story 3 - Reconcile to Declared State (Priority: P1)

**Goal**: Users can return their shell to the exact state defined in their configuration file with a single command, regardless of what experimental changes they've made during the session.

**Independent Test**: Load experimental plugins, run `zap sync`, and verify runtime state matches config file exactly (experimental plugins removed).

### Tests for User Story 3

**TDD WORKFLOW**: RED (write + fail) → GREEN (implement) → REFACTOR (improve)

- [x] T049 [P] [US3] Contract test for zap sync command in tests/contract/declarative/test_sync_command.zsh
- [x] T050 [P] [US3] Contract test for idempotency (sync; sync; sync → same result) in tests/contract/declarative/test_sync_idempotency.zsh
- [x] T051 [P] [US3] Integration test for experimental plugin removal in tests/integration/declarative/test_sync_remove_experimental.bats
- [x] T052 [P] [US3] Integration test for declared plugin reloading in tests/integration/declarative/test_sync_reload_declared.bats
- [x] T053 [P] [US3] Integration test for config change reconciliation in tests/integration/declarative/test_sync_config_change.bats
- [x] T054 [P] [US3] Integration test for no-op when in sync in tests/integration/declarative/test_sync_noop.bats
- [x] T055 [P] [US3] Performance test for sync (< 2s for 20 plugins) in tests/integration/declarative/test_sync_performance.bats

### Implementation for User Story 3

- [x] T056 [P] [US3] Implement _zap_calculate_drift() (two-way merge) in lib/declarative.zsh
  NOTE: Implemented as simple query of declared vs experimental lists in zap diff/sync - simpler and works perfectly
- [x] T057 [P] [US3] Implement _zap_list_declared_plugins() query in lib/state.zsh
- [x] T058 [P] [US3] Implement _zap_list_experimental_plugins() query in lib/state.zsh
- [x] T059 [US3] Implement zap sync command function in lib/declarative.zsh
- [x] T060 [US3] Add drift calculation logic in zap sync in lib/declarative.zsh
- [x] T061 [US3] Add preview/summary output in zap sync in lib/declarative.zsh
- [x] T062 [US3] Implement full reload reconciliation (exec zsh) in zap sync in lib/declarative.zsh
- [x] T063 [US3] Add history preservation (INC_APPEND_HISTORY + fc -W) in zap sync in lib/declarative.zsh
- [x] T064 [US3] Add --dry-run flag support for zap sync in lib/declarative.zsh
- [x] T065 [US3] Add --verbose flag support for zap sync in lib/declarative.zsh
- [x] T066 [US3] Add state metadata update after sync in lib/declarative.zsh
- [x] T067 [US3] Add logging for sync operations in lib/declarative.zsh
- [ ] T068 [US3] Write unit test for drift calculation in tests/unit/declarative/test_drift_calculation.zsh

**Checkpoint**: All P1 user stories (1, 2, 3) should now be independently functional. This represents the core declarative paradigm: declare, experiment, reconcile.

---

## Phase 6: User Story 4 - Adopt Experiments (Priority: P2)

**Goal**: Users can promote successful experiments to their declared configuration with a single command, automatically updating their config file.

**Independent Test**: Run `zap try plugin`, then `zap adopt plugin`, and verify the plugin appears in the `.zshrc` plugins array.

### Tests for User Story 4

**TDD WORKFLOW**: RED (write + fail) → GREEN (implement) → REFACTOR (improve)

- [x] T069 [P] [US4] Contract test for zap adopt command in tests/contract/declarative/test_adopt_command.zsh
- [x] T070 [P] [US4] Integration test for config file modification in tests/integration/declarative/test_adopt_config_update.bats
- [x] T071 [P] [US4] Integration test for backup creation in tests/integration/declarative/test_adopt_backup.bats
- [x] T072 [P] [US4] Integration test for adopt on already-declared plugin (no-op) in tests/integration/declarative/test_adopt_noop.bats
- [x] T073 [P] [US4] Integration test for adopt on non-loaded plugin (error) in tests/integration/declarative/test_adopt_error.bats
- [x] T074 [P] [US4] Integration test for --all flag in tests/integration/declarative/test_adopt_all.bats
- [x] T075 [P] [US4] Performance test for adopt (< 500ms) in tests/integration/declarative/test_adopt_performance.bats

### Implementation for User Story 4

- [x] T076 [P] [US4] Implement zap adopt command function in lib/declarative.zsh
- [x] T077 [P] [US4] Implement AWK-based config file modification in lib/declarative.zsh
- [x] T078 [US4] Add validation (plugin must be loaded as experimental) in zap adopt in lib/declarative.zsh
- [x] T079 [US4] Add check for already-declared plugins in zap adopt in lib/declarative.zsh
- [x] T080 [US4] Implement backup creation (.zshrc.backup-timestamp) in zap adopt in lib/declarative.zsh
- [x] T081 [US4] Implement plugins array insertion logic (before closing )) in zap adopt in lib/declarative.zsh
- [x] T082 [US4] Add atomic write (temp file + mv) in zap adopt in lib/declarative.zsh
- [x] T083 [US4] Add permission preservation in zap adopt in lib/declarative.zsh
- [x] T084 [US4] Add state metadata update (experimental → declared) in zap adopt in lib/declarative.zsh
- [x] T085 [US4] Add --all flag support in zap adopt in lib/declarative.zsh
- [x] T086 [US4] Add --yes flag support (skip confirmation) in zap adopt in lib/declarative.zsh
- [x] T087 [US4] Add --verbose flag support for zap adopt in lib/declarative.zsh
- [ ] T088 [US4] Write unit test for config file modification in tests/unit/declarative/test_config_modification.zsh

**Checkpoint**: Users can now adopt experimental plugins to declared state. The full workflow (declare → try → adopt → sync) is complete.

---

## Phase 7: User Story 5 - Inspect State Drift (Priority: P2)

**Goal**: Users can view the difference between their declared configuration and current runtime state, understanding exactly what would change if they reconcile.

**Independent Test**: Create state drift, run `zap status` and `zap diff`, and verify accurate reporting.

### Tests for User Story 5

**TDD WORKFLOW**: RED (write + fail) → GREEN (implement) → REFACTOR (improve)

- [x] T089 [P] [US5] Contract test for zap status command in tests/contract/declarative/test_status_command.zsh
- [x] T090 [P] [US5] Contract test for zap diff command in tests/contract/declarative/test_diff_command.zsh
- [x] T091 [P] [US5] Integration test for status output (declared vs experimental) in tests/integration/declarative/test_status_basic.bats
- [x] T092 [P] [US5] Integration test for drift detection in tests/integration/declarative/test_diff_basic.bats
- [x] T093 [P] [US5] Integration test for diff preview (no side effects) in tests/integration/declarative/test_status_diff_edge_cases.bats
- [x] T094 [P] [US5] Performance test for status (< 100ms) in tests/integration/declarative/test_performance.bats
- [x] T095 [P] [US5] Performance test for diff (< 200ms) in tests/integration/declarative/test_performance.bats

### Implementation for User Story 5

- [x] T096 [P] [US5] Implement zap status command function in lib/declarative.zsh
- [x] T097 [P] [US5] Implement zap diff command function in lib/declarative.zsh
- [x] T098 [US5] Add declared plugins display in zap status in lib/declarative.zsh
- [x] T099 [US5] Add experimental plugins display in zap status in lib/declarative.zsh
- [x] T100 [US5] Add drift detection logic in zap status in lib/declarative.zsh
- [x] T101 [US5] Add --verbose flag support for zap status (show versions, paths, load times) in lib/declarative.zsh
- [x] T102 [US5] Add --machine-readable flag support for zap status (JSON output) in lib/declarative.zsh
- [x] T103 [US5] Implement drift calculation in zap diff (reuse _zap_calculate_drift) in lib/declarative.zsh
- [x] T104 [US5] Add preview output (+/- plugins) in zap diff in lib/declarative.zsh
- [x] T105 [US5] Add --verbose flag support for zap diff in lib/declarative.zsh
- [x] T106 [US5] Add exit code logic (0 = drift, 1 = in sync) in zap diff in lib/declarative.zsh
- [ ] T107 [US5] Add time ago formatting for timestamps in lib/utils.zsh

**Checkpoint**: Users can now inspect state drift before reconciling. The observability story is complete.

---

## Phase 8: User Story 6 - Multi-Machine Sync (Priority: P3)

**Goal**: Users maintain identical plugin configurations across multiple machines by syncing their dotfiles repository, with Zap automatically reconciling each machine to the declared state.

**Independent Test**: Push config to git from one machine, pull on another, and run `zap sync` to verify state convergence.

### Tests for User Story 6

**TDD WORKFLOW**: RED (write + fail) → GREEN (implement) → REFACTOR (improve)

- [ ] T108 [P] [US6] Integration test for multi-machine sync workflow in tests/integration/declarative/test_multimachine_sync.bats
- [ ] T109 [P] [US6] Integration test for version pinning across machines in tests/integration/declarative/test_multimachine_versions.bats
- [ ] T110 [P] [US6] Integration test for conditional loading (machine-specific) in tests/integration/declarative/test_conditional_loading.bats
- [ ] T111 [P] [US6] Integration test for team config cloning in tests/integration/declarative/test_team_config.bats

### Implementation for User Story 6

- [ ] T112 [US6] Add support for conditional plugin loading (if/case statements) in _zap_load_declared_plugins() in lib/declarative.zsh
- [ ] T113 [US6] Add support for $HOST-based plugin arrays in _zap_extract_plugins_array() in lib/parser.zsh
- [ ] T114 [US6] Add support for environment-based plugin arrays in _zap_extract_plugins_array() in lib/parser.zsh
- [ ] T115 [US6] Add git merge conflict detection in zap status in lib/declarative.zsh
- [ ] T116 [US6] Add version drift detection (pinned vs actual) in zap diff in lib/declarative.zsh

**Checkpoint**: All user stories (1-6) should now be independently functional. Multi-machine sync is fully supported.

---

## Phase 9: Backward Compatibility & Integration

**Purpose**: Ensure existing zap commands continue to work alongside declarative mode

- [ ] T117 Mark legacy zap load command as experimental in lib/loader.zsh
- [ ] T118 [P] Add deprecation warning for zap load in lib/loader.zsh
- [ ] T119 [P] Update zap list to show declarative vs imperative sources in lib/loader.zsh
- [ ] T120 [P] Update zap update to respect version pins from state in lib/updater.zsh
- [ ] T121 [P] Update zap clean to preserve declared plugin state in lib/loader.zsh
- [ ] T122 Write integration test for mixed mode (declarative + imperative) in tests/integration/declarative/test_mixed_mode.bats
- [ ] T123 Write integration test for backward compatibility in tests/integration/declarative/test_backward_compat.bats

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T124 [P] Add zap help sync in lib/declarative.zsh
- [ ] T125 [P] Add zap help try in lib/declarative.zsh
- [ ] T126 [P] Add zap help adopt in lib/declarative.zsh
- [ ] T127 [P] Add zap help status in lib/declarative.zsh
- [ ] T128 [P] Add zap help diff in lib/declarative.zsh
- [ ] T129 [P] Update main README with declarative examples
- [ ] T130 [P] Create migration guide (imperative → declarative) in docs/migration-guide.md
- [ ] T131 [P] Update installer to explain declarative mode in install.zsh
- [ ] T132 Code cleanup and refactoring (single responsibility, WHY comments)
- [ ] T133 Run quickstart.md validation (all examples work as documented)
- [ ] T134 Security audit (validate all inputs, check for injection vectors)
- [ ] T135 Performance profiling (ensure all budgets met)
- [ ] T136 [P] Add error message improvements (what failed, why, how to fix)
- [ ] T137 [P] Add color support for status/diff output in lib/utils.zsh
- [ ] T138 Final integration test suite run (all 119+ test cases)
- [ ] T139 Update CLAUDE.md with declarative patterns and examples

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion
- **User Story 2 (Phase 4)**: Depends on Foundational completion (can run in parallel with US1)
- **User Story 3 (Phase 5)**: Depends on Foundational completion, benefits from US1+US2 (but can run independently)
- **User Story 4 (Phase 6)**: Depends on Foundational completion, requires US2 (zap try) and US3 (state updates)
- **User Story 5 (Phase 7)**: Depends on Foundational completion, benefits from US1+US3 (but can run independently)
- **User Story 6 (Phase 8)**: Depends on Foundational completion, requires US1+US3 (declarative loading + sync)
- **Backward Compatibility (Phase 9)**: Depends on at least US1 completion
- **Polish (Phase 10)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 3 (P1)**: Can start after Foundational - No dependencies on other stories (can run in parallel with US1+US2)
- **User Story 4 (P2)**: Requires US2 (zap try must exist) and US3 (state tracking)
- **User Story 5 (P2)**: Can start after Foundational - Benefits from US1+US3 but independently testable
- **User Story 6 (P3)**: Requires US1 (declarative loading) and US3 (sync)

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD workflow)
- Foundational utilities before commands
- Core implementation before flags/options
- Integration tests after implementation
- Story complete before moving to next priority

### Parallel Opportunities

**Setup Phase (Phase 1)**:
- T002 (test directories) and T003 (logging) can run in parallel

**Foundational Phase (Phase 2)**:
- T007-T010 (state operations) can run in parallel after T005-T006
- T015-T017 (parsing utilities) can run in parallel after T014
- T020-T021 (array parsing features) can run in parallel after T019

**User Story 1 (Phase 3)**:
- All 5 tests (T023-T027) can run in parallel
- T028-T029 (core loading logic) can run in parallel
- T033 (logging) can run in parallel with T034 (performance test)

**User Story 2 (Phase 4)**:
- All 5 tests (T035-T039) can run in parallel
- T040-T041 (command setup) then T042-T048 in parallel groups

**User Story 3 (Phase 5)**:
- All 7 tests (T049-T055) can run in parallel
- T056-T058 (drift utilities) can run in parallel
- T064-T065 (flags) can run in parallel

**User Story 4 (Phase 6)**:
- All 7 tests (T069-T075) can run in parallel
- T076-T077 (core adopt logic) then T086-T087 (flags) in parallel

**User Story 5 (Phase 7)**:
- All 7 tests (T089-T095) can run in parallel
- T096-T097 (command functions) can run in parallel
- T101-T102 (status flags) can run in parallel

**User Story 6 (Phase 8)**:
- All 4 tests (T108-T111) can run in parallel
- T112-T114 (conditional loading features) can run in parallel

**Backward Compatibility (Phase 9)**:
- T118-T121 (updates to existing commands) can run in parallel

**Polish Phase (Phase 10)**:
- T124-T128 (help functions) can run in parallel
- T129-T131 (documentation) can run in parallel
- T136-T137 (UX improvements) can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Contract test for automatic plugin loading from array in tests/contract/declarative/test_declarative_loading.zsh"
Task: "Integration test for shell startup with plugins array in tests/integration/declarative/test_startup_loading.bats"
Task: "Integration test for version-pinned plugins in tests/integration/declarative/test_version_pinning.bats"
Task: "Integration test for subdirectory plugins in tests/integration/declarative/test_subdir_plugins.bats"
Task: "Integration test for empty array (no plugins loaded) in tests/integration/declarative/test_empty_array.bats"

# Launch parallel implementation tasks:
Task: "Implement _zap_load_declared_plugins() to read plugins=() and load each in lib/declarative.zsh"
Task: "Add plugin load order preservation logic in _zap_load_declared_plugins() in lib/declarative.zsh"
```

---

## Implementation Strategy

### MVP First (User Stories 1, 2, 3 Only - Core Declarative Paradigm)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T022) - CRITICAL, blocks all stories
3. Complete Phase 3: User Story 1 (T023-T034) - Declarative loading
4. Complete Phase 4: User Story 2 (T035-T048) - Experimentation
5. Complete Phase 5: User Story 3 (T049-T068) - Reconciliation
6. **STOP and VALIDATE**: Test the core workflow independently
   - Declare plugins in array → automatic loading ✓
   - Try experimental plugin → loads temporarily ✓
   - Sync to declared state → experimental removed ✓
7. Deploy/demo if ready

**MVP Task Count**: 68 tasks (Setup + Foundational + US1 + US2 + US3)

### Incremental Delivery

1. Complete Setup + Foundational (T001-T022) → Foundation ready
2. Add User Story 1 (T023-T034) → Test independently → Deploy/Demo (basic declarative loading)
3. Add User Story 2 (T035-T048) → Test independently → Deploy/Demo (experimentation added)
4. Add User Story 3 (T049-T068) → Test independently → Deploy/Demo (MVP complete!)
5. Add User Story 4 (T069-T088) → Test independently → Deploy/Demo (adoption workflow)
6. Add User Story 5 (T089-T107) → Test independently → Deploy/Demo (observability)
7. Add User Story 6 (T108-T116) → Test independently → Deploy/Demo (multi-machine sync)
8. Add Backward Compatibility (T117-T123) → Ensure existing users not broken
9. Add Polish (T124-T139) → Production-ready release

Each increment adds value without breaking previous stories.

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (T001-T022)
2. Once Foundational is done (after T022):
   - **Developer A**: User Story 1 (T023-T034)
   - **Developer B**: User Story 2 (T035-T048)
   - **Developer C**: User Story 3 (T049-T068)
3. Once US1+US2+US3 complete:
   - **Developer A**: User Story 4 (T069-T088) - requires US2+US3
   - **Developer B**: User Story 5 (T089-T107) - independent
   - **Developer C**: User Story 6 (T108-T116) - requires US1+US3
4. Final integration:
   - **Developer A**: Backward Compatibility (T117-T123)
   - **Developers B+C**: Polish (T124-T139)

---

## Notes

- [P] tasks = different files, no dependencies within their phase
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- **TDD WORKFLOW**: Write tests first, verify they FAIL, then implement
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All tasks include exact file paths for clear implementation guidance
- Security validation is critical (FR-027) - all user input must be validated
- Performance budgets are enforced through tests (Constitution Principle IV)
- 80%+ test coverage required on reconciliation, state management, adoption logic (Constitution Principle II)

---

## Task Count Summary

- **Total Tasks**: 139
- **Setup Phase**: 3 tasks
- **Foundational Phase**: 19 tasks
- **User Story 1** (P1): 12 tasks (5 tests + 7 implementation)
- **User Story 2** (P1): 14 tasks (5 tests + 9 implementation)
- **User Story 3** (P1): 20 tasks (7 tests + 12 implementation + 1 unit test)
- **User Story 4** (P2): 20 tasks (7 tests + 12 implementation + 1 unit test)
- **User Story 5** (P2): 19 tasks (7 tests + 11 implementation + 1 utility)
- **User Story 6** (P3): 9 tasks (4 tests + 5 implementation)
- **Backward Compatibility**: 7 tasks
- **Polish & Cross-Cutting**: 16 tasks

**Test Tasks**: 57 (contract + integration + unit + performance + security)
**Implementation Tasks**: 82

**MVP (US1+US2+US3)**: 68 tasks total
**Full Feature**: 139 tasks total

**Parallel Opportunities Identified**: 60+ tasks marked [P] for parallel execution
