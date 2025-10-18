<!--
Sync Impact Report:
- Version change: 1.0.0 → 1.1.0
- Modified principles:
  * I. Code Quality & Maintainability (EXPANDED: Added "Comments Explain WHY, Not WHAT" sub-principle)
- Added sections:
  * V. Documentation Organization (NEW PRINCIPLE: Structured docs, forbidden root clutter, cleanup discipline)
- Removed sections: None
- Templates requiring updates:
  ✅ plan-template.md (UPDATED: Constitution Check section now includes documentation organization gate)
  ✅ spec-template.md (NO CHANGE NEEDED: Quality Requirements section already comprehensive)
  ✅ tasks-template.md (NO CHANGE NEEDED: TDD workflow already enforced)
  ✅ checklist-template.md (NO CHANGE NEEDED: can generate doc organization checklist via command)
  ✅ agent-file-template.md (NO CHANGE NEEDED: development guidelines align with principles)
- Follow-up TODOs: None
-->

# Zap Constitution

## Core Principles

### I. Code Quality & Maintainability

Code MUST be written for readability and long-term maintainability:

- **Clear Intent**: Function and variable names MUST express intent without requiring comments to explain basic behavior
- **Single Responsibility**: Each function/class MUST have one well-defined purpose; extract complexity into smaller, focused units
- **No Magic**: Avoid hard-coded values; use named constants with clear semantics
- **Documentation**: Public APIs MUST include docstrings explaining purpose, parameters, return values, and exceptions
- **Comments Explain WHY, Not WHAT**: Code shows HOW something is done; comments MUST explain WHY it's done that way
  - ❌ BAD: `varname = "sleepy"  # sets varname to sleepy`
  - ✅ GOOD: `varname = "sleepy"  # default state for new sessions per security requirement SEC-042`
  - Avoid redundant comments that merely restate the code
  - Use comments to explain business logic, gotchas, workarounds, or non-obvious design decisions
- **Error Handling**: Failures MUST be explicit; use proper exception types and meaningful error messages
- **Code Review**: All code changes MUST be reviewed by at least one other developer before merging

**Rationale**: Technical debt compounds exponentially. Code is read 10x more than written. Quality at authoring time reduces maintenance cost and enables sustainable velocity.

### II. Test-First Development (NON-NEGOTIABLE)

Testing is not optional; it is the foundation of reliable software:

- **TDD Workflow**: MUST write tests before implementation (Red-Green-Refactor)
  1. Write test(s) for new functionality
  2. Verify tests fail (Red)
  3. Implement minimum code to pass (Green)
  4. Refactor while keeping tests green
- **Test Categories**:
  - **Contract Tests**: Verify API boundaries and data contracts
  - **Integration Tests**: Validate component interactions and user journeys
  - **Unit Tests**: Test individual functions/methods in isolation (optional unless explicitly required)
- **Coverage**: Critical paths MUST have test coverage; aim for 80%+ on core business logic
- **Test Clarity**: Each test MUST verify one behavior; test names MUST describe the scenario and expected outcome
- **CI/CD Gates**: All tests MUST pass before merging; failing builds MUST block deployment

**Rationale**: Tests written after code validate implementation bias rather than requirements. Test-first ensures specifications are testable, catches regressions, and enables confident refactoring.

### III. User Experience Consistency

User-facing features MUST provide consistent, predictable, and accessible experiences:

- **Interface Consistency**: UI patterns, terminology, and interactions MUST be uniform across features
- **Response Time**: User-initiated actions MUST acknowledge within 100ms; complete or show progress within 1 second
- **Error Messages**: MUST be actionable and user-friendly; explain what happened and how to resolve
- **Accessibility**: MUST support keyboard navigation, screen readers, and color-blind safe palettes
- **Progressive Disclosure**: Show essential information first; provide advanced options on demand
- **Mobile-First**: If applicable, design for mobile constraints first, then enhance for larger screens
- **User Testing**: Major UX changes MUST be validated with real users before final release

**Rationale**: Inconsistent experiences erode trust and increase support burden. Users form mental models; violations cause frustration and errors. Accessibility is not optional.

### IV. Performance & Scalability

Performance is a feature; systems MUST be designed for efficiency and scale:

- **Performance Budgets**:
  - API endpoints: p95 latency < 200ms for reads, < 500ms for writes
  - Page load: Time to Interactive < 3 seconds on 3G network
  - Memory: No memory leaks; RSS growth < 10% over 24 hours under load
