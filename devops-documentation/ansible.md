Ansible Enterprise Guide
========================

This document is a training and reference guide for Ansible: what it is, how to set it up, how to structure projects, and how to write and run playbooks and roles with safe, repeatable practices.

1. Introduction
---------------
- Ansible is an agentless configuration management and orchestration tool that connects over SSH/WinRM.
- It is **idempotent**: tasks describe desired state (e.g., “package is present”) rather than imperative steps.
- Core building blocks:
  - **Inventory**: lists hosts and groups.
  - **Modules**: units of work (`apt`, `yum`, `service`, `copy`, `template`, `user`, etc.).
  - **Tasks/Plays/Playbooks**: ordered tasks applied to target hosts.
  - **Roles**: reusable packaging of tasks, handlers, templates, files, and vars.

2. Environment Setup
--------------------
- Install on control node:
  - macOS: `brew install ansible`
  - Ubuntu/Debian: `sudo apt-get install ansible`
  - Python/pip: `pip install ansible`
- Verify: `ansible --version`
- Use SSH keys; ensure Python exists on managed hosts (default on most Linux). For Windows, use WinRM modules.

3. YAML Basics (for Playbooks)
------------------------------
- Lists:
  ```yaml
  packages:
    - nginx
    - curl
  ```
- Dictionaries:
  ```yaml
  user:
    name: app
    shell: /bin/bash
  ```
- Indent with spaces only; no tabs.

4. Ad hoc Commands (quick tasks)
--------------------------------
```
ansible -i inventories/prod/hosts.ini web -m ping
ansible -i inventories/prod/hosts.ini web -a "uptime"
ansible -i inventories/prod/hosts.ini web -b -m apt -a "name=nginx state=present update_cache=yes"
```
- Parallelism: default forks=5; increase with `-f 20`.
- File transfer: `ansible web -m copy -a "src=./file dest=/tmp/file"`.
- Facts: `ansible web -m setup` (filter with `-a 'filter=ansible_os_family'`).

5. Directory Structure (typical)
--------------------------------
```
ansible/
├─ inventories/
│  ├─ prod/
│  │  ├─ hosts.ini
│  │  ├─ group_vars/
│  │  │  ├─ all.yml
│  │  │  └─ web.yml
│  │  └─ host_vars/
│  │     └─ web1.yml
│  └─ staging/...
├─ roles/
│  └─ web/
│     ├─ defaults/main.yml
│     ├─ vars/main.yml
│     ├─ tasks/main.yml
│     ├─ handlers/main.yml
│     ├─ templates/nginx.conf.j2
│     └─ files/...
├─ group_vars/          # optional shared vars (global scope)
├─ host_vars/           # optional per-host vars (global scope)
├─ requirements.yml     # external roles/collections to install
└─ site.yml             # entry playbook
```
**What each part does**
- `inventories/<env>/hosts.ini`: environment-specific hosts/groups. Keep env-specific vars under `inventories/<env>/group_vars` and `host_vars` to avoid leaking across environments.
- `group_vars` / `host_vars`: shared or host-specific variables (YAML). Can exist globally or within each inventory.
- `roles/`: reusable units. Each role has:
  - `tasks/` (main entry, can include other task files),
  - `handlers/` (restarts, notifications),
  - `templates/` (Jinja2 templates),
  - `files/` (static files),
  - `defaults/` (low-priority vars),
  - `vars/` (higher-priority vars).
- `requirements.yml`: pinned external roles/collections installed via `ansible-galaxy install -r requirements.yml`.
- `site.yml`: top-level playbook that targets groups and includes roles/tasks.

6. Inventory
------------
- Separate per environment (`inventories/prod/hosts.ini`, `inventories/staging/hosts.ini`).
- Use SSH keys; set `ansible_user`, `ansible_host`, `ansible_ssh_private_key_file`.
- For cloud fleets, prefer dynamic inventory plugins (AWS/GCP/Azure) over static IPs.

Example static inventory (`inventories/prod/hosts.ini`):
```
[web]
web1 ansible_host=10.0.1.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[db]
db1 ansible_host=10.0.2.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

7. Playbooks
------------
- Structure: a play targets hosts and runs tasks in order.
- Best practices: idempotent tasks (`state: present/absent`, `creates`/`removes`), `become` only when needed, use handlers for restarts, vars from group/host vars, `serial` for rolling updates.

Example playbook (`site.yml`):
```yaml
- hosts: web
  become: true
  vars:
    app_user: app
  tasks:
    - name: Ensure base packages
      apt:
        name: [nginx, curl]
        state: present
        update_cache: yes
    - name: Deploy config
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify: restart nginx
  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted
