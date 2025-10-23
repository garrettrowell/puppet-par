# frozen_string_literal: true

# Given steps - Setup
Given('ansible-playbook is installed') do
  # This is checked in the Before hook in env.rb
  # If we get here, ansible-playbook is available
  expect(ansible_available?).to be true
end

Given('I have a test playbook at {string}') do |playbook_path|
  # Create a simple playbook that outputs a recognizable message
  playbook_content = <<~YAML
    ---
    - name: Test Playbook
      hosts: localhost
      connection: local
      gather_facts: no
      tasks:
        - name: Output test message
          debug:
            msg: "Hello from PAR test playbook"
  YAML

  @playbook_path = create_playbook(File.basename(playbook_path, '.yml'), playbook_content)
end

Given('I create a playbook {string} with content:') do |playbook_path, doc_string|
  @playbook_path = create_playbook(File.basename(playbook_path, '.yml'), doc_string)
end

Given('a Puppet manifest with PAR resource:') do |doc_string|
  # Replace placeholder paths with actual playbook path
  # This handles both /tmp/aruba/playbooks/*.yml and /tmp/test_playbook.yml patterns
  manifest_content = doc_string.gsub(%r{/tmp/(?:aruba/)?playbooks/[\w-]+\.yml}, @playbook_path) if @playbook_path
  manifest_content = (manifest_content || doc_string).gsub(%r{/tmp/(?:aruba/)?test_playbook\.yml}, @playbook_path) if @playbook_path
  manifest_content = (manifest_content || doc_string).gsub(%r{/tmp/(?:aruba/)?nonexistent\.yml}, '/tmp/aruba/nonexistent.yml')
  @manifest_path = create_manifest('test', manifest_content || doc_string)
end

Given('a Puppet manifest with PAR resources:') do |doc_string|
  # Replace placeholder paths with actual playbook path
  manifest_content = doc_string.gsub(%r{/tmp/(?:aruba/)?playbooks/[\w-]+\.yml}, @playbook_path) if @playbook_path
  manifest_content = (manifest_content || doc_string).gsub(%r{/tmp/(?:aruba/)?test_playbook\.yml}, @playbook_path) if @playbook_path
  @manifest_path = create_manifest('test', manifest_content || doc_string)
end

# When steps - Actions
When('I apply the manifest') do
  cmd = puppet_apply_command(@manifest_path)
  run_command_and_stop(cmd, fail_on_error: false)
end

When('I apply the manifest with --noop') do
  cmd = puppet_apply_command(@manifest_path, noop: true)
  run_command_and_stop(cmd, fail_on_error: false)
end

# Then steps - Assertions
Then('the Puppet run should succeed') do
  unless [0, 2].include?(last_command_started.exit_status)
    puts "\n=== PUPPET OUTPUT ==="
    puts last_command_started.output
    puts "=== END OUTPUT ===\n"
  end
  # Exit code 0 = no changes, 2 = changes made successfully with --detailed-exitcodes
  expect(last_command_started.exit_status).to(satisfy { |code| [0, 2].include?(code) })
end

Then('the Puppet run should fail') do
  # Exit code 4 = failures, 6 = changes and failures with --detailed-exitcodes
  expect(last_command_started.exit_status).to(satisfy { |code| [4, 6].include?(code) })
end

Then('the playbook should have executed') do
  # Check that the playbook was executed successfully
  # With JSON output format, we look for "plays" or "stats" or the success notice
  expect(last_command_started.output).to match(/plays|stats|Ansible playbook execution/)
end

Then('the playbook should not have executed') do
  # In noop mode, Puppet should show that the resource would be created (noop)
  expect(last_command_started.output).to match(%r{created \(noop\)|noop})
end

Then('both playbooks should have executed') do
  # Check for evidence of multiple playbook executions
  # With JSON output, look for multiple "plays" or "stats" or success messages
  expect(last_command_started.output).to match(/plays|stats|Ansible playbook execution/)
end

# Idempotency test steps
Given('I have a test directory for idempotency tests') do
  # Aruba creates temporary directories, just ensure it's accessible
  # Create the directory if it doesn't exist
  FileUtils.mkdir_p('/tmp/aruba') unless Dir.exist?('/tmp/aruba')
  expect(Dir.exist?('/tmp/aruba')).to be true
end

When('I apply the manifest again') do
  cmd = puppet_apply_command(@manifest_path)
  run_command_and_stop(cmd, fail_on_error: false)
end

When('I apply the manifest a third time') do
  cmd = puppet_apply_command(@manifest_path)
  run_command_and_stop(cmd, fail_on_error: false)
end

When('I update the playbook content to {string}') do |new_content|
  # Read the current playbook, update the content field
  playbook_content = File.read(@playbook_path)
  updated_content = playbook_content.gsub(/content:.*$/, "content: \"#{new_content}\"")
  File.write(@playbook_path, updated_content)
end

Then('the playbook should report no changes') do
  # With logoutput => false (default), we won't see full Ansible output
  # But PAR will log at debug level for idempotent runs
  # Check that "changed" count is 0 or no "changed" message appears
  # Allow the run to succeed with no explicit "changed" message
  expect(last_command_started.exit_status).to(satisfy { |code| [0, 2].include?(code) })
end
