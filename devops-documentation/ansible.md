Ansible Enterprise Guide
========================

A concise, enterprise-ready guide with explanations and practical examples (Docker, k3s, kubectl, Helm, Jenkins on a single host).

1) Introduction
---------------
- Agentless config/orchestration over SSH/WinRM.
- Idempotent: tasks declare desired state, not imperative steps.
- Core pieces: Inventory (which hosts), Modules (what to do), Plays/Playbooks (ordered tasks), Roles (reuse), Handlers (react on change), Variables.

2) Environment Setup
--------------------
- Install: macOS `brew install ansible`; Ubuntu `sudo apt-get install ansible`; pip `pip install ansible`.
- Verify install and Python path:
  - `ansible --version` → shows Ansible version and Python interpreter.
- Access: use SSH keys; ensure Python is on targets (default on most Linux). For Windows, configure WinRM.

3) YAML Basics
--------------
- Lists and dictionaries, space-indented:
  ```yaml
  packages:
    - nginx
    - curl
  user:
    name: app
    shell: /bin/bash
  ```
- No tabs; consistent spacing is required for valid YAML/playbooks.

4) Ad hoc Commands (quick wins)
-------------------------------
```
ansible -i inventories/prod/hosts.ini web -m ping
```
- Tests connectivity/auth; uses the `ping` module.
```
ansible -i inventories/prod/hosts.ini web -a "uptime"
```
- Runs a raw command (`uptime`) on group `web`.
```
ansible -i inventories/prod/hosts.ini web -b -m apt -a "name=nginx state=present update_cache=yes"
```
- Uses the `apt` module with sudo (`-b`) to ensure nginx is installed.
```
ansible web -m copy -a "src=./file dest=/tmp/file"
```
- Copies a local file to remote `/tmp/file`.
```
ansible web -m setup -a 'filter=ansible_os_family'
```
- Gathers facts; filtered to show OS family. Useful for conditionals.
- Speed: increase parallelism with `-f 20` if needed.

5) Project Structure (reference)
--------------------------------
```
ansible/
├─ inventories/
│  └─ prod/
│     ├─ hosts.ini
│     ├─ group_vars/
│     │  └─ all.yml
│     └─ host_vars/
├─ roles/
│  └─ web/
│     ├─ defaults/main.yml
│     ├─ vars/main.yml
│     ├─ tasks/main.yml
│     ├─ handlers/main.yml
│     ├─ templates/
│     └─ files/
├─ requirements.yml
└─ site.yml
```
- `inventories/<env>/hosts.ini`: hosts/groups per env; env-specific vars live in `group_vars`/`host_vars` under that env.
- `roles/`: reusable units (tasks, handlers, templates, files, defaults, vars).
- `requirements.yml`: pinned external roles/collections (install via `ansible-galaxy install -r requirements.yml`).
- `site.yml`: entry playbook that targets groups and pulls in roles/tasks.

6) Inventory
------------
Static example (`inventories/prod/hosts.ini`):
```
[jenkins_k3s]
host1 ansible_host=34.197.228.164 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devops-jenkins.pem
```
- `ansible_host`: actual IP/DNS. `ansible_user`: SSH user. `ansible_ssh_private_key_file`: key path.
- Dynamic inventory plugins (AWS EC2, etc.) discover hosts automatically; use for larger fleets.

7) Playbooks
------------
- Use modules with `state` for idempotence; `become` only when needed; handlers for restarts; vars from group/host vars; `serial` for rolling changes.
Example:
```yaml
- hosts: web
  become: true
  tasks:
    - name: Ensure nginx
      apt:
        name: nginx
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
- Explanation: First task installs nginx if missing. Second templates config; handler restarts nginx only on change.

8) Roles
--------
- Structure: `tasks/`, `handlers/`, `templates/`, `files/`, `defaults/`, `vars/`.
- Create scaffold: `ansible-galaxy init roles/web`
- Use in `site.yml`:
```yaml
- hosts: web
  become: true
  roles:
    - role: geerlingguy.nginx
      vars:
        nginx_listen_port: 80
