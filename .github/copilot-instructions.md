# par Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-10-24

## Active Technologies
- Ruby 2.7+ (compatible with Puppet 7.24+) + Puppet 7.24+ (core framework for custom types/providers)
- Ansible (external dependency, assumed pre-installed)
- RSpec with rspec-puppet-facts for multi-platform testing

## Project Structure

```text
lib/puppet/type/par.rb          - Custom type definition
lib/puppet/provider/par/par.rb  - Provider implementation
spec/types/par_spec.rb          - Type unit tests
spec/unit/providers/par_spec.rb - Provider unit tests
spec/support/                    - Shared test contexts (windows_cross_compatibility)
spec/spec_helper_local.rb       - PDK-safe local RSpec configuration
examples/                        - Example manifests (9 total)
```

## Commands

# PDK Commands
- `pdk validate` - Run all validators (metadata, puppet, ruby, yaml)
- `pdk test unit` - Run RSpec unit tests
- `pdk bundle exec rake acceptance` - Run Cucumber acceptance tests (all scenarios)
- `pdk bundle exec rake acceptance FEATURE=spec/acceptance/par_basic.feature` - Run specific feature file
- `pdk bundle exec rake spec` - Run RSpec unit tests (alternative)

# Cucumber Test Rules
- ❌ **NEVER** run `cucumber` command directly
- ❌ **NEVER** run `pdk bundle exec cucumber` directly
- ✅ **ALWAYS** use `pdk bundle exec rake acceptance` for acceptance tests
- ✅ Use FEATURE environment variable to run individual features when debugging
- ✅ The rake task properly configures step definitions and support files

# Development Workflow
1. Make changes to code
2. Run `pdk validate` to check code style and syntax
3. Run `pdk test unit` to verify unit tests pass
4. Run `pdk bundle exec rake acceptance` to verify acceptance tests pass
5. Test all example manifests with `puppet apply --libdir=lib examples/*.pp`
6. All validation steps must pass before changes are considered complete

## Code Style

Ruby 2.7+ (compatible with Puppet 7.24+): Follow standard conventions

## Validation Requirements

All changes must pass the following validation steps:

1. **Code Validation**: `pdk validate`
   - Validates metadata.json syntax
   - Checks Puppet manifest syntax and style
   - Checks Ruby code style (RuboCop)
   - Validates YAML syntax
   - Note: puppet-lint may report false positive indentation warnings for heredoc syntax in examples/ - these can be ignored

2. **Unit Tests**: `pdk test unit`
   - All RSpec unit tests must pass
   - Tests for types, providers, and internal logic
   - Current status: 2,481 examples across 16 platforms (100% pass rate)
   - Multi-platform testing validates Windows, RHEL-family, and Debian-family systems

3. **Acceptance Tests**: `pdk bundle exec rake acceptance`
   - All Cucumber acceptance tests must pass
   - Tests real Puppet + Ansible integration
   - Current status: 18 scenarios (129 steps) passing
   - Requires ansible-playbook installed locally

4. **Example Manifests**: `puppet apply --libdir=lib examples/*.pp`
   - All example manifests must successfully apply
   - Examples must demonstrate actual working functionality
   - Use `puppet apply --libdir=lib examples/FILENAME.pp` to test each example
   - Examples: basic.pp, noop.pp, with_vars.pp, tags.pp, timeout.pp, idempotent.pp, logoutput.pp, exclusive.pp, init.pp
   - Noop example requires: `puppet apply --libdir=lib --noop examples/noop.pp`
   - All examples must complete without errors

**Note**: Do not commit or consider work complete unless all four validation steps pass.

## Constitution Enforcement

**NO SHORTCUTS ALLOWED**: This constitution MUST be strictly adhered to at all times.

- ❌ **NEVER** proceed past a validation gate without 100% pass rate
- ❌ **NEVER** suggest "conditionally passed" or "partial pass" for validation gates
- ❌ **NEVER** skip failing tests with the intention of "fixing them later"
- ❌ **NEVER** consider work complete with any failing validations
- ❌ **NEVER** ignore or skip RuboCop conventions or warnings
- ❌ **NEVER** leave "optional" style issues unresolved

✅ **ALL validation steps must pass 100%** before moving to the next phase
✅ **ALL tests must pass** - unit tests AND acceptance tests
✅ **Zero offenses** in all validators - including conventions and warnings
✅ **All examples must work** without errors
✅ **All RuboCop suggestions must be addressed** - conventions are not optional

If validation fails, the work is NOT complete. Fix all failures before proceeding.
If RuboCop reports conventions or warnings, fix them immediately.
No exceptions. No shortcuts. No compromises. No "optional" issues.

## Recent Changes
- 001-ansible-playbook-runner: Completed all phases (P1-P3) with comprehensive testing
- Added multi-platform testing support (16 OS platforms)
- Implemented change detection and idempotency reporting
- Added Windows cross-compatibility testing infrastructure
- All validation gates passing: 2,481 unit tests, 18 acceptance scenarios, 9 examples

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
