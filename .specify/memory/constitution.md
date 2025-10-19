<!--
Sync Impact Report:
- Version change: 1.1.0 → 1.2.0
- Modified principles:
  * III. User Experience Consistency (GENERALIZED: Removed web/mobile-specific requirements; now platform-agnostic)
    - ADDED: "Respect Standard Behaviors" requirement (keybindings, shortcuts, platform conventions)
  * IV. Performance & Scalability (GENERALIZED: Removed hard-coded numeric targets; now domain-agnostic with requirement to define budgets)
- Added sections:
  * VI. Security (NEW PRINCIPLE: Input validation, least privilege, secure defaults, vulnerability response)
  * VII. Observability (NEW PRINCIPLE: Logging, monitoring, debugging, error tracking)
- Removed sections: None
- Reorganized sections:
  * Development Workflow (SIMPLIFIED: Detailed checklists moved to project-specific CLAUDE.md; constitution retains high-level process requirements)
- Templates requiring updates:
  ✅ spec-template.md (UPDATED: Added Security and Observability requirement sections)
  ✅ plan-template.md (UPDATED: Constitution Check now includes all 7 principles)
  ✅ tasks-template.md (NO CHANGE NEEDED: TDD workflow remains unchanged)
  ✅ CLAUDE.md (UPDATED: Added Zsh-specific UX standards, Default Keybindings, Security practices, Observability examples)
- Follow-up TODOs:
  * Consider creating docs/CONTRIBUTING.md with detailed development workflow for human contributors
  * Review existing Zap code (lib/defaults.zsh) to ensure compliance with new keybinding standards
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

User-facing features MUST provide consistent, predictable, and accessible experiences appropriate to the platform:

- **Interface Consistency**: Interaction patterns, terminology, and behaviors MUST be uniform across features
- **Response Time**: User-initiated actions MUST acknowledge promptly; provide feedback for long-running operations
- **Error Messages**: MUST be actionable and user-friendly; explain what happened and how to resolve
- **Accessibility**: MUST support platform-appropriate accessibility features (e.g., keyboard navigation for CLI, screen readers for GUI, voice control for mobile)
- **Progressive Disclosure**: Show essential information first; provide advanced options on demand
- **Platform Adaptation**: Design for the target platform's constraints and conventions (e.g., CLI should respect UNIX principles; GUI should follow OS design guidelines; mobile should prioritize touch interactions)
- **Respect Standard Behaviors**: MUST NOT override platform-standard keybindings, shortcuts, or behaviors without explicit user consent; defaults should match user expectations from the platform/OS
- **User Validation**: Major UX changes MUST be validated with real users or usability testing before final release

**Rationale**: Inconsistent experiences erode trust and increase support burden. Users form mental models based on platform conventions; violations cause frustration and errors. Overriding standard keybindings breaks muscle memory and creates hostile user experiences. Accessibility is not optional.

### IV. Performance & Scalability

Performance is a feature; systems MUST be designed for efficiency and scale:

- **Performance Budgets**:
  - Each project MUST define performance budgets appropriate to its domain and platform
  - Examples: API latency targets, page load times, shell startup time, memory limits, throughput requirements
  - Budgets MUST be measurable and enforced in testing
- **Optimization Workflow**:
  1. Measure baseline performance with realistic data
  2. Identify bottlenecks using profiling tools appropriate to the platform
  3. Optimize hot paths only; avoid premature optimization
  4. Re-measure to validate improvement
- **Scalability Design**:
  - Data access patterns MUST use appropriate indexing, caching, or batching strategies
  - Avoid algorithmic inefficiencies (e.g., N+1 queries, quadratic complexity in linear use cases)
  - Large datasets MUST use pagination, streaming, or lazy loading
  - Long operations MUST run asynchronously with status updates
- **Monitoring**: Production systems MUST track performance metrics appropriate to the platform; alert on degradation

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

### VI. Security

