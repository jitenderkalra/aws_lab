# Git Enterprise Training Guide

Use this as the instructor’s deck outline and handout. It covers fundamentals, setup, daily commands (mapped to the Git cheat sheet), branching/PR flow, and enterprise controls. Convert to PDF/Word via pandoc if needed.

## 1) What is Git
- Distributed version control: every clone has full history.
- Snapshots (commits) with metadata (author, message, timestamp).
- Branches to isolate work; merges/rebases to integrate.

## 2) Install and Configure
- Install: macOS `brew install git`; Ubuntu `sudo apt-get install git`; Windows: Git for Windows.
- Identity:
  ```
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  git config --global init.defaultBranch main
  git config --global color.ui auto
  ```
- Auth (SSH recommended):
  ```
  ssh-keygen -t ed25519 -C "you@example.com"
  cat ~/.ssh/id_ed25519.pub  # add to GitHub/GitLab SSH keys
  ssh -T git@github.com      # test
  ```

## 3) Create or Clone a Repository
- New repo: `git init`
- Clone: `git clone git@github.com:org/repo.git`
- Check remotes: `git remote -v`

## 4) Working Tree, Staging, Committing
- Status: `git status`
- Stage: `git add file1 dir/`
- Commit: `git commit -m "feat: add API client"`
- Inspect:
  - `git log --oneline --graph`
  - `git diff` (unstaged), `git diff --cached` (staged)
- Typical flow:
  ```
  git status
  git add README.md
  git commit -m "docs: add overview"
  ```

## 5) Branching and Merging
- List: `git branch`
- Create/switch: `git switch -c feature/auth`
- Merge to main (from main): `git merge feature/auth`
- If conflicts: `git status`, edit files, `git add`, `git commit` (or `git merge --continue` if in merge flow).
- Rebase (team preference): `git fetch origin && git rebase origin/main`

## 6) Remotes, Pull, Push
- Fetch: `git fetch origin`
- Pull (merge): `git pull origin main`
- Pull (rebase): `git pull --rebase origin main`
- Push: `git push origin feature/auth` (first time: `-u origin feature/auth`)

## 7) Tags and Releases
- Create annotated tag: `git tag -a v1.0.0 -m "First release"`
- Push tag: `git push origin v1.0.0`
- List: `git tag --list`

## 8) Stash, Clean, Undo
- Stash: `git stash push -m "wip: refactor"`; restore: `git stash pop`
- Clean untracked (danger): `git clean -fd`
- Restore file: `git restore path`
- Unstage: `git restore --staged path`
- Revert a commit (safe on shared branches): `git revert <commit>`
- Reset (avoid on shared branches): `git reset --hard <commit>`

## 9) .gitignore (example snippet)
```
# node
node_modules/
dist/
*.log

# python
__pycache__/
*.pyc

# terraform
.terraform/
*.tfstate*

# secrets
*.pem
*.key
*.env
```

## 10) Collaboration Workflow (PR-based)
1) `git switch -c feature/x`
2) Code → `git status` → `git add` → `git commit`
3) Sync with main: `git fetch origin && git rebase origin/main` (or merge)
4) Push: `git push -u origin feature/x`
5) Open PR; ensure CI (lint/tests) passes; get review
6) Merge to main; delete branch

### Example: feature flow end-to-end
```
git switch -c feature/login-button
vim src/login.js
git status
git add src/login.js
git commit -m "feat: add login button handler"
git fetch origin
git rebase origin/main          # resolve conflicts if any, then continue
git push -u origin feature/login-button
# Open PR, review, merge in UI, then locally:
git switch main
git pull origin main
git branch -d feature/login-button
```

## 11) Enterprise Policies and Security
- Protect `main`: required reviews, status checks, no force-push.
- Mandatory 2FA; least-privilege access; use SSO/SSO-bound tokens where possible.
- Prefer SSH or short-lived tokens/OIDC for automation over long-lived PATs.
- No secrets in git: use secret scanners (gitleaks/trufflehog) and .gitignore.
- Pre-commit hooks: format, lint, test, secret scan before PR.
- Code owners for sensitive paths (infra, auth).
- Backup/mirror critical repos; test restore procedures.

## 12) Mapping to Git Cheat Sheet (key commands)
- Status/add/commit: `git status`, `git add`, `git commit -m`
- Branch: `git branch`, `git switch -c`, `git merge`
- Remote sync: `git fetch`, `git pull`, `git push`
- Inspect: `git log --oneline --graph`, `git diff`, `git show`
- Undo: `git restore`, `git revert`, `git reset --hard` (caution)
- Stash: `git stash push`, `git stash pop`
- Tags: `git tag -a vX.Y.Z`, `git push origin vX.Y.Z`

## 13) Troubleshooting
- Merge conflicts: use `git status` to list, resolve in files, `git add`, then continue merge.
- Detached HEAD: `git switch main` (or your branch) to get back to a branch.
- “Rejected” on push: fetch/rebase/merge main, resolve conflicts, then push.
- Large files: use Git LFS; avoid binary blobs in main repo when possible.

## 14) Practical Examples

### Basic init and first commit
```
mkdir demo && cd demo
git init
echo "# Demo" > README.md
git status
git add README.md
git commit -m "chore: initial commit"
```

### Create and merge a feature branch
```
git switch -c feature/api
echo "console.log('api');" > api.js
git add api.js
git commit -m "feat: add api stub"
git switch main
git merge feature/api
```

### Pull + rebase to sync with main
```
git fetch origin
git rebase origin/main   # on your feature branch
# if conflicts: fix files, git add <files>, git rebase --continue
```

### Resolve a merge conflict (quick demo)
1) On branch A, change `config.yml` line: `timeout: 5`
2) On branch B, change same line to `timeout: 10`
3) Merge B into A → conflict:
```
git status                # shows config.yml conflicted
git diff                  # see conflict markers
# edit config.yml to desired value, e.g., timeout: 8
git add config.yml
git commit                # completes merge
```

### Tag and push a release
```
git tag -a v1.2.0 -m "Release 1.2.0"
git push origin v1.2.0
```

### Stash and restore work-in-progress
```
git status
git stash push -m "wip: refactor utils"
# switch branches, do other work
git stash list
git stash pop             # reapplies and drops stash
```

### Revert a bad commit on main
```
git log --oneline         # find bad commit SHA abc1234
git revert abc1234        # creates new commit that undoes abc1234
git push origin main
```

### .gitignore in action
```
echo "node_modules/" >> .gitignore
echo "secret.env" >> .gitignore
git status   # ensures these files are not staged
```

### Inspect history and blame
```
git log --oneline --graph --decorate --all
git show HEAD~1
git blame src/app.js       # see who last changed each line
```
