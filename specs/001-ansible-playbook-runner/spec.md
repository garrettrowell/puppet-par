# Feature Specification: Ansible Playbook Runner Custom Type

**Feature Branch**: `001-ansible-playbook-runner`  
**Created**: 2025-10-22  
**Status**: Draft  
**Input**: User description: "Create a puppet module that provides a type and provider called par. The provider should allow users to specify which ansible playbook they would like ran against the localhost. It should also allow for arbitrary configuration options to be passed in by the user. The location of the playbook should also be configurable."

## Clarifications

### Session 2025-10-22

- Q: Should idempotency use unless/onlyif conditions or parse Ansible output? → A: Parse Ansible output - playbook always runs, provider reports changes/no-changes/failures based on Ansible's changed/ok/failed status in output
- Q: How should output logging be controlled? → A: Add logoutput parameter (boolean, default false) similar to Puppet exec resource - when true, displays full ansible-playbook stdout/stderr during execution
- Q: What output format should be used for parsing Ansible results? → A: Use Ansible JSON output format (via `-o` flag or stdout_callback=json) for structured parsing of changed/ok/failed status
- Q: How should partial failures be handled (some tasks succeed, some fail)? → A: Report failure if any task fails - entire playbook execution considered failed even if some tasks succeeded
- Q: How should concurrent playbook execution be handled? → A: Configurable per resource - add 'exclusive' parameter (default false) to optionally serialize specific resources
- Q: How should privilege escalation (sudo/become) be handled? → A: Delegate to Ansible's become mechanism - playbooks use become/become_user directives, PAR user parameter only controls ansible-playbook process user
- Q: What should the parameter be named for passing variables to playbooks? → A: Rename 'extra_vars' to 'playbook_vars' to clearly indicate that the user is passing configuration directly to the playbook

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Execute Basic Ansible Playbook (Priority: P1)

A system administrator wants to run an Ansible playbook on the local machine through Puppet to integrate Ansible automation into their Puppet-managed infrastructure. They need to specify which playbook to execute and where it's located.

**Why this priority**: This is the core functionality of the PAR module. Without the ability to execute a basic playbook, the module has no value. This represents the minimum viable product.

**Independent Test**: Can be fully tested by declaring a PAR resource with a playbook path, applying the Puppet catalog, and verifying the playbook executes successfully on localhost.

**Acceptance Scenarios**:

1. **Given** a valid Ansible playbook exists at `/etc/ansible/playbooks/webserver.yml`, **When** a user declares `par { 'setup-webserver': playbook => '/etc/ansible/playbooks/webserver.yml' }` and applies the catalog, **Then** Puppet executes the playbook against localhost and reports success
2. **Given** a PAR resource is declared with a playbook path, **When** Puppet runs in noop mode, **Then** Puppet reports what would be executed without actually running the playbook
3. **Given** a playbook path that doesn't exist, **When** the catalog is applied, **Then** Puppet reports a clear error indicating the playbook file was not found

---

###User Story 2 - Pass Custom Configuration Options (Priority: P2) ✅ COMPLETE

A system administrator needs to pass custom variables and configuration options to Ansible playbooks to control their behavior without modifying the playbook files themselves.

**Status**: ✅ Implemented in Phase 4 - All configuration options working

**Why this priority**: Configuration options enable reusability of playbooks across different environments and use cases. This is essential for practical usage but the module provides value without it (P1 can run playbooks with hardcoded values).

**Independent Test**: Can be tested by declaring a PAR resource with playbook_vars and verifying those variables are correctly passed to ansible-playbook command and used within the playbook execution.

**Acceptance Scenarios**: ✅ All passing (18 scenarios, 129 steps)

1. ✅ **Given** a playbook that accepts variables, **When** a user declares `par { 'deploy': playbook => '/path/to/deploy.yml', playbook_vars => { 'app_version' => '2.1.0', 'environment' => 'production' } }`, **Then** Ansible receives these variables and executes accordingly
2. ✅ **Given** multiple configuration options are specified (playbook_vars, tags, skip_tags), **When** the catalog is applied, **Then** all options are correctly passed to the ansible-playbook command
3. ✅ **Given** configuration options with special characters or spaces, **When** passed to the PAR resource, **Then** values are properly escaped and passed safely to Ansible

---

### User Story 3 - Idempotent Playbook Execution (Priority: P3)

A system administrator wants Puppet to correctly report when Ansible playbooks make changes versus when they report no changes, following Puppet's idempotent model based on Ansible's own change detection.

**Why this priority**: Idempotency reporting ensures Puppet accurately reflects system state changes. While the module is functional without it, proper change reporting follows Puppet best practices and enables accurate audit trails.

**Independent Test**: Can be tested by applying a catalog twice with the same PAR resource - first run should report changes (if playbook makes changes), second run should report no changes (if playbook is idempotent and system already in desired state).

**Acceptance Scenarios**:

1. **Given** a PAR resource with an idempotent playbook that needs to make changes, **When** the catalog is applied, **Then** Puppet reports the resource changed and shows Ansible made modifications
2. **Given** a PAR resource with an idempotent playbook where system is already in desired state, **When** the catalog is applied, **Then** Puppet reports the resource is in sync (no changes) based on Ansible's output
3. **Given** a playbook that encounters errors during execution, **When** Puppet runs, **Then** the resource reports failure with error details from Ansible output

---

