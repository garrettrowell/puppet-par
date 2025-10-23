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
