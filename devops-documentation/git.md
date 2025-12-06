# Git: concepts, setup, and core commands

Use this as training material. Covers setup, daily commands (aligned with the Git cheat sheet), and enterprise practices.

## What is Git
- Distributed version control system: every clone is a full copy of history.
- Tracks snapshots (commits) of files; supports branching/merging to enable parallel work.

## Setup
Install:
- macOS: `brew install git`
- Ubuntu/Debian: `sudo apt-get install git`
- Windows: install Git for Windows (includes Git Bash)

Identify yourself (required for commits):
```
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Color, editor, and safety:
```
git config --global color.ui auto
git config --global pull.rebase false    # use merges on pull by default
git config --global init.defaultBranch main
```

SSH with GitHub/GitLab (recommended):
```
ssh-keygen -t ed25519 -C "you@example.com"
cat ~/.ssh/id_ed25519.pub   # add this to GitHub/GitLab SSH keys
ssh -T git@github.com       # test
```

## Creating or cloning a repo
```
git init                     # create new repo in current folder
git clone git@github.com:org/repo.git   # SSH clone
git clone https://github.com/org/repo.git  # HTTPS clone
```

## Working tree basics
```
git status                   # what changed
git add file1 dir/           # stage changes
git commit -m "feat: add login form"  # save snapshot
git log --oneline --graph    # view history
git diff                     # unstaged changes
git diff --cached            # staged changes
```

Practical flow (cheat-sheet aligned):
```
git status
git add README.md
git commit -m "docs: add overview"
```

## Branching and merging
```
git branch                   # list branches
git switch -c feature/api    # create & switch
git switch main              # go back to main
git merge feature/api        # merge into current branch
```
Notes:
- Keep feature branches short-lived; prefer merging via reviewed PRs.
- Resolve conflicts with `git status` + `git diff` + editor, then `git add` and `git commit` (or `git merge --continue` if using `--no-ff` merges).

## Remotes, fetch, pull, push
```
git remote -v                       # show remotes
git fetch origin                    # download refs
git pull origin main                # fetch + merge
git push origin main                # publish
git push --set-upstream origin feature/api
```
Tip: if you want rebase on pull: `git config --global pull.rebase true` (team preference).

## Tags and releases
```
git tag -a v1.0.0 -m "First release"
git push origin v1.0.0
git tag --list
```
Use annotated tags for releases; keep a CHANGELOG.

## Stash and clean
```
git stash push -m "wip: refactor"   # save dirty tree
git stash list
git stash pop                       # reapply and drop
git clean -fd                       # remove untracked files (dangerous; use with care)
```

## Inspecting history
```
git log --oneline --graph --decorate --all
git show <commit>
git blame path/to/file
```

## Undo/repair
```
git restore path/to/file           # discard unstaged changes
git restore --staged path/to/file  # unstage
git revert <commit>                # make a new commit that undoes a bad commit
git reset --hard <commit>          # move branch pointer & working tree (dangerous; avoid on shared branches)
```
Prefer `revert` on shared branches; avoid rewriting published history unless the team agrees and force-push is allowed.

## .gitignore (example)
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
*.tfstate
*.tfstate.*

# secrets (never commit)
*.pem
*.key
*.env
```
Always verify with `git status` that secrets are not staged; use secret scanners (trufflehog/gitleaks).

## Common collaboration model
1) Create a branch: `git switch -c feature/x`
2) Work: `git status`, `git add`, `git commit`
3) Sync: `git fetch`, `git rebase origin/main` (or merge) to update
4) Push: `git push -u origin feature/x`
5) Open PR; get review; CI must pass
6) Merge to `main`; delete branch

## Enterprise practices
- Protect `main`: required reviews, status checks, no force-push (except admins when needed).
- Enforce small PRs; one logical change per commit. Use conventional commits if your org prefers (`feat:`, `fix:`, `docs:`).
- Mandatory 2FA; least-privilege repo/team access. Rotate deploy keys; prefer short-lived tokens/OIDC for automation.
- Run pre-commit hooks: fmt/lint/tests/secret scan.
- Back up critical repos/mirrors; test restore procedures.

## Quick command reference (mapped to cheat sheet)
- Status/add/commit: `git status`, `git add`, `git commit -m`
- Branching: `git branch`, `git switch -c`, `git merge`
- Remote sync: `git fetch`, `git pull`, `git push`
- Inspect: `git log --oneline --graph`, `git diff`, `git show`
- Undo: `git restore`, `git revert`, `git reset --hard` (caution)
- Stash: `git stash push`, `git stash pop`
- Tags: `git tag -a vX.Y.Z`, `git push origin vX.Y.Z`
