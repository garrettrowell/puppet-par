# Implementation Tasks: Ansible Playbook Runner Custom Type

**Feature**: 001-ansible-playbook-runner  
**Branch**: `001-ansible-playbook-runner`  
**Date**: 2025-10-22  
**Tech Stack**: Ruby 2.7+, Puppet 7.24+, RSpec 3.x, Cucumber  
**Test Approach**: TDD (Test-Driven Development) - Write tests before implementation

## Overview

This task list implements a Puppet custom type and provider named `par` that executes Ansible playbooks against localhost. The implementation is organized by user story priority (P1 → P2 → P3) to enable incremental delivery and independent testing.

**Total Tasks**: 46  
**Parallelizable Tasks**: 18  
**User Stories**: 3 (P1: Basic Execution, P2: Configuration Options, P3: Idempotency)

## Implementation Strategy

- **MVP Scope**: User Story 1 (P1) - Basic playbook execution with minimal parameters
- **Incremental Delivery**: Each user story is independently testable and deliverable
- **TDD Workflow**: Write failing tests → Implement → Tests pass → Refactor
- **Validation Gates**: Run `pdk validate` and `pdk test unit` after each phase

---

## Phase 1: Setup & Project Initialization

**Goal**: Prepare the Puppet module structure and test infrastructure for PAR implementation.

**Tasks**:

- [x] T001 Verify PDK module structure exists with lib/, spec/, examples/ directories
- [x] T002 Create lib/puppet/type/ directory if not exists
- [x] T003 Create lib/puppet/provider/par/ directory if not exists
- [x] T004 Create spec/types/ directory for type tests
- [x] T005 Create spec/unit/providers/ directory for provider tests (PDK-compatible layout)
- [x] T006 Create spec/acceptance/ directory for Cucumber scenarios
- [x] T007 Create spec/fixtures/playbooks/ directory for test playbooks
- [x] T008 Create examples/ directory if not exists
- [x] T009 [P] Verify Gemfile includes puppet, puppet-rspec, rspec-puppet gems
- [x] T010 [P] Verify Gemfile includes cucumber and aruba gems for acceptance tests (configured via .sync.yml and pdk update)
- [x] T011 Run `pdk bundle install` to install dependencies
- [x] T012 [P] Create spec/fixtures/playbooks/simple.yml test playbook
- [x] T013 [P] Create spec/fixtures/playbooks/with_vars.yml test playbook
- [x] T014 [P] Create spec/fixtures/playbooks/failing.yml test playbook

**Validation**: Directory structure matches plan.md, bundle install succeeds, test fixtures created.

---

## Phase 2: Foundational Infrastructure

**Goal**: Implement shared utilities and validation logic needed by all user stories.

**Tasks**:

- [x] T015 [P] Create spec/spec_helper.rb with RSpec configuration for puppet-rspec
- [x] T016 [P] Create spec/acceptance/support/env.rb for Cucumber environment setup
- [x] T017 Verify ansible-playbook is available in test environment PATH

**Validation**: RSpec and Cucumber can load without errors, ansible-playbook found.

---

## Phase 3: User Story 1 - Execute Basic Ansible Playbook (P1 - MVP)

**Goal**: Implement core functionality to execute an Ansible playbook against localhost with minimal parameters.

**Independent Test Criteria**: 
- PAR resource can be declared with just a playbook path
- Playbook executes against localhost successfully
- Puppet reports success/failure correctly
- Noop mode works without executing playbook
- Clear error messages for missing playbooks and ansible executable

### Tests (TDD - Write First)

- [x] T018 [P] [US1] Write type spec in spec/types/par_spec.rb - test namevar parameter
- [x] T019 [P] [US1] Write type spec - test playbook parameter validation (required, absolute path)
- [x] T020 [P] [US1] Write type spec - test playbook parameter rejects relative paths
- [x] T021 [P] [US1] Write provider spec in spec/providers/par_spec.rb - test exists? method
- [x] T022 [P] [US1] Write provider spec - test create method basic structure
- [x] T023 [P] [US1] Write provider spec - test build_command generates correct ansible-playbook command
- [x] T024 [P] [US1] Write provider spec - test validate_ansible checks for ansible-playbook in PATH
- [x] T025 [P] [US1] Write provider spec - test noop mode prevents execution
- [x] T026 [P] [US1] Write provider spec - test error handling for missing playbook file
- [x] T027 [P] [US1] Write provider spec - test error handling for missing ansible executable
- [x] T028 [P] [US1] Write Cucumber feature in spec/acceptance/par_basic.feature - basic execution scenario

