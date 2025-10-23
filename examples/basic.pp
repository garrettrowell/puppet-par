# Basic PAR (Puppet Ansible Runner) Usage
#
# This example demonstrates the minimal configuration needed to execute
# an Ansible playbook against localhost using the PAR custom type.
#
# Requirements:
# - ansible-playbook must be installed and available in PATH
# - The playbook file must exist at the specified path
#
# Usage:
#   puppet apply examples/basic.pp

# Ensure the playbook file exists first
# PAR will autorequire this File resource automatically
file { '/tmp/example_playbook.yml':
  ensure  => file,
  content => stdlib::to_yaml([
      {
        'name'         => 'Example Playbook',
        'hosts'        => 'localhost',
        'gather_facts' => false,
        'tasks'        => [
          {
            'name'                 => 'Create test file',
            'ansible.builtin.file' => {
              'path'  => '/tmp/par_test.txt',
              'state' => 'touch',
              'mode'  => '0644',
            },
          },
          {
            'name'                  => 'Display message',
            'ansible.builtin.debug' => {
              'msg' => 'PAR successfully executed this playbook!',
            },
          },
        ],
      },
  ]),
}

# Execute the Ansible playbook against localhost
# The namevar 'example-playbook' is a unique identifier for this resource
# The playbook parameter specifies the absolute path to the playbook file
par { 'example-playbook':
  ensure   => present,
  playbook => '/tmp/example_playbook.yml',
}

# The PAR resource will:
# 1. Validate that ansible-playbook is available in PATH
# 2. Check that /tmp/example_playbook.yml exists
# 3. Execute: ansible-playbook -i localhost, --connection=local /tmp/example_playbook.yml
# 4. Report success/failure to Puppet
#
# Output:
# Notice: /Stage[main]/Main/Par[example-playbook]/ensure: created
