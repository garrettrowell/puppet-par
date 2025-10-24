# PAR with Variables Example
#
# This example demonstrates passing variables to an Ansible playbook
# using the playbook_vars parameter. Variables are serialized to JSON
# and passed via ansible-playbook's -e (--extra-vars) flag.
#
# Requirements:
# - ansible-playbook must be installed and available in PATH
# - The playbook file must exist at the specified path
#
# Usage:
#   puppet apply --libdir=lib examples/with_vars.pp

# Create a playbook that uses variables
file { '/tmp/vars_playbook.yml':
  ensure  => file,
  # lint:ignore:140chars lint:ignore:strict_indent
  content => @(END),
---
- name: Playbook with Variables
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Display app_name variable
      ansible.builtin.debug:
        msg: "Application: {{ app_name }}"
    
    - name: Display deploy_env variable
      ansible.builtin.debug:
        msg: "Environment: {{ deploy_env }}"
    
    - name: Display version variable
      ansible.builtin.debug:
        msg: "Version: {{ app_version }}"
    
    - name: Display port variable
      ansible.builtin.debug:
        msg: "Port: {{ app_port }}"
    
    - name: Display debug_mode variable
      ansible.builtin.debug:
        msg: "Debug Mode: {{ debug_mode }}"
    
    - name: Display nested config
      ansible.builtin.debug:
        msg: "Database Host: {{ database.host }}, Port: {{ database.port }}"
| END
  # lint:endignore
}

# Execute the playbook with variables
# Variables are passed as a Hash and automatically converted to JSON
par { 'playbook-with-vars':
  ensure        => present,
  playbook      => '/tmp/vars_playbook.yml',
  playbook_vars => {
    'app_name'    => 'myapp',
    'deploy_env'  => 'production',
    'app_version' => '1.2.3',
    'app_port'    => 8080,
    'debug_mode'  => true,
    'database'    => {
      'host' => 'db.example.com',
      'port' => 5432,
    },
  },
}

# The PAR resource will:
# 1. Serialize playbook_vars to JSON
# 2. Execute: ansible-playbook -i localhost, --connection=local \
#    -e '{"app_name":"myapp","deploy_env":"production",...}' \
#    /tmp/vars_playbook.yml
# 3. Variables are available in the playbook as Jinja2 template variables
#
# Supported variable types:
# - String: 'myapp'
# - Integer: 8080
# - Boolean: true/false
# - Hash: { 'key' => 'value' }
# - Array: ['item1', 'item2']
# - Nested structures: { 'db' => { 'host' => 'localhost' } }
#
# Special characters in variables are automatically escaped during JSON serialization.
