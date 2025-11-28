# GitHub Secrets Exporter

Securely export your GitHub repository secrets. They're encrypted with your personal key, so only you can decrypt them.

**WARNING**: If you are here because somebody is trying to add this to your repository. **STOP!**
They are a almost certainly a scammer. Delete their PR.

Additionally **nobody (not even you) ever needs to merge a pr with this in a workflow**.
It is for temporary use only by repository OWNERS and by design does not and should not be merged.

## Why?

GitHub Actions secrets are write-only by design. You can't read them through the UI or API. This makes it hard to:

- Migrate to a new secrets manager (Vault, Pulumi, etc.)
- Move secrets between repositories
- Back up secrets for disaster recovery
- Audit what's currently set

This action lets you export all secrets safely by encrypting them with your personal key.

## Quick Start

> **Want maximum security?** See [ADVANCED.md](ADVANCED.md) for forking and auditing the code yourself.

### 1. Install dependencies

**age** (encryption tool):
- [Installation instructions](https://github.com/FiloSottile/age#installation)

**GitHub CLI**:
```bash
# macOS
brew install gh

# Linux/WSL - see https://github.com/cli/cli#installation
```

### 2. Export your secrets

**Option A: Interactive script (recommended)**

The easiest and safest way is to use the interactive script:

```bash
# Download and run the script
curl -fsSL https://raw.githubusercontent.com/gerrywastaken/github-secrets-exporter/main/export-secrets.sh | bash

# Or if you've cloned the repo:
./export-secrets.sh
```

The script will:
- Generate a temporary age keypair (auto-deleted after)
- Create the workflow file with your public key
- Create a PR and wait for the workflow
- Download and decrypt your secrets
- Clean up everything automatically

> **Security:** The private key is stored in a temporary directory created with `mktemp` and deleted when the script exits. It never touches your working directory.

**Option B: Manual commands (advanced)**

If you prefer manual control:

```bash
# Use mktemp for secure key storage
PRIVATE_KEY=$(mktemp)
age-keygen -o "$PRIVATE_KEY"

# Extract public key (will be printed by age-keygen)
# Copy it and add to your workflow file at .github/workflows/export-secrets.yml

# Create workflow manually (see step 3 above), then:
BRANCH="export-secrets-$(date +%s)"
git checkout -b "$BRANCH"
git add .github/workflows/export-secrets.yml
git commit -m "Add secrets export workflow"
git push -u origin "$BRANCH"

# Create PR and capture workflow
gh pr create --title "DO NOT MERGE: Export secrets" --body "Temporary PR" && \
RUN_ID=$(gh run list --branch "$BRANCH" --workflow=export-secrets.yml --limit 1 --json databaseId --jq '.[0].databaseId') && \
gh run watch "$RUN_ID" && \
gh run download "$RUN_ID" --name encrypted-secrets && \
age --decrypt --identity "$PRIVATE_KEY" < encrypted-secrets.age

# Cleanup
gh pr close
gh run delete "$RUN_ID"
rm "$PRIVATE_KEY" encrypted-secrets.age
git checkout -
git branch -D "$BRANCH"
git push origin --delete "$BRANCH"
```


> **Security:**
> - Your public key is inline in the workflow (visible, auditable)
> - Encrypted secrets stored as artifact with 1-day retention (not logs)
> - For maximum security: fork and audit the code yourself (see ADVANCED.md)

---

**Need more control?** See [ADVANCED.md](ADVANCED.md) for:
- Forking for maximum security
- Using age keys instead of SSH
- How it works under the hood
- Security details

## License

MIT
