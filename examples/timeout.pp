# PAR with Timeout Example
#
# This example demonstrates using the timeout parameter to limit
# the execution time of an Ansible playbook. This is useful for
# preventing runaway playbooks from blocking Puppet runs.
#
# Requirements:
# - ansible-playbook must be installed and available in PATH
# - The playbook file must exist at the specified path
#
# Usage:
#   puppet apply --libdir=lib examples/timeout.pp

# Create a playbook that executes quickly
file { '/tmp/quick_playbook.yml':
  ensure  => file,
  # lint:ignore:140chars lint:ignore:strict_indent
  content => @(END),
---
- name: Quick Playbook
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Quick task 1
      ansible.builtin.debug:
        msg: "Task 1"
    
    - name: Quick task 2
      ansible.builtin.debug:
        msg: "Task 2"
| END
  # lint:endignore
}

# Example: Adequate timeout (will succeed)
par { 'playbook-with-timeout':
  ensure   => present,
  playbook => '/tmp/quick_playbook.yml',
  timeout  => 30, # 30 seconds is plenty for this quick playbook
}

# The PAR resource will:
# 1. Execute ansible-playbook with the --timeout flag
# 2. Monitor execution time
# 3. Terminate the playbook if it exceeds the timeout
# 4. Raise a Puppet error with a clear timeout message
#
# Command executed:
# ansible-playbook -i localhost, --connection=local \
#   --timeout 30 /tmp/quick_playbook.yml
#
# Timeout behavior:
# - timeout parameter accepts an Integer (seconds)
# - Must be a positive value (> 0)
# - If playbook exceeds timeout, PAR raises an error
# - Error message: "Playbook execution timed out after X seconds"
# - Useful for preventing hung playbooks in production
#
# Best practices:
# - Set timeout based on expected playbook duration + buffer
# - Use generous timeouts in development (or omit for no limit)
# - Use conservative timeouts in production to detect issues
# - Monitor playbook execution times to tune timeout values
#
# Default behavior:
# - If timeout is not specified, playbook runs until completion
# - No time limit is applied by default
