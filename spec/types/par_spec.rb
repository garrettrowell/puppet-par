# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:par) do
  let(:resource_name) { 'test-playbook' }
  let(:valid_playbook) { '/tmp/test.yml' }

  describe 'namevar (name parameter)' do
    it 'accepts a string as the name' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:name]).to eq(resource_name)
    end

    it 'uses name as the namevar' do
      described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(described_class.key_attributes).to eq([:name])
    end

    it 'requires a name' do
      expect {
        described_class.new(playbook: valid_playbook)
      }.to raise_error(Puppet::Error, %r{Title or name must be provided})
    end

    it 'allows alphanumeric names with hyphens and underscores' do
      valid_names = ['simple', 'with-hyphen', 'with_underscore', 'Mixed123']
      valid_names.each do |name|
        resource = described_class.new(
          name: name,
          playbook: valid_playbook,
        )
        expect(resource[:name]).to eq(name)
      end
    end
  end

  describe 'playbook parameter' do
    it 'is required' do
      expect {
        described_class.new(name: resource_name)
      }.to raise_error(Puppet::Error, %r{playbook.*required}i)
    end

    it 'accepts an absolute path' do
      resource = described_class.new(
        name: resource_name,
        playbook: '/etc/ansible/playbooks/test.yml',
      )
      expect(resource[:playbook]).to eq('/etc/ansible/playbooks/test.yml')
    end

    it 'accepts absolute paths with spaces' do
      playbook_with_spaces = '/path/with spaces/playbook.yml'
      resource = described_class.new(
        name: resource_name,
        playbook: playbook_with_spaces,
      )
      expect(resource[:playbook]).to eq(playbook_with_spaces)
    end

    it 'rejects relative paths' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: 'relative/path/playbook.yml',
        )
      }.to raise_error(Puppet::Error, %r{absolute path}i)
    end

    it 'rejects paths starting with ./' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: './playbook.yml',
        )
      }.to raise_error(Puppet::Error, %r{absolute path}i)
    end

    it 'rejects paths starting with ../' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: '../playbook.yml',
        )
      }.to raise_error(Puppet::Error, %r{absolute path}i)
    end

    it 'accepts Windows absolute paths on Windows', if: Puppet::Util::Platform.windows? do
      resource = described_class.new(
        name: resource_name,
        playbook: 'C:/ansible/playbooks/test.yml',
      )
      expect(resource[:playbook]).to eq('C:/ansible/playbooks/test.yml')
    end
  end

  describe 'playbook_vars parameter' do
    it 'accepts a hash of variables' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        playbook_vars: { 'ansible_user' => 'deploy', 'app_version' => '1.2.3' },
      )
      expect(resource[:playbook_vars]).to eq({ 'ansible_user' => 'deploy', 'app_version' => '1.2.3' })
    end

    it 'accepts an empty hash' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        playbook_vars: {},
      )
      expect(resource[:playbook_vars]).to eq({})
    end

    it 'accepts nested hashes' do
      vars = {
        'database' => {
          'host' => 'localhost',
          'port' => 5432,
        },
        'cache' => {
          'enabled' => true,
        },
      }
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        playbook_vars: vars,
      )
      expect(resource[:playbook_vars]).to eq(vars)
    end

    it 'accepts hashes with array values' do
      vars = {
        'servers' => ['web1', 'web2', 'web3'],
        'ports' => [80, 443, 8080],
      }
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        playbook_vars: vars,
      )
      expect(resource[:playbook_vars]).to eq(vars)
    end

    it 'is optional' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:playbook_vars]).to be_nil
    end

    it 'rejects string values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          playbook_vars: 'not a hash',
        )
      }.to raise_error(Puppet::Error, %r{playbook_vars must be a Hash}i)
    end

    it 'rejects array values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          playbook_vars: ['not', 'a', 'hash'],
        )
      }.to raise_error(Puppet::Error, %r{playbook_vars must be a Hash}i)
    end

    it 'rejects integer values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          playbook_vars: 42,
        )
      }.to raise_error(Puppet::Error, %r{playbook_vars must be a Hash}i)
    end

    it 'rejects boolean values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          playbook_vars: true,
        )
      }.to raise_error(Puppet::Error, %r{playbook_vars must be a Hash}i)
    end
  end

  describe 'tags parameter' do
    it 'accepts an array of tags' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        tags: ['webserver', 'database'],
      )
      expect(resource[:tags]).to eq(['webserver', 'database'])
    end

    it 'accepts an empty array' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        tags: [],
      )
      expect(resource[:tags]).to eq([])
    end

    it 'accepts a single-element array' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        tags: ['configuration'],
      )
      expect(resource[:tags]).to eq(['configuration'])
    end

    it 'is optional' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:tags]).to be_nil
    end

    it 'rejects string values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          tags: 'webserver',
        )
      }.to raise_error(Puppet::Error, %r{tags must be an Array}i)
    end

    it 'rejects hash values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          tags: { 'tag' => 'webserver' },
        )
      }.to raise_error(Puppet::Error, %r{tags must be an Array}i)
    end
  end

  describe 'skip_tags parameter' do
    it 'accepts an array of tags to skip' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        skip_tags: ['slow', 'dangerous'],
      )
      expect(resource[:skip_tags]).to eq(['slow', 'dangerous'])
    end

    it 'accepts an empty array' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        skip_tags: [],
      )
      expect(resource[:skip_tags]).to eq([])
    end

    it 'is optional' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:skip_tags]).to be_nil
    end

    it 'rejects string values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          skip_tags: 'slow',
        )
      }.to raise_error(Puppet::Error, %r{skip_tags must be an Array}i)
    end
  end

  describe 'start_at_task parameter' do
    it 'accepts a task name string' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        start_at_task: 'Install packages',
      )
      expect(resource[:start_at_task]).to eq('Install packages')
    end

    it 'is optional' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:start_at_task]).to be_nil
    end

    it 'rejects empty strings' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          start_at_task: '',
        )
      }.to raise_error(Puppet::Error, %r{start_at_task cannot be empty}i)
    end

    it 'rejects array values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          start_at_task: ['task1'],
        )
      }.to raise_error(Puppet::Error, %r{start_at_task must be a String}i)
    end
  end

  describe 'limit parameter' do
    it 'accepts a host pattern string' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        limit: 'localhost',
      )
      expect(resource[:limit]).to eq('localhost')
    end

    it 'accepts multiple hosts pattern' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        limit: 'web*:db*',
      )
      expect(resource[:limit]).to eq('web*:db*')
    end

    it 'is optional' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:limit]).to be_nil
    end

    it 'rejects empty strings' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          limit: '',
        )
      }.to raise_error(Puppet::Error, %r{limit cannot be empty}i)
    end

    it 'rejects array values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          limit: ['localhost'],
        )
      }.to raise_error(Puppet::Error, %r{limit must be a String}i)
    end
  end

  describe 'verbose parameter' do
    it 'accepts true' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        verbose: true,
      )
      expect(resource[:verbose]).to eq(true)
    end

    it 'accepts false' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        verbose: false,
      )
      expect(resource[:verbose]).to eq(false)
    end

    it 'is optional' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:verbose]).to be_nil
    end

    it 'accepts string "true"' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        verbose: 'true',
      )
      expect(resource[:verbose]).to eq(true)
    end

    it 'accepts string "false"' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        verbose: 'false',
      )
      expect(resource[:verbose]).to eq(false)
    end
  end

  describe 'check_mode parameter' do
    it 'accepts true' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        check_mode: true,
      )
      expect(resource[:check_mode]).to eq(true)
    end

    it 'accepts false' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        check_mode: false,
      )
      expect(resource[:check_mode]).to eq(false)
    end

    it 'is optional' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:check_mode]).to be_nil
    end

    it 'accepts string "true"' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        check_mode: 'true',
      )
      expect(resource[:check_mode]).to eq(true)
    end

    it 'accepts string "false"' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        check_mode: 'false',
      )
      expect(resource[:check_mode]).to eq(false)
    end
  end

  describe 'timeout parameter' do
    it 'accepts positive integers' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        timeout: 300,
      )
      expect(resource[:timeout]).to eq(300)
    end

    it 'accepts zero' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        timeout: 0,
      )
      expect(resource[:timeout]).to eq(0)
    end

    it 'is optional' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:timeout]).to be_nil
    end

    it 'rejects negative integers' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          timeout: -10,
        )
      }.to raise_error(Puppet::Error, %r{timeout must be a non-negative integer}i)
    end

    it 'rejects string values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          timeout: '300',
        )
      }.to raise_error(Puppet::Error, %r{timeout must be an Integer}i)
    end

    it 'rejects float values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          timeout: 30.5,
        )
      }.to raise_error(Puppet::Error, %r{timeout must be an Integer}i)
    end
  end

  describe 'user parameter' do
    it 'accepts a username string' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        user: 'ansible',
      )
      expect(resource[:user]).to eq('ansible')
    end

    it 'accepts usernames with special characters' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        user: 'ansible_user-1',
      )
      expect(resource[:user]).to eq('ansible_user-1')
    end

    it 'is optional' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:user]).to be_nil
    end

    it 'rejects empty strings' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          user: '',
        )
      }.to raise_error(Puppet::Error, %r{user cannot be empty}i)
    end

    it 'rejects array values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          user: ['ansible'],
        )
      }.to raise_error(Puppet::Error, %r{user must be a String}i)
    end
  end

  describe 'environment parameter' do
    it 'accepts a hash of environment variables' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        environment: { 'ANSIBLE_FORCE_COLOR' => 'true', 'ANSIBLE_HOST_KEY_CHECKING' => 'false' },
      )
      expect(resource[:environment]).to eq({ 'ANSIBLE_FORCE_COLOR' => 'true', 'ANSIBLE_HOST_KEY_CHECKING' => 'false' })
    end

    it 'accepts an empty hash' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
        environment: {},
      )
      expect(resource[:environment]).to eq({})
    end

    it 'is optional' do
      resource = described_class.new(
        name: resource_name,
        playbook: valid_playbook,
      )
      expect(resource[:environment]).to be_nil
    end

    it 'rejects string values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          environment: 'PATH=/usr/bin',
        )
      }.to raise_error(Puppet::Error, %r{environment must be a Hash}i)
    end

    it 'rejects array values' do
      expect {
        described_class.new(
          name: resource_name,
          playbook: valid_playbook,
          environment: ['PATH=/usr/bin'],
        )
      }.to raise_error(Puppet::Error, %r{environment must be a Hash}i)
    end
  end

  describe 'autorequire' do
    let(:catalog) { Puppet::Resource::Catalog.new }
    let(:playbook_path) { '/etc/ansible/playbooks/setup.yml' }

    it 'autorequires File resource for the playbook path' do
      # Create a file resource for the playbook
      file = Puppet::Type.type(:file).new(
        name: playbook_path,
        ensure: :file,
      )
      catalog.add_resource(file)

      # Create a PAR resource that references the same playbook path
      par = described_class.new(
        name: resource_name,
        playbook: playbook_path,
      )
      catalog.add_resource(par)

      # Get autorequire relationships
      autorequired = par.autorequire

      # Verify the relationship was created
      expect(autorequired.length).to eq(1)
      expect(autorequired[0].source).to eq(file)
      expect(autorequired[0].target).to eq(par)
    end

    it 'does not autorequire when no matching File resource exists' do
      # Create a PAR resource without a corresponding File resource
      par = described_class.new(
        name: resource_name,
        playbook: playbook_path,
      )
      catalog.add_resource(par)

      # Get autorequire relationships
      autorequired = par.autorequire

      # Verify no relationships were created
      expect(autorequired.length).to eq(0)
    end

    it 'autorequires File resource even with different casing on namevar' do
      # Create a file resource with different resource title
      file = Puppet::Type.type(:file).new(
        name: playbook_path,
        ensure: :file,
      )
      catalog.add_resource(file)

      # Create a PAR resource
      par = described_class.new(
        name: resource_name,
        playbook: playbook_path, # Same path
      )
      catalog.add_resource(par)

      # Get autorequire relationships
      autorequired = par.autorequire

      # Verify the relationship was created based on path matching
      expect(autorequired.length).to eq(1)
      expect(autorequired[0].source.title).to eq(playbook_path)
    end
  end
end
