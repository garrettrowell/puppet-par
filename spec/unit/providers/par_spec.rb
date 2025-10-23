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
    it 'always returns false to ensure playbook execution' do
      # PAR resources represent actions (playbook executions), not states
      # Therefore exists? always returns false so create() is always called
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
        allow(provider).to receive(:execute_playbook)
      end

      it 'calls execute_playbook' do
        expect(provider).to receive(:execute_playbook)
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
end