- **Optimization Workflow**:
  1. Measure baseline performance with realistic data
  2. Identify bottlenecks using profiling tools
  3. Optimize hot paths only; avoid premature optimization
  4. Re-measure to validate improvement
- **Scalability Design**:
  - Database queries MUST use indexes for common access patterns
  - Avoid N+1 queries; batch or cache where appropriate
  - Large datasets MUST use pagination or streaming
  - Long operations MUST run asynchronously with status updates
- **Monitoring**: Production systems MUST track latency, error rate, and throughput; alert on degradation

**Rationale**: Performance problems are difficult to fix retroactively. Slow systems frustrate users and increase infrastructure costs. Designing for scale prevents costly rewrites.

### V. Documentation Organization

Documentation MUST be organized systematically to prevent repository clutter and confusion:

- **Structured Documentation**:
  - Feature specs: MUST reside in `specs/###-feature-name/` following Speckit structure
  - Project-wide docs: MUST live in `docs/` directory (e.g., architecture, setup, guides)
  - API documentation: Generate from code docstrings; store in `docs/api/`
  - ADRs (Architecture Decision Records): MUST be in `docs/adr/` with sequential numbering
- **Forbidden**: Random `.md` files scattered in repository root or random subdirectories
- **Troubleshooting & Analysis**:
  - Temporary analysis files MUST go in `docs/troubleshooting/YYYY-MM-DD-issue-name.md`
  - Once issue resolved, either delete the file or convert findings into permanent documentation
  - Do NOT leave orphaned analysis files that are never referenced or acted upon
- **Cleanup Discipline**:
  - Delete temporary/draft documentation after issue resolution or feature completion
  - Archive old feature specs to `specs/archive/` if no longer relevant
  - Keep only living documentation that serves current development needs
- **Documentation Hygiene**:
  - Monthly review: Identify and remove stale documentation
  - Link documentation to code/features it describes
  - If documentation has no clear owner or purpose, delete it

**Rationale**: Scattered documentation creates confusion, makes information hard to find, and signals low organizational discipline. Abandoned analysis documents clutter the repository and mislead future developers. Structured organization enables knowledge discovery and maintains project clarity.

## Development Workflow

### Code Review Standards

All pull requests MUST meet these criteria before approval:

- Follows Core Principles (I-V)
- Tests pass in CI/CD pipeline
- Code is readable and self-documenting
- Comments explain WHY, not WHAT
- Documentation placed in proper structured directories (no root clutter)
- No unaddressed review comments
- Performance implications considered for data-heavy paths
- Documentation updated for user-facing changes

### Quality Gates

Before merging to main:

- [ ] All automated tests pass
- [ ] Code review approved by at least one peer
- [ ] No decrease in test coverage on modified code
- [ ] Performance tests pass (if applicable)
- [ ] Documentation updated
- [ ] Breaking changes communicated to stakeholders

### Definition of Done

A feature is complete when:

- All acceptance criteria from spec.md validated
- Tests written and passing (contract + integration minimum)
- Code reviewed and approved
- Documentation complete (API docs, user guides, quickstart)
- Deployed to staging and validated by stakeholder or QA
- Performance meets budgets defined in plan.md
- Accessibility verified (if user-facing)

## Compliance & Enforcement

### Amendment Process

Constitution changes require:

1. Proposal documenting rationale and impact
2. Review by project leads and affected teams
3. Update to `.specify/memory/constitution.md` with version bump
4. Sync all dependent templates (plan, spec, tasks)
5. Communication to all contributors

### Version Semantics

- **MAJOR**: Breaking principle changes or removals (e.g., removing TDD requirement)
- **MINOR**: New principles or sections added
- **PATCH**: Clarifications, wording improvements, or formatting fixes

### Conflict Resolution

When constitution conflicts with practical constraints:

1. Document the conflict in plan.md Complexity Tracking section
2. Justify why principle cannot be met
3. Propose alternative approach that preserves intent
4. Get approval from project lead before proceeding

### Enforcement

- All PRs MUST reference constitution compliance in review checklist
- `/speckit.plan` command enforces Constitution Check section
- Repeated violations require process review and team training

**Version**: 1.1.0 | **Ratified**: 2025-10-17 | **Last Amended**: 2025-10-17