```
Common modules/tags: `apt`/`yum`, `template`, `copy`, `service`, `user`, `unarchive`, `lineinfile`, `blockinfile`, `when` (conditionals), `loop`.

8. Roles
--------
- Purpose: reuse and encapsulate tasks/handlers/templates/files/vars.
- Structure recap:
  ```
  roles/myrole/
    defaults/main.yml   # lowest-precedence vars
    vars/main.yml       # higher-precedence vars
    tasks/main.yml      # includes other task files
    handlers/main.yml
    templates/...
    files/...
  ```
- Create scaffold: `ansible-galaxy init roles/web`
- Use in playbook:
```yaml
- hosts: web
  become: true
  roles:
    - role: geerlingguy.nginx
      vars:
        nginx_listen_port: 80
```

9. Variables and Vault
----------------------
- Prefer `group_vars/all.yml` for shared, `group_vars/<group>.yml` per group, `host_vars/<host>.yml` per host.
- Secrets: Ansible Vault or external secret stores (SSM/HashiCorp Vault) via lookups; never plain text in git.
- Vault example:
  ```
  ansible-vault create group_vars/all/vault.yml
  ```
  In play:
  ```yaml
  vars_files:
    - group_vars/all/vault.yml
  ```
  Run: `ansible-playbook ... --ask-vault-pass`

10. Execution and Safety
------------------------
- Dry-run: `ansible-playbook ... --check --diff`
- Limit scope: `-l hostgroup` and `--tags` for targeted changes.
- Rolling updates: `serial: 1` or `serial: 20%`; set `max_fail_percentage` for risky ops.
- Idempotence: rerun playbooks; ensure tasks only change when content changes.

11. Common Commands
-------------------
```
ansible-inventory -i inventories/prod/hosts.ini --graph
ansible -i inventories/prod/hosts.ini web -m ping
ansible-playbook -i inventories/prod/hosts.ini site.yml --check --diff
ansible-playbook -i inventories/prod/hosts.ini site.yml --tags "nginx"
ansible-playbook -i inventories/prod/hosts.ini site.yml -l web1
```

12. Examples
------------

### Install and configure a service
```yaml
- hosts: web
  become: true
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
        update_cache: yes
    - name: Place nginx config
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify: restart nginx
  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted
```

### Rolling update with serial
```yaml
- hosts: web
  become: true
  serial: 1
  tasks:
    - name: Deploy app package
      unarchive:
        src: /tmp/app.tar.gz
        dest: /opt/app
        remote_src: yes
      notify: restart app
  handlers:
    - name: restart app
      service:
        name: app
        state: restarted
```

### Conditional tasks
```yaml
- hosts: web
  become: true
  tasks:
    - name: Install firewalld on RHEL
      yum:
        name: firewalld
        state: present
      when: ansible_os_family == "RedHat"
```

13. Idempotence Checklist
-------------------------
- Use module states (`present/absent/latest`); avoid raw shell/command when a module exists.
- Guard shell/command with `creates`/`removes`/`when`.
- Templates only change when content changes; handlers fire only on change.

14. CI/CD Integration
---------------------
- Lint: `ansible-lint`, `yamllint`.
- Validate inventory: `ansible-inventory --list`.
- Use `--check` where safe; keep Vault passwords in CI secret store.

15. Troubleshooting
-------------------
- Verbose: `-vvv` to see SSH commands/facts.
- Facts: `ansible -m setup` (or disable with `gather_facts: false` if not needed).
- Connection: `ansible <group> -m ping -vvv`.
- Become/sudo: ensure `become: true` and sudoers allow required commands.

## Directory structure (typical)
```
ansible/
├─ inventories/
│  ├─ prod/
│  │  ├─ hosts.ini
│  │  ├─ group_vars/
│  │  │  ├─ all.yml
│  │  │  └─ web.yml
│  │  └─ host_vars/
│  │     └─ web1.yml
│  └─ staging/...
├─ roles/
│  └─ web/
│     ├─ defaults/main.yml
│     ├─ vars/main.yml
│     ├─ tasks/main.yml
│     ├─ handlers/main.yml
│     ├─ templates/nginx.conf.j2
│     └─ files/...
├─ group_vars/          # optional shared vars
├─ host_vars/           # optional per-host vars
├─ requirements.yml     # roles/collections
└─ site.yml             # entry playbook
```
**What each part is for:**
- `inventories/<env>/hosts.ini`: hosts grouped by role/env; env-specific vars live under `inventories/<env>/group_vars` and `host_vars`.
- `group_vars` / `host_vars`: shared or host-specific variables (YAML). Use env-scoped folders under `inventories/` to avoid cross-env leakage.
- `roles/`: reusable units. Each role has `tasks/` (main entry), `handlers/` (restarts), `templates/` (Jinja2), `files/`, `defaults/` (low-priority vars), `vars/` (higher-priority vars).
- `requirements.yml`: pinned external roles/collections to install via `ansible-galaxy install -r requirements.yml`.
- `site.yml`: entry playbook that includes roles/plays for target groups.

## Inventory
- Separate per environment (`inventories/prod/hosts.ini`, `inventories/staging/hosts.ini`).
- Use SSH keys; set `ansible_user`, `ansible_host`, `ansible_ssh_private_key_file`.
- For cloud fleets, prefer dynamic inventory plugins (AWS/GCP/Azure) over static IPs.

Example static inventory (`inventories/prod/hosts.ini`):
```
[web]
web1 ansible_host=10.0.1.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[db]
db1 ansible_host=10.0.2.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

