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
  #   validation, handles noop mode, executes the playbook, and manages exclusive
  #   locking when requested.
  #
  #   Workflow:
  #   1. Validates ansible-playbook is available in PATH
  #   2. Validates playbook file exists
  #   3. Acquires exclusive lock if exclusive parameter is true
  #   4. If in noop mode: logs what would be executed and returns
  #   5. If not in noop mode: executes the playbook via execute_playbook
  #   6. Parses output and reports changes/failures
  #   7. Releases lock in ensure block (if acquired)
  #
  #   Error Handling:
  #   - Raises Puppet::Error if ansible-playbook not found in PATH
  #   - Raises Puppet::Error if playbook file does not exist
  #   - Raises Puppet::Error if exclusive lock cannot be acquired
  #   - Raises Puppet::Error if playbook execution fails
  #
  #   Note: This method always runs when ensure => present (similar to exec resources).
  #   Idempotency is handled by Ansible's own change detection mechanisms.
  #
  #   @return [void]
  #   @raise [Puppet::Error] if ansible-playbook is not available
  #   @raise [Puppet::Error] if playbook file does not exist
  #   @raise [Puppet::Error] if exclusive lock cannot be acquired
  #   @raise [Puppet::Error] if playbook execution fails
  #
  #   @example Normal execution
  #     provider.create #=> Executes playbook
  #
  #   @example Noop mode
  #     # With --noop flag
  #     provider.create #=> Logs command, does not execute
  #
  #   @example Exclusive locking
  #     # With exclusive => true
  #     provider.create #=> Acquires lock, executes, releases lock
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

    # Acquire exclusive lock if requested
    if resource[:exclusive] == :true
      unless acquire_lock
        raise Puppet::Error, "Could not acquire exclusive lock for playbook: #{playbook_path}"
      end
    end

    # Handle noop mode
    if resource.noop?
      command = build_command
      Puppet.notice("Would execute: #{command.join(' ')}")
      return
    end

    # Execute the playbook and get output
    output = execute_playbook

    # Parse JSON output to get execution statistics
    stats = parse_json_output(output)

    # Handle logoutput parameter - display full output if requested
    if resource[:logoutput] == :true
      Puppet.notice("Ansible playbook execution output:\n#{output}")
    end

    # Check for failures and raise error if any tasks failed
    if stats[:failed] > 0
      task_word = (stats[:failed] == 1) ? 'task' : 'tasks'
      raise Puppet::Error, "Ansible playbook execution failed: #{stats[:failed]} #{task_word} failed"
    end

    # Log appropriate message based on change detection
    if stats[:changed] > 0
      task_word = (stats[:changed] == 1) ? 'task' : 'tasks'
      Puppet.info("Ansible playbook execution completed: #{stats[:changed]} #{task_word} changed")
    else
      Puppet.debug('Ansible playbook execution completed with no changes (idempotent run)')
    end
  ensure
    # Always release lock if it was acquired
    release_lock if resource[:exclusive] == :true
  end

  # @!method parse_json_output
  #   Parses Ansible JSON output to extract execution statistics.
  #
  #   This method parses the JSON output from ansible-playbook when using
  #   the 'json' stdout callback. It extracts the stats section which contains
  #   information about task execution results.
  #
  #   The stats section includes counts for:
  #   - ok: Tasks that succeeded without changes
  #   - changed: Tasks that made changes to the system
  #   - failed: Tasks that failed
  #   - unreachable: Hosts that were unreachable
  #   - skipped: Tasks that were skipped
  #
  #   @param output [String] The JSON output from ansible-playbook
  #   @return [Hash] A hash containing :ok, :changed, and :failed counts
  #   @raise [JSON::ParserError] if output is not valid JSON
  #
  #   @example Parse successful run with changes
  #     json = '{"stats": {"localhost": {"ok": 3, "changed": 2, "failed": 0}}}'
  #     stats = parse_json_output(json)
  #     stats[:changed] #=> 2
  #     stats[:ok] #=> 3
  #     stats[:failed] #=> 0
  #
  #   @example Parse idempotent run (no changes)
  #     json = '{"stats": {"localhost": {"ok": 3, "changed": 0, "failed": 0}}}'
  #     stats = parse_json_output(json)
  #     stats[:changed] #=> 0
  #
  def parse_json_output(output)
    require 'json'

    # Ansible may output warnings before the JSON
    # Extract only the JSON portion (starts with '{' and ends with '}')
    json_start = output.index('{')
    json_end = output.rindex('}')

    if json_start && json_end && json_end >= json_start
      json_content = output[json_start..json_end]
      data = JSON.parse(json_content)
    else
      # If we can't find JSON markers, try parsing the whole thing
      data = JSON.parse(output)
    end

    # Extract stats for localhost
    # Ansible JSON output structure: {"stats": {"localhost": {...}}}
    stats = data.dig('stats', 'localhost') || {}

    {
      ok: stats['ok'] || 0,
      changed: stats['changed'] || 0,
      failed: stats['failed'] || 0,
    }
  end

  # @!method acquire_lock
  #   Acquires an exclusive lock for playbook execution.
  #
  #   This method creates a lock file to prevent concurrent execution of the
  #   same playbook when the `exclusive` parameter is set to true. The lock
  #   is based on the playbook file path to ensure only one instance of a
  #   specific playbook runs at a time.
  #
  #   The lock file path is derived from the playbook path by appending '.lock'
  #   to the playbook filename. The lock is implemented using Puppet::Util::Lockfile,
  #   which provides cross-platform file locking.
  #
  #   Lock file location: <playbook_path>.lock
  #   Example: /etc/ansible/playbooks/webserver.yml.lock
  #
  #   @return [Boolean] true if lock was successfully acquired, false otherwise
  #
  #   @example Acquire lock for a playbook
  #     provider.acquire_lock #=> true (if lock acquired)
  #     provider.acquire_lock #=> false (if already locked)
  #
  def acquire_lock
    require 'puppet/util/lockfile'

    playbook_path = resource[:playbook]
    lock_path = "#{playbook_path}.lock"

    @lockfile = Puppet::Util::Lockfile.new(lock_path)
    @lockfile.lock
  end

  # @!method release_lock
  #   Releases the exclusive lock acquired by acquire_lock.
  #
  #   This method releases the lock file created during acquire_lock. It should
  #   be called after playbook execution completes, whether successful or not.
  #   Typically called from an ensure block to guarantee cleanup.
  #
  #   The method safely handles cases where no lock was acquired (lockfile is nil),
  #   making it safe to call unconditionally in ensure blocks.
  #
  #   @return [void]
  #
  #   @example Release lock after execution
  #     provider.release_lock
  #
  def release_lock
    @lockfile&.unlock
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
  #   - Returns output for parsing by create method
  #   - Raises Puppet::ExecutionFailure on non-zero exit codes
  #
  #   Implementation Details:
  #   - `failonfail: true` ensures non-zero exit codes raise exceptions
  #   - `combine: true` merges stdout and stderr for unified logging
  #   - `custom_environment:` provides UTF-8 locale required by Ansible
  #   - ANSIBLE_STDOUT_CALLBACK=json enables JSON output format
  #   - Output is returned to caller for parsing and conditional logging
  #
  #   @return [String] The JSON output from ansible-playbook execution
  #   @raise [Puppet::ExecutionFailure] if ansible-playbook exits with non-zero status
  #
  #   @api private
  #
  #   @example Internal usage
  #     output = execute_playbook # Called by create method
  #
  def execute_playbook
    command = build_command

    # Build environment hash with proper locale settings for Ansible
    # Ansible requires UTF-8 locale encoding to function properly
    # ANSIBLE_STDOUT_CALLBACK=json enables JSON output for parsing
    custom_env = ENV.to_h.merge(
      'LC_ALL' => 'en_US.UTF-8',
      'LANG' => 'en_US.UTF-8',
      'ANSIBLE_STDOUT_CALLBACK' => 'json',
    )

    # Merge any user-specified environment variables
    custom_env.merge!(resource[:environment]) if resource[:environment]

    output = Puppet::Util::Execution.execute(
      command,
      failonfail: true,
      combine: true,
      custom_environment: custom_env,
    )

    # Return output for parsing and conditional logging by caller
    output
  end
end
