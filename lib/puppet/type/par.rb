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
