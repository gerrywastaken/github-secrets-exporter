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

- **[age](https://github.com/FiloSottile/age#installation)** (encryption tool)
- **[gh](https://cli.github.com/)** (GitHub CLI)

### 2. Generate your encryption key

```bash
# Use mktemp for secure storage (auto-deleted by system)
TEMP_DIR=$(mktemp -d)
PRIVATE_KEY="$TEMP_DIR/private.key"
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
git commit -m "DO NOT MERGE: Export secrets"
git push -u origin export-secrets
gh pr create --fill
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
pushd $TEMP_DIR
mv ~/Downloads/encrypted-secrets.zip $TEMP_DIR
unzip encrypted-secrets.zip

age --decrypt --identity "$PRIVATE_KEY" < encrypted-secrets.age
# You'll see your secrets in JSON format 🎉

popd # jumps back to the repo
```

### 7. Final cleanup

```bash
# Close the PR and delete remote and local branch
gh pr close -d export-secrets

# Delete temporary files
rm -rf "$TEMP_DIR"
```


---

## Security

- Your public key is inline in the workflow (visible, auditable)
- Encrypted secrets stored as artifact with 1-day retention (not logs)
- Private key stored in `mktemp` (auto-cleanup by system, never in git)
- See [ADVANCED.md](ADVANCED.md) for the paranoid version

## License

MIT
