# par

PAR (Puppet Ansible Runner) - Execute Ansible playbooks through Puppet

## Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with par](#setup)
    * [What par affects](#what-par-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with par](#beginning-with-par)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference - Types and parameters](#reference)
    * [Quick Reference](#quick-reference)
1. [Limitations - OS compatibility, etc.](#limitations)
    * [Platform Support](#platform-support)
    * [Known Issues](#known-issues)
1. [Development - Guide for contributing to the module](#development)
    * [Running Tests](#running-tests)
    * [Contributing](#contributing)
1. [Release Notes](#release-notes)

## Description

The PAR module provides a custom Puppet type and provider that enables execution of Ansible playbooks on the local machine. This allows you to integrate Ansible automation into your Puppet-managed infrastructure without requiring SSH access, inventory files, or remote connections.

Key features:
- Execute Ansible playbooks directly from Puppet catalogs
- Runs playbooks against localhost only (no SSH required)
- Supports Puppet noop mode for dry-run testing
- Automatic dependency management with File resources
- Comprehensive error handling and validation
- Change detection via Ansible JSON output parsing
- Idempotency reporting (shows "created" only when changes occur)
- Exclusive locking to prevent concurrent playbook execution
- Full output control with `logoutput` parameter

## Setup

### What par affects

* Executes `ansible-playbook` command on the local system
* May modify system state based on playbook content
* Requires Ansible to be installed and available in PATH

### Setup Requirements

**Required**:
- Puppet 7.24 or higher
- Ansible 2.9 or higher (ansible-playbook command must be in PATH)

**Supported Platforms**:
- RHEL/CentOS/AlmaLinux/Rocky 7-9
- Debian 10-12
- Ubuntu 18.04-22.04
- Windows Server 2019-2022, Windows 10-11

### Beginning with par

1. Install the module by adding it to your `Puppetfile`:
   ```ruby
   mod 'par',
     git: 'git@github.com:garrettrowell/puppet-par.git',
     tag: '0.1.0'
   ```

2. Ensure Ansible is installed on your nodes:
   ```bash
   # RHEL/CentOS/Fedora
   sudo dnf install ansible-core
   
   # Debian/Ubuntu
   sudo apt install ansible
   ```

3. Create a simple playbook and use PAR to execute it:
   ```puppet
   file { '/etc/ansible/playbooks/setup.yml':
     ensure => file,
     source => 'puppet:///modules/mymodule/setup.yml',
   }
   
   par { 'run-setup':
     ensure   => present,
     playbook => '/etc/ansible/playbooks/setup.yml',
   }
   ```

## Usage

For complete working examples, see the [examples/](examples/) directory which includes:
- `basic.pp` - Simple playbook execution
- `with_vars.pp` - Passing variables to playbooks
- `tags.pp` - Using tags for selective execution
- `timeout.pp` - Timeout and exclusive locking
- `idempotent.pp` - Change detection demonstration
- `logoutput.pp` - Output control
- `exclusive.pp` - Exclusive locking
- `noop.pp` - Noop mode testing
- `init.pp` - Comprehensive example with all parameters

### Basic playbook execution

```puppet
par { 'setup-webserver':
  ensure   => present,
  playbook => '/etc/ansible/playbooks/webserver.yml',
}
```

### Passing variables to playbooks

```puppet
par { 'deploy-app':
  ensure        => present,
  playbook      => '/etc/ansible/playbooks/deploy.yml',
  playbook_vars => {
    'app_version' => '2.1.0',
    'environment' => 'production',
    'debug_mode'  => true,
  },
}
```

### Using tags for selective execution

```puppet
par { 'run-database-tasks':
  ensure   => present,
  playbook => '/etc/ansible/playbooks/full-setup.yml',
  tags     => ['database', 'config'],
}
```

### With timeout and exclusive locking

```puppet
par { 'critical-deployment':
  ensure    => present,
  playbook  => '/etc/ansible/playbooks/deploy.yml',
  timeout   => 600,      # 10 minutes max
  exclusive => true,     # Prevent concurrent execution
  logoutput => true,     # Display full Ansible output
}
```

### With automatic dependency management

PAR automatically creates dependencies on File resources that manage the playbook:

```puppet
file { '/etc/ansible/playbooks/database.yml':
  ensure => file,
  source => 'puppet:///modules/mymodule/database.yml',
}

par { 'configure-database':
  ensure   => present,
  playbook => '/etc/ansible/playbooks/database.yml',
  # Automatically requires File['/etc/ansible/playbooks/database.yml']
}
```

### Testing with noop mode

```bash
# Preview what would execute without actually running
puppet apply --noop mymanifest.pp
```

### Change detection and idempotency

PAR automatically detects changes made by Ansible playbooks:

```puppet
# First run: Creates files, Puppet shows "ensure: created"
# Second run: Files exist, NO "created" message (idempotent)
par { 'idempotent-config':
  ensure   => present,
  playbook => '/etc/ansible/playbooks/config.yml',
}
```

When a playbook makes changes (Ansible reports `changed > 0`), Puppet shows:
```
Notice: /Stage[main]/Main/Par[idempotent-config]/ensure: created
Info: Ansible playbook execution completed: 2 tasks changed
```

When a playbook is idempotent (no changes needed), Puppet shows:
```
Notice: Applied catalog in X.XX seconds
```
(No "created" message - resource is already in desired state)

### Important behavior notes

- **Change detection**: PAR executes playbooks and reports "created" only when Ansible reports changes
- **Idempotency**: First run may show "created", subsequent runs won't if playbook is idempotent
- **Always executes**: Playbook runs every time to check for changes (similar to Ansible's model)
- **Localhost only**: Playbooks should target localhost with `connection: local`
- **UTF-8 locale**: Provider automatically sets LC_ALL and LANG environment variables for Ansible compatibility
- **Exclusive locking**: Use `exclusive => true` to prevent concurrent execution of the same playbook

## Reference

See [REFERENCE.md](REFERENCE.md) for detailed API documentation.

### Quick Reference

**Type**: `par`

**Parameters**:
- `name` (namevar) - Unique identifier for the resource
- `playbook` (required) - Absolute path to Ansible playbook file
- `playbook_vars` - Hash of variables to pass to the playbook
- `tags` - Array of tags to execute
- `skip_tags` - Array of tags to skip
- `start_at_task` - Task name to start execution from
- `limit` - Limit execution to specific hosts pattern
- `verbose` - Boolean to enable verbose output
- `check_mode` - Boolean to run playbook in check mode
- `timeout` - Maximum execution time in seconds
- `user` - User to run ansible-playbook as
- `env_vars` - Hash of environment variables
- `logoutput` - Boolean to display full Ansible output (default: false)
- `exclusive` - Boolean to enable exclusive locking (default: false)

**Properties**:
- `ensure` - Set to `present` to execute (default: `present`)

## Limitations

### Platform Support

- Tested on RHEL-family and Debian-family Linux distributions
- Windows support is declared but not yet thoroughly tested
- Ansible must be installed separately (not managed by this module)

### Known Issues

- Playbooks must target localhost - remote execution not supported
- Playbooks should use `connection: local` for best results
- No integration with Ansible inventory systems

## Development

This module is under active development. Contributions are welcome!

### Running Tests

```bash
# Validate code
pdk validate

# Run unit tests  
pdk test unit -v

# List available unit tests
pdk test unit --list

# Run acceptance tests (requires Ansible installed)
pdk bundle exec rake acceptance

# Run specific acceptance test feature
pdk bundle exec rake acceptance FEATURE=spec/acceptance/par_basic.feature

# Run specific scenario by line number
pdk bundle exec rake acceptance FEATURE=spec/acceptance/par_basic.feature:10

# Test all example manifests
puppet apply --libdir=lib examples/basic.pp
puppet apply --libdir=lib examples/with_vars.pp
puppet apply --libdir=lib examples/tags.pp
puppet apply --libdir=lib examples/timeout.pp
puppet apply --libdir=lib examples/idempotent.pp
puppet apply --libdir=lib examples/logoutput.pp
puppet apply --libdir=lib examples/exclusive.pp
puppet apply --libdir=lib examples/init.pp
puppet apply --libdir=lib --noop examples/noop.pp
```

**Important**: 
- ❌ **Never run `cucumber` directly** - it won't load step definitions properly
- ✅ **Always use `pdk bundle exec rake acceptance`** - properly configured rake task
- ✅ Use the `FEATURE` environment variable to run individual tests when debugging

**Note**: Acceptance tests require:
- Ansible (ansible-playbook) installed and in PATH
- Ability to execute playbooks on localhost

### Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Ensure all validation steps pass:
   - `pdk validate` - Zero offenses
   - `pdk test unit` - All tests passing
   - `pdk bundle exec rake acceptance` - All scenarios passing
   - `puppet apply --libdir=lib examples/*.pp` - All examples working
5. Submit a pull request

## Release Notes

See [CHANGELOG.md](CHANGELOG.md) for version history and release details.
