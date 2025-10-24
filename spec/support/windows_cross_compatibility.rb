# frozen_string_literal: true

# Shared context for testing Windows behavior on non-Windows systems
shared_context 'windows_cross_compatibility' do |os_facts: {}|
  before(:each) do
    # workaround the following error when unit tests are not ran on windows based operating systems
    #
    #       ArgumentError:  wrong number of arguments (given 1, expected 0)
    #
    if os_facts[:kernel].casecmp('windows').zero?
      begin
        # Test to see if this works without modification
        include 'puppet/util/windows'
        include 'puppet/util/windows/adsi'
        Puppet::Util::Windows::ADSI.computer_name
      rescue LoadError, StandardError
        user = instance_double('user')
        allow(Puppet::Util::Windows::ADSI::User).to receive(:new).and_return(user)
        allow(user).to receive(:groups).and_return(['group2', 'group3'])
        allow(Puppet::Util::Windows::ADSI::Group).to receive(:name_sid_hash).and_return({})
      end

      # Mock File.expand_path to handle Windows paths correctly on non-Windows test systems
      # This allows us to test Windows path validation without actually running on Windows
      original_expand_path = File.method(:expand_path)
      allow(File).to receive(:expand_path) do |path, *args|
        # If path looks like a Windows absolute path, return it unchanged
        if path =~ %r{^[A-Za-z]:/} || path =~ %r{^//}
          path
        else
          # Otherwise, call the original implementation
          original_expand_path.call(path, *args)
        end
      end
    end
  end
end
