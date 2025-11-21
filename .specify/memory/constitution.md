<!-- Sync Impact Report
Version: old -> 1.0.0
List of modified principles:
- [PRINCIPLE_1_NAME] -> I. Library-First
- [PRINCIPLE_2_NAME] -> II. Interface-Driven
- [PRINCIPLE_3_NAME] -> III. Test-First
- [PRINCIPLE_4_NAME] -> IV. Spec-Driven
- [PRINCIPLE_5_NAME] -> V. Atomic Delivery
Added sections:
- System Standards
- Contribution Workflow
Templates requiring updates: None
-->
# Zap Constitution

## Core Principles

### I. Library-First
Every feature starts as a standalone library. Libraries must be self-contained, independently testable, and documented. Clear purpose is required - no organizational-only libraries.

### II. Interface-Driven
Every library exposes functionality via clear interfaces (CLI or API). Text in/out protocol is preferred for CLI tools: stdin/args → stdout, errors → stderr. Support JSON + human-readable formats.

### III. Test-First
Test-Driven Development (TDD) is standard. Tests are written and fail before implementation begins. The Red-Green-Refactor cycle is strictly enforced for all core logic.

### IV. Spec-Driven
No code is written without a plan. Changes originate from a specification or issue. Documentation (specs) precedes implementation.

### V. Atomic Delivery
User stories and tasks must be independently testable and deliverable. Big bang releases are avoided in favor of incremental, verifiable value.

## System Standards

### Operational Constraints
- **Security**: No secrets in code. Principle of least privilege.
- **Performance**: Measure before optimizing. Define clear SLAs.
- **Documentation**: Required for all public APIs and modules.

## Contribution Workflow

### Quality Gates
- **Code Review**: All changes require peer review or self-review against this constitution.
- **Testing**: CI must pass before merge. Coverage should not decrease.
- **Commits**: Use conventional commits (feat, fix, docs, etc.).

## Governance

### Amendments
This constitution supersedes all other practices. Amendments require documentation, approval by the project owner, and a clear migration plan if retroactive.

### Compliance
All PRs and reviews must verify compliance with these principles. Deviations must be explicitly justified in the PR description or Plan. Complexity must be justified.

**Version**: 1.0.0 | **Ratified**: 2025-11-20 | **Last Amended**: 2025-11-20
