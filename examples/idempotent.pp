# PAR Idempotency and Change Detection Example
#
# This example demonstrates how PAR detects and reports changes made by
# Ansible playbooks. PAR uses Ansible's JSON output format to parse
# execution statistics and report whether tasks made changes to the system.
#
# Change Detection Behavior:
# - First run: Creates file, PAR reports "X tasks changed" (info level)
# - Second run: File already exists, PAR reports "no changes" (debug level)
# - This demonstrates Ansible's idempotency through PAR
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
#   rm /tmp/idempotent_test.txt

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
    - name: Create a test file (idempotent task)
      ansible.builtin.file:
        path: /tmp/idempotent_test.txt
        state: touch
        mode: '0644'
    
    - name: Set file content (idempotent task)
      ansible.builtin.copy:
        dest: /tmp/idempotent_test.txt
        content: |
          This file was created by PAR idempotency test.
          If this file already exists with this content, no changes will be made.
        mode: '0644'
    
    - name: Display idempotency status
      ansible.builtin.debug:
        msg: "Task completed - check PAR change detection!"
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
# FIRST RUN (when /tmp/idempotent_test.txt doesn't exist):
# Info: /Stage[main]/Main/Par[idempotent-example]/ensure: Ansible playbook 
#       execution completed: 2 tasks changed
#
# SECOND RUN (when /tmp/idempotent_test.txt already exists with correct content):
# Debug: /Stage[main]/Main/Par[idempotent-example]/ensure: Ansible playbook 
#        execution completed with no changes (idempotent run)
#
# This demonstrates:
# - PAR parses Ansible's JSON output to detect changes
# - First run creates resources (reports changes at info level)
# - Subsequent runs are idempotent (reports at debug level)
# - Ansible's own change detection is preserved through PAR
#
# Notes:
# - Change detection requires Ansible JSON callback (automatically enabled)
# - Use 'logoutput => true' parameter to see full Ansible output
# - Info messages appear in standard Puppet runs
# - Debug messages only appear with --debug flag
