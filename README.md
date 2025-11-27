# GitHub Secrets Exporter

Securely export your GitHub repository secrets. They're encrypted with your personal key, so only you can decrypt them.

## Why?

GitHub Actions secrets are write-only by design. You can't read them through the UI or API. This makes it hard to:

- Migrate to a new secrets manager (Vault, Pulumi, etc.)
- Move secrets between repositories
- Back up secrets for disaster recovery
- Audit what's currently set

This action lets you export all secrets safely by encrypting them with your personal key.

## Quick Start

> **Want maximum security?** See [ADVANCED.md](ADVANCED.md) for forking and auditing the code yourself.

### 1. [Install age](https://github.com/FiloSottile/age#installation)

### 2. Get your public key

```bash
# If you have an SSH key, get it from GitHub
curl https://github.com/YOUR_USERNAME.keys

# Or generate a new age key
age-keygen
```

Copy your public key (starts with `age1...` or `ssh-ed25519` or `ssh-rsa`).

### 3. Add the workflow to your repository

```yaml
# .github/workflows/export-secrets.yml
name: Export Secrets
on: pull_request  # Runs on PR creation, then close PR without merging

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      # For better security: fork, audit, and use your own copy (see ADVANCED.md)
      - uses: gerrywastaken/github-secrets-exporter@main
        env:
          SECRETS_JSON: ${{ toJSON(secrets) }}
        with:
          public_encryption_key: 'age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p'
```

Replace with your actual public key. It's public, so it's safe to commit!

> **Workflow approach:** Create a PR with this workflow, let it run and export your secrets, then close the PR **without merging**. This way the workflow never enters your main branch.

### 4. Create PR and decrypt

```bash
# Create a branch with the workflow
git checkout -b export-secrets
git add .github/workflows/export-secrets.yml
git commit -m "Add secrets export workflow"
git push -u origin export-secrets

# Create PR (workflow runs automatically)
gh pr create --title "Export secrets" --body "Temporary PR to export secrets"

# Wait for workflow to complete, then download the artifact
gh run download --name encrypted-secrets

# Decrypt the secrets
age --decrypt --identity ~/.ssh/id_ed25519 < encrypted-secrets.age

# Close the PR without merging
gh pr close
```

You'll see your secrets in JSON format.

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