**Run Tests**: `pdk test unit -v` - All tests should FAIL (Red phase)

### Implementation

- [x] T029 [US1] Implement PAR custom type skeleton in lib/puppet/type/par.rb with @doc
- [x] T030 [US1] Implement namevar parameter (name) in lib/puppet/type/par.rb
- [x] T031 [US1] Implement playbook parameter with absolute path validation in lib/puppet/type/par.rb
- [x] T032 [US1] Implement autorequire for File[playbook] in lib/puppet/type/par.rb
- [x] T033 [US1] Add Puppet Strings documentation for namevar and playbook parameters
- [x] T034 [US1] Create provider skeleton in lib/puppet/provider/par/par.rb with desc
- [x] T035 [US1] Implement exists? method to check playbook file existence
- [x] T036 [US1] Implement validate_ansible method to check for ansible-playbook in PATH
- [x] T037 [US1] Implement build_command method to construct ansible-playbook CLI command
- [x] T038 [US1] Implement create method with ansible-playbook execution using Puppet::Util::Execution
- [x] T039 [US1] Implement noop mode support in create method
- [x] T040 [US1] Implement error handling for missing playbook file
- [x] T041 [US1] Implement error handling for missing ansible executable
- [x] T042 [US1] Add Puppet Strings documentation for provider methods

**Run Tests**: `pdk test unit -v` - All US1 tests should PASS (Green phase)

### Examples & Documentation

- [x] T043 [P] [US1] Create examples/basic.pp with minimal PAR resource declaration
- [x] T044 [P] [US1] Create examples/noop.pp demonstrating noop mode usage

**Validation**:
- [x] Run `pdk validate` - zero offenses
- [x] Run `pdk test unit -v` - 100% pass rate for US1 tests (34 examples, 0 failures)
- [x] Run `puppet apply examples/basic.pp` - playbook executes successfully (locale environment variables set by provider)
- [x] Run `puppet apply --noop examples/noop.pp` - shows what would execute without running

**Story Complete**: User Story 1 is independently testable and deployable as MVP.

---

## Phase 4: User Story 2 - Pass Custom Configuration Options (P2)

**Goal**: Add support for passing variables and configuration options to Ansible playbooks.

**Independent Test Criteria**:
- PAR resource accepts playbook_vars hash
- Variables correctly serialized to JSON and passed via -e flag
- Ansible configuration parameters (tags, skip_tags, etc.) work correctly
- Special characters in variables are properly escaped
- Nested hashes and arrays handled correctly

### Tests (TDD - Write First)

- [ ] T045 [P] [US2] Write type spec - test playbook_vars parameter accepts Hash
- [ ] T046 [P] [US2] Write type spec - test playbook_vars rejects non-Hash values
- [ ] T047 [P] [US2] Write type spec - test tags parameter accepts Array
- [ ] T048 [P] [US2] Write type spec - test skip_tags parameter accepts Array
- [ ] T049 [P] [US2] Write type spec - test start_at_task parameter accepts String
- [ ] T050 [P] [US2] Write type spec - test limit parameter accepts String
- [ ] T051 [P] [US2] Write type spec - test verbose parameter accepts Boolean
- [ ] T052 [P] [US2] Write type spec - test check_mode parameter accepts Boolean
- [ ] T053 [P] [US2] Write type spec - test timeout parameter accepts Integer and validates positive
- [ ] T054 [P] [US2] Write type spec - test user parameter accepts String
- [ ] T055 [P] [US2] Write type spec - test environment parameter accepts Hash
- [ ] T056 [P] [US2] Write provider spec - test build_command includes playbook_vars as JSON via -e flag
- [ ] T057 [P] [US2] Write provider spec - test build_command handles empty playbook_vars
- [ ] T058 [P] [US2] Write provider spec - test build_command adds tags with -t option
- [ ] T059 [P] [US2] Write provider spec - test build_command adds skip_tags with --skip-tags
- [ ] T060 [P] [US2] Write provider spec - test build_command adds other Ansible options
- [ ] T061 [P] [US2] Write provider spec - test JSON serialization handles nested hashes
- [ ] T062 [P] [US2] Write provider spec - test JSON serialization handles arrays
- [ ] T063 [P] [US2] Write provider spec - test JSON serialization escapes special characters
- [ ] T064 [P] [US2] Write provider spec - test timeout handling terminates long-running playbooks
- [ ] T065 [P] [US2] Write Cucumber feature - variables passing scenario
- [ ] T066 [P] [US2] Write Cucumber feature - complex variables scenario