## Playbook practices
- Idempotent tasks: use `state: present/absent`, `creates`, `removes`, `when`.
- Minimal privilege escalation: `become: true` only where needed.
- Vars from `group_vars`/`host_vars`; secrets in Vault or secret managers, not in git.
- Handlers for restarts; notify only on change.
- Rolling changes: use `serial` to limit parallelism; set `max_fail_percentage` in risky ops.

Example playbook (`site.yml`):
```yaml
- hosts: web
  become: true
  vars:
    app_user: app
  tasks:
    - name: Ensure base packages
      apt:
        name: [nginx, curl]
        state: present
        update_cache: yes

    - name: Deploy config
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify: restart nginx

  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted
```

## Roles (reuse)
- Structure: `defaults/` (low-priority vars), `vars/` (high-priority), `tasks/`, `handlers/`, `templates/`, `files/`.
- Main task file includes sub-tasks for clarity (`tasks/main.yml` -> include `install.yml`, `configure.yml`).
- Pin versions of external roles/collections in `requirements.yml`; install with `ansible-galaxy install -r requirements.yml`.

Example `requirements.yml`:
```yaml
---
collections:
  - name: community.general
roles:
  - src: geerlingguy.nginx
    version: 0.22.3
```

## Variables and precedence
- Prefer `group_vars/all.yml` for shared settings, `group_vars/<group>.yml` for group-specific, `host_vars/<host>.yml` for host-specific.
- Avoid `vars:` in playbooks unless needed; prefer defaults in roles.
- Secret handling: Ansible Vault or external secret stores (AWS SSM, HashiCorp Vault) via lookups; never plain text in git.

## Execution and safety
- Dry-run configs with `--check --diff` where safe.
- Limit scope: `-l hostgroup` and `--tags` for targeted changes.
- Rolling updates: `serial: 1` or `serial: 20%` to reduce blast radius.
- Idempotence checks: rerun playbooks to ensure no unintended changes.

## Common commands
```
ansible-inventory -i inventories/prod/hosts.ini --graph
ansible -i inventories/prod/hosts.ini web -m ping
ansible-playbook -i inventories/prod/hosts.ini site.yml --check --diff
ansible-playbook -i inventories/prod/hosts.ini site.yml --tags "nginx"
ansible-playbook -i inventories/prod/hosts.ini site.yml -l web1
```

## Examples

### 1) Install a package and configure a service
```yaml
- hosts: web
  become: true
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
        update_cache: yes

    - name: Place nginx config
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify: restart nginx

  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted
```

### 2) Using roles in site.yml
```yaml
- hosts: web
  become: true
  roles:
    - role: geerlingguy.nginx
      vars:
        nginx_listen_port: 80
        nginx_vhosts:
          - listen: "80"
            server_name: "example.com"
            root: "/var/www/html"
```

### 3) Rolling update with serial
```yaml
- hosts: web
  become: true
  serial: 1
  tasks:
    - name: Deploy app package
      unarchive:
        src: /tmp/app.tar.gz
        dest: /opt/app
        remote_src: yes
      notify: restart app
  handlers:
    - name: restart app
      service:
        name: app
        state: restarted
```

### 4) Vault-encrypted secret
Create a vault file:
```
ansible-vault create group_vars/all/vault.yml
```
Use it:
```yaml
- hosts: web
  become: true
  vars_files:
    - group_vars/all/vault.yml
  tasks:
    - name: Write secret config
      copy:
        content: "{{ vault_app_secret }}"
        dest: /etc/app/secret.conf
        mode: "0600"
```
Run with vault password:
```
ansible-playbook -i inventories/prod/hosts.ini site.yml --ask-vault-pass
```

### 5) Conditional tasks and when
```yaml
- hosts: web
  become: true
  tasks:
    - name: Install firewalld on RHEL
      yum:
        name: firewalld
        state: present
      when: ansible_os_family == "RedHat"
```

## Idempotence checklist
- Use `state: present/absent/latest`; avoid shell/command unless necessary; if used, guard with `creates`/`removes`/`when`.
- Templates should not change unless content changed (use Jinja2 vars and defaults).
- Handlers fire only on change; avoid `service: state=restarted` without a notify.

## CI/CD integration
- Run `ansible-lint` and `yamllint` on PRs.
- Use `--check` where applicable; validate inventories (`ansible-inventory --list`).
- Store Vault password in CI secret store, never in git.

## Troubleshooting tips
- Increase verbosity: `-vvv` to see SSH commands and facts.
- Fact gathering issues: set `gather_facts: false` if not needed, or run `ansible -m setup` to inspect.
- Connection issues: test with `ansible <group> -m ping -vvv`.
- Check become/sudo: ensure `become: true` and sudoers allow commands without prompts where required.
