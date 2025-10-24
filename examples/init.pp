# PAR Comprehensive Example
#
# This example demonstrates ALL available parameters of the PAR custom type.
# It shows how to configure every aspect of Ansible playbook execution through Puppet.
#
# This is a reference example - real-world usage would typically only use
# a subset of these parameters based on specific requirements.
#
# Requirements:
# - ansible-playbook must be installed and available in PATH
#
# Usage:
#   puppet apply --libdir=lib examples/init.pp

# Create a comprehensive playbook that demonstrates various scenarios
file { '/tmp/comprehensive_playbook.yml':
  ensure  => file,
  # lint:ignore:140chars lint:ignore:strict_indent
  content => @(END),
---
- name: Comprehensive PAR Demonstration Playbook
  hosts: localhost
  gather_facts: true
  tasks:
    # Task with tag: setup
    - name: Display environment information
      ansible.builtin.debug:
        msg: "Running in {{ environment }} environment"
      tags: [setup, display]
    
    # Task with tag: setup
    - name: Display version information
      ansible.builtin.debug:
        msg: "Deploying version {{ app_version }}"
      tags: [setup, display]
    
    # Task with tag: config
    - name: Ensure configuration directory exists
      ansible.builtin.file:
        path: /tmp/par_comprehensive
        state: directory
        mode: '0755'
      tags: [config]
    
    # Task with tag: config
    - name: Create configuration file
      ansible.builtin.copy:
        dest: /tmp/par_comprehensive/app.conf
        content: |
          # Application Configuration
          app_name: {{ app_name }}
          environment: {{ environment }}
          version: {{ app_version }}
          
          # Database Configuration
          db_host: {{ database.host }}
          db_port: {{ database.port }}
          db_name: {{ database.name }}
          
          # Feature Flags
          debug_mode: {{ debug_mode }}
          maintenance_mode: {{ maintenance_mode }}
        mode: '0644'
      tags: [config]
    
    # Task with tag: deploy
    - name: Create deployment marker
      ansible.builtin.copy:
        dest: /tmp/par_comprehensive/deployed_at.txt
        content: "Deployed at {{ ansible_date_time.iso8601 }}\n"
        mode: '0644'
      tags: [deploy]
    
    # Task with tag: slow (will be skipped)
    - name: Slow operation that we skip
      ansible.builtin.command:
        cmd: sleep 30
      tags: [slow]
      changed_when: false
    
    # Task with tag: verify
    - name: Verify deployment
      ansible.builtin.stat:
        path: /tmp/par_comprehensive/app.conf
      register: config_stat
      tags: [verify]
    
    # Task with tag: verify
    - name: Display verification result
      ansible.builtin.debug:
        msg: "Configuration file exists: {{ config_stat.stat.exists }}"
      tags: [verify]
    
    # Final task
    - name: Display completion message
      ansible.builtin.debug:
        msg: "Comprehensive PAR demonstration completed successfully!"
      tags: [always]
| END
  # lint:endignore
}

