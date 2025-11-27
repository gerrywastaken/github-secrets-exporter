# Advanced Options

## Fork for Maximum Security (Recommended)

The code is intentionally simple (~40 lines) so you can audit it yourself:

1. Fork this repository to your own account
2. Review the code (it's short!)
3. Use `your-username/github-secrets-exporter@main` in your workflow instead of `gerrywastaken/github-secrets-exporter@main`
4. You control the code and verify no malicious updates occur

This way you're not trusting us - you're trusting code you've personally reviewed.

## Using Different Key Types

### SSH Keys

If you already have an SSH key on GitHub:

```bash
# Get your public key
curl https://github.com/YOUR_USERNAME.keys
```

Use it in your workflow:
```yaml
with:
  public_encryption_key: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKw...'
```

Decrypt with:
```bash
age --decrypt --identity ~/.ssh/id_ed25519 < encrypted-secrets.age
```

### Age Keys

Generate a dedicated age key:

```bash
age-keygen -o ~/private_age.txt
```

This outputs:
```
Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

Use it in your workflow:
```yaml
with:
  public_encryption_key: 'age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p'
```

Decrypt with:
```bash
age --decrypt --identity ~/private_age.txt < encrypted-secrets.age
```

## How It Works

1. You provide your public encryption key inline in the workflow file
2. Workflow exports all secrets as JSON
3. Encrypts with your public key using `age`
4. Uploads encrypted data as workflow artifact (1-day retention)
5. **You download artifact and decrypt locally with your private key**

### Security Details

- **Public key is inline** in your workflow file (visible, auditable)
- **Secrets only exist in memory** during the workflow - they never touch disk
- **Encrypted output stored as artifact** (not logs) with 1-day retention
- Artifacts can be deleted manually for extra security
- Even if someone steals your private key years later, artifact is already deleted
- The action code is simple enough (~40 lines) to audit yourself
- Uses asymmetric encryption (public/private keys, not passwords)
- **Best practice**: Fork and audit the code before using

## Security Notes

- Uses **asymmetric encryption** (public/private keys, not passwords)
- **Private key never leaves your machine**
- **Secrets only exist in memory** during the workflow run
- Simple, auditable code (~30 lines in `action.yml`)

### Critical: Workflow Trigger Security

**⚠️ NEVER use `pull_request` or `pull_request_target` triggers with this action!**

Why? A malicious PR could:
1. Modify the workflow file to change the encryption key
2. Exfiltrate secrets before encryption
3. Send secrets to an attacker-controlled server

**Always use `workflow_dispatch`** (manual trigger only). This ensures:
- Only repo maintainers with write access can trigger the export
- The workflow file in the main branch is used (not from a PR)
- No automated triggers that could be exploited

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

## Manual Artifact Deletion

For extra security, you can delete the artifact immediately after downloading:

```bash
# Download the artifact first
gh run download --name encrypted-secrets

# Delete the artifact
gh api repos/:owner/:repo/actions/artifacts/ARTIFACT_ID -X DELETE
```

Or delete via the GitHub UI: Actions → Workflow run → Artifacts section → Delete

## Troubleshooting

### "no identity matched any of the recipients" or "Failed to decrypt"

The private key you're using doesn't match the public key used for encryption.

Solutions:
1. Check which public key is in your workflow file (look at `public_encryption_key`)
2. If using SSH key: try different keys (`~/.ssh/id_ed25519`, `~/.ssh/id_rsa`, `~/.ssh/id_ecdsa`)
3. If using age key: make sure you're using the correct `private_age.txt` file
4. Verify the public key hasn't changed since the workflow ran
