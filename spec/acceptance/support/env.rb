# frozen_string_literal: true

# Cucumber environment setup for PAR acceptance tests
# This file configures Aruba for CLI testing of puppet apply commands

require 'aruba/cucumber'
require 'puppet'

# Configure Aruba for command execution
Aruba.configure do |config|
  # Set timeout for command execution (playbooks may take time)
  config.exit_timeout = 300
  config.io_wait_timeout = 30
  config.startup_wait_time = 2
  
  # Use relative path for Aruba working directory
  config.working_directory = 'tmp/aruba'
end

# Helper methods for Puppet testing
module PuppetHelpers
  # Get the module path for puppet apply
  def module_path
    File.expand_path('../../../..', __dir__)
  end
  
  # Build puppet apply command with proper modulepath
  def puppet_apply_command(manifest_path, options = {})
    cmd = ['puppet', 'apply']
    cmd << '--modulepath' << module_path
    cmd << '--noop' if options[:noop]
    cmd << '--debug' if options[:debug]
    cmd << '--verbose' if options[:verbose]
    cmd << manifest_path
    cmd.join(' ')
  end
  
  # Check if ansible-playbook is available
  def ansible_available?
    system('which ansible-playbook > /dev/null 2>&1')
  end
  
  # Create a temporary manifest file
  def create_manifest(name, content)
    manifest_path = File.join(aruba.config.working_directory, "#{name}.pp")
    FileUtils.mkdir_p(File.dirname(manifest_path))
    File.write(manifest_path, content)
    manifest_path
  end
  
  # Create a temporary playbook file
  def create_playbook(name, content)
    playbook_path = File.join(aruba.config.working_directory, "playbooks", "#{name}.yml")
    FileUtils.mkdir_p(File.dirname(playbook_path))
    File.write(playbook_path, content)
    playbook_path
  end
  
  # Clean up temporary files
  def cleanup_temp_files
    temp_dir = File.join(Dir.pwd, 'tmp', 'aruba')
    FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
  end
end

# Include helper methods in Cucumber world
World(PuppetHelpers)

# Before and After hooks for test isolation
Before do
  # Ensure clean state before each scenario
  cleanup_temp_files
  
  # Skip tests if Ansible is not installed
  unless ansible_available?
    skip_this_scenario("Ansible is not installed. Please install ansible-playbook to run acceptance tests.")
  end
end

After do
  # Clean up after each scenario
  cleanup_temp_files
end

# Print useful information at the start of the test run
at_exit do
  puts "\n=== Cucumber Acceptance Test Summary ==="
  puts "Puppet version: #{Puppet.version}"
  puts "Ruby version: #{RUBY_VERSION}"
  puts "Aruba version: #{Aruba::VERSION}"
  puts "========================================\n"
end
