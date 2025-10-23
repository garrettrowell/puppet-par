Feature: PAR Playbook Variables Passing
  As a system administrator
  I want to pass variables to Ansible playbooks through Puppet
  So that I can customize playbook behavior dynamically

  Background:
    Given ansible-playbook is installed

  Scenario: Pass simple string variables to playbook
    Given I create a playbook "vars-test.yml" with content:
      """
      ---
      - name: Variables test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display variable
            debug:
              msg: "App version is {{ app_version }}"
            changed_when: false

          - name: Display deploy environment
            debug:
              msg: "Deploy environment is {{ deploy_env }}"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-vars':
        playbook      => '/tmp/aruba/playbooks/vars-test.yml',
        playbook_vars => {
          'app_version' => '1.2.3',
          'deploy_env'  => 'production',
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "App version is 1.2.3"
    And the output should contain "Deploy environment is production"

  Scenario: Pass numeric variables to playbook
    Given I create a playbook "numeric-vars.yml" with content:
      """
      ---
      - name: Numeric variables test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display port
            debug:
              msg: "Port is {{ port }}"
            changed_when: false

          - name: Display timeout
            debug:
              msg: "Timeout is {{ timeout }}"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-numeric':
        playbook      => '/tmp/aruba/playbooks/numeric-vars.yml',
        playbook_vars => {
          'port'    => 8080,
          'timeout' => 300,
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "Port is 8080"
    And the output should contain "Timeout is 300"

  Scenario: Pass boolean variables to playbook
    Given I create a playbook "bool-vars.yml" with content:
      """
      ---
      - name: Boolean variables test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display enabled status
            debug:
              msg: "Feature enabled: {{ feature_enabled }}"
            changed_when: false

          - name: Display debug mode
            debug:
              msg: "Debug mode: {{ debug_mode }}"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-bool':
        playbook      => '/tmp/aruba/playbooks/bool-vars.yml',
        playbook_vars => {
          'feature_enabled' => true,
          'debug_mode'      => false,
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "Feature enabled: True"
    And the output should contain "Debug mode: False"

  Scenario: Empty playbook_vars should not affect execution
    Given I create a playbook "no-vars.yml" with content:
      """
      ---
      - name: No variables needed
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Simple task
            debug:
              msg: "No variables required"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-no-vars':
        playbook      => '/tmp/aruba/playbooks/no-vars.yml',
        playbook_vars => {},
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "No variables required"

  Scenario: Variables with special characters
    Given I create a playbook "special-chars.yml" with content:
      """
      ---
      - name: Special characters test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display path
            debug:
              msg: "Path is {{ log_path }}"
            changed_when: false

          - name: Display message
            debug:
              msg: "Message is {{ welcome_msg }}"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-special':
        playbook      => '/tmp/aruba/playbooks/special-chars.yml',
        playbook_vars => {
          'log_path'    => '/var/log/app.log',
          'welcome_msg' => 'Hello "World"!',
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "Path is /var/log/app.log"
    And the output should contain 'Message is Hello "World"!'

  Scenario: Verify variables are passed as JSON to ansible-playbook
    Given I create a playbook "simple-var.yml" with content:
      """
      ---
      - name: Simple variable test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display version
            debug:
              msg: "Version {{ version }}"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-json':
        playbook      => '/tmp/aruba/playbooks/simple-var.yml',
        playbook_vars => {
          'version' => '2.0.0',
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "Version 2.0.0"
