# frozen_string_literal: true

# @summary Manages Ansible playbook execution against localhost
#
# The PAR (Puppet Ansible Runner) custom type enables Puppet to execute
# Ansible playbooks on the local machine. This allows integration of Ansible
# automation into Puppet-managed infrastructure without requiring remote
# connections or inventory files.
#
# @example Basic playbook execution
#   par { 'setup-webserver':
#     ensure   => present,
#     playbook => '/etc/ansible/playbooks/webserver.yml',
#   }
#
# @example Using with file resource for dependency ordering
#   file { '/etc/ansible/playbooks/setup.yml':
#     ensure => file,
#     source => 'puppet:///modules/mymodule/setup.yml',
#   }
#
#   par { 'run-setup':
#     ensure   => present,
#     playbook => '/etc/ansible/playbooks/setup.yml',
#     # PAR will automatically autorequire the file resource above
#   }
#
Puppet::Type.newtype(:par) do
  @doc = "Manages Ansible playbook execution against localhost.

  The PAR (Puppet Ansible Runner) type executes Ansible playbooks on the local
  machine using `ansible-playbook -i localhost, --connection=local`. This enables
  integration of Ansible automation workflows into Puppet catalogs without requiring
  SSH access, inventory files, or remote connections.

  Key features:
  - Executes playbooks against localhost only
  - No SSH or inventory configuration required
  - Supports Puppet noop mode (--noop flag)
  - Provides clear error messages for missing files or executables
  - Integrates with Puppet's resource model and reporting

  The type validates parameters at catalog compilation time, while the provider
  handles actual playbook execution during catalog application.

  Requirements:
  - Ansible must be installed (ansible-playbook must be in PATH)
  - Playbook files must exist and be readable
  - Playbooks should target localhost and use connection: local

  For more information about Ansible playbooks, see:
  https://docs.ansible.com/ansible/latest/user_guide/playbooks.html
  "

  ensurable do
    desc "Manages the presence of the PAR resource.

    The PAR type uses 'ensurable' to trigger playbook execution. When ensure
    is set to 'present' (the default), the playbook will be executed during
    catalog application.

    Note: Unlike most Puppet resources, PAR executes the playbook every time
    (similar to exec resources). Idempotency is handled by Ansible's own
    change detection mechanism."

    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc <<~DESC
      The name of the PAR resource (namevar).

      This parameter serves as the unique identifier for the PAR resource in the
      Puppet catalog. It should be a descriptive string that indicates the purpose
      of the playbook execution.

      The name parameter accepts alphanumeric characters, hyphens, and underscores.
      It has no effect on the actual playbook execution - it only serves as a
      catalog identifier.

      Valid characters: a-z, A-Z, 0-9, hyphen (-), underscore (_)

      @example Valid resource names
        par { 'setup-webserver': ... }
        par { 'configure_database': ... }
        par { 'deploy-application': ... }
    DESC

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "Name must be a String, got #{value.class}"
      end
      if value.empty?
        raise ArgumentError, 'Name cannot be empty'
      end
      unless %r{^[a-zA-Z0-9_-]+$}.match?(value)
        raise ArgumentError, "Name must contain only alphanumeric characters, hyphens, and underscores, got: #{value}"
      end
    end
  end

  newparam(:playbook) do
    desc <<~DESC
      The absolute path to the Ansible playbook file (required).

      This parameter specifies the location of the Ansible playbook YAML file to
      execute. The path must be absolute (starting with '/' on Unix/Linux or a
      drive letter on Windows) to ensure consistent behavior across different
      execution contexts.

      Requirements:
      - Must be an absolute path (relative paths are rejected)
      - File must exist and be readable by the Puppet agent process
      - Must be a valid Ansible playbook YAML file
      - Playbooks should target localhost and use connection: local

      The provider validates the file's existence before attempting execution.
      If the playbook file is managed by a Puppet file resource, PAR will
      automatically create an autorequire relationship to ensure proper ordering.

      Path normalization: The path is automatically expanded and normalized using
      File.expand_path to resolve symlinks and relative components.

      @example Unix/Linux absolute paths
        playbook => '/etc/ansible/playbooks/webserver.yml'
        playbook => '/opt/config/setup.yml'
        playbook => '/home/admin/playbooks/deploy.yml'

      @example Windows absolute paths
        playbook => 'C:/Ansible/playbooks/setup.yml'
        playbook => 'D:/config/playbook.yml'
    DESC

    validate do |value|
      unless value.is_a?(String)
        raise Puppet::Error, "Playbook must be a String, got #{value.class}"
      end
      if value.empty?
        raise Puppet::Error, 'Playbook path cannot be empty'
      end

      # Check for relative path indicators
      if value.start_with?('./', '../')
        raise Puppet::Error, "Playbook path must be absolute path, got relative path: #{value}"
      end

      # For Unix/Linux paths, ensure it starts with /
      # For Windows paths, check for drive letter pattern (C:/, D:/, etc.)
      unless value.start_with?('/') || value =~ %r{^[A-Za-z]:[/\\]}
        raise Puppet::Error, "Playbook path must be absolute path, got: #{value}"
      end
    end

    munge do |value|
      # Normalize the path - expand to absolute, resolve symlinks
      # This ensures consistent path handling across the system
      File.expand_path(value)
    end
  end

  newparam(:playbook_vars) do
    desc <<~DESC
      A hash of variables to pass to the Ansible playbook (optional).

      This parameter allows you to pass custom variables to your Ansible playbook
      at runtime. The variables are serialized to JSON and passed to ansible-playbook
      using the --extra-vars (-e) flag.

      Variable precedence: Extra vars (passed via this parameter) have the highest
      precedence in Ansible and will override variables defined in the playbook,
      inventory, or other sources.

      The parameter accepts:
      - Simple key-value pairs (strings, numbers, booleans)
      - Nested hashes for complex data structures
      - Arrays for list values
      - Empty hash {} (no variables passed)
      - nil/undef (no variables passed)

      The parameter rejects:
      - Non-hash values (strings, arrays, integers, booleans)

      @example Simple variables
        par { 'deploy-app':
          playbook      => '/etc/ansible/playbooks/deploy.yml',
          playbook_vars => {
            'app_version' => '1.2.3',
            'environment' => 'production',
          },
        }

      @example Complex nested variables
        par { 'configure-database':
          playbook      => '/etc/ansible/playbooks/database.yml',
          playbook_vars => {
            'database' => {
              'host'     => 'localhost',
              'port'     => 5432,
              'name'     => 'myapp',
              'ssl_mode' => 'require',
            },
            'users' => ['admin', 'readonly'],
          },
        }

      @example No variables (optional)
        par { 'basic-playbook':
          playbook => '/etc/ansible/playbooks/setup.yml',
          # playbook_vars is optional - can be omitted
        }
    DESC

    validate do |value|
      unless value.is_a?(Hash)
        raise Puppet::Error, "playbook_vars must be a Hash, got #{value.class}"
      end
    end

    # No munge needed - pass the hash through as-is
    # Provider will handle JSON serialization
  end

  newparam(:tags) do
    desc <<~DESC
      An array of Ansible tags to execute (optional).

      This parameter allows you to run only tasks with specific tags in your
      Ansible playbook. This is passed to ansible-playbook using the --tags (-t)
      flag.

      Tags provide a way to selectively execute portions of your playbook. Only
      tasks, plays, and roles that are tagged with the specified tags will run.

      @example Running specific tags
        par { 'partial-deploy':
          playbook => '/etc/ansible/playbooks/deploy.yml',
          tags     => ['webserver', 'database'],
        }

      @example Single tag
        par { 'configure-only':
          playbook => '/etc/ansible/playbooks/setup.yml',
          tags     => ['configuration'],
        }
    DESC

    validate do |value|
      unless value.is_a?(Array)
        raise Puppet::Error, "tags must be an Array, got #{value.class}"
      end
    end
  end

  newparam(:skip_tags) do
    desc <<~DESC
      An array of Ansible tags to skip (optional).

      This parameter allows you to skip tasks with specific tags in your
      Ansible playbook. This is passed to ansible-playbook using the --skip-tags
      flag.

      Skip tags provide a way to exclude portions of your playbook from execution.
      Tasks, plays, and roles that are tagged with the specified tags will be skipped.

      @example Skipping risky operations
        par { 'safe-deploy':
          playbook  => '/etc/ansible/playbooks/deploy.yml',
          skip_tags => ['dangerous', 'slow'],
        }
    DESC

    validate do |value|
      unless value.is_a?(Array)
        raise Puppet::Error, "skip_tags must be an Array, got #{value.class}"
      end
    end
  end

  newparam(:start_at_task) do
    desc <<~DESC
      The name of the task to start execution at (optional).

      This parameter allows you to start playbook execution at a specific task
      instead of from the beginning. This is passed to ansible-playbook using
      the --start-at-task flag.

      This is useful for resuming playbook execution after a failure or for
      testing specific portions of a playbook.

      @example Resume from specific task
        par { 'resume-deploy':
          playbook       => '/etc/ansible/playbooks/deploy.yml',
          start_at_task  => 'Install application',
        }
    DESC

    validate do |value|
      unless value.is_a?(String)
        raise Puppet::Error, "start_at_task must be a String, got #{value.class}"
      end
      if value.empty?
        raise Puppet::Error, 'start_at_task cannot be empty'
      end
    end
  end

  newparam(:limit) do
    desc <<~DESC
      Limit playbook execution to specific hosts (optional).

      This parameter allows you to limit which hosts the playbook runs against.
      This is passed to ansible-playbook using the --limit flag.

      The value should be a host pattern following Ansible's host pattern syntax.
      For PAR (which runs against localhost), this is typically 'localhost' but
      can be used with more complex patterns if your playbook targets multiple hosts.

      @example Limit to localhost
        par { 'local-only':
          playbook => '/etc/ansible/playbooks/setup.yml',
          limit    => 'localhost',
        }

      @example Multiple host pattern
        par { 'web-servers':
          playbook => '/etc/ansible/playbooks/deploy.yml',
          limit    => 'web*:db*',
        }
    DESC

    validate do |value|
      unless value.is_a?(String)
        raise Puppet::Error, "limit must be a String, got #{value.class}"
      end
      if value.empty?
        raise Puppet::Error, 'limit cannot be empty'
      end
    end
  end

  newparam(:verbose, boolean: true) do
    desc <<~DESC
      Enable verbose output from Ansible (optional).

      When set to true, enables verbose mode for ansible-playbook execution
      using the -v flag. This provides more detailed output about what Ansible
      is doing during playbook execution.

      This can be useful for debugging or understanding playbook execution flow.

      @example Enable verbose output
        par { 'debug-run':
          playbook => '/etc/ansible/playbooks/setup.yml',
          verbose  => true,
        }
    DESC

    newvalues(:true, :false)
  end

  newparam(:check_mode, boolean: true) do
    desc <<~DESC
      Run Ansible in check mode (dry-run) (optional).

      When set to true, runs ansible-playbook with the --check flag, which
      performs a dry-run without making any changes to the system. This is
      Ansible's equivalent of Puppet's noop mode.

      Note: This is different from Puppet's --noop flag. When Puppet runs in
      noop mode, the PAR provider skips execution entirely. This parameter
      enables Ansible's own check mode during normal Puppet runs.

      @example Run in check mode
        par { 'test-playbook':
          playbook   => '/etc/ansible/playbooks/changes.yml',
          check_mode => true,
        }
    DESC

    newvalues(:true, :false)
  end

  newparam(:timeout) do
    desc <<~DESC
      Timeout in seconds for playbook execution (optional).

      This parameter sets a maximum execution time for the ansible-playbook
      command. If the playbook takes longer than this timeout, execution will
      be terminated.

      The value must be a non-negative integer. A value of 0 means no timeout.

      @example Set 5 minute timeout
        par { 'quick-deploy':
          playbook => '/etc/ansible/playbooks/deploy.yml',
          timeout  => 300,
        }
    DESC

    validate do |value|
      unless value.is_a?(Integer)
        raise Puppet::Error, "timeout must be an Integer, got #{value.class}"
      end
      if value.negative?
        raise Puppet::Error, 'timeout must be a non-negative integer'
      end
    end
  end

  newparam(:user) do
    desc <<~DESC
      Remote user to use for Ansible connections (optional).

      This parameter specifies the user account to use when connecting to remote
      hosts. This is passed to ansible-playbook using the --user (-u) flag.

      For PAR (which typically runs against localhost with local connection),
      this may not be necessary, but can be useful for playbooks that connect
      to remote hosts.

      @example Specify remote user
        par { 'remote-deploy':
          playbook => '/etc/ansible/playbooks/deploy.yml',
          user     => 'ansible',
        }
    DESC

    validate do |value|
      unless value.is_a?(String)
        raise Puppet::Error, "user must be a String, got #{value.class}"
      end
      if value.empty?
        raise Puppet::Error, 'user cannot be empty'
      end
    end
  end

  newparam(:environment) do
    desc <<~DESC
      Additional environment variables for ansible-playbook execution (optional).

      This parameter allows you to set custom environment variables that will
      be passed to the ansible-playbook process. This is useful for configuring
      Ansible behavior via environment variables.

      Common Ansible environment variables include:
      - ANSIBLE_FORCE_COLOR: Enable/disable color output
      - ANSIBLE_HOST_KEY_CHECKING: Disable SSH host key checking
      - ANSIBLE_CONFIG: Path to ansible.cfg file
      - ANSIBLE_VAULT_PASSWORD_FILE: Path to vault password file

      @example Set Ansible environment variables
        par { 'custom-config':
          playbook    => '/etc/ansible/playbooks/deploy.yml',
          environment => {
            'ANSIBLE_FORCE_COLOR'        => 'true',
            'ANSIBLE_HOST_KEY_CHECKING'  => 'false',
          },
        }
    DESC

    validate do |value|
      unless value.is_a?(Hash)
        raise Puppet::Error, "environment must be a Hash, got #{value.class}"
      end
    end
  end

  newparam(:logoutput, boolean: true) do
    desc <<~DESC
      Control whether playbook output is displayed in Puppet logs (optional).

      When set to true, the full output from ansible-playbook execution will be
      displayed in Puppet's notice log level. When set to false or omitted, only
      summary information (changed/ok/failed task counts) will be logged.

      This parameter is useful for debugging playbook execution or when you want
      to see detailed Ansible output in your Puppet logs. However, verbose output
      can clutter logs for routine operations.

      Default: false (output suppressed, only summaries shown)

      Note: Regardless of this setting, errors and failures will always be logged
      to help with troubleshooting.

      @example Show detailed playbook output
        par { 'debug-deployment':
          playbook  => '/etc/ansible/playbooks/deploy.yml',
          logoutput => true,
        }

      @example Suppress detailed output (default behavior)
        par { 'routine-task':
          playbook  => '/etc/ansible/playbooks/maintenance.yml',
          logoutput => false,
        }

      @example Omit parameter for default behavior
        par { 'simple-task':
          playbook => '/etc/ansible/playbooks/task.yml',
          # logoutput defaults to false
        }
    DESC

    newvalues(:true, :false)
    defaultto :false
  end

  newparam(:exclusive, boolean: true) do
    desc <<~DESC
      Serialize playbook execution using a lock file (optional).

      When set to true, PAR will acquire an exclusive lock before executing the
      playbook and release it after completion. This prevents multiple PAR resources
      from executing playbooks concurrently, which can be useful when:

      - Playbooks modify shared resources that could cause conflicts
      - System resources (CPU, memory, I/O) would be overwhelmed by concurrent runs
      - Playbooks need to run in a specific sequence
      - You want to prevent race conditions between multiple Ansible executions

      The lock is implemented using Puppet's built-in locking mechanism and is stored
      in Puppet's state directory. If a lock cannot be acquired (because another PAR
      resource is currently executing), the resource will fail with an error.

      Default: false (no locking, playbooks can run concurrently)

      Important: The lock is per-node, not per-playbook. If you need finer-grained
      locking, consider using Ansible's own locking mechanisms or orchestrating
      execution order through Puppet resource dependencies.

      @example Enable exclusive execution
        par { 'critical-deployment':
          playbook  => '/etc/ansible/playbooks/deploy.yml',
          exclusive => true,
        }

      @example Allow concurrent execution (default)
        par { 'routine-maintenance':
          playbook  => '/etc/ansible/playbooks/maintenance.yml',
          exclusive => false,
        }

      @example Multiple resources with selective locking
        # This will run with locking
        par { 'database-migration':
          playbook  => '/etc/ansible/playbooks/db-migrate.yml',
          exclusive => true,
        }

        # This can run concurrently (no lock needed)
        par { 'log-rotation':
          playbook  => '/etc/ansible/playbooks/logrotate.yml',
          exclusive => false,
        }
    DESC

    newvalues(:true, :false)
    defaultto :false
  end

  # @!method autorequire(type)
  #   Automatically creates a dependency on File resources that match the playbook path.
  #   This ensures that if a File resource manages the playbook file, Puppet will
  #   apply that File resource before executing the PAR resource.
  #
  #   @return [Array<Puppet::Resource>] Array of autorequired File resources
  #
  #   @example Autorequire behavior
  #     file { '/etc/ansible/playbooks/setup.yml':
  #       ensure => file,
  #       source => 'puppet:///modules/mymodule/setup.yml',
  #     }
  #
  #     par { 'run-setup':
  #       playbook => '/etc/ansible/playbooks/setup.yml',
  #       # Automatically requires File['/etc/ansible/playbooks/setup.yml']
  #     }
  autorequire(:file) do
    # Return the playbook path so Puppet can create a dependency
    # on any File resource that manages this path
    [self[:playbook]]
  end

  validate do
    # Ensure playbook parameter is provided
    if self[:playbook].nil? || self[:playbook].to_s.empty?
      raise Puppet::Error, 'Playbook parameter is required'
    end
  end
end
