Feature: Basic PAR Playbook Execution
  As a system administrator
  I want to execute Ansible playbooks through Puppet
  So that I can integrate Ansible automation into my Puppet-managed infrastructure

  Background:
    Given ansible-playbook is installed
    And I have a test playbook at "playbooks/simple.yml"

  Scenario: Execute a basic playbook successfully
    Given a Puppet manifest with PAR resource:
      """
      par { 'test-basic':
        playbook => '/tmp/aruba/playbooks/simple.yml',
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the playbook should have executed
    And the output should contain "Hello from PAR test playbook"

  Scenario: Puppet noop mode prevents playbook execution
    Given a Puppet manifest with PAR resource:
      """
      par { 'test-noop':
        playbook => '/tmp/aruba/playbooks/simple.yml',
      }
      """
    When I apply the manifest with --noop
    Then the Puppet run should succeed
    And the playbook should not have executed
    And the output should contain "Would execute:"
    And the output should contain "ansible-playbook"

  Scenario: Error when playbook file does not exist
    Given a Puppet manifest with PAR resource:
      """
      par { 'test-missing':
        playbook => '/tmp/aruba/nonexistent.yml',
      }
      """
    When I apply the manifest
    Then the Puppet run should fail
    And the output should contain "Playbook file not found"
    And the output should contain "/tmp/aruba/nonexistent.yml"

  Scenario: Simple playbook with localhost execution
    Given I create a playbook "test-hello.yml" with content:
      """
      ---
      - name: Test playbook
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Say hello
            debug:
              msg: "Hello from test playbook"
            changed_when: true
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'hello-test':
        playbook => '/tmp/aruba/playbooks/test-hello.yml',
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "Hello from test playbook"

  Scenario: PAR resource with descriptive name
    Given a Puppet manifest with PAR resource:
      """
      par { 'setup-webserver':
        playbook => '/tmp/aruba/playbooks/simple.yml',
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "Par[setup-webserver]"

  Scenario: Multiple playbook executions in sequence
    Given a Puppet manifest with PAR resources:
      """
      par { 'first-playbook':
        playbook => '/tmp/aruba/playbooks/simple.yml',
      }
      
      par { 'second-playbook':
        playbook => '/tmp/aruba/playbooks/simple.yml',
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And both playbooks should have executed
