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
