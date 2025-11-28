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

### 1. [Install age](https://github.com/FiloSottile/age#installation)

### 2. Get your public key

```bash
# Generate a new age private key (or you can use one of your own https://github.com/YOUR_USERNAME.keys)
age-keygen -o private.key
```

Copy your public key (starts with `age1...` or `ssh-ed25519` or `ssh-rsa`).

### 3. Add the workflow to your repository

> **Heads up for forks:** GitHub does not pass repository secrets to workflows running from forked pull requests. Use a branch in the same repo (as shown below) or a `workflow_dispatch` run if you fork this action.

```yaml
# .github/workflows/export-secrets.yml
name: Export Secrets
on: pull_request  # Runs on PR creation, then close PR without merging

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      # For better security: fork, audit, and use your own copy (see ADVANCED.md)
      - uses: gerrywastaken/github-secrets-exporter@v1
        env:
          SECRETS_JSON: ${{ toJSON(secrets) }}
        with:
          # YOUR public key goes here
          public_encryption_key: '<your public key e.g. starts with `age`>'
```

Replace with your actual public key. It's public, so it's safe to commit!

> **Workflow approach:** Create a PR with this workflow, let it run and export your secrets, then close the PR **without merging**. This way the workflow never enters your main branch.

### 4. Create PR and decrypt

```bash

##################################
# Kick off the artifact generation
##################################

# Create a branch with the workflow
git checkout -b export-secrets
git add .github/workflows/export-secrets.yml
git commit -m "Add secrets export workflow"
git push -u origin export-secrets

# Create PR (workflow runs automatically)
gh pr create --title "Export secrets" --body "Temporary PR to export secrets"

# Watch the workflow until the artifact is created
gh run watch

##################
# Grab the secrets
##################

# Wait for workflow to complete, then download the artifact
gh run download --name encrypted-secrets

# Decrypt the secrets and store the secrets somewhere secure
age --decrypt --identity private.key < encrypted-secrets.age

# You'll see your secrets in JSON format.

################
# Do the cleanup
################

# 1. Close the PR to prevent it from being accidentally mered
gh pr close

# 2. delete the plaintext after you have stored the passwords
# 3. Delete the encrypted file too as well as the the private key you
# generated for this process, so it is never possible for somebody to steal
# the key and encrypted file.

# 3. Delete the workflow and thus the encrypted secrets
gh run delete --name encrypted-secrets
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
