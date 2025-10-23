# PAR Noop Mode Example
#
# This example demonstrates how PAR behaves in Puppet's noop (--noop) mode.
# When applied with --noop flag, PAR will validate dependencies but NOT
# execute the Ansible playbook, showing you what would happen.
#
# Requirements:
# - ansible-playbook must be installed and available in PATH
# - The playbook file must exist at the specified path
#
# Usage:
#   puppet apply --noop examples/noop.pp
#
# In noop mode, PAR will:
# 1. Check that ansible-playbook is in PATH (fails if missing)
# 2. Check that playbook file exists (fails if missing)
# 3. Show "would execute" message without running ansible-playbook
# 4. Report what would change
#
# Compare with:
#   puppet apply examples/noop.pp  (actually executes playbook)

# Create a playbook that makes a visible change
file { '/tmp/noop_example_playbook.yml':
  ensure  => file,
  content => stdlib::to_yaml([
      {
        'name'         => 'Noop Mode Example Playbook',
        'hosts'        => 'localhost',
        'gather_facts' => false,
        'tasks'        => [
          {
            'name'                 => 'Create a timestamp file',
            'ansible.builtin.copy' => {
              'content' => "Last run: {{ ansible_date_time.iso8601 }}\n",
              'dest'    => '/tmp/par_noop_test.txt',
              'mode'    => '0644',
            },
          },
          {
            'name'                  => 'Display noop status',
            'ansible.builtin.debug' => {
              'msg' => 'This playbook ran at {{ ansible_date_time.iso8601 }}',
            },
          },
        ],
      },
  ]),
}

# PAR resource that will respect noop mode
par { 'noop-mode-example':
  ensure   => present,
  playbook => '/tmp/noop_example_playbook.yml',
}

# Expected behavior:
#
# With --noop flag:
#   Notice: /Stage[main]/Main/File[/tmp/noop_example_playbook.yml]/ensure: current_value 'absent', should be 'file' (noop)
#   Notice: /Stage[main]/Main/Par[noop-mode-example]/ensure: current_value 'absent', should be 'present' (noop)
#   Notice: Class[Main]: Would have triggered 'refreshed' from 2 events
#
# Without --noop flag:
#   Notice: /Stage[main]/Main/File[/tmp/noop_example_playbook.yml]/ensure: defined content as '{sha256}...'
#   Notice: /Stage[main]/Main/Par[noop-mode-example]/ensure: created
#   (Ansible playbook actually executes, /tmp/par_noop_test.txt is created)
#
# Verification after normal run:
#   cat /tmp/par_noop_test.txt
#   (Shows timestamp of last execution)
