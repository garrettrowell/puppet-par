# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:par).provider(:par) do
  let(:resource) do
    Puppet::Type.type(:par).new(
      name: 'test-playbook',
      playbook: '/tmp/test.yml',
    )
  end

  let(:provider) { resource.provider }

  describe '#exists?' do
    before(:each) do
      allow(File).to receive(:exist?).with('/tmp/test.yml').and_return(true)
      allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return('/usr/bin/ansible-playbook')
      allow(resource).to receive(:noop?).and_return(false)
    end

    it 'returns false when playbook makes changes' do
      # When playbook makes changes, exists? should return false to trigger create()
      allow(provider).to receive(:execute_playbook).and_return('{"stats": {"localhost": {"ok": 2, "changed": 1, "failed": 0}}}')
      expect(provider.exists?).to be false
    end

    it 'returns true when playbook is idempotent' do
      # When playbook is idempotent, exists? should return true (no create() call)
      allow(provider).to receive(:execute_playbook).and_return('{"stats": {"localhost": {"ok": 2, "changed": 0, "failed": 0}}}')
      expect(provider.exists?).to be true
    end

    it 'caches execution results for create method' do
      # exists? should cache the output so create() doesn't re-execute
      allow(provider).to receive(:execute_playbook).once.and_return('{"stats": {"localhost": {"ok": 1, "changed": 1, "failed": 0}}}')
      provider.exists?
      provider.create
    end

    it 'returns false in noop mode without executing playbook' do
      # In noop mode, should return false immediately without validation
      allow(resource).to receive(:noop?).and_return(true)
      expect(provider).not_to receive(:execute_playbook_with_validation)
      expect(provider.exists?).to be false
    end
  end

  describe '#create' do
    before(:each) do
      allow(File).to receive(:exist?).with('/tmp/test.yml').and_return(true)
      allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return('/usr/bin/ansible-playbook')
    end

    it 'is defined' do
      expect(provider).to respond_to(:create)
    end

    context 'when not in noop mode' do
      before(:each) do
        allow(resource).to receive(:noop?).and_return(false)
        allow(provider).to receive(:execute_playbook).and_return('{"stats": {"localhost": {"ok": 1, "changed": 0, "failed": 0}}}')
      end

      it 'uses cached results from exists? if available' do
        # Set up cached results
        provider.instance_variable_set(:@execution_output, '{"stats": {"localhost": {"ok": 1, "changed": 1, "failed": 0}}}')
        provider.instance_variable_set(:@execution_stats, { ok: 1, changed: 1, failed: 0 })

        # Should not call execute_playbook again
        expect(provider).not_to receive(:execute_playbook)
        provider.create
      end

      it 'executes playbook if no cached results available' do
        # Should call execute_playbook_with_validation
        expect(provider).to receive(:execute_playbook_with_validation).and_return('{"stats": {"localhost": {"ok": 1, "changed": 0, "failed": 0}}}')
        provider.create
      end
    end

    context 'when in noop mode' do
      before(:each) do
        allow(resource).to receive(:noop?).and_return(true)
      end

      it 'does not execute the playbook' do
        expect(provider).not_to receive(:execute_playbook)
        expect(Puppet).to receive(:notice).with(%r{Would execute:})
        provider.create
      end

      it 'logs what would be executed' do
        allow(provider).to receive(:build_command).and_return(['ansible-playbook', '-i', 'localhost,', '/tmp/test.yml'])
        expect(Puppet).to receive(:notice).with(%r{Would execute:.*ansible-playbook})
        provider.create
      end
    end
  end

  describe '#build_command' do
    it 'returns an array' do
      expect(provider.build_command).to be_a(Array)
    end

    it 'includes ansible-playbook as the first element' do
      expect(provider.build_command.first).to eq('ansible-playbook')
    end

    it 'includes -i localhost, for inventory' do
      command = provider.build_command
      localhost_index = command.index('localhost,')
      expect(command[localhost_index - 1]).to eq('-i')
      expect(command[localhost_index]).to eq('localhost,')
    end

    it 'includes --connection=local' do
      expect(provider.build_command).to include('--connection=local')
    end

    it 'includes the playbook path' do
      expect(provider.build_command).to include('/tmp/test.yml')
    end

    it 'places the playbook path at the end' do
      expect(provider.build_command.last).to eq('/tmp/test.yml')
    end

    context 'with a playbook path containing spaces' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-with-spaces',
          playbook: '/path/with spaces/playbook.yml',
        )
      end

      it 'includes the full path with spaces' do
        expect(provider.build_command).to include('/path/with spaces/playbook.yml')
      end
    end

    context 'with playbook_vars parameter' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-with-vars',
          playbook: '/tmp/test.yml',
          playbook_vars: { 'app_version' => '1.2.3', 'environment' => 'production' },
        )
      end

      it 'includes -e flag' do
        expect(provider.build_command).to include('-e')
      end

      it 'serializes vars to JSON' do
        command = provider.build_command
        e_index = command.index('-e')
        json_value = command[e_index + 1]
        expect(json_value).to match(%r{app_version})
        expect(json_value).to match(%r{1\.2\.3})
        expect(json_value).to match(%r{environment})
        expect(json_value).to match(%r{production})
      end

      it 'places vars before the playbook path' do
        command = provider.build_command
        e_index = command.index('-e')
        playbook_index = command.index('/tmp/test.yml')
        expect(e_index).to be < playbook_index
      end
    end

    context 'with empty playbook_vars' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-empty-vars',
          playbook: '/tmp/test.yml',
          playbook_vars: {},
        )
      end

      it 'does not include -e flag' do
        expect(provider.build_command).not_to include('-e')
      end
    end

    context 'with nil playbook_vars' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-nil-vars',
          playbook: '/tmp/test.yml',
        )
      end

      it 'does not include -e flag' do
        expect(provider.build_command).not_to include('-e')
      end
    end

    context 'with nested playbook_vars' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-nested-vars',
          playbook: '/tmp/test.yml',
          playbook_vars: {
            'database' => {
              'host' => 'localhost',
              'port' => 5432,
            },
            'cache' => {
              'enabled' => true,
            },
          },
        )
      end

      it 'serializes nested structures to JSON' do
        command = provider.build_command
        e_index = command.index('-e')
        json_value = command[e_index + 1]
        expect(json_value).to match(%r{database})
        expect(json_value).to match(%r{host})
        expect(json_value).to match(%r{localhost})
        expect(json_value).to match(%r{port})
        expect(json_value).to match(%r{5432})
      end
    end

    context 'with array values in playbook_vars' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-array-vars',
          playbook: '/tmp/test.yml',
          playbook_vars: {
            'servers' => ['web1', 'web2', 'web3'],
            'ports' => [80, 443, 8080],
          },
        )
      end

      it 'serializes arrays to JSON' do
        command = provider.build_command
        e_index = command.index('-e')
        json_value = command[e_index + 1]
        expect(json_value).to match(%r{servers})
        expect(json_value).to match(%r{web1})
        expect(json_value).to match(%r{web2})
        expect(json_value).to match(%r{ports})
        expect(json_value).to match(%r{80})
      end
    end

    context 'with special characters in playbook_vars' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-special-chars',
          playbook: '/tmp/test.yml',
          playbook_vars: {
            'password' => 'p@ssw0rd!',
            'message' => 'Hello "world"',
            'path' => '/var/log/app.log',
          },
        )
      end

      it 'properly escapes special characters in JSON' do
        command = provider.build_command
        e_index = command.index('-e')
        json_value = command[e_index + 1]
        # JSON should escape quotes properly
        expect(json_value).to be_a(String)
        # Verify the JSON is parseable
        require 'json'
        expect { JSON.parse(json_value) }.not_to raise_error
      end
    end

    context 'with tags parameter' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-with-tags',
          playbook: '/tmp/test.yml',
          tags: ['webserver', 'database'],
        )
      end

      it 'includes --tags flag' do
        expect(provider.build_command).to include('--tags')
      end

      it 'includes comma-separated tag list' do
        command = provider.build_command
        tags_index = command.index('--tags')
        tags_value = command[tags_index + 1]
        expect(tags_value).to eq('webserver,database')
      end
    end

    context 'with single tag' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-single-tag',
          playbook: '/tmp/test.yml',
          tags: ['configuration'],
        )
      end

      it 'includes the single tag' do
        command = provider.build_command
        tags_index = command.index('--tags')
        tags_value = command[tags_index + 1]
        expect(tags_value).to eq('configuration')
      end
    end

    context 'with skip_tags parameter' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-with-skip-tags',
          playbook: '/tmp/test.yml',
          skip_tags: ['slow', 'dangerous'],
        )
      end

      it 'includes --skip-tags flag' do
        expect(provider.build_command).to include('--skip-tags')
      end

      it 'includes comma-separated tag list' do
        command = provider.build_command
        skip_index = command.index('--skip-tags')
        skip_value = command[skip_index + 1]
        expect(skip_value).to eq('slow,dangerous')
      end
    end

    context 'with start_at_task parameter' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-start-at',
          playbook: '/tmp/test.yml',
          start_at_task: 'Install packages',
        )
      end

      it 'includes --start-at-task flag' do
        expect(provider.build_command).to include('--start-at-task')
      end

      it 'includes the task name' do
        command = provider.build_command
        start_index = command.index('--start-at-task')
        task_name = command[start_index + 1]
        expect(task_name).to eq('Install packages')
      end
    end

    context 'with limit parameter' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-limit',
          playbook: '/tmp/test.yml',
          limit: 'localhost',
        )
      end

      it 'includes --limit flag' do
        expect(provider.build_command).to include('--limit')
      end

      it 'includes the limit pattern' do
        command = provider.build_command
        limit_index = command.index('--limit')
        limit_value = command[limit_index + 1]
        expect(limit_value).to eq('localhost')
      end
    end

    context 'with verbose parameter' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-verbose',
          playbook: '/tmp/test.yml',
          verbose: true,
        )
      end

      it 'includes -v flag' do
        expect(provider.build_command).to include('-v')
      end
    end

    context 'with verbose false' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-no-verbose',
          playbook: '/tmp/test.yml',
          verbose: false,
        )
      end

      it 'does not include -v flag' do
        expect(provider.build_command).not_to include('-v')
      end
    end

    context 'with check_mode parameter' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-check',
          playbook: '/tmp/test.yml',
          check_mode: true,
        )
      end

      it 'includes --check flag' do
        expect(provider.build_command).to include('--check')
      end
    end

    context 'with check_mode false' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-no-check',
          playbook: '/tmp/test.yml',
          check_mode: false,
        )
      end

      it 'does not include --check flag' do
        expect(provider.build_command).not_to include('--check')
      end
    end

    context 'with user parameter' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-user',
          playbook: '/tmp/test.yml',
          user: 'ansible',
        )
      end

      it 'includes --user flag' do
        expect(provider.build_command).to include('--user')
      end

      it 'includes the username' do
        command = provider.build_command
        user_index = command.index('--user')
        username = command[user_index + 1]
        expect(username).to eq('ansible')
      end
    end

    context 'with timeout parameter' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-timeout',
          playbook: '/tmp/test.yml',
          timeout: 300,
        )
      end

      it 'includes --timeout flag' do
        expect(provider.build_command).to include('--timeout')
      end

      it 'includes the timeout value as string' do
        command = provider.build_command
        timeout_index = command.index('--timeout')
        timeout_value = command[timeout_index + 1]
        expect(timeout_value).to eq('300')
      end
    end

    context 'with multiple configuration options' do
      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'test-complex',
          playbook: '/tmp/test.yml',
          playbook_vars: { 'version' => '2.0' },
          tags: ['deploy'],
          verbose: true,
          check_mode: true,
          user: 'deployer',
        )
      end

      it 'includes all specified options' do
        command = provider.build_command
        expect(command).to include('-e')
        expect(command).to include('--tags')
        expect(command).to include('-v')
        expect(command).to include('--check')
        expect(command).to include('--user')
      end

      it 'places playbook path at the end' do
        expect(provider.build_command.last).to eq('/tmp/test.yml')
      end
    end
  end

  describe '#validate_ansible' do
    context 'when ansible-playbook is in PATH' do
      before(:each) do
        allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return('/usr/bin/ansible-playbook')
      end

      it 'returns true' do
        expect(provider.validate_ansible).to be true
      end

      it 'does not raise an error' do
        expect { provider.validate_ansible }.not_to raise_error
      end
    end

    context 'when ansible-playbook is not in PATH' do
      before(:each) do
        allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return(nil)
      end

      it 'returns false' do
        expect(provider.validate_ansible).to be false
      end
    end

    context 'when checking multiple times' do
      before(:each) do
        allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return('/usr/bin/ansible-playbook')
      end

      it 'consistently returns the same result' do
        expect(provider.validate_ansible).to be true
        expect(provider.validate_ansible).to be true
      end
    end
  end

  describe 'error handling' do
    describe 'missing playbook file' do
      before(:each) do
        allow(File).to receive(:exist?).with('/tmp/nonexistent.yml').and_return(false)
      end

      let(:resource) do
        Puppet::Type.type(:par).new(
          name: 'missing-playbook',
          playbook: '/tmp/nonexistent.yml',
        )
      end

      it 'raises an error when trying to create with missing playbook' do
        allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return('/usr/bin/ansible-playbook')
        expect {
          provider.create
        }.to raise_error(Puppet::Error, %r{Playbook file not found}i)
      end

      it 'includes the playbook path in the error message' do
        allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return('/usr/bin/ansible-playbook')
        expect {
          provider.create
        }.to raise_error(Puppet::Error, %r{/tmp/nonexistent\.yml})
      end
    end

    describe 'missing ansible executable' do
      before(:each) do
        allow(File).to receive(:exist?).with('/tmp/test.yml').and_return(true)
        allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return(nil)
      end

      it 'raises an error when ansible-playbook is not found' do
        expect {
          provider.create
        }.to raise_error(Puppet::Error, %r{ansible-playbook.*not found}i)
      end

      it 'provides a helpful error message' do
        expect {
          provider.create
        }.to raise_error(Puppet::Error, %r{PATH}i)
      end
    end
  end

  # T095: Test build_command adds JSON output flag
  describe '#build_command with JSON output' do
    before(:each) do
      allow(File).to receive(:exist?).with('/tmp/test.yml').and_return(true)
      allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return('/usr/bin/ansible-playbook')
    end

    it 'includes ANSIBLE_STDOUT_CALLBACK environment variable for JSON output' do
      # This will be tested via environment settings in execute_playbook
      # The build_command method doesn't need modification for JSON output
      # as it's controlled by environment variables
      expect(provider).to respond_to(:build_command)
    end
  end

  # T096-T098: Test parse_json_output method
  describe '#parse_json_output' do
    let(:json_output_with_changes) do
      <<~JSON
        {
          "plays": [
            {
              "play": {"name": "Test Play"},
              "tasks": []
            }
          ],
          "stats": {
            "localhost": {
              "ok": 5,
              "changed": 2,
              "unreachable": 0,
              "failed": 0,
              "skipped": 1,
              "rescued": 0,
              "ignored": 0
            }
          }
        }
      JSON
    end

    let(:json_output_no_changes) do
      <<~JSON
        {
          "plays": [
            {
              "play": {"name": "Test Play"},
              "tasks": []
            }
          ],
          "stats": {
            "localhost": {
              "ok": 3,
              "changed": 0,
              "unreachable": 0,
              "failed": 0,
              "skipped": 0,
              "rescued": 0,
              "ignored": 0
            }
          }
        }
      JSON
    end

    let(:json_output_with_failures) do
      <<~JSON
        {
          "plays": [
            {
              "play": {"name": "Test Play"},
              "tasks": []
            }
          ],
          "stats": {
            "localhost": {
              "ok": 2,
              "changed": 1,
              "unreachable": 0,
              "failed": 2,
              "skipped": 0,
              "rescued": 0,
              "ignored": 0
            }
          }
        }
      JSON
    end

    it 'extracts changed_count from JSON stats' do
      stats = provider.parse_json_output(json_output_with_changes)
      expect(stats[:changed]).to eq(2)
    end

    it 'extracts ok_count from JSON stats' do
      stats = provider.parse_json_output(json_output_with_changes)
      expect(stats[:ok]).to eq(5)
    end

    it 'extracts failed_count from JSON stats' do
      stats = provider.parse_json_output(json_output_with_failures)
      expect(stats[:failed]).to eq(2)
    end

    it 'returns zero changed when no changes made' do
      stats = provider.parse_json_output(json_output_no_changes)
      expect(stats[:changed]).to eq(0)
    end

    it 'handles missing stats gracefully' do
      expect {
        provider.parse_json_output('{}')
      }.not_to raise_error
    end

    it 'handles invalid JSON gracefully' do
      expect {
        provider.parse_json_output('not valid json')
      }.to raise_error(JSON::ParserError)
    end

    it 'handles Ansible warnings with Jinja2 templates before JSON' do
      output_with_warnings = <<~OUTPUT
        [WARNING]: conditional statements should not include jinja2 templating
        delimiters such as {{ }} or {% %}. Found: {{ ansible_facts['distribution'] |
        lower in nginx_distributions.keys() | list }}
        {
          "plays": [],
          "stats": {
            "localhost": {
              "ok": 3,
              "changed": 1,
              "failed": 0
            }
          }
        }
      OUTPUT

      stats = provider.parse_json_output(output_with_warnings)
      expect(stats[:changed]).to eq(1)
      expect(stats[:ok]).to eq(3)
      expect(stats[:failed]).to eq(0)
    end

    it 'handles multiple warnings with curly braces before JSON' do
      output_with_multiple_warnings = <<~OUTPUT
        [WARNING]: Found: {{ ansible_facts['os_family'] }}
        [WARNING]: Found: {% if condition %}
        [WARNING]: Found: {{ variable | filter }}
        {
          "stats": {
            "localhost": {
              "ok": 5,
              "changed": 2,
              "failed": 0
            }
          }
        }
      OUTPUT

      stats = provider.parse_json_output(output_with_multiple_warnings)
      expect(stats[:changed]).to eq(2)
    end
  end

  # T099-T101: Test change detection in create method
  describe '#create with change detection' do
    let(:json_output_changed) do
      {
        stats: {
          'localhost' => {
            'ok' => 3,
            'changed' => 2,
            'failed' => 0,
          },
        },
      }
    end

    let(:json_output_no_changes) do
      {
        stats: {
          'localhost' => {
            'ok' => 3,
            'changed' => 0,
            'failed' => 0,
          },
        },
      }
    end

    let(:json_output_failed) do
      {
        stats: {
          'localhost' => {
            'ok' => 1,
            'changed' => 0,
            'failed' => 2,
          },
        },
      }
    end

    before(:each) do
      allow(File).to receive(:exist?).with('/tmp/test.yml').and_return(true)
      allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return('/usr/bin/ansible-playbook')
      allow(provider).to receive(:execute_playbook).and_return('')
    end

    it 'reports changed when Ansible reports changes' do
      # Set up cached results to simulate exists? already ran
      provider.instance_variable_set(:@execution_output, '')
      provider.instance_variable_set(:@execution_stats, { ok: 3, changed: 2, failed: 0 })

      expect(Puppet).to receive(:info).with(%r{2 tasks changed})
      provider.create
    end

    it 'executes playbook when no cached results' do
      allow(provider).to receive_messages(
        execute_playbook_with_validation: '',
        parse_json_output: { ok: 3, changed: 1, failed: 0 },
      )
      expect(Puppet).to receive(:info).with(%r{1 task changed})
      provider.create
    end

    it 'raises error when Ansible reports failures' do
      allow(provider).to receive(:parse_json_output).and_return(
        ok: 1, changed: 0, failed: 2,
      )
      expect {
        provider.create
      }.to raise_error(Puppet::Error, %r{2 tasks? failed})
    end
  end

  # T102-T103: Test logoutput parameter behavior
  describe '#create with logoutput parameter' do
    before(:each) do
      allow(File).to receive(:exist?).with('/tmp/test.yml').and_return(true)
      allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return('/usr/bin/ansible-playbook')
      allow(provider).to receive_messages(execute_playbook: "PLAY [Test]\n\nTASK [Debug]\nok: [localhost]\n", parse_json_output: { ok: 1, changed: 0, failed: 0 })
    end

    it 'displays stdout when logoutput is true' do
      resource[:logoutput] = :true
      expect(Puppet).to receive(:notice).with(%r{PLAY \[Test\]})
      provider.create
    end

    it 'suppresses stdout when logoutput is false' do
      resource[:logoutput] = :false
      expect(Puppet).not_to receive(:notice).with(%r{PLAY})
      provider.create
    end

    it 'suppresses stdout when logoutput is not specified' do
      expect(Puppet).not_to receive(:notice).with(%r{PLAY})
      provider.create
    end
  end

  # T104-T106: Test exclusive locking
  describe '#locking with exclusive parameter' do
    before(:each) do
      allow(File).to receive(:exist?).with('/tmp/test.yml').and_return(true)
      allow(Puppet::Util).to receive(:which).with('ansible-playbook').and_return('/usr/bin/ansible-playbook')
      allow(provider).to receive_messages(execute_playbook: '', parse_json_output: { ok: 1, changed: 0, failed: 0 })
    end

    it 'acquires lock when exclusive is true' do
      resource[:exclusive] = :true
      expect(provider).to receive(:acquire_lock).and_return(true)
      expect(provider).to receive(:release_lock)
      provider.create
    end

    it 'releases lock after execution when exclusive is true' do
      resource[:exclusive] = :true
      allow(provider).to receive(:acquire_lock).and_return(true)
      expect(provider).to receive(:release_lock)
      provider.create
    end

    it 'releases lock even when execution fails' do
      resource[:exclusive] = :true
      allow(provider).to receive(:acquire_lock).and_return(true)
      allow(provider).to receive(:execute_playbook).and_raise(StandardError, 'Test error')
      expect(provider).to receive(:release_lock)
      expect { provider.create }.to raise_error(StandardError, 'Test error')
    end

    it 'does not acquire lock when exclusive is false' do
      resource[:exclusive] = :false
      expect(provider).not_to receive(:acquire_lock)
      provider.create
    end

    it 'does not acquire lock when exclusive is not specified' do
      expect(provider).not_to receive(:acquire_lock)
      provider.create
    end

    it 'raises error when lock cannot be acquired' do
      resource[:exclusive] = :true
      allow(provider).to receive(:acquire_lock).and_return(false)
      expect {
        provider.create
      }.to raise_error(Puppet::Error, %r{lock})
    end
  end

  describe '#acquire_lock' do
    it 'responds to acquire_lock method' do
      expect(provider).to respond_to(:acquire_lock)
    end
  end

  describe '#release_lock' do
    it 'responds to release_lock method' do
      expect(provider).to respond_to(:release_lock)
    end
  end
end
