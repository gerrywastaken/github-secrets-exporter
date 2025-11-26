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
      - uses: gerrywastaken/github-secrets-exporter@main
        env:
          SECRETS_JSON: ${{ toJSON(secrets) }}
```

### 3. Run and decrypt

```bash
# Trigger the workflow
gh workflow run export-secrets.yml

# Get the latest run and decrypt with your SSH key
gh run view --log | \
  grep --after-context=1000 "ENCRYPTED SECRETS" | \
  grep --invert-match "===" | \
  base64 --decode | \
  age --decrypt --identity ~/.ssh/id_ed25519
```

**Multiple SSH keys?** If you have multiple SSH keys on GitHub, the action encrypts for all of them. Try each of your private keys (`~/.ssh/id_ed25519`, `~/.ssh/id_rsa`, etc.) until one works.

You'll see your secrets in JSON format.

## Advanced Options

### Fork for Maximum Security (Recommended)

The code is intentionally simple (~36 lines) so you can audit it yourself:

1. Fork this repository to your own account
2. Review the code (it's short!)
3. Use `your-username/github-secrets-exporter@main` in your workflow
4. You control the code and verify no malicious updates occur

### Use Age Keys Instead of SSH

If you don't have GitHub SSH keys or prefer age keys:

1. Generate an age keypair:
```bash
age-keygen -o ~/private_age.txt 2>&1 | \
  grep "Public key:" | \
  cut -d' ' -f3 > public_age.txt
```

2. Commit the public key:
```bash
git add public_age.txt
git commit -m "Add age public key"
git push
```

3. Update your workflow to specify the key path:
```yaml
- uses: gerrywastaken/github-secrets-exporter@main
  env:
    SECRETS_JSON: ${{ toJSON(secrets) }}
  with:
    public_key_path: 'public_age.txt'
```

4. Decrypt with `age --decrypt --identity ~/private_age.txt`

## How It Works

1. Workflow fetches your GitHub SSH public keys from `https://github.com/USERNAME.keys`
2. Exports all secrets as JSON
3. Encrypts with your SSH public keys using `age`
4. Outputs base64-encoded ciphertext to logs
5. **You decrypt locally with your SSH private key**

The secrets are only in memory during the workflow - they never touch disk. Even if GitHub's logs leak, nobody can decrypt without your private key.

## Security Notes

- Uses **asymmetric encryption** (public/private keys, not passwords)
- **Private key never leaves your machine**
- **Encrypted logs are safe** - only you can decrypt
- **Secrets only exist in memory** during the workflow run
- Simple, auditable code (~30 lines)

## Example Output

After decryption, you'll see:
```json
{
  "NPM_TOKEN": "npm_abc123...",
  "AWS_ACCESS_KEY_ID": "AKIA...",
  "DATABASE_URL": "postgresql://..."
}
```

## License

MIT