# Execute the playbook with ALL available PAR parameters configured
par { 'comprehensive-example':
  # REQUIRED PARAMETERS
  # -------------------

  # ensure: Whether the playbook should be executed
  # Values: present (execute), absent (not supported)
  # Default: No default (must be specified)
  ensure        => present,

  # playbook: Absolute path to the Ansible playbook YAML file
  # Must be an absolute path (relative paths are rejected)
  # Type: String (absolute path)
  # Default: No default (required parameter)
  playbook      => '/tmp/comprehensive_playbook.yml',

  # VARIABLE PARAMETERS
  # -------------------

  # playbook_vars: Variables to pass to the playbook via -e flag
  # Variables are serialized to JSON and available as Jinja2 variables
  # Supports: Strings, Integers, Booleans, Hashes, Arrays, nested structures
  # Type: Hash
  # Default: undef (no variables passed)
  playbook_vars => {
    'app_name'         => 'comprehensive-app',
    'environment'      => 'production',
    'app_version'      => '2.1.0',
    'debug_mode'       => false,
    'maintenance_mode' => false,
    'database'         => {
      'host' => 'db.example.com',
      'port' => 5432,
      'name' => 'app_production',
    },
    'servers'          => [
      'web1.example.com',
      'web2.example.com',
      'web3.example.com',
    ],
  },

  # EXECUTION CONTROL PARAMETERS
  # ----------------------------

  # tags: Only run tasks with these tags (comma-separated list passed via --tags)
  # Type: Array[String]
  # Default: undef (all tasks run)
  tags          => ['setup', 'config', 'deploy', 'verify'],

  # skip_tags: Skip tasks with these tags (comma-separated list passed via --skip-tags)
  # Type: Array[String]
  # Default: undef (no tasks skipped)
  skip_tags     => ['slow'],

  # start_at_task: Start execution at a specific task name (passed via --start-at-task)
  # Useful for resuming failed playbook runs
  # Type: String
  # Default: undef (start from beginning)
  # start_at_task => 'Create configuration file',

  # limit: Limit execution to specific hosts (passed via --limit)
  # Pattern matching Ansible host patterns
  # Type: String
  # Default: undef (no limit)
  limit         => 'localhost',

  # check_mode: Run in check mode without making changes (passed via --check)
  # Similar to Puppet noop but at Ansible level
  # Type: Boolean
  # Default: false
  check_mode    => false,

  # timeout: Timeout in seconds for ansible-playbook execution (passed via --timeout)
  # Type: Integer
  # Default: undef (no timeout)
  timeout       => 300,

  # user: Remote user for SSH connections (passed via --user)
  # Not typically needed for localhost execution
  # Type: String
  # Default: undef (current user)
  # user => 'ansible',

  # env_vars: Additional environment variables for playbook execution
  # Merged with default environment (LC_ALL, LANG, ANSIBLE_STDOUT_CALLBACK)
  # Type: Hash
  # Default: {}
  env_vars      => {
    'ANSIBLE_FORCE_COLOR'       => 'true',
    'ANSIBLE_HOST_KEY_CHECKING' => 'false',
  },

  # OUTPUT PARAMETERS
  # -----------------

  # verbose: Enable verbose output from ansible-playbook (adds -v flag)
  # Type: Boolean
  # Default: false
  verbose       => false,

  # logoutput: Display full ansible-playbook output in Puppet logs
  # When true: Full output shown via Puppet.notice()
  # When false: Output suppressed, only summary shown
  # Type: Boolean
  # Default: false
  logoutput     => true,

  # CONCURRENCY PARAMETERS
  # ----------------------

  # exclusive: Enable exclusive locking to prevent concurrent execution
  # Creates lock file at <playbook_path>.lock
  # Lock held during execution, released after completion (even on failure)
  # Type: Boolean
  # Default: false
  exclusive     => true,
}

# Parameter Summary by Category:
#
# REQUIRED (2):
#   - ensure: present/absent
#   - playbook: absolute path to playbook file
#
# VARIABLES (1):
#   - playbook_vars: Hash of variables passed via -e
#
# EXECUTION CONTROL (7):
#   - tags: Array of tags to run
#   - skip_tags: Array of tags to skip
#   - start_at_task: Task name to start at
#   - limit: Host pattern limit
#   - check_mode: Run without making changes
#   - timeout: Execution timeout in seconds
#   - user: Remote user for SSH
#
# ENVIRONMENT (1):
#   - env_vars: Hash of environment variables
#
# OUTPUT (2):
#   - verbose: Enable -v verbose flag
#   - logoutput: Display full output in Puppet logs
#
# CONCURRENCY (1):
#   - exclusive: Enable exclusive locking
#
# Total: 14 parameters
#
# Parameter Usage Guidelines:
#
# MINIMAL USAGE (required only):
#   par { 'simple':
#     ensure   => present,
#     playbook => '/path/to/playbook.yml',
#   }
#
# TYPICAL USAGE (common parameters):
#   par { 'typical':
#     ensure        => present,
#     playbook      => '/path/to/playbook.yml',
#     playbook_vars => { 'version' => '1.0' },
#     tags          => ['deploy'],
#     logoutput     => true,
#   }
#
# ADVANCED USAGE (all parameters):
#   See the comprehensive-example resource above
#
# Best Practices:
# 1. Always use absolute paths for playbook parameter
# 2. Use tags to control which tasks run
# 3. Enable logoutput for debugging
# 4. Use exclusive for critical playbooks
# 5. Set timeout to prevent runaway executions
# 6. Use check_mode for dry-run testing
# 7. Keep playbook_vars simple and flat when possible
# 8. Use env_vars only when needed
# 9. Avoid skip_tags unless necessary (use tags instead)
# 10. Test with verbose => true when troubleshooting
#
# Expected Output:
#
# With logoutput => true, you'll see:
# - Notice: Ansible playbook execution output: [full JSON output]
# - Info: Ansible playbook execution completed: N tasks changed
#
# With logoutput => false (default), you'll see:
# - Info: Ansible playbook execution completed: N tasks changed
#
# Change Detection:
# - First run: Creates files → "ensure: created" + info message
# - Second run: Files exist → No "created" message (idempotent)
#
# Cleanup:
#   rm -rf /tmp/par_comprehensive
