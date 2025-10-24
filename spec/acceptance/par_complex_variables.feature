Feature: PAR Complex Playbook Variables
  As a system administrator
  I want to pass complex data structures to Ansible playbooks
  So that I can configure sophisticated playbook behaviors with nested data

  Background:
    Given ansible-playbook is installed

  Scenario: Pass nested hash variables to playbook
    Given I create a playbook "nested-hash.yml" with content:
      """
      ---
      - name: Nested hash variables test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display database config
            debug:
              msg: "DB: {{ database.host }}:{{ database.port }} ({{ database.name }})"
            changed_when: false

          - name: Display cache config
            debug:
              msg: "Cache enabled: {{ cache.enabled }}, TTL: {{ cache.ttl }}"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-nested-hash':
        playbook      => '/tmp/aruba/playbooks/nested-hash.yml',
        logoutput     => true,
        playbook_vars => {
          'database' => {
            'host' => 'localhost',
            'port' => 5432,
            'name' => 'myapp',
          },
          'cache' => {
            'enabled' => true,
            'ttl'     => 3600,
          },
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "DB: localhost:5432 (myapp)"
    And the output should contain "Cache enabled: True, TTL: 3600"

  Scenario: Pass array variables to playbook
    Given I create a playbook "array-vars.yml" with content:
      """
      ---
      - name: Array variables test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display servers list
            debug:
              msg: "Servers: {{ servers | join(', ') }}"
            changed_when: false

          - name: Display ports list
            debug:
              msg: "Ports: {{ ports | join(', ') }}"
            changed_when: false

          - name: Count servers
            debug:
              msg: "Total servers: {{ servers | length }}"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-arrays':
        playbook      => '/tmp/aruba/playbooks/array-vars.yml',
        logoutput     => true,
        playbook_vars => {
          'servers' => ['web1', 'web2', 'web3'],
          'ports'   => [80, 443, 8080],
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "Servers: web1, web2, web3"
    And the output should contain "Ports: 80, 443, 8080"
    And the output should contain "Total servers: 3"

  Scenario: Pass deeply nested structures
    Given I create a playbook "deep-nested.yml" with content:
      """
      ---
      - name: Deeply nested variables test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display app config
            debug:
              msg: "App: {{ app.name }} v{{ app.version }}"
            changed_when: false

          - name: Display primary DB
            debug:
              msg: "Primary DB: {{ app.databases.primary.host }}"
            changed_when: false

          - name: Display replica DB
            debug:
              msg: "Replica DB: {{ app.databases.replica.host }}"
            changed_when: false

          - name: Display feature flags
            debug:
              msg: "Features: {{ app.features | join(', ') }}"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-deep-nested':
        playbook      => '/tmp/aruba/playbooks/deep-nested.yml',
        logoutput     => true,
        playbook_vars => {
          'app' => {
            'name'    => 'myapp',
            'version' => '2.0',
            'databases' => {
              'primary' => {
                'host' => 'db-primary.example.com',
                'port' => 5432,
              },
              'replica' => {
                'host' => 'db-replica.example.com',
                'port' => 5432,
              },
            },
            'features' => ['auth', 'api', 'websocket'],
          },
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "App: myapp v2.0"
    And the output should contain "Primary DB: db-primary.example.com"
    And the output should contain "Replica DB: db-replica.example.com"
    And the output should contain "Features: auth, api, websocket"

  Scenario: Mix of simple and complex variables
    Given I create a playbook "mixed-vars.yml" with content:
      """
      ---
      - name: Mixed variables test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display simple vars
            debug:
              msg: "Environment: {{ env }}, Version: {{ version }}"
            changed_when: false

          - name: Display server list
            debug:
              msg: "Servers: {{ servers | join(', ') }}"
            changed_when: false

          - name: Display config
            debug:
              msg: "Config host: {{ config.host }}, port: {{ config.port }}"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-mixed':
        playbook      => '/tmp/aruba/playbooks/mixed-vars.yml',
        logoutput     => true,
        playbook_vars => {
          'env'     => 'production',
          'version' => '1.5.0',
          'servers' => ['app1', 'app2'],
          'config'  => {
            'host' => 'localhost',
            'port' => 8080,
          },
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "Environment: production, Version: 1.5.0"
    And the output should contain "Servers: app1, app2"
    And the output should contain "Config host: localhost, port: 8080"

  Scenario: Array of hashes
    Given I create a playbook "array-of-hashes.yml" with content:
      """
      ---
      - name: Array of hashes test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display each user
            debug:
              msg: "User: {{ item.name }} ({{ item.role }})"
            loop: "{{ users }}"
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-array-hashes':
        playbook      => '/tmp/aruba/playbooks/array-of-hashes.yml',
        logoutput     => true,
        playbook_vars => {
          'users' => [
            { 'name' => 'admin', 'role' => 'administrator' },
            { 'name' => 'deploy', 'role' => 'deployer' },
            { 'name' => 'readonly', 'role' => 'viewer' },
          ],
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "User: admin (administrator)"
    And the output should contain "User: deploy (deployer)"
    And the output should contain "User: readonly (viewer)"

  Scenario: Hash with mixed value types
    Given I create a playbook "mixed-types.yml" with content:
      """
      ---
      - name: Mixed types test
        hosts: localhost
        connection: local
        gather_facts: false
        tasks:
          - name: Display config details
            debug:
              msg: |
                Name: {{ service.name }}
                Port: {{ service.port }}
                Enabled: {{ service.enabled }}
                Tags: {{ service.tags | join(', ') }}
            changed_when: false
      """
    And a Puppet manifest with PAR resource:
      """
      par { 'test-mixed-types':
        playbook      => '/tmp/aruba/playbooks/mixed-types.yml',
        logoutput     => true,
        playbook_vars => {
          'service' => {
            'name'    => 'webserver',
            'port'    => 8080,
            'enabled' => true,
            'tags'    => ['production', 'frontend', 'critical'],
          },
        },
      }
      """
    When I apply the manifest
    Then the Puppet run should succeed
    And the output should contain "Name: webserver"
    And the output should contain "Port: 8080"
    And the output should contain "Enabled: True"
    And the output should contain "Tags: production, frontend, critical"
