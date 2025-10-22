# Data Model: Ansible Playbook Runner Custom Type

**Feature**: 001-ansible-playbook-runner  
**Date**: 2025-10-22  
**Purpose**: Define entities and their relationships for PAR custom type

## Overview

The PAR (Puppet Ansible Runner) module extends Puppet's resource model with a custom type. This document describes the entities involved in the implementation and their relationships.

## Core Entities

### 1. PAR Resource Type

**Description**: The declarative interface for managing Ansible playbook execution through Puppet catalogs.

**Location**: `lib/puppet/type/par.rb`

**Properties**:
- None (this is not a property-based resource; it's action-based like `exec`)

**Parameters**:

| Parameter | Type | Required | Default | Validation | Description |
|-----------|------|----------|---------|------------|-------------|
| `name` (namevar) | String | Yes | - | Non-empty string | Unique identifier for the resource |
| `playbook` | Absolute path | Yes | - | Must be absolute path | Path to Ansible playbook YAML file |
| `playbook_vars` | Hash | No | `{}` | Must be Hash | Variables to pass to Ansible as JSON |
| `tags` | Array[String] | No | `[]` | Array of strings | Ansible tags to execute |
| `skip_tags` | Array[String] | No | `[]` | Array of strings | Ansible tags to skip |
| `start_at_task` | String | No | `nil` | String | Task name to start execution from |
| `limit` | String | No | `nil` | String | Limit execution to specific hosts |
| `verbose` | Boolean | No | `false` | Boolean | Enable verbose Ansible output (-v) |
| `check_mode` | Boolean | No | `false` | Boolean | Run Ansible in check mode (--check) |
| `logoutput` | Boolean | No | `false` | Boolean | Display full ansible-playbook stdout/stderr during execution |
| `exclusive` | Boolean | No | `false` | Boolean | Serialize execution to prevent concurrent PAR resources |
| `timeout` | Integer | No | `300` | Positive integer | Maximum execution time in seconds |
| `user` | String | No | `nil` | Valid username | User to run playbook as |
| `environment` | Hash | No | `{}` | Must be Hash | Environment variables for execution |

**Validation Rules**:
- `playbook` must be an absolute path (checked via `Puppet::Util.absolute_path?`)
- `playbook_vars` must be a Hash if provided
- `tags` and `skip_tags` must be Arrays if provided
- `timeout` must be a positive integer
- `environment` must be a Hash if provided

**Autorequire**:
- Autorequires `File[playbook]` if such a resource exists in catalog
- This ensures playbook file is managed by Puppet before execution

---

### 2. PAR Provider

**Description**: The implementation that executes ansible-playbook commands based on PAR resource declarations.

**Location**: `lib/puppet/provider/par/par.rb`

**State**:
- Stateless (doesn't track persistent state between runs)
- Each catalog application re-evaluates conditions and executes if needed

**Methods**:

| Method | Purpose | Returns |
|--------|---------|---------|
| `exists?` | Check if playbook file exists | Boolean |
| `create` | Execute the ansible-playbook command | Void |
| `destroy` | Not applicable (no destroy action for playbook execution) | N/A |
| `build_command` | Construct ansible-playbook CLI command | String |
| `parse_json_output` | Parse Ansible JSON output to detect changed/ok/failed status | Hash |
| `validate_ansible` | Verify ansible-playbook is in PATH | Boolean |
| `acquire_lock` | Acquire execution lock if exclusive=true | Boolean |
| `release_lock` | Release execution lock if exclusive=true | Void |

**Command Structure**:
```
ansible-playbook -i localhost, --connection=local <playbook_path> [options]
```

**Options Added Based on Parameters**:
- `-e '<json_vars>'` if `playbook_vars` is present
- `-o` or set `stdout_callback=json` to enable JSON output format for parsing
- `-t <tags>` if `tags` is present
- `--skip-tags <tags>` if `skip_tags` is present
- `--start-at-task <task>` if `start_at_task` is present
- `--limit <limit>` if `limit` is present
- `-v` if `verbose` is true
- `--check` if `check_mode` is true

---

### 3. Execution Context

**Description**: The runtime environment and state during playbook execution.

**Attributes**:

| Attribute | Type | Source | Description |
|-----------|------|--------|-------------|
| `command` | String | Built by provider | Full ansible-playbook command to execute |
| `working_directory` | String | Current dir | Directory where ansible-playbook runs |
| `execution_user` | String | `user` param or current | User executing the command |
| `env_vars` | Hash | `environment` param | Environment variables set for execution |
| `timeout_value` | Integer | `timeout` param | Timeout in seconds |
| `noop_mode` | Boolean | Puppet catalog | Whether in noop mode |
| `exclusive_lock` | Boolean | `exclusive` param | Whether execution requires locking |

**Execution Flow**:
1. Provider checks `exists?` → evaluates file existence
2. If exclusive=true, acquire lock before execution
3. Puppet calls `create` to execute playbook
4. `create` builds command, validates ansible, executes playbook with JSON output enabled
5. Provider captures JSON stdout and parses for change status
6. Parse output to determine changed/ok/failed status
7. If logoutput=true, display full output to user
8. Non-zero exit or "failed" status raises `Puppet::Error`
9. Success with "changed" status reports resource changed to Puppet
10. Success with "ok" status reports resource in-sync to Puppet
11. If exclusive=true, release lock after execution

---

### 4. Execution Result

**Description**: The outcome and artifacts from ansible-playbook execution.

**Attributes**:

| Attribute | Type | Description |
|-----------|------|-------------|
| `exit_code` | Integer | ansible-playbook exit status (0=success) |
| `stdout` | String | JSON-formatted standard output from playbook execution |
| `stderr` | String | Standard error from playbook execution |
| `execution_time` | Float | Duration of execution in seconds |
| `success` | Boolean | Whether execution succeeded (exit_code == 0) |
| `changed_count` | Integer | Number of tasks that reported "changed" status (parsed from JSON) |
| `ok_count` | Integer | Number of tasks that reported "ok" status (parsed from JSON) |
| `failed_count` | Integer | Number of tasks that reported "failed" status (parsed from JSON) |
| `change_status` | String | Overall status: "changed", "ok", or "failed" (parsed from JSON) |

**Exit Code Meanings** (Ansible standard):
- `0`: Success, all tasks completed
- `1`: Error occurred during execution
- `2`: Host unreachable or failure
- `4`: Bad or incomplete options
- `99+`: Custom error codes from playbooks

**Change Status Determination**:
- `failed`: Any task failed (failed_count > 0) → Puppet resource fails
- `changed`: No failures and at least one change (changed_count > 0) → Puppet reports resource changed
- `ok`: No failures and no changes (changed_count == 0) → Puppet reports resource in-sync

**Logging Strategy**:
- Info level: Command being executed (in noop and real runs)
- Debug level: Parsed change status from JSON output
- Info level (if logoutput=true): Full stdout/stderr from execution
- Error level: stderr and exit code on failure
- Notice level: Noop mode messages

---

## Entity Relationships

```
┌─────────────────┐
│  Puppet Catalog │
│                 │
└────────┬────────┘
         │ contains
         ▼
┌─────────────────┐
│   PAR Resource  │◄────── declares ──────┐
│   (Type)        │                       │
└────────┬────────┘                       │
         │                          ┌─────────────┐
         │ implemented by           │ Puppet User │
         │                          └─────────────┘
         ▼
┌─────────────────┐
│  PAR Provider   │
│                 │
└────────┬────────┘
         │ creates
         ▼
┌─────────────────────┐
│ Execution Context   │
│                     │
└────────┬────────────┘
         │ executes
         ▼
┌─────────────────────────┐
│  ansible-playbook CLI   │
│  (external command)     │
└────────┬────────────────┘
         │ reads
         ▼
┌─────────────────────┐         ┌──────────────────┐
│ Ansible Playbook    │────────▶│ Execution Result │
│ (YAML file)         │  produces│                  │
└─────────────────────┘         └──────────────────┘
```

---

## State Transitions

### PAR Resource Lifecycle

```
[Catalog Compilation]
        │
        ▼
[Type Validation] ──────── validation fails ─────▶ [Compilation Error]
        │ validation passes
        ▼
[Provider exists? check]
        │
        ├─── file missing ─────▶ [Execute create → Error: file not found]
        │
        ├─── noop mode ─────────▶ [Log command → in sync]
        │
        ▼
[Acquire lock if exclusive=true]
        │
        ├─── lock acquisition fails ──▶ [Error: could not acquire lock]
        │
        ▼
[Execute create (ansible-playbook with JSON output)]
        │
        ├─── timeout ───────────▶ [Error: timeout exceeded]
        │
        ├─── exit code != 0 ────▶ [Error: playbook failed]
        │
        ▼
[Parse JSON output for change status]
        │
        ├─── failed_count > 0 ──▶ [Error: task failures detected]
        │
        ├─── changed_count > 0 ─▶ [Success → Resource changed]
        │
        ├─── changed_count == 0 ▶ [Success → Resource in sync]
        │
        ▼
[Release lock if exclusive=true]
        │
        ▼
[Complete]
```

---

## Testing Entities

### RSpec Test Doubles

**Mock Resources**:
```ruby
let(:resource) do
  Puppet::Type.type(:par).new(
    name: 'test-playbook',
    playbook: '/tmp/test.yml',
    extra_vars: { 'foo' => 'bar' }
  )
end
```

**Stubbed Commands**:
```ruby
allow(Puppet::Util::Execution).to receive(:execute)
  .with(/ansible-playbook/, anything)
  .and_return(double(exitstatus: 0, stdout: 'Success'))
```

### Cucumber Test Data

**Test Playbooks**:
- `spec/fixtures/playbooks/simple.yml`: Basic playbook that always succeeds
- `spec/fixtures/playbooks/with_vars.yml`: Playbook that requires extra_vars
- `spec/fixtures/playbooks/failing.yml`: Playbook that returns exit 1
- `spec/fixtures/playbooks/slow.yml`: Playbook that takes >5 seconds (for timeout tests)

**Test Manifests**:
- `examples/basic.pp`: Simple PAR resource declaration
- `examples/with_vars.pp`: PAR with extra_vars
- `examples/idempotent.pp`: PAR with unless/onlyif conditions

---

## Implementation Notes

### Type Implementation Pattern
```ruby
Puppet::Type.newtype(:par) do
  @doc = "Manages Ansible playbook execution"
  
  ensurable do
    defaultvalues
    defaultto :present
  end
  
  newparam(:name, :namevar => true) do
    desc "Resource identifier"
  end
  
  newparam(:playbook) do
    desc "Absolute path to playbook"
    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        raise ArgumentError, "Playbook must be absolute path"
      end
    end
  end
end
```

### Provider Implementation Pattern
```ruby
Puppet::Type.type(:par).provide(:par) do
  desc "PAR provider using ansible-playbook CLI"
  
  commands :ansible_playbook => 'ansible-playbook'
  
  def exists?
    File.exist?(resource[:playbook])
  end
  
  def create
    return if resource.noop?
    
    acquire_lock if resource[:exclusive]
    begin
      execute_playbook
    ensure
      release_lock if resource[:exclusive]
    end
  end
  
  private
  
  def build_command
    cmd = ['ansible-playbook', '-i', 'localhost,', '--connection=local']
    cmd << '-o'  # Enable JSON output
    cmd << resource[:playbook]
    cmd += ['-e', JSON.generate(resource[:playbook_vars])] unless resource[:playbook_vars].empty?
    cmd
  end
  
  def execute_playbook
    result = Puppet::Util::Execution.execute(
      build_command,
      :failonfail => false,
      :combine => true
    )
    
    parsed = parse_json_output(result)
    
    if resource[:logoutput]
      Puppet.info(result)
    end
    
    if parsed['failed_count'] > 0
      raise Puppet::Error, "Ansible playbook execution failed"
    elsif parsed['changed_count'] > 0
      Puppet.info("Playbook made #{parsed['changed_count']} changes")
    else
      Puppet.debug("Playbook execution completed with no changes")
    end
  end
  
  def parse_json_output(output)
    json = JSON.parse(output)
    stats = json['stats']['localhost']
    {
      'changed_count' => stats['changed'] || 0,
      'ok_count' => stats['ok'] || 0,
      'failed_count' => stats['failures'] || 0
    }
  end
end
```

---

## Summary

The PAR module extends Puppet with a single custom type/provider pair that wraps ansible-playbook execution. The data model is intentionally simple:
- One type defining the interface
- One provider implementing execution
- Stateless execution model (no persistent state tracking)
- Standard Puppet patterns throughout (namevar, parameters, validation, autorequire)

This design aligns with Puppet's philosophy of declarative resource management while providing flexibility through Ansible's powerful automation capabilities.
