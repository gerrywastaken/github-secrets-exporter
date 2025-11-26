# Advanced Options

## Fork for Maximum Security (Recommended)

The code is intentionally simple (~36 lines) so you can audit it yourself:

1. Fork this repository to your own account
2. Review the code (it's short!)
3. Use `your-username/github-secrets-exporter@main` in your workflow instead of `gerrywastaken/github-secrets-exporter@main`
4. You control the code and verify no malicious updates occur

This way you're not trusting us - you're trusting code you've personally reviewed.

## Use Age Keys Instead of SSH

If you don't have GitHub SSH keys or prefer age keys:

### 1. Generate an age keypair

```bash
age-keygen -o ~/private_age.txt 2>&1 | \
  grep "Public key:" | \
  cut -d' ' -f3 > public_age.txt
```

This creates:
- Private key: `~/private_age.txt` (keep this safe!)
- Public key: `public_age.txt` (will be committed to your repo)

**NEVER commit `private_age.txt` - keep it private and outside your repo!**

### 2. Commit the public key

```bash
git add public_age.txt
git commit -m "Add age public key"
git push
```

### 3. Update your workflow

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
        with:
          public_key_path: 'public_age.txt'
```

### 4. Decrypt with your age key

```bash
gh run view --log | \
  grep --after-context=1000 "ENCRYPTED SECRETS" | \
  grep --invert-match "===" | \
  base64 --decode | \
  age --decrypt --identity ~/private_age.txt
```

## How It Works

### Default (SSH Keys)

1. Workflow fetches your GitHub SSH public keys from `https://github.com/USERNAME.keys`
2. Exports all secrets as JSON
3. Encrypts with your SSH public keys using `age`
4. Outputs base64-encoded ciphertext to logs
5. **You decrypt locally with your SSH private key**

### With Age Keys

1. Workflow checks out your repo to access `public_age.txt`
2. Exports all secrets as JSON
3. Encrypts with your age public key
4. Outputs base64-encoded ciphertext to logs
5. **You decrypt locally with your age private key**

### Security Details

- **Secrets only exist in memory** during the workflow - they never touch disk
- Even if GitHub's logs leak, nobody can decrypt without your private key
- The workflow is simple enough (~36 lines) to audit yourself
- Uses asymmetric encryption (public/private keys, not passwords)

## Security Notes

- Uses **asymmetric encryption** (public/private keys, not passwords)
- **Private key never leaves your machine**
- **Encrypted logs are safe** - only you can decrypt
- **Secrets only exist in memory** during the workflow run
- Simple, auditable code (~36 lines in `action.yml`)

## Example Output

After decryption, you'll see:
```json
{
  "NPM_TOKEN": "npm_abc123...",
  "AWS_ACCESS_KEY_ID": "AKIA...",
  "DATABASE_URL": "postgresql://..."
}
```

You can parse this with `jq` if needed:
```bash
# Get a specific secret
cat decrypted.json | jq -r '.NPM_TOKEN'

# Convert to env format
cat decrypted.json | jq -r 'to_entries[] | "\(.key)=\(.value)"'
```

## Troubleshooting

### "No such file or directory: /tmp/github_keys.txt"

You don't have any SSH keys on your GitHub account. Either:
1. Add SSH keys to GitHub (Settings → SSH and GPG keys)
2. Use age keys instead (see "Use Age Keys Instead of SSH" above)

### "no identity matched any of the recipients"

The SSH private key you're using doesn't match any of the public keys used for encryption. Try:
1. Different SSH keys: `~/.ssh/id_rsa`, `~/.ssh/id_ecdsa`, etc.
2. Check which keys are on your GitHub: `curl https://github.com/YOUR_USERNAME.keys`

### "Failed to decrypt"

Make sure you're using the correct private key that corresponds to the public key used for encryption.