**Run Tests**: `pdk test unit -v` - All US2 tests should FAIL (Red phase)

### Implementation

- [ ] T067 [US2] Implement playbook_vars parameter with Hash validation in lib/puppet/type/par.rb
- [ ] T068 [US2] Implement tags parameter with Array validation in lib/puppet/type/par.rb
- [ ] T069 [US2] Implement skip_tags parameter with Array validation in lib/puppet/type/par.rb
- [ ] T070 [US2] Implement start_at_task parameter in lib/puppet/type/par.rb
- [ ] T071 [US2] Implement limit parameter in lib/puppet/type/par.rb
- [ ] T072 [US2] Implement verbose parameter with Boolean validation in lib/puppet/type/par.rb
- [ ] T073 [US2] Implement check_mode parameter with Boolean validation in lib/puppet/type/par.rb
- [ ] T074 [US2] Implement timeout parameter with Integer validation in lib/puppet/type/par.rb
- [ ] T075 [US2] Implement user parameter in lib/puppet/type/par.rb
- [ ] T076 [US2] Implement environment parameter with Hash validation in lib/puppet/type/par.rb
- [ ] T077 [US2] Add Puppet Strings documentation for all new parameters
- [ ] T078 [US2] Update build_command to add -e flag with JSON.generate(playbook_vars)
- [ ] T079 [US2] Add require 'json' to provider in lib/puppet/provider/par/par.rb
- [ ] T080 [US2] Update build_command to add -t tags if provided
- [ ] T081 [US2] Update build_command to add --skip-tags if provided
- [ ] T082 [US2] Update build_command to add --start-at-task if provided
- [ ] T083 [US2] Update build_command to add --limit if provided
- [ ] T084 [US2] Update build_command to add -v if verbose is true
- [ ] T085 [US2] Update build_command to add --check if check_mode is true
- [ ] T086 [US2] Implement timeout support in execute call using :timeout option
- [ ] T087 [US2] Implement timeout error handling with clear error message
- [ ] T088 [US2] Implement user support in execute call using :uid option
- [ ] T089 [US2] Implement environment support in execute call using :custom_environment option

**Run Tests**: `pdk test unit -v` - All US2 tests should PASS (Green phase)

### Examples & Documentation

- [ ] T090 [P] [US2] Create examples/with_vars.pp demonstrating playbook_vars usage
- [ ] T091 [P] [US2] Create examples/tags.pp demonstrating tags and skip_tags usage
- [ ] T092 [P] [US2] Create examples/timeout.pp demonstrating timeout parameter

**Validation**:
- [ ] Run `pdk validate` - zero offenses
- [ ] Run `pdk test unit -v` - 100% pass rate for US1 + US2 tests
- [ ] Run `puppet apply examples/with_vars.pp` - variables passed correctly
- [ ] Verify JSON serialization with complex nested structures

**Story Complete**: User Story 2 is independently testable and can be deployed incrementally.

---

## Phase 5: User Story 3 - Idempotent Playbook Execution (P3)

**Goal**: Parse Ansible JSON output to detect changes and report idempotency status to Puppet.

**Independent Test Criteria**:
- Playbooks always execute (no conditional skipping)
- Provider parses Ansible JSON output for change status
- Puppet reports "changed" when Ansible reports changes
- Puppet reports "in-sync" when Ansible reports no changes
- Puppet reports "failed" when Ansible reports task failures
- logoutput parameter controls output visibility
- exclusive parameter serializes execution when enabled

### Tests (TDD - Write First)

