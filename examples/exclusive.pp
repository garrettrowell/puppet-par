# PAR Exclusive Locking Example
#
# This example demonstrates the 'exclusive' parameter which enables
# exclusive locking to prevent concurrent execution of the same playbook.
#
# exclusive Parameter:
# - true:  Acquire exclusive lock before execution, prevent concurrent runs
# - false: No locking, allow concurrent execution (default)
#
# Lock Mechanism:
# - Creates a lock file: <playbook_path>.lock
# - Lock is held during playbook execution
# - Lock is released after completion (even on failure)
# - If lock cannot be acquired, PAR raises an error
#
# Requirements:
# - ansible-playbook must be installed and available in PATH
#
# Usage:
#   # Single execution (no locking needed)
#   puppet apply --libdir=lib examples/exclusive.pp
#
#   # Test concurrent execution protection:
#   # Terminal 1: puppet apply --libdir=lib examples/exclusive.pp
#   # Terminal 2: puppet apply --libdir=lib examples/exclusive.pp (while 1 is running)
#   # Terminal 2 will fail with: "Could not acquire exclusive lock for playbook"

# Create a playbook that takes some time to execute
file { '/tmp/exclusive_playbook.yml':
  ensure  => file,
  # lint:ignore:140chars lint:ignore:strict_indent
  content => @(END),
---
- name: Exclusive Lock Test Playbook
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Display start message
      ansible.builtin.debug:
        msg: "Starting playbook execution with exclusive lock"
    
    - name: Simulate long-running task (sleep)
      ansible.builtin.command:
        cmd: sleep 3
      changed_when: false
    
    - name: Create test file
      ansible.builtin.file:
        path: /tmp/exclusive_test.txt
        state: touch
        mode: '0644'
    
    - name: Write timestamp
      ansible.builtin.copy:
        dest: /tmp/exclusive_test.txt
        content: "Execution completed at {{ ansible_date_time.iso8601 }}\n"
        mode: '0644'
    
    - name: Display completion message
      ansible.builtin.debug:
        msg: "Playbook completed - lock will be released"
| END
  # lint:endignore
}

# Execute the playbook with exclusive locking enabled
par { 'exclusive-example':
  ensure    => present,
  playbook  => '/tmp/exclusive_playbook.yml',
  exclusive => true,  # Enable exclusive locking
}

# Locking Behavior:
#
# SINGLE EXECUTION:
# 1. PAR acquires lock: /tmp/exclusive_playbook.yml.lock
# 2. Playbook executes (takes ~3 seconds due to sleep)
# 3. PAR releases lock
# 4. Success!
#
# CONCURRENT EXECUTION (two puppet apply commands at the same time):
# Process 1:
#   - Acquires lock successfully
#   - Executes playbook
#   - Releases lock after completion
#
# Process 2 (started while Process 1 is running):
#   - Attempts to acquire lock
#   - Lock is already held by Process 1
#   - Error: "Could not acquire exclusive lock for playbook: /tmp/exclusive_playbook.yml"
#   - Puppet run fails
#
# LOCK CLEANUP:
# - Lock is ALWAYS released via ensure block
# - Even if playbook fails, lock is released
# - No manual cleanup required
#
# Use Cases:
# - Prevent concurrent deployments of the same playbook
# - Ensure sequential execution of critical playbooks
# - Protect shared resources from concurrent modification
# - Useful in multi-node Puppet environments
#
# Notes:
# - Lock file location: <playbook_path>.lock
# - Different playbooks have different locks
# - exclusive => false (default) allows concurrent execution
# - Lock is process-level, not thread-level
# - Use with caution: can cause Puppet runs to fail if locked
