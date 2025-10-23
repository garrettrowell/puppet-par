# PAR with Tags Example
#
# This example demonstrates using Ansible tags to selectively execute
# tasks in a playbook. Tags allow you to run only specific parts of
# a playbook without executing all tasks.
#
# Requirements:
# - ansible-playbook must be installed and available in PATH
# - The playbook file must exist at the specified path
#
# Usage:
#   puppet apply --libdir=lib examples/tags.pp

# Create a playbook with tagged tasks
file { '/tmp/tagged_playbook.yml':
  ensure  => file,
  # lint:ignore:140chars lint:ignore:strict_indent
  content => @(END),
---
- name: Playbook with Tagged Tasks
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Setup task
      ansible.builtin.debug:
        msg: "Running setup"
      tags:
        - setup
        - always
    
    - name: Install packages
      ansible.builtin.debug:
        msg: "Installing packages"
      tags:
        - install
        - packages
    
    - name: Configure application
      ansible.builtin.debug:
        msg: "Configuring application"
      tags:
        - config
        - configure
    
    - name: Deploy application
      ansible.builtin.debug:
        msg: "Deploying application"
      tags:
        - deploy
    
    - name: Cleanup task
      ansible.builtin.debug:
        msg: "Running cleanup"
      tags:
        - cleanup
        - never
| END
  # lint:endignore
}

# Example 1: Run only setup and config tasks
par { 'run-setup-and-config':
  ensure   => present,
  playbook => '/tmp/tagged_playbook.yml',
  tags     => ['setup', 'config'],
}

# Example 2: Run all tasks except cleanup
par { 'run-without-cleanup':
  ensure    => present,
  playbook  => '/tmp/tagged_playbook.yml',
  skip_tags => ['cleanup'],
}

# Example 3: Run only deploy tasks
par { 'run-deploy-only':
  ensure   => present,
  playbook => '/tmp/tagged_playbook.yml',
  tags     => ['deploy'],
}

# The PAR resource will translate tags parameters to ansible-playbook CLI options:
#
# tags parameter:
# - tags => ['setup', 'config']
# - Executes: ansible-playbook -i localhost, --connection=local \
#   -t setup,config /tmp/tagged_playbook.yml
# - Only tasks tagged with 'setup' or 'config' will run
#
# skip_tags parameter:
# - skip_tags => ['cleanup']
# - Executes: ansible-playbook -i localhost, --connection=local \
#   --skip-tags cleanup /tmp/tagged_playbook.yml
# - All tasks except those tagged with 'cleanup' will run
#
# Special tags:
# - 'always': Tasks tagged with 'always' run unless explicitly skipped
# - 'never': Tasks tagged with 'never' only run when explicitly included
# - 'all': Runs all tasks (default behavior)
#
# Note: tags and skip_tags can be used together for fine-grained control