- [ ] T093 [P] [US3] Write type spec - test logoutput parameter accepts Boolean, defaults to false
- [ ] T094 [P] [US3] Write type spec - test exclusive parameter accepts Boolean, defaults to false
- [ ] T095 [P] [US3] Write provider spec - test build_command adds -o flag for JSON output
- [ ] T096 [P] [US3] Write provider spec - test parse_json_output extracts changed_count from JSON
- [ ] T097 [P] [US3] Write provider spec - test parse_json_output extracts ok_count from JSON
- [ ] T098 [P] [US3] Write provider spec - test parse_json_output extracts failed_count from JSON
- [ ] T099 [P] [US3] Write provider spec - test create reports changed when changed_count > 0
- [ ] T100 [P] [US3] Write provider spec - test create reports in-sync when changed_count == 0
- [ ] T101 [P] [US3] Write provider spec - test create raises error when failed_count > 0
- [ ] T102 [P] [US3] Write provider spec - test logoutput displays stdout when true
- [ ] T103 [P] [US3] Write provider spec - test logoutput suppresses stdout when false
- [ ] T104 [P] [US3] Write provider spec - test acquire_lock when exclusive is true
- [ ] T105 [P] [US3] Write provider spec - test release_lock when exclusive is true
- [ ] T106 [P] [US3] Write provider spec - test lock prevents concurrent execution
- [ ] T107 [P] [US3] Write Cucumber feature - idempotency scenario (run twice, verify change detection)

**Run Tests**: `pdk test unit -v` - All US3 tests should FAIL (Red phase)

### Implementation

- [ ] T108 [US3] Implement logoutput parameter with Boolean validation in lib/puppet/type/par.rb
- [ ] T109 [US3] Implement exclusive parameter with Boolean validation in lib/puppet/type/par.rb
- [ ] T110 [US3] Add Puppet Strings documentation for logoutput and exclusive parameters
- [ ] T111 [US3] Update build_command to add -o flag for JSON output format
- [ ] T112 [US3] Implement parse_json_output method to parse Ansible JSON stats
- [ ] T113 [US3] Update execute_playbook to capture JSON output
- [ ] T114 [US3] Update execute_playbook to call parse_json_output
- [ ] T115 [US3] Update execute_playbook to display output when logoutput is true
- [ ] T116 [US3] Update execute_playbook to suppress output when logoutput is false
- [ ] T117 [US3] Update execute_playbook to raise error when failed_count > 0
- [ ] T118 [US3] Update execute_playbook to log info message when changed_count > 0
- [ ] T119 [US3] Update execute_playbook to log debug message when changed_count == 0
- [ ] T120 [US3] Implement acquire_lock method using Puppet::Util::Lockfile or similar
- [ ] T121 [US3] Implement release_lock method
- [ ] T122 [US3] Update create method to acquire lock before execution if exclusive is true
- [ ] T123 [US3] Update create method to release lock after execution in ensure block
- [ ] T124 [US3] Implement lock error handling for acquisition failures

**Run Tests**: `pdk test unit -v` - All US3 tests should PASS (Green phase)

### Examples & Documentation

- [ ] T125 [P] [US3] Create examples/idempotent.pp demonstrating change detection
- [ ] T126 [P] [US3] Create examples/logoutput.pp demonstrating logoutput parameter
- [ ] T127 [P] [US3] Create examples/exclusive.pp demonstrating exclusive parameter

**Validation**:
- [ ] Run `pdk validate` - zero offenses
- [ ] Run `pdk test unit -v` - 100% pass rate for all tests (US1 + US2 + US3)
- [ ] Run `puppet apply examples/idempotent.pp` twice - verify change detection
- [ ] Verify JSON parsing with debug output
- [ ] Test exclusive locking with concurrent PAR resources

**Story Complete**: User Story 3 is independently testable. All P1-P3 stories complete.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Goal**: Complete documentation, examples, and final validation.

**Tasks**:

- [ ] T128 Add comprehensive example in examples/init.pp demonstrating all parameters
- [ ] T129 Generate REFERENCE.md using `pdk bundle exec rake strings:generate:reference`
- [ ] T130 Review and update README.md with PAR usage examples
- [ ] T131 [P] Run full Cucumber acceptance test suite `pdk bundle exec cucumber`
- [ ] T132 Run `pdk validate` final check - must report zero offenses
- [ ] T133 Run `pdk test unit -v` final check - must report 100% pass rate
- [ ] T134 [P] Test on RHEL/CentOS system (primary target platform)
- [ ] T135 [P] Test on Debian/Ubuntu system
- [ ] T136 Verify all quickstart.md scenarios work as documented
- [ ] T137 Update CHANGELOG.md with feature details
- [ ] T138 Verify metadata.json includes correct Puppet and OS support
- [ ] T139 Tag release candidate for review

