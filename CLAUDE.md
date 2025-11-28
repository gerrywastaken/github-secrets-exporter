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

### Recommended Approach (Simple)

1. Generate key with `mktemp` for security
2. Create workflow file with public key
3. Create PR to trigger workflow
4. Use `gh run view --web` - opens interactive menu
5. Select workflow, download artifact, delete run from web UI
6. Decrypt locally and cleanup

See README.md for full step-by-step instructions.

**Why this approach:**
- Simple: Just 7 straightforward steps
- Safe: Uses `mktemp` for private key (never in working directory)
- User-friendly: `gh run view --web` provides interactive menu
- Clean: Web UI makes download/delete workflow runs easy

### Alternative Approaches

**Automated script:** `export-secrets.sh` - handles everything automatically (see ADVANCED.md)

**Fully manual CLI:** Complete command-line control without web UI (see ADVANCED.md)

**Key improvements from original approach:**
- Uses `mktemp` for secure private key storage (never in working directory)
- Leverages `gh run view --web` interactive menu instead of complex commands
- Targets specific workflow run by branch + name (avoids deleting wrong workflow)
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
