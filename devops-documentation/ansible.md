Ansible Enterprise Guide
========================

A concise, enterprise-ready guide to Ansible with examples drawn from this stack (Docker, k3s, kubectl, Helm, Jenkins on a single host).

1) Introduction
---------------
- Agentless config/orchestration over SSH/WinRM.
- Idempotent: tasks declare desired state.
- Core pieces: Inventory, Modules, Tasks/Plays/Playbooks, Roles, Handlers, Variables.

2) Environment Setup
--------------------
- Install: macOS `brew install ansible`; Ubuntu `sudo apt-get install ansible`; pip `pip install ansible`.
- Verify: `ansible --version`
- Use SSH keys; Python required on managed hosts. For Windows, use WinRM modules.

3) YAML Basics
--------------
- Lists:
  ```yaml
  packages:
    - nginx
    - curl
  ```
- Dicts:
  ```yaml
  user:
    name: app
    shell: /bin/bash
  ```
- Use spaces, not tabs.

4) Ad hoc Commands (quick wins)
-------------------------------
```
ansible -i inventories/prod/hosts.ini web -m ping
ansible -i inventories/prod/hosts.ini web -a "uptime"
ansible -i inventories/prod/hosts.ini web -b -m apt -a "name=nginx state=present update_cache=yes"
ansible web -m copy -a "src=./file dest=/tmp/file"
ansible web -m setup -a 'filter=ansible_os_family'
```
- Increase forks if needed: `-f 20`.

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
- `inventories/<env>/hosts.ini`: env hosts/groups; env vars in `group_vars`/`host_vars`.
- `roles/`: reusable logic (tasks, handlers, templates, files, defaults, vars).
- `requirements.yml`: external roles/collections (pinned versions).
- `site.yml`: entry playbook.

6) Inventory
------------
Static example (`inventories/prod/hosts.ini`):
```
[jenkins_k3s]
host1 ansible_host=34.197.228.164 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devops-jenkins.pem
```
Use dynamic inventory plugins (e.g., AWS EC2) for larger fleets.

7) Playbooks
------------
- Idempotent tasks (`state: present/absent`, `creates`/`removes`), `become` only when needed.
- Handlers for restarts; vars from group/host vars; `serial` for rolling updates.
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
- Install external deps: `ansible-galaxy install -r requirements.yml`

9) Variables and Vault
----------------------
- Shared vars in `group_vars`, host vars in `host_vars`; role defaults for sensible defaults.
- Secrets: Ansible Vault or external secret stores; never plain text in git.
```bash
ansible-vault create group_vars/all/vault.yml
# run with: ansible-playbook ... --ask-vault-pass
```

10) Execution and Safety
------------------------
- Dry-run: `--check --diff` (where safe).
- Narrow scope: `-l <host/group>` and `--tags`.
- Rolling changes: `serial: 1` or `20%`; use `max_fail_percentage` for risky ops.
- Idempotence: rerun playbooks; tasks should change only when inputs change.

11) Common Commands
-------------------
```
ansible-inventory -i inventories/prod/hosts.ini --graph
ansible -i inventories/prod/hosts.ini jenkins_k3s -m ping
ansible-playbook -i inventories/prod/hosts.ini site.yml --check --diff
ansible-playbook -i inventories/prod/hosts.ini site.yml --tags "jenkins"
ansible-playbook -i inventories/prod/hosts.ini site.yml -l host1
```

12) Project Examples (from this stack)
--------------------------------------
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
