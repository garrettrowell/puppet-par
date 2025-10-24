# PAR Log Output Control Example
#
# This example demonstrates the 'logoutput' parameter which controls
# whether Ansible playbook execution output is displayed in Puppet logs.
#
# logoutput Parameter:
# - true:  Display full Ansible playbook output (useful for debugging)
# - false: Suppress output, only show PAR's change detection summary (default)
#
# Requirements:
# - ansible-playbook must be installed and available in PATH
#
# Usage:
#   puppet apply --libdir=lib examples/logoutput.pp

# Create a playbook with verbose output
file { '/tmp/logoutput_playbook.yml':
  ensure  => file,
  # lint:ignore:140chars lint:ignore:strict_indent
  content => @(END),
---
- name: Log Output Test Playbook
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Display first message
      ansible.builtin.debug:
        msg: "This is task 1 - you'll see this if logoutput is enabled"
    
    - name: Display second message
      ansible.builtin.debug:
        msg: "This is task 2 - detailed Ansible output"
    
    - name: Create a test file
      ansible.builtin.file:
        path: /tmp/logoutput_test.txt
        state: touch
        mode: '0644'
    
    - name: Display completion message
      ansible.builtin.debug:
        msg: "Playbook completed successfully!"
| END
  # lint:endignore
}

# Example 1: With logoutput enabled (verbose)
# This will display the full Ansible JSON output including all task details
par { 'logoutput-enabled':
  ensure    => present,
  playbook  => '/tmp/logoutput_playbook.yml',
  logoutput => true,  # Enable full output display
}

# Example 2: With logoutput disabled (default behavior)
# This will only show PAR's change detection summary
# Uncomment to test:
# par { 'logoutput-disabled':
#   ensure    => present,
#   playbook  => '/tmp/logoutput_playbook.yml',
#   logoutput => false,  # Suppress detailed output (default)
# }

# Output Comparison:
#
# WITH logoutput => true:
# Notice: /Stage[main]/Main/Par[logoutput-enabled]/ensure: Ansible playbook 
#         execution output:
#         {
#           "plays": [...],
#           "stats": {
#             "localhost": {
#               "ok": 4,
#               "changed": 1,
#               "unreachable": 0,
#               "failed": 0,
#               "skipped": 0,
#               "rescued": 0,
#               "ignored": 0
#             }
#           }
#         }
# Info: /Stage[main]/Main/Par[logoutput-enabled]/ensure: Ansible playbook 
#       execution completed: 1 task changed
#
# WITH logoutput => false (or not specified):
# Info: /Stage[main]/Main/Par[logoutput-disabled]/ensure: Ansible playbook 
#       execution completed: 1 task changed
#
# Use Cases:
# - logoutput => true:  Debugging, troubleshooting, detailed logging
# - logoutput => false: Production use, cleaner logs, focus on changes
#
# Notes:
# - Default is false (output suppressed)
# - Change detection summary always appears regardless of logoutput
# - Full JSON output includes task names, timings, and detailed results
# - Use --debug flag with Puppet to see even more detail