Security MUST be designed in from the start, not bolted on later:

- **Input Validation**:
  - ALL user inputs MUST be validated and sanitized before use
  - Reject invalid input explicitly; never attempt to "fix" malformed data
  - Use allowlists over denylists where possible
  - Validate data type, format, length, and range constraints
- **Least Privilege**:
  - Code MUST run with minimum required permissions
  - Avoid requiring root/admin privileges unless absolutely necessary
  - File permissions MUST follow principle of least access
- **Secure Defaults**:
  - Default configurations MUST be secure (e.g., encryption enabled, authentication required)
  - Insecure options MUST require explicit opt-in with clear warnings
  - Secrets MUST NOT be stored in code, config files, or version control
- **Dependency Management**:
  - Keep dependencies up to date; monitor for security advisories
  - Pin dependency versions to prevent supply chain attacks
  - Review dependencies for excessive permissions or suspicious behavior
- **Vulnerability Response**:
  - Security issues MUST be fixed with highest priority
  - Provide clear disclosure and migration path for users
  - Document security considerations in API documentation

**Rationale**: Security vulnerabilities can have catastrophic consequences. Retrofitting security is expensive and error-prone. Defense-in-depth and secure-by-default design minimize attack surface and blast radius.

### VII. Observability

Systems MUST be designed for debugging, monitoring, and operational visibility:

- **Logging**:
  - Log significant events, state changes, and errors with sufficient context
  - Use structured logging (key-value pairs) for machine parsing
  - Include correlation IDs for distributed tracing where applicable
  - Log levels MUST be appropriate: ERROR for failures, WARN for degraded states, INFO for significant events, DEBUG for troubleshooting
- **Error Tracking**:
  - Errors MUST include actionable context (what failed, why, how to fix)
  - Error messages MUST be preserved in logs for post-mortem analysis
  - Critical errors MUST be surfaced to monitoring/alerting systems
- **Metrics & Monitoring**:
  - Track key performance indicators appropriate to the domain (latency, throughput, error rate, resource usage)
  - Expose health check endpoints or status commands
  - Alert on anomalies, degradation, or SLA violations
- **Debugging Support**:
  - Provide debug modes or verbose output flags for troubleshooting
  - Include version information in logs and error reports
  - Preserve stack traces and diagnostic information for failures
- **Operational Transparency**:
  - Document expected log output and error conditions
  - Provide runbooks or troubleshooting guides for common issues
  - Make system state inspectable (e.g., status commands, admin dashboards)

**Rationale**: You cannot fix what you cannot see. Observability enables rapid debugging, proactive monitoring, and data-driven optimization. Systems designed for visibility reduce mean time to resolution and improve reliability.

## Development Workflow

### Code Review Standards

All pull requests MUST meet these criteria before approval:

- Follows Core Principles (I-VII)
- Tests pass in CI/CD pipeline
- Code is readable and self-documenting
- Comments explain WHY, not WHAT
- Documentation placed in proper structured directories (no root clutter)
- No unaddressed review comments
- Performance implications considered for data-heavy paths
- Security implications reviewed (input validation, permissions, secrets handling)
- Observability included (logging, error handling, debugging support)
- Documentation updated for user-facing changes

**Note**: Detailed project-specific checklists should be maintained in `CLAUDE.md` (for AI agent guidance) or `docs/CONTRIBUTING.md` (for human contributors). The constitution establishes requirements; project files provide implementation details.

### Quality Gates

Before merging to main:

- [ ] All automated tests pass
- [ ] Code review approved by at least one peer
- [ ] No decrease in test coverage on modified code
- [ ] Performance budgets met (if applicable to change)
- [ ] Security review completed (if touching auth, input handling, or sensitive data)
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
- Security review completed (if applicable)
- Observability verified (logging, error handling, debugging support)
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

**Version**: 1.2.0 | **Ratified**: 2025-10-17 | **Last Amended**: 2025-10-18
