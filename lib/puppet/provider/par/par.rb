# frozen_string_literal: true

# @summary Provider for the PAR custom type
#
# This provider implements Ansible playbook execution on localhost using the
# ansible-playbook command. It handles command construction, execution, noop
# mode, and error handling.
#
# The provider uses Puppet::Util::Execution.execute for command execution,
# which ensures proper integration with Puppet's logging, error handling,
# and noop mode support.
#
# @example Basic provider usage (automatic via type)
#   par { 'setup-webserver':
#     playbook => '/etc/ansible/playbooks/webserver.yml',
#   }
#
Puppet::Type.type(:par).provide(:par) do
  desc <<~DESC
    Default provider for PAR type using ansible-playbook.

    This provider executes Ansible playbooks against localhost without requiring
    SSH access or inventory files. It uses the command:
      ansible-playbook -i localhost, --connection=local <playbook>

    Features:
    - Validates ansible-playbook is available in PATH
    - Checks playbook file existence before execution
    - Supports Puppet noop mode (--noop flag)
    - Provides detailed error messages for common issues
    - Logs ansible-playbook output to Puppet's log

    The provider follows Puppet's standard resource workflow:
    1. exists? - Checks if playbook file exists
    2. create - Executes the playbook (always runs when ensure => present)

    Note: Unlike most Puppet resources, PAR executes every time (similar to exec).
    Idempotency is handled by Ansible's own change detection mechanisms.

    Requirements:
    - ansible-playbook must be in PATH
    - Playbook file must exist and be readable
    - Playbook should target localhost with connection: local

    For more information about Ansible playbooks, see:
    https://docs.ansible.com/ansible/latest/user_guide/playbooks.html
  DESC

  commands ansible_playbook: 'ansible-playbook'

  # @!method exists?
  #   Determines whether the PAR resource should be executed.
  #
  #   Unlike traditional Puppet resources that manage persistent state (like files
  #   or packages), PAR resources represent playbook executions - actions rather than
  #   states. Therefore, this method always returns false to ensure the playbook
  #   executes every time Puppet runs when ensure => present.
  #
  #   This behavior is similar to the `exec` resource type, which also represents
  #   actions rather than states. The actual idempotency is handled by Ansible's
  #   own change detection mechanisms within the playbook.
  #
  #   Note: The playbook file existence is validated in the `create` method before
  #   execution, so this method doesn't need to check for file presence.
  #
  #   @return [Boolean] always returns false to trigger playbook execution
  #
  #   @example
  #     provider.exists? #=> false (always, to ensure execution)
  #
  def exists?
    # Always return false so create() is always called when ensure => present
    # This makes PAR behave like exec - it always runs
    false
  end

  # @!method validate_ansible
  #   Validates that ansible-playbook is available in the system PATH.
  #
  #   This method checks whether the ansible-playbook command can be found
  #   and executed. It's used to provide clear error messages when Ansible
  #   is not installed or not in PATH.
  #
  #   The method uses Puppet::Util.which to search for the command in PATH,
  #   which is the standard Puppet approach for command validation.
  #
  #   @return [Boolean] true if ansible-playbook is found in PATH, false otherwise
  #
  #   @example
  #     provider.validate_ansible #=> true (if ansible-playbook is installed)
  #     provider.validate_ansible #=> false (if ansible-playbook is not found)
  #
  def validate_ansible
    ansible_path = Puppet::Util.which('ansible-playbook')
    !ansible_path.nil?
  end

  # @!method build_command
  #   Constructs the ansible-playbook command array.
  #
  #   This method builds the command line arguments for executing ansible-playbook
  #   against localhost without requiring inventory files or SSH access.
  #
  #   The command structure is:
  #     ansible-playbook [options] -i localhost, --connection=local <playbook_path>
  #
  #   Key arguments:
  #   - `-i localhost,` - Uses localhost as the inventory (comma is required)
  #   - `--connection=local` - Uses local connection instead of SSH
  #   - playbook path is always the last argument
  #   - Configuration options are inserted before the playbook path
  #
  #   Supported options (from resource parameters):
  #   - playbook_vars: Serialized to JSON and passed via -e
  #   - tags: Comma-separated list passed via --tags
  #   - skip_tags: Comma-separated list passed via --skip-tags
  #   - start_at_task: Task name passed via --start-at-task
  #   - limit: Host pattern passed via --limit
  #   - verbose: Adds -v flag if true
  #   - check_mode: Adds --check flag if true
  #   - user: Username passed via --user
  #   - timeout: Timeout in seconds passed via --timeout
  #
  #   Returning an array (rather than a string) ensures proper argument separation
  #   and automatic shell escaping by Puppet::Util::Execution, which safely handles
  #   paths with spaces and special characters.
  #
  #   @return [Array<String>] Command array suitable for Puppet::Util::Execution.execute
  #
  #   @example Basic command
  #     provider.build_command
  #     #=> ['ansible-playbook', '-i', 'localhost,', '--connection=local', '/tmp/playbook.yml']
  #
  #   @example With variables
  #     # playbook_vars: { 'version' => '1.0', 'env' => 'prod' }
  #     provider.build_command
  #     #=> ['ansible-playbook', '-i', 'localhost,', '--connection=local',
  #          '-e', '{"version":"1.0","env":"prod"}', '/tmp/playbook.yml']
  #
  #   @example With multiple options
  #     # tags: ['deploy'], verbose: true, check_mode: true
  #     provider.build_command
  #     #=> ['ansible-playbook', '-i', 'localhost,', '--connection=local',
  #          '--tags', 'deploy', '-v', '--check', '/tmp/playbook.yml']
  #
  def build_command
    require 'json'

    playbook_path = resource[:playbook]
    cmd = [
      'ansible-playbook',
      '-i',
      'localhost,',
      '--connection=local',
    ]

    # Add playbook variables as JSON via -e flag
    if resource[:playbook_vars] && !resource[:playbook_vars].empty?
      cmd << '-e'
      cmd << JSON.generate(resource[:playbook_vars])
    end

    # Add tags filter
    if resource[:tags] && !resource[:tags].empty?
      cmd << '--tags'
      cmd << resource[:tags].join(',')
    end

    # Add skip_tags filter
    if resource[:skip_tags] && !resource[:skip_tags].empty?
      cmd << '--skip-tags'
      cmd << resource[:skip_tags].join(',')
    end

    # Add start-at-task option
    if resource[:start_at_task]
      cmd << '--start-at-task'
      cmd << resource[:start_at_task]
    end

    # Add limit option
    if resource[:limit]
      cmd << '--limit'
      cmd << resource[:limit]
    end

    # Add verbose flag
    cmd << '-v' if resource[:verbose] == :true

    # Add check mode flag
    cmd << '--check' if resource[:check_mode] == :true

    # Add user option
    if resource[:user]
      cmd << '--user'
      cmd << resource[:user]
    end

    # Add timeout option
    if resource[:timeout]
      cmd << '--timeout'
      cmd << resource[:timeout].to_s
    end

    # Playbook path must be last
    cmd << playbook_path

    cmd
  end

  # @!method create
  #   Creates (applies) the PAR resource by executing the Ansible playbook.
  #
  #   This is the main method called by Puppet when ensure => present. It performs
  #   validation, handles noop mode, and executes the playbook.
  #
  #   Workflow:
  #   1. Validates ansible-playbook is available in PATH
  #   2. Validates playbook file exists
  #   3. If in noop mode: logs what would be executed and returns
  #   4. If not in noop mode: executes the playbook via execute_playbook
  #
  #   Error Handling:
  #   - Raises Puppet::Error if ansible-playbook not found in PATH
  #   - Raises Puppet::Error if playbook file does not exist
  #
  #   Note: This method always runs when ensure => present (similar to exec resources).
  #   Idempotency is handled by Ansible's own change detection mechanisms.
  #
  #   @return [void]
  #   @raise [Puppet::Error] if ansible-playbook is not available
  #   @raise [Puppet::Error] if playbook file does not exist
  #
  #   @example Normal execution
  #     provider.create #=> Executes playbook
  #
  #   @example Noop mode
  #     # With --noop flag
  #     provider.create #=> Logs command, does not execute
  #
  def create
    playbook_path = resource[:playbook]

    # Validate ansible-playbook is available
    unless validate_ansible
      raise Puppet::Error, 'ansible-playbook command not found in PATH. Please install Ansible.'
    end

    # Validate playbook file exists
    unless File.exist?(playbook_path)
      raise Puppet::Error, "Playbook file not found: #{playbook_path}"
    end

    # Handle noop mode
    if resource.noop?
      command = build_command
      Puppet.notice("Would execute: #{command.join(' ')}")
      return
    end

    # Execute the playbook
    execute_playbook
  end

  private

  # @!method execute_playbook
  #   Executes the ansible-playbook command.
  #
  #   This private method performs the actual command execution using
  #   Puppet::Util::Execution.execute, which integrates with Puppet's
  #   logging and error handling.
  #
  #   The method:
  #   - Builds the command array via build_command
  #   - Sets LC_ALL and LANG environment variables to en_US.UTF-8 (required by Ansible)
  #   - Executes using Puppet::Util::Execution.execute
  #   - Combines stdout and stderr for unified output
  #   - Logs all output to Puppet's log
  #   - Raises Puppet::ExecutionFailure on non-zero exit codes
  #
  #   Implementation Details:
  #   - `failonfail: true` ensures non-zero exit codes raise exceptions
  #   - `combine: true` merges stdout and stderr for unified logging
  #   - `custom_environment:` provides UTF-8 locale required by Ansible
  #   - All output is logged to Puppet's notice level for visibility
  #   - Ansible's own exit codes determine success/failure
  #
  #   @return [void]
  #   @raise [Puppet::ExecutionFailure] if ansible-playbook exits with non-zero status
  #
  #   @api private
  #
  #   @example Internal usage
  #     execute_playbook # Called by create method
  #
  def execute_playbook
    command = build_command

    # Build environment hash with proper locale settings for Ansible
    # Ansible requires UTF-8 locale encoding to function properly
    custom_env = ENV.to_h.merge(
      'LC_ALL' => 'en_US.UTF-8',
      'LANG' => 'en_US.UTF-8',
    )

    output = Puppet::Util::Execution.execute(
      command,
      failonfail: true,
      combine: true,
      custom_environment: custom_env,
    )

    Puppet.notice("Ansible playbook execution output:\n#{output}")
  end
end
