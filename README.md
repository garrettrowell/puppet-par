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
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

The PAR module provides a custom Puppet type and provider that enables execution of Ansible playbooks on the local machine. This allows you to integrate Ansible automation into your Puppet-managed infrastructure without requiring SSH access, inventory files, or remote connections.

Key features:
- Execute Ansible playbooks directly from Puppet catalogs
- Runs playbooks against localhost only (no SSH required)
- Supports Puppet noop mode for dry-run testing
- Automatic dependency management with File resources
- Comprehensive error handling and validation
- Idempotency handled by Ansible's change detection

**Note**: This module is currently in MVP (Minimum Viable Product) status. It provides basic playbook execution functionality. Advanced features like passing variables and parsing Ansible output for change detection are planned for future releases.

## Setup

### What par affects

* Executes `ansible-playbook` command on the local system
* May modify system state based on playbook content
* Requires Ansible to be installed and available in PATH

### Setup Requirements

**Required**:
- Puppet 7.24 or higher
- Ansible 2.9 or higher (ansible-playbook command must be in PATH)
- puppetlabs/stdlib module (for example manifests)

**Supported Platforms**:
- RHEL/CentOS/AlmaLinux/Rocky 7-9
- Debian 10-12
- Ubuntu 18.04-22.04
- Windows Server 2019-2022, Windows 10-11

### Beginning with par

1. Install the module:
   ```
   puppet module install garrettrowell-par
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

### Basic playbook execution

```puppet
par { 'setup-webserver':
  ensure   => present,
  playbook => '/etc/ansible/playbooks/webserver.yml',
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

### Important behavior notes

- **Always executes**: PAR resources run every time Puppet applies the catalog (similar to `exec` resources)
- **Idempotency**: Managed by Ansible's own change detection within playbooks
- **Localhost only**: Playbooks should target localhost with `connection: local`
- **UTF-8 locale**: Provider automatically sets LC_ALL and LANG environment variables for Ansible compatibility

## Reference

See [REFERENCE.md](REFERENCE.md) for detailed API documentation.

### Quick Reference

**Type**: `par`

**Parameters**:
- `name` (namevar) - Unique identifier for the resource
- `playbook` (required) - Absolute path to Ansible playbook file

**Properties**:
- `ensure` - Set to `present` to execute (default: `present`)

## Limitations

### Current MVP Limitations

This is an MVP release with basic functionality. The following features are planned for future releases:

- **No variable passing**: Cannot pass custom variables to playbooks yet
- **No Ansible option support**: Tags, limits, verbosity, etc. not yet supported  
- **No change detection**: Provider doesn't parse Ansible output to detect changes
- **Always executes**: Runs playbook every time (idempotency via Ansible only)

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

# List available tests
pdk test unit --list
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Ensure all tests pass with `pdk test unit -v`
5. Ensure validation passes with `pdk validate`
6. Submit a pull request

### Development Roadmap

**Phase 1**: ✅ MVP - Basic playbook execution (current release)
**Phase 2**: 🔄 Configuration options (variables, tags, limits, verbosity)
**Phase 3**: 🔄 Change detection (parse Ansible JSON output)
**Phase 4**: 🔄 Documentation and polish

## Release Notes

### 0.1.0 (MVP)

Initial release with basic playbook execution functionality:
- PAR custom type and provider
- Ansible playbook execution on localhost
- Noop mode support
- Automatic File resource dependencies
- Comprehensive error handling
- UTF-8 locale configuration for Ansible

[1]: https://puppet.com/docs/pdk/latest/pdk_generating_modules.html
[2]: https://puppet.com/docs/puppet/latest/puppet_strings.html
[3]: https://puppet.com/docs/puppet/latest/puppet_strings_style.html

[1]: https://puppet.com/docs/pdk/latest/pdk_generating_modules.html
[2]: https://puppet.com/docs/puppet/latest/puppet_strings.html
[3]: https://puppet.com/docs/puppet/latest/puppet_strings_style.html