```
- Explanation: Roles encapsulate reusable logic; vars override defaults. External deps installed via `ansible-galaxy install -r requirements.yml`.

9) Variables and Vault
----------------------
- Place shared vars in `group_vars`, host vars in `host_vars`; role defaults for safe defaults.
- Secrets: Ansible Vault or external secret stores; never in plain text.
```bash
ansible-vault create group_vars/all/vault.yml   # creates encrypted var file
ansible-playbook ... --ask-vault-pass           # prompt for vault password at runtime
```

10) Execution and Safety
------------------------
- Dry-run: `ansible-playbook ... --check --diff` to see changes without applying (where safe).
- Narrow scope: `-l <host/group>` limits targets; `--tags` runs only tagged tasks.
- Rolling: `serial: 1` or `20%` to reduce blast radius; use `max_fail_percentage` for risky ops.
- Idempotence: re-run playbooks; no changes should occur if nothing drifted.

11) Common Commands (with explanations)
---------------------------------------
- `ansible-inventory -i inventories/prod/hosts.ini --graph`
  - Shows inventory graph to verify groups/hosts.
- `ansible -i inventories/prod/hosts.ini jenkins_k3s -m ping`
  - Connectivity/auth test to the `jenkins_k3s` group.
- `ansible-playbook -i inventories/prod/hosts.ini site.yml --check --diff`
  - Dry-run with diffs to preview changes.
- `ansible-playbook -i inventories/prod/hosts.ini site.yml --tags "jenkins"`
  - Runs only tasks tagged `jenkins`.
- `ansible-playbook -i inventories/prod/hosts.ini site.yml -l host1`
  - Limits execution to `host1`.

12) Project Examples (stack: Docker, k3s, kubectl, Helm, Jenkins)
-----------------------------------------------------------------
### Install Docker
```yaml
- hosts: jenkins_k3s
  become: true
  tasks:
    - name: Install Docker
      apt:
        name: docker.io
        state: present
        update_cache: yes
    - name: Ensure docker is running
      service:
        name: docker
        state: started
        enabled: yes
```
- Installs Docker and ensures the service is started/enabled.

### Install k3s (single node)
```yaml
- hosts: jenkins_k3s
  become: true
  tasks:
    - name: Install k3s
      shell: |
        curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --node-name devops-jenkins" sh -
      args:
        creates: /usr/local/bin/k3s
    - name: Ensure k3s is running
      service:
        name: k3s
        state: started
        enabled: yes
```
- Downloads/installs k3s if not present; ensures the service is running/enabled.

### Install kubectl
```yaml
- hosts: jenkins_k3s
  become: true
  tasks:
    - name: Install kubectl
      shell: |
        KUBE_VERSION="v1.29.3"
        curl -LO "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl"
        install -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
      args:
        creates: /usr/local/bin/kubectl
```
- Fetches a specific kubectl version and installs it if missing.

### Install Helm
```yaml
- hosts: jenkins_k3s
  become: true
  tasks:
    - name: Install Helm
      shell: |
        HELM_VERSION="v3.14.4"
        curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
        tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz
        install -m 0755 linux-amd64/helm /usr/local/bin/helm
        rm -rf linux-amd64 helm-${HELM_VERSION}-linux-amd64.tar.gz
      args:
        creates: /usr/local/bin/helm
```
- Downloads and installs Helm if not already present.

### Install Jenkins (APT repo)
```yaml
- hosts: jenkins_k3s
  become: true
  tasks:
    - name: Add Jenkins apt key
      shell: |
        curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
      args:
        creates: /usr/share/keyrings/jenkins-keyring.asc

    - name: Add Jenkins apt repo
      copy:
        dest: /etc/apt/sources.list.d/jenkins.list
        content: "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/\n"
        mode: "0644"

    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install Jenkins
      apt:
        name: jenkins
        state: present
        update_cache: yes

    - name: Ensure Jenkins running
      service:
        name: jenkins
        state: started
        enabled: yes
```
- Adds Jenkins repo/key, installs Jenkins, ensures service is running.

### Wire Jenkins to k3s (kubeconfig)
```yaml
- hosts: jenkins_k3s
  become: true
  tasks:
    - name: Create Jenkins kube dir
      file:
        path: /var/lib/jenkins/.kube
        state: directory
        owner: jenkins
        group: jenkins
        mode: "0750"
    - name: Copy k3s kubeconfig
      copy:
        src: /etc/rancher/k3s/k3s.yaml
        dest: /var/lib/jenkins/.kube/config
        remote_src: yes
        owner: jenkins
        group: jenkins
        mode: "0640"
    - name: Set KUBECONFIG for Jenkins
      lineinfile:
        path: /etc/default/jenkins
        regexp: "^KUBECONFIG="
        line: "KUBECONFIG=/var/lib/jenkins/.kube/config"
        create: yes
    - name: Restart Jenkins
      service:
        name: jenkins
        state: restarted
```
- Gives Jenkins its own kubeconfig to talk to k3s; sets env and restarts Jenkins.

13) Idempotence Checklist
-------------------------
- Use module states; avoid raw shell unless needed, guard with `creates`/`removes`/`when`.
- Templates change only when content changes; handlers fire on change.
- Re-run playbooks to confirm no unintended changes.

14) CI/CD Integration
---------------------
- Lint: `ansible-lint`, `yamllint`.
- Validate inventory: `ansible-inventory --list`.
- Use `--check` where safe; keep Vault passwords in CI secrets.

15) Troubleshooting
-------------------
- Verbose: `-vvv`; facts: `ansible -m setup`; connection: `ansible <group> -m ping -vvv`.
- Become/sudo: ensure `become: true` and sudoers allow required commands.
