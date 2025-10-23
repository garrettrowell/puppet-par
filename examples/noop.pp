# PAR Noop Mode Example
#
# This example demonstrates Puppet's noop mode with PAR resources.
# In noop mode, PAR will report what would happen without actually
# executing the Ansible playbook.
#
# Requirements:
# - ansible-playbook must be installed and available in PATH
# - The playbook file must exist at the specified path
#
# Usage:
#   puppet apply --libdir=lib --noop examples/noop.pp
#
# Or test with explicit noop flag per resource:
#   puppet apply --libdir=lib examples/noop.pp

# Create a test playbook
file { '/tmp/test_playbook.yml':
  ensure  => file,
  # lint:ignore:140chars lint:ignore:strict_indent
  content => @(END),
---
- name: Test Playbook for Noop
  hosts: localhost
  gather_facts: false
  tasks:
    - name: This would run in normal mode
      ansible.builtin.debug:
        msg: "This playbook would execute normally"
    
    - name: This would create a file
      ansible.builtin.file:
        path: /tmp/noop_test.txt
        state: touch
| END
  # lint:endignore
}

# In noop mode, this resource will show what would happen
# but will not actually execute the playbook
par { 'noop-example':
  ensure   => present,
  playbook => '/tmp/test_playbook.yml',
  noop     => true, # Explicitly enable noop for this resource
}

# Noop mode behavior:
# - PAR validates the playbook file exists
# - PAR validates ansible-playbook is available
# - PAR shows that it would execute the playbook
# - PAR does NOT actually run ansible-playbook
#
# Expected output in noop mode:
# Notice: /Stage[main]/Main/Par[noop-example]/ensure: created (noop)
#
# This is useful for:
# - Testing Puppet manifests safely
# - Previewing changes before applying
# - CI/CD validation without side effects
