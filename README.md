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

### 2. Add the workflow to your repository

```yaml
# .github/workflows/export-secrets.yml
name: Export Secrets
on: workflow_dispatch

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      # For better security: fork, audit, and use your own copy (see ADVANCED.md)
      - uses: gerrywastaken/github-secrets-exporter@main
        env:
          SECRETS_JSON: ${{ toJSON(secrets) }}
```

### 3. Run and decrypt

```bash
# Trigger the workflow
gh workflow run export-secrets.yml

# Wait for it to complete, then download the artifact
gh run download --name encrypted-secrets

# Decrypt the secrets
cat encrypted-secrets.txt | \
  base64 --decode | \
  age --decrypt --identity ~/.ssh/id_ed25519
```

**Multiple SSH keys?** If you have multiple SSH keys on GitHub, the action encrypts for all of them. Try each of your private keys (`~/.ssh/id_ed25519`, `~/.ssh/id_rsa`, etc.) until one works.

You'll see your secrets in JSON format.

> **Security:** Encrypted secrets are stored as a workflow artifact with 1-day retention (not in logs). This minimizes risk if your SSH key is compromised in the future.

---

**Need more control?** See [ADVANCED.md](ADVANCED.md) for:
- Forking for maximum security
- Using age keys instead of SSH
- How it works under the hood
- Security details

## License

MIT
