# Implementation Plan: Ansible Playbook Runner Custom Type

**Branch**: `001-ansible-playbook-runner` | **Date**: 2025-10-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-ansible-playbook-runner/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Create a Puppet custom type and provider named `par` that executes Ansible playbooks against localhost. The provider constructs and executes `ansible-playbook` commands with configurable playbook paths and JSON-formatted variables (playbook_vars) passed via the `-e` flag. The provider parses Ansible's JSON output to detect changes, reporting resource changed/in-sync/failed based on Ansible's change detection. The type supports optional output logging (logoutput parameter), configurable execution serialization (exclusive parameter), timeout handling, and proper error reporting. Implementation uses Ruby for the provider logic with RSpec for unit testing and Cucumber for BDD scenarios.

## Technical Context

**Language/Version**: Ruby 2.7+ (compatible with Puppet 7.24+)  
**Primary Dependencies**: Puppet 7.24+ (core framework for custom types/providers), Ansible (external dependency, assumed pre-installed)  
**Storage**: N/A (stateless provider that executes commands)  
**Testing**: RSpec 3.x with puppet-rspec gem for unit tests, Cucumber for BDD scenarios  
**Target Platform**: RHEL/CentOS/AlmaLinux/Rocky 7-9, Debian 10-12, Ubuntu 18.04-22.04, Windows Server 2019-2022/10-11  
**Project Type**: Puppet module (PDK structure: lib/puppet/type/, lib/puppet/provider/, spec/)  
**Performance Goals**: Command execution completes within configurable timeout (default 300s), validation checks <100ms  
**Constraints**: Must use PDK conventions, zero offenses from `pdk validate`, 100% test pass rate, localhost-only execution via `ansible-playbook -i localhost, --connection=local`  
**Scale/Scope**: Single custom type/provider pair, ~500-800 lines of Ruby code, support for 20 functional requirements

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ I. Puppet Standards & PDK First
- Module uses existing PDK structure (generated with `pdk new module`)
- Custom type goes in `lib/puppet/type/par.rb`
- Provider goes in `lib/puppet/provider/par/par.rb`
- All code follows PDK conventions
- metadata.json already exists with proper dependencies

### ✅ II. Test-Driven Development (RSpec/Cucumber) (NON-NEGOTIABLE)
- RSpec tests in `spec/unit/puppet/type/par_spec.rb` and `spec/unit/puppet/provider/par/par_spec.rb`
- Cucumber scenarios in `spec/acceptance/` for BDD testing
- Tests written BEFORE implementation (Red-Green-Refactor)
- All user stories map to test scenarios
- Target: 100% pass rate for `pdk test unit -v`

### ✅ III. Documentation Standards (Puppet Strings)
- Type file includes Strings annotations for all parameters
- Provider includes Strings documentation for public methods
- Examples provided showing PAR resource usage
- REFERENCE.md regenerated after implementation via `pdk bundle exec rake strings:generate:reference`

### ✅ IV. Validation & Quality Gates
- All code must pass `pdk validate` with zero offenses
- Ruby syntax validation for type/provider files
- No puppet-lint warnings
- metadata.json validation passes

### ✅ V. Code Quality & Idiomatic Puppet
- Type uses proper Puppet type DSL (newparam, newproperty, validate)
- Provider follows Puppet provider patterns (prefetch, flush, exists?)
- Clear method names and logical organization
- Minimal complexity - straightforward command execution pattern
- Proper error handling with descriptive messages

**Gate Status**: ✅ ALL GATES PASSED - Proceed to Phase 0

## Project Structure

### Documentation (this feature)

```text
specs/001-ansible-playbook-runner/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── checklists/
│   └── requirements.md  # Quality validation checklist
└── spec.md              # Feature specification
```

### Source Code (repository root)

Puppet module structure following PDK conventions:

```text
lib/
└── puppet/
    ├── type/
    │   └── par.rb                    # Custom type definition
    └── provider/
        └── par/
            └── par.rb                # Provider implementation

spec/
├── unit/
│   └── puppet/
│       ├── type/
│       │   └── par_spec.rb          # RSpec tests for type
│       └── provider/
│           └── par/
│               └── par_spec.rb      # RSpec tests for provider
└── acceptance/
    └── par.feature                   # Cucumber BDD scenarios

examples/
└── init.pp                           # Example PAR resource declarations

REFERENCE.md                          # Generated by Puppet Strings
metadata.json                         # Module metadata (already exists)
Gemfile                              # Ruby dependencies (already exists)
Rakefile                             # Rake tasks (already exists)
```

**Structure Decision**: Standard Puppet module structure as generated by PDK. This is a single-project layout (no backend/frontend split) focused on extending Puppet's resource type system. The custom type (`lib/puppet/type/par.rb`) defines the interface and parameters, while the provider (`lib/puppet/provider/par/par.rb`) contains the implementation logic for executing ansible-playbook commands.

## Complexity Tracking

> **No violations detected - this section intentionally left empty**

All constitution principles are satisfied without exceptions. The implementation follows standard Puppet custom type/provider patterns with no additional complexity requiring justification.

---

## Post-Design Constitution Re-evaluation

*Completed after Phase 1 design (research.md, data-model.md, quickstart.md)*

### ✅ I. Puppet Standards & PDK First
- **Status**: COMPLIANT
- **Evidence**: Project structure matches PDK conventions exactly
- **Files**: lib/puppet/type/par.rb, lib/puppet/provider/par/par.rb follow naming standards

### ✅ II. Test-Driven Development (RSpec/Cucumber) (NON-NEGOTIABLE)
- **Status**: COMPLIANT
- **Evidence**: Test structure defined with clear unit (RSpec) and acceptance (Cucumber) paths
- **Test Coverage Plan**: 10+ scenarios in quickstart.md map to test cases
- **TDD Workflow**: Tests will be written first per research.md section 9

### ✅ III. Documentation Standards (Puppet Strings)
- **Status**: COMPLIANT
- **Evidence**: research.md section 10 defines Strings annotation requirements
- **Documentation Plan**: All parameters documented with @doc, examples included

### ✅ IV. Validation & Quality Gates
- **Status**: COMPLIANT
- **Evidence**: quickstart.md includes `pdk validate` verification steps
- **Quality Gates**: Zero offenses target confirmed, automated validation in workflow

### ✅ V. Code Quality & Idiomatic Puppet
- **Status**: COMPLIANT
- **Evidence**: research.md sections 1-2 detail idiomatic Puppet patterns
- **Simplicity**: Single type/provider pair, ~500-800 LOC, no unnecessary abstraction

**Final Gate Status**: ✅ ALL GATES PASSED - Ready for `/speckit.tasks` phase

**Changes from Initial Check**: None - design maintains full constitutional compliance throughout all phases.