**Validation**:
- [ ] All documentation complete and accurate
- [ ] REFERENCE.md generated successfully
- [ ] All platforms tested
- [ ] Ready for production deployment

---

## Dependency Graph

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational)
    ↓
Phase 3 (US1 - MVP) ──────────────────┐
    ↓                                  │
Phase 4 (US2 - Configuration) ────────┤ All independent
    ↓                                  │ after Phase 2
Phase 5 (US3 - Idempotency) ──────────┘
    ↓
Phase 6 (Polish)
```

**Story Completion Order**: P1 → P2 → P3 (sequential by priority)

**Independent Stories**: US2 and US3 have no dependencies on each other (both depend on US1 only)

---

## Parallel Execution Opportunities

### Within User Story 1 (MVP)
- Tests (T018-T028) can all be written in parallel
- Documentation tasks (T043-T044) can be done in parallel with implementation

### Within User Story 2 (Configuration)
- Tests (T045-T066) can mostly be written in parallel (22 test tasks)
- Parameter implementations (T067-T076) can be done in parallel once type file created
- Example files (T090-T092) can be created in parallel

### Within User Story 3 (Idempotency)
- Tests (T093-T107) can mostly be written in parallel (15 test tasks)
- Example files (T125-T127) can be created in parallel

### Phase 6 (Polish)
- Platform testing (T134-T135) can be done in parallel
- Test suite execution (T131) can run in parallel with documentation updates

**Estimated Parallel Speedup**: ~40% reduction in wall-clock time if parallelizable tasks run concurrently

---

## Testing Strategy

### TDD Red-Green-Refactor Cycle

For each user story phase:

1. **RED**: Write all tests first (they should fail)
   - Run `pdk test unit -v` to verify tests fail appropriately
   - Failing tests confirm test validity

2. **GREEN**: Implement functionality to pass tests
   - Implement minimal code to make tests pass
   - Run `pdk test unit -v` repeatedly until all pass
   - Don't optimize yet - just make it work

3. **REFACTOR**: Improve code quality
   - Clean up implementation
   - Run tests after each refactor to ensure no regression
   - Run `pdk validate` to check code style

### Test Coverage Goals

- **Unit Tests**: 100% coverage of type parameters and provider methods
- **Acceptance Tests**: All quickstart.md scenarios covered by Cucumber features
- **Validation**: Zero offenses from `pdk validate` throughout development

---

## Success Criteria

### Phase 3 Complete (MVP Ready)
- [ ] Basic playbook execution works
- [ ] Noop mode prevents execution
- [ ] Error handling for missing files/executables
- [ ] All US1 tests pass
- [ ] Examples work on test system

### Phase 4 Complete (Configuration Ready)
- [ ] Variables passed correctly as JSON
- [ ] All Ansible configuration options work
- [ ] Timeout handling works
- [ ] All US1 + US2 tests pass

### Phase 5 Complete (Idempotency Ready)
- [ ] JSON output parsing works
- [ ] Change detection accurate
- [ ] logoutput parameter controls visibility
- [ ] exclusive parameter serializes execution
- [ ] All US1 + US2 + US3 tests pass

### Phase 6 Complete (Production Ready)
- [ ] All documentation complete
- [ ] REFERENCE.md generated
- [ ] Zero validation offenses
- [ ] 100% test pass rate
- [ ] Multi-platform tested
- [ ] Ready for release

---

## Command Reference

```bash
# Run all unit tests
pdk test unit -v

# Run specific test file (standard puppet-rspec layout)
pdk test unit --tests=spec/types/par_spec.rb
pdk test unit --tests=spec/providers/par_spec.rb

# Run validation
pdk validate

# Run acceptance tests
pdk bundle exec cucumber spec/acceptance/

# Generate documentation
pdk bundle exec rake strings:generate:reference

# Apply example manifest
puppet apply --modulepath=/path/to/modules examples/basic.pp

# Apply in noop mode
puppet apply --noop --modulepath=/path/to/modules examples/basic.pp
```

---

## Notes

- **Constitution Compliance**: All tasks designed to maintain PDK conventions, TDD workflow, and zero validation offenses
- **Incremental Value**: Each user story delivers standalone value and can be deployed independently
- **Test First**: Always write tests before implementation (TDD mandate)
- **Validation Gates**: Run `pdk validate` and `pdk test unit` after each phase completion
- **Documentation**: Puppet Strings annotations required for all parameters and methods
