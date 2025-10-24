# PAR Idempotency and Change Detection Example
#
# This example demonstrates how PAR detects and reports changes made by
# Ansible playbooks. PAR uses Ansible's JSON output format to parse
# execution statistics and report whether tasks made changes to the system.
#
# Change Detection Behavior:
# - First run: Creates directory and file, Puppet shows "ensure: created"
# - Second run: No changes needed, Puppet shows NO "created" message (idempotent)
# - This demonstrates Ansible's idempotency detection through PAR
#
# Requirements:
# - ansible-playbook must be installed and available in PATH
#
# Usage:
#   # First run - should report changes
#   puppet apply --libdir=lib examples/idempotent.pp
#   
#   # Second run - should report no changes (idempotent)
#   puppet apply --libdir=lib examples/idempotent.pp
#
#   # Clean up to test again
#   rm -rf /tmp/par_test_dir

# Create a playbook that is idempotent (file creation)
file { '/tmp/idempotent_playbook.yml':
  ensure  => file,
  # lint:ignore:140chars lint:ignore:strict_indent
  content => @(END),
---
- name: Idempotency Test Playbook
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Ensure test directory exists (idempotent task)
      ansible.builtin.file:
        path: /tmp/par_test_dir
        state: directory
        mode: '0755'

    - name: Set file content (idempotent task)
      ansible.builtin.copy:
        dest: /tmp/par_test_dir/idempotent_test.txt
        content: |
          This file was created by PAR idempotency test.
          If this file already exists with this content, no changes will be made.
        mode: '0644'

    - name: Display idempotency status
      ansible.builtin.debug:
        msg: "Task completed - check PAR change detection!"
      changed_when: false
| END
  # lint:endignore
}

# Execute the playbook with change detection enabled
par { 'idempotent-example':
  ensure   => present,
  playbook => '/tmp/idempotent_playbook.yml',
}

# Change Detection Output:
#
# FIRST RUN (when /tmp/par_test_dir/idempotent_test.txt doesn't exist):
# Notice: /Stage[main]/Main/Par[idempotent-example]/ensure: created
# Info: Ansible playbook execution completed: 2 tasks changed
#
# SECOND RUN (when directory and file already exist with correct content):
# Notice: Applied catalog in X.XX seconds
# (NO "created" message - resource is idempotent)
#
# This demonstrates:
# - PAR executes Ansible playbook and checks for changes
# - First run creates resources and Puppet reports "created"
# - Subsequent idempotent runs do NOT show "created" (no changes)
# - exists? returns true when no changes, false when changes made
# - Puppet's change reporting accurately reflects actual system changes
#
# Notes:
# - Change detection requires Ansible JSON callback (automatically enabled)
# - Use 'logoutput => true' parameter to see full Ansible output
# - exists? method executes playbook to determine if changes would be made
