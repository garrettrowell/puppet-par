# Changelog

All notable changes to this project will be documented in this file.

## Release 0.1.0 (2025-10-24)

Initial release of PAR (Puppet Ansible Runner) - A Puppet custom type and provider for executing Ansible playbooks through Puppet with comprehensive configuration options and change detection.

### Features

#### Core Functionality
- **Ansible Playbook Execution**: Execute Ansible playbooks against localhost through Puppet resources
- **Always-Run Model**: Playbooks execute on every Puppet run, with change detection based on Ansible's own idempotency reporting
- **Change Detection**: Parse Ansible JSON output to accurately report changes to Puppet's change tracking system
- **Noop Support**: Full support for Puppet's `--noop` mode - shows intended actions without execution

#### Parameters

**Required Parameters**:
- `playbook` - Absolute path to Ansible playbook file (autorequires File resource)

**Variables**:
- `playbook_vars` - Hash of variables to pass to playbook via Ansible's `--extra-vars` (serialized as JSON)

**Execution Control**:
- `tags` - Array of tags to execute (Ansible `--tags`)
- `skip_tags` - Array of tags to skip (Ansible `--skip-tags`)
- `start_at_task` - Task name to start execution at (Ansible `--start-at-task`)
- `limit` - Limit execution to specific hosts (Ansible `--limit`)
- `verbose` - Enable verbose Ansible output (Ansible `-v`)
- `check_mode` - Run in check mode without making changes (Ansible `--check`)
- `timeout` - Maximum execution time in seconds (terminates on timeout)

**Environment**:
- `environment` - Hash of environment variables to set for playbook execution
- `user` - Unix user to execute playbook as (Ansible `--user`)

**Output & Logging**:
- `logoutput` - Display ansible-playbook stdout during execution (default: false)
- `exclusive` - Serialize execution with lock file to prevent concurrent runs (default: false)

**Concurrency Control**:
- `exclusive` - Lock-based serialization to prevent concurrent PAR executions

#### Validation & Error Handling
- Absolute path validation for playbook parameter
- Pre-execution validation for ansible-playbook availability
- Comprehensive error messages for missing playbooks and executables
- Timeout handling with process termination
- Failed task detection from Ansible JSON output

#### Data Type Support
- Simple scalar values (strings, integers, booleans)
- Complex nested hashes and arrays
- Proper JSON serialization with special character escaping
- Type validation for all parameters

### Testing

#### Test Coverage
- **Unit Tests**: 154 examples with 100% pass rate
- **Acceptance Tests**: 18 Cucumber scenarios (129 steps) validating real Puppet + Ansible integration
- **Multi-Platform**: Tests validate functionality across 16 operating systems using rspec-puppet-facts
- **Zero Offenses**: All PDK validators passing (metadata, puppet, ruby, yaml)

#### Supported Platforms
- **RHEL-family**: CentOS 7/8/9, RHEL 7/8/9, OracleLinux 7, Scientific 7, Rocky 8, AlmaLinux 8
- **Debian-family**: Debian 10/11/12, Ubuntu 18.04/20.04/22.04
- **Windows**: Server 2019/2022, Windows 10/11

### Examples

Eight comprehensive example manifests demonstrating all features:
- `basic.pp` - Minimal playbook execution
- `noop.pp` - Noop mode demonstration
- `with_vars.pp` - Variable passing
- `tags.pp` - Tag filtering
- `timeout.pp` - Timeout handling
- `idempotent.pp` - Change detection
- `logoutput.pp` - Output control
- `exclusive.pp` - Concurrent execution control
- `init.pp` - Comprehensive demonstration of all 14 parameters

### Documentation
- Complete API documentation in REFERENCE.md (generated via Puppet Strings)
- Comprehensive README.md with usage examples and feature descriptions
- Detailed quickstart.md with 10 validation scenarios
- Inline Puppet Strings annotations for all parameters and methods

### Bugfixes

None - Initial release.

### Known Issues

- **Windows Autorequire**: File autorequire may not consistently work on Windows due to path normalization differences. This is a known Puppet/Windows limitation and does not affect PAR's core functionality.
- **Locale Warnings**: Ansible may emit locale warnings on systems without proper locale configuration. PAR automatically sets `LC_ALL=en_US.UTF-8` to minimize these warnings.

### Breaking Changes

None - Initial release.

### Migration Notes

Not applicable - Initial release.

### Contributors

- Garrett Rowell (@garrettrowell) - Initial implementation
