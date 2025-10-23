Feature: PAR Idempotency and Change Detection
  As a system administrator
  I want PAR to detect and report changes made by Ansible playbooks
  So that I can track what changes are being made to my systems

  Background:
    Given ansible-playbook is installed
    And I have a test directory for idempotency tests

  Scenario: Detect changes on first run, no changes on second run
    Given I create a playbook "idempotent-file.yml" with content:
      """
      ---
      - name: Idempotent playbook test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Create a test file
            ansible.builtin.file:
              path: /tmp/aruba/test-idempotent.txt
              state: touch
              mode: '0644'
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-idempotent':
        playbook => '/tmp/aruba/playbooks/idempotent-file.yml',
        logoutput => true,
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "changed"
    When I apply the manifest again
    Then the Puppet run should succeed
    And the playbook should report no changes

  Scenario: Detect changes when file content changes
    Given I create a playbook "update-file.yml" with content:
      """
      ---
      - name: Update file content
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Ensure test file exists with specific content
            ansible.builtin.copy:
              dest: /tmp/aruba/test-content.txt
              content: "Version 1"
              mode: '0644'
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-update':
        playbook => '/tmp/aruba/playbooks/update-file.yml',
        logoutput => true,
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "changed"
    When I update the playbook content to "Version 2"
    And I apply the manifest again
    Then the Puppet run should succeed
    And the output should contain "changed"

  Scenario: Report failure when task fails
    Given I create a playbook "failing-task.yml" with content:
      """
      ---
      - name: Playbook with failing task
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: This task will fail
            ansible.builtin.command: /bin/false
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-failure':
        playbook => '/tmp/aruba/playbooks/failing-task.yml',
        logoutput => true,
      }
      """
    When I apply the manifest
    Then the Puppet run should fail
    And the output should contain "failed"

  Scenario: logoutput parameter shows playbook output
    Given I create a playbook "with-output.yml" with content:
      """
      ---
      - name: Playbook with debug output
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display a message
            ansible.builtin.debug:
              msg: "This is test output from Ansible"
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-output-visible':
        playbook   => '/tmp/aruba/playbooks/with-output.yml',
        logoutput => true,
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "This is test output from Ansible"

  Scenario: logoutput parameter suppresses playbook output when false
    Given I create a playbook "with-output.yml" with content:
      """
      ---
      - name: Playbook with debug output
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display a message
            ansible.builtin.debug:
              msg: "This output should be suppressed"
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-output-suppressed':
        playbook   => '/tmp/aruba/playbooks/with-output.yml',
        logoutput => false,
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should not contain "This output should be suppressed"

  Scenario: Multiple playbook executions are idempotent
    Given I create a playbook "multi-task.yml" with content:
      """
      ---
      - name: Multi-task idempotent playbook
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Create directory
            ansible.builtin.file:
              path: /tmp/aruba/test-dir
              state: directory
              mode: '0755'
          
          - name: Create file in directory
            ansible.builtin.file:
              path: /tmp/aruba/test-dir/test.txt
              state: touch
              mode: '0644'
          
          - name: Set file content
            ansible.builtin.copy:
              dest: /tmp/aruba/test-dir/test.txt
              content: "Test content"
              mode: '0644'
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-multi-task':
        playbook => '/tmp/aruba/playbooks/multi-task.yml',
        logoutput => true,
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "changed"
    When I apply the manifest again
    Then the Puppet run should succeed
    And the playbook should report no changes
    When I apply the manifest a third time
    Then the Puppet run should succeed
    And the playbook should report no changes