### Edge Cases

- What happens when the Ansible executable is not installed or not in the system PATH?
- How does the provider handle playbooks that fail or return non-zero exit codes?
- What happens when a playbook takes longer than Puppet's timeout threshold?
- How are Ansible connection errors (localhost unreachable) handled and reported?
- What happens when the user running Puppet doesn't have permissions to execute the playbook or access required files?
- How does the provider handle playbooks that require user interaction (prompts)?
- What happens when multiple PAR resources try to run conflicting playbooks simultaneously? (Answer: By default allow concurrent execution; users can set exclusive=true to serialize specific resources)
- How are partial failures handled when some tasks in a playbook succeed while others fail? (Answer: Report failure if any task fails, entire execution considered failed)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Module MUST provide a custom type named `par` that can be declared in Puppet manifests
- **FR-002**: Type MUST accept a `playbook` parameter that specifies the absolute path to an Ansible playbook file
- **FR-003**: Type MUST validate that the specified playbook file exists before attempting execution
- **FR-004**: Provider MUST execute the specified Ansible playbook against localhost using the `ansible-playbook` command
- **FR-005**: ✅ Type MUST accept an optional `playbook_vars` parameter that accepts a hash of key-value pairs to pass as Ansible variables
- **FR-006**: ✅ Type MUST accept optional Ansible configuration parameters including: `tags`, `skip_tags`, `start_at_task`, `limit`, `verbose`, `check_mode`
- **FR-007**: ✅ Provider MUST properly escape and format all configuration options when constructing the ansible-playbook command
- **FR-008**: Provider MUST parse ansible-playbook JSON output (using `-o` flag or stdout_callback=json) to detect changes - report resource changed if Ansible reports "changed" status, report in-sync if "ok" status, report failed if "failed" status
- **FR-009**: Type MUST accept an optional `logoutput` parameter (boolean, default false) - when true, display full ansible-playbook stdout/stderr during execution similar to Puppet exec's logoutput
- **FR-010**: Provider MUST capture and log both stdout and stderr from ansible-playbook execution for parsing and optional display
- **FR-011**: Provider MUST report Puppet resource as failed if ansible-playbook returns non-zero exit code or output indicates task failures
- **FR-012**: ✅ Type MUST accept an optional `timeout` parameter to specify maximum execution time in seconds (default: 300)
- **FR-013**: ✅ Provider MUST terminate playbook execution if timeout is exceeded and report failure
- **FR-014**: ✅ Type MUST accept optional `user` parameter to specify which user should execute the ansible-playbook process (privilege escalation within playbooks handled by Ansible's become mechanism)
- **FR-015**: Provider MUST support Puppet noop mode by not executing playbooks when noop is enabled
- **FR-016**: Provider MUST verify ansible-playbook executable is available in PATH before attempting execution
- **FR-017**: ✅ Type MUST accept an optional `environment` parameter to set environment variables for playbook execution
- **FR-018**: Type title (namevar) MUST serve as a unique identifier for the resource and can be different from the playbook path
- **FR-019**: Provider MUST properly handle playbook paths with spaces and special characters
- **FR-020**: Module MUST support all operating systems declared in metadata.json (RHEL/CentOS/AlmaLinux/Rocky 7-9, Debian 10-12, Ubuntu 18.04-22.04, Windows Server 2019-2022/10-11)
- **FR-021**: Provider MUST always execute playbooks (no unless/onlyif skipping) and rely on Ansible's idempotency for change detection
- **FR-022**: Type MUST accept an optional `exclusive` parameter (boolean, default false) - when true, prevents concurrent execution of other PAR resources by using a lock mechanism

### Key Entities

- **PAR Resource**: Represents an Ansible playbook execution managed by Puppet. Key attributes include: resource title (namevar), playbook path, configuration options (playbook_vars, tags, etc.), timeout, user (for ansible-playbook process), environment variables, logoutput flag, and exclusive execution flag.
- **Ansible Playbook**: An external YAML file containing Ansible automation tasks. The PAR provider interacts with it through the ansible-playbook command-line interface. Privilege escalation handled internally via Ansible's become directives.
- **Execution Result**: The outcome of running an Ansible playbook, including exit code, JSON-formatted stdout, stderr, execution time, parsed change status (changed/ok/failed), and success/failure determination.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully execute an Ansible playbook through Puppet by declaring a single PAR resource with just a playbook path (minimal configuration)
- **SC-002**: Playbook execution completes within the specified timeout period (default 300 seconds) or fails gracefully with clear error message
- **SC-003**: Users can pass at least 10 different configuration variables to a playbook and verify they are correctly received and used
- **SC-004**: PAR resources correctly report changes when Ansible makes modifications and report in-sync when playbooks are idempotent and no changes needed, with 95% accuracy in change detection
- **SC-005**: Error messages clearly identify the failure reason (playbook not found, ansible not installed, execution failed, timeout exceeded) within 2 seconds of failure
- **SC-006**: Module passes all validation gates (`pdk validate` reports zero offenses, `pdk test unit -v` passes with 100% success rate)
- **SC-007**: Users can successfully execute playbooks on all supported operating systems without platform-specific configuration changes
- **SC-008**: Noop mode correctly reports what would be executed without making any changes, allowing users to safely preview actions
- **SC-009**: Users can enable logoutput to see full Ansible execution details during Puppet runs for debugging purposes
