<!--
  ============================================================================
  SYNC IMPACT REPORT
  ============================================================================
  Version Change: 1.2.0 → 1.3.0
  
  Amendment: Mandate documented justification before disabling lint checks.
  
  Modified Principles:
  - [UPDATED] IV. Validation & Quality Gates
    * Added "Lint Check Disabling" bullet point
    * Requires documented justification before disabling any lint check
    * Mandates explaining why violation is necessary and unavoidable
    * Reinforces NEVER modifying PDK-managed files (.puppet-lint.rc, .rubocop.yml) directly
    * Encourages refactoring to comply rather than disabling checks
    * Updated rationale to emphasize lint rules exist for good reasons
  
  Unchanged Principles:
  - I. Puppet Standards & PDK First
  - II. Test-Driven Development (RSpec/Cucumber)
  - III. Documentation Standards (Puppet Strings)
  - V. Code Quality & Idiomatic Puppet
  
  Impact Analysis:
  - Lint checks can no longer be disabled without documented technical justification
  - Must explore code refactoring before considering disabling checks
  - PDK-managed lint configuration files remain off-limits for direct edits
  - Encourages using proper Puppet/Ruby idioms rather than working around linters
  - No breaking changes to existing workflow
  
  Templates Status:
  ✅ plan-template.md - No changes required
  ✅ spec-template.md - No changes required
  ✅ tasks-template.md - No changes required
  ✅ agent-file-template.md - No changes required
  ✅ checklist-template.md - No changes required
  
  Command Files Status:
  ✅ .github/prompts/*.prompt.md - No changes required
  
  Follow-up TODOs:
  - Review any existing lint disables in codebase for proper justification
  - Document common lint patterns and how to comply with them
  
  Previous Amendments:
  - v1.1.0 → v1.2.0: Explicitly mandated RuboCop validation
  - v1.0.0 → v1.1.0: Added PDK template management requirement (.sync.yml)
  
  ============================================================================
-->

# puppet-par Constitution

## Core Principles

### I. Puppet Standards & PDK First

All Puppet code MUST adhere to Puppet Development Kit (PDK) standards and conventions:

- PDK is the primary development tool for scaffolding, validation, and testing
- All modules MUST be generated and maintained using PDK commands
- Module structure MUST follow PDK conventions (manifests/, spec/, tasks/, etc.)
- Metadata MUST be declared in metadata.json following Puppet Forge standards
- Code MUST support Puppet 7.24+ as defined in metadata.json requirements
- All supported operating systems MUST be explicitly declared in metadata.json
- **PDK-Managed Files**: Any modifications to PDK-managed files (Gemfile, Rakefile, .rubocop.yml, etc.) MUST be made via `.sync.yml` configuration, followed by `pdk update` to apply changes. NEVER edit PDK-managed files directly as changes will be lost on next PDK update.

**Rationale**: PDK ensures consistency, maintainability, and compatibility across the Puppet ecosystem. Standard structure enables automated tooling and community collaboration. The `.sync.yml` approach ensures customizations persist across PDK updates.

### II. Test-Driven Development (RSpec/Cucumber) (NON-NEGOTIABLE)

Testing is mandatory and MUST follow strict test-first discipline:

- **Unit Testing**: All Puppet classes, defined types, and functions MUST have RSpec tests using puppet-rspec framework
- **BDD Testing**: All behavior-driven scenarios MUST be written in Cucumber
- **Test-First Workflow**: Tests MUST be written before implementation (Red-Green-Refactor)
- **Coverage**: All code paths, parameters, and operating systems MUST be tested
- **Test Execution**: `pdk test unit -v` MUST pass with zero failures before any commit

**Rationale**: Test-first development catches regressions early, documents expected behavior, and ensures cross-platform compatibility critical for infrastructure code.

### III. Documentation Standards (Puppet Strings)

All Puppet code MUST be documented following Puppet Strings formatting:

- Every class, defined type, function, and task MUST have complete Strings annotations
- Parameters MUST document type, description, and default values
- Examples MUST be provided for all public interfaces
- Reference documentation MUST be regenerated after changes: `pdk bundle exec rake strings:generate:reference`
- REFERENCE.md MUST be kept up-to-date and committed alongside code changes

**Rationale**: Puppet Strings provides consistent, machine-parseable documentation that generates readable reference material for module users and maintainers.

### IV. Validation & Quality Gates

All code MUST pass validation checks before commit:

- **PDK Validation**: `pdk validate` MUST report zero offenses across all validators
  - **RuboCop**: All Ruby code (types, providers, specs) MUST pass RuboCop style checks with zero offenses
  - **Puppet-Lint**: All Puppet manifests MUST pass puppet-lint checks with zero warnings
  - **Metadata Validation**: metadata.json MUST pass PDK schema validation
  - **YAML Syntax**: All YAML files MUST be syntactically valid
- **Syntax**: All Puppet manifests, Ruby code, and templates MUST be syntactically valid
- **Dependencies**: All module dependencies MUST be explicitly declared and version-pinned
- **Lint Check Disabling**: NEVER disable lint checks without documented justification. If a lint check must be disabled:
  - Document the specific technical reason in code comments
  - Explain why the violation is necessary and unavoidable
  - Consider if the code can be refactored to comply instead
  - NEVER modify PDK-managed files (.puppet-lint.rc, .rubocop.yml) directly - use `.sync.yml` if configuration changes are truly necessary

**Rationale**: Automated validation catches common errors early and enforces community best practices, reducing technical debt and maintenance burden. RuboCop ensures consistent Ruby style, readability, and prevents common Ruby antipatterns. Lint rules exist for good reasons; disabling them should be rare and well-justified.

### V. Code Quality & Idiomatic Puppet

Code MUST be clear, maintainable, and follow Puppet idioms:

- Use Puppet's declarative resource model (avoid exec resources when native types exist)
- Follow Puppet Style Guide for naming, spacing, and code organization
- Prefer data-in-Hiera pattern for configuration values
- Keep classes and defined types focused (single responsibility)
- Use meaningful variable and parameter names
- Avoid complexity: prefer simple, readable code over clever abstractions

**Rationale**: Idiomatic Puppet code is easier to understand, maintain, and debug. Following conventions reduces cognitive load for team members and future maintainers.

## Technology Stack Requirements

**Module Framework**: Puppet Development Kit (PDK) 3.4.0+  
**Puppet Version**: >= 7.24, < 9.0.0  
**Testing Framework**: RSpec with puppet-rspec gem  
**BDD Framework**: Cucumber for behavior-driven scenarios  
**Documentation**: Puppet Strings for code annotations and reference generation  
**Validation**: PDK validate (includes puppet-lint, metadata-json-lint, syntax checks)  
**Supported Platforms**: RHEL/CentOS/AlmaLinux/Rocky 7-9, Debian 10-12, Ubuntu 18.04-22.04, Windows Server 2019-2022/10-11

## Development Workflow

**Pre-Implementation**:
1. Write specification with clear user stories and acceptance criteria
2. Write failing tests (RSpec unit tests, Cucumber BDD scenarios)
3. Verify tests fail: `pdk test unit -v`

**Implementation**:
1. Implement Puppet code with complete Puppet Strings documentation
2. Run tests iteratively until passing: `pdk test unit -v`
3. Validate code quality: `pdk validate` (must report zero offenses)
4. Regenerate reference docs: `pdk bundle exec rake strings:generate:reference`

**Pre-Commit**:
1. All tests MUST pass: `pdk test unit -v`
2. All validation MUST pass: `pdk validate`
3. REFERENCE.md MUST be up-to-date and committed
4. Git commit with conventional commit message

**Review Gates**:
- Code review MUST verify test coverage and documentation completeness
- All CI/CD pipelines MUST pass before merge
- Breaking changes MUST be clearly documented and version-bumped appropriately

## Governance

This constitution supersedes all other development practices and conventions. All code contributions, reviews, and architectural decisions MUST comply with these principles.

**Amendment Process**:
- Proposed amendments MUST be documented with rationale and impact analysis
- Version MUST be bumped following semantic versioning (MAJOR.MINOR.PATCH)
- All dependent templates and documentation MUST be updated to reflect changes
- Amendment effective date MUST be recorded in LAST_AMENDED_DATE

**Compliance**:
- All pull requests MUST demonstrate adherence to these principles
- Complexity exceptions MUST be explicitly justified with "Why Needed" and "Simpler Alternative Rejected Because" documentation
- Automated gates (PDK validate, test suite) enforce non-negotiable principles
- Use `.specify/templates/agent-file-template.md` for runtime development guidance

**Version**: 1.3.0 | **Ratified**: 2025-10-22 | **Last Amended**: 2025-10-22
