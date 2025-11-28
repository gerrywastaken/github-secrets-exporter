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

### 2. Generate your encryption key

```bash
# Use mktemp for secure storage (auto-deleted by system)
PRIVATE_KEY=$(mktemp)
age-keygen -o "$PRIVATE_KEY"

# This prints your public key - copy it!
# Example: Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

### 3. Create the workflow file

Create `.github/workflows/export-secrets.yml`:

```yaml
name: Export Secrets
on: pull_request

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: gerrywastaken/github-secrets-exporter@v1.1
        with:
          secrets_json: ${{ toJSON(secrets) }}
          public_encryption_key: 'age1...'  # Paste your public key here
```

### 4. Create a PR to trigger the workflow

```bash
git checkout -b export-secrets
git add .github/workflows/export-secrets.yml
git commit -m "Add secrets export workflow"
git push -u origin export-secrets
gh pr create --title "DO NOT MERGE: Export secrets" --body "Temporary PR"
```

### 5. Download the artifact and cleanup

```bash
# Opens interactive menu to select and view your workflow run
gh run view --web
```

This opens an interactive menu where you can:
1. **Select your "Export Secrets" workflow run** (use arrows, press Enter)
2. **Browser opens** to the workflow run page
3. **Scroll to bottom** → Download the `encrypted-secrets` artifact
4. **Click "Delete workflow run"** button to cleanup

### 6. Decrypt your secrets

```bash
# Extract and decrypt the artifact
unzip encrypted-secrets.zip
age --decrypt --identity "$PRIVATE_KEY" < encrypted-secrets.age

# You'll see your secrets in JSON format
```

### 7. Final cleanup

```bash
# Close the PR
gh pr close

# Delete temporary files
rm "$PRIVATE_KEY" encrypted-secrets.zip encrypted-secrets.age
```


---

## Security

- Your public key is inline in the workflow (visible, auditable)
- Encrypted secrets stored as artifact with 1-day retention (not logs)
- Private key stored in `mktemp` (auto-cleanup by system, never in git)
- For maximum security: fork and audit the code yourself (see ADVANCED.md)

## Advanced Options

See [ADVANCED.md](ADVANCED.md) for:
- **Automated script** (`export-secrets.sh`) - fully automated from start to finish
- **Fully manual CLI approach** - complete command-line control without using the web UI
- **Forking for maximum security** - audit the code yourself
- **Using SSH keys** - alternative to age keys
- **Troubleshooting** - common issues and solutions

## License

MIT
