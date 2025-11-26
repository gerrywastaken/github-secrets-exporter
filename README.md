# GitHub Secrets Exporter

Securely export your GitHub repository secrets. They're encrypted with your personal key, so only you can decrypt them.

## Why?

GitHub Actions secrets are write-only by design. You can't read them through the UI or API. This makes it hard to:

- Migrate to a new secrets manager (Vault, Pulumi, etc.)
- Move secrets between repositories
- Back up secrets for disaster recovery
- Audit what's currently set

This action lets you export all secrets safely by encrypting them with your personal key.

## Security Best Practice

**We recommend forking this repo and using your own fork.**

The code is intentionally simple (~35 lines) so you can audit it yourself. After reviewing:
1. Fork this repository to your own account
2. Use `your-username/github-secrets-exporter@main` instead
3. You control the code and can verify no malicious updates occur

This way you're not trusting us - you're trusting code you've personally reviewed.

## Quick Start

### 1. [Install age](https://github.com/FiloSottile/age#installation)

### 2. Generate your key pair

```bash
age-keygen -o ~/private_age.txt 2>&1 | \
  grep "Public key:" | \
  cut -d' ' -f3 > public_age.txt
```

This creates both keys at once:
- Private key: `~/private_age.txt` (keep this safe!)
- Public key: `public_age.txt` (committed to your repo)

**NEVER commit `private_age.txt` - keep it private and outside your repo!**

### 3. Add your public key to the repo

```bash
git add public_age.txt
git commit -m "Add age public key"
git push
```

### 4. Add the workflow to your repository

```yaml
# .github/workflows/export-secrets.yml
name: Export Secrets
on: workflow_dispatch

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: your-username/github-secrets-exporter@main  # Use your fork!
        env:
          SECRETS_JSON: ${{ toJSON(secrets) }}
```

### 5. Run and decrypt

```bash
# Trigger the workflow
gh workflow run export-secrets.yml

# Get the latest run and decrypt in one command
gh run view --log | \
  grep --after-context=1000 "ENCRYPTED SECRETS" | \
  grep --invert-match "===" | \
  base64 --decode | \
  age --decrypt --identity ~/private_age.txt
```

You'll see your secrets in `KEY=value` format.

## How It Works

1. Workflow exports all secrets as JSON
2. Converts to `KEY=value` format
3. Encrypts with your public key using `age`
4. Outputs base64-encoded ciphertext to logs
5. **You decrypt locally with your private key**

The secrets are only in memory during the workflow - they never touch disk. Even if GitHub's logs leak, nobody can decrypt without your private key.

## Security Notes

- Uses **asymmetric encryption** (public/private keys, not passwords)
- **Private key never leaves your machine**
- **Encrypted logs are safe** - only you can decrypt
- **Secrets only exist in memory** during the workflow run
- Simple, auditable code (~35 lines)

## Example Output

After decryption, you'll see:
```
NPM_TOKEN=npm_abc123...
AWS_ACCESS_KEY_ID=AKIA...
DATABASE_URL=postgresql://...
```

## License

MIT
