# CLAUDE.md

## Project Overview

**GitHub Secrets Secure Exporter** - A GitHub Action that allows you to securely export all repository secrets encrypted with your age public key.

## Problem This Solves

GitHub Actions secrets are write-only by design - you can set them but not read them. This creates a problem when:
- Migrating to a new secret management system (like Pulumi, Vault, etc.)
- Moving secrets between repositories
- Backing up secrets for disaster recovery
- Auditing what secrets are currently set

This action solves this by:
1. Exporting all secrets in a GitHub workflow
2. Encrypting them with your age public key (asymmetric encryption)
3. Only you can decrypt with your private key
4. The encrypted output is safe to appear in logs and can be audited

## How It Works

1. User generates an age keypair locally (public + private keys)
2. User commits their public age key to `.github/data/public_age.txt` in the repo
3. User triggers the workflow (manually or on push/PR)
4. Workflow exports all secrets, encrypts them with the public key
5. Outputs encrypted secrets as base64 in the workflow logs
6. User copies the encrypted output and decrypts locally with their private key

**Security:** Even if GitHub's logs are compromised, the secrets are encrypted and only the holder of the private key can decrypt them.

## Usage

### Quick Start (Recommended)

Use the interactive script for the safest and easiest experience:

```bash
./export-secrets.sh
```

The script handles everything automatically:
- Generates temporary age keypair (stored in `mktemp` directory)
- Creates workflow file with your public key
- Creates PR and waits for completion
- Downloads and decrypts secrets
- Cleans up all temporary files and artifacts

### Manual Approach

If you prefer full control:

```bash
# 1. Generate keypair in temporary location
PRIVATE_KEY=$(mktemp)
age-keygen -o "$PRIVATE_KEY"
# Note the public key printed

# 2. Create workflow with your public key
# See README.md for workflow template

# 3. Run the export process
BRANCH="export-secrets-$(date +%s)"
git checkout -b "$BRANCH"
git add .github/workflows/export-secrets.yml
git commit -m "Add secrets export workflow"
git push -u origin "$BRANCH"

# Create PR and get workflow run ID
gh pr create --title "DO NOT MERGE: Export secrets" --body "Temporary PR"
RUN_ID=$(gh run list --branch "$BRANCH" --workflow=export-secrets.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID"
gh run download "$RUN_ID" --name encrypted-secrets
age --decrypt --identity "$PRIVATE_KEY" < encrypted-secrets.age

# 4. Cleanup
gh pr close
gh run delete "$RUN_ID"
rm "$PRIVATE_KEY" encrypted-secrets.age
git checkout - && git branch -D "$BRANCH"
```

**Key improvements over old approach:**
- Uses `mktemp` for secure private key storage (never in working directory)
- Targets specific workflow run by ID (avoids deleting wrong workflow)
- Unique branch names prevent conflicts

### Customization

The workflow can be configured to:
- Export all secrets: `secrets_json: ${{ toJSON(secrets) }}`
- Export specific secrets: `secrets_json: '{"API_KEY": "${{ secrets.API_KEY }}"}'`
- Run on workflow_dispatch (manual trigger)
- Run on push to specific branches
- Run on pull request creation

## Security Considerations

- **Asymmetric encryption**: Uses age with public/private keys, not passwords
- **Private key never leaves your machine**: Only the public key is in the repo
- **Encrypted logs are safe**: Even if GitHub's infrastructure is compromised, secrets remain encrypted
- **Auditable**: The workflow is simple and easy to review (< 50 lines)
- **Temporary exposure**: Plaintext secrets only exist in memory during workflow run, immediately deleted after encryption

## Files

- `action.yml` - The GitHub Action implementation
- `export-secrets.sh` - Interactive script for easy exports (recommended method)
- `README.md` - User-facing documentation
- `ADVANCED.md` - Advanced usage and security details
- `CLAUDE.md` - This file (project overview for Claude)

## Development

This is a simple, standalone workflow - no dependencies beyond standard GitHub Actions features and common CLI tools (age, jq, base64).

## License

MIT (or whatever license you choose)
