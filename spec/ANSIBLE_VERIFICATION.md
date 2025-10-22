# Ansible Verification for PAR Testing

## Current Status

✅ **ansible-playbook is available in the test environment**

## Verification Details

**Executable Location**: `/Users/garrett.rowell/.pyenv/shims/ansible-playbook`

**Version**: ansible-playbook [core 2.19.3]

**Python Version**: 3.13.7

**Installation Method**: System installation via Homebrew/pyenv

## How Provider Will Check

The PAR provider uses `Puppet::Util.which('ansible-playbook')` to locate the executable, which searches the system PATH. This matches standard Puppet provider patterns.

## Cucumber Environment

The `spec/acceptance/support/env.rb` file includes an `ansible_available?` helper method that checks for ansible-playbook before running acceptance tests. Tests are automatically skipped if Ansible is not installed.

## Installing Ansible (if needed)

If ansible-playbook is not available in your environment, install it using one of these methods:

### macOS
```bash
brew install ansible
```

### RHEL/CentOS/Rocky/AlmaLinux
```bash
sudo yum install ansible
# or
sudo dnf install ansible
```

### Debian/Ubuntu
```bash
sudo apt-get update
sudo apt-get install ansible
```

### Python pip (any OS)
```bash
pip install ansible
# or
pip3 install ansible
```

### Verify Installation
```bash
which ansible-playbook
ansible-playbook --version
```

## Test Environment Requirements

- Ansible 2.9+ (recommended: 2.12+)
- Python 2.7+ or Python 3.6+ (for Ansible)
- SSH access not required (PAR uses `--connection=local`)

## Skipping Acceptance Tests

If Ansible cannot be installed, you can still run unit tests:

```bash
# Run only unit tests (no Ansible required)
pdk test unit -v

# Skip acceptance tests
pdk test unit --tests=spec/unit/
```

The Cucumber acceptance tests will automatically skip if ansible-playbook is not found.

## Verification Commands

```bash
# Check if ansible-playbook is in PATH
which ansible-playbook

# Verify it works
ansible-playbook --version

# Test with Puppet utilities (matches provider logic)
pdk bundle exec ruby -e "require 'puppet'; puts Puppet::Util.which('ansible-playbook') || 'NOT FOUND'"
```

## Notes

- The PAR module executes playbooks locally using `ansible-playbook -i localhost, --connection=local`
- No Ansible inventory files are required
- No SSH setup is needed
- Playbooks run directly on the local machine
- All Ansible community modules and collections are available if installed

## Status for Task T017

✅ Verified: ansible-playbook is available in test environment PATH  
✅ Version confirmed: ansible-playbook [core 2.19.3]  
✅ Functional verification: successful  
✅ Ready for acceptance test development
