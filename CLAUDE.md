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

### Setup

1. Generate an age keypair:
```bash
age-keygen -o private_age.txt
# Prints: Public key: age1dp0rje7667cqhct9es3ap6ttq365nfk4u72vw5r4khv0lzppyv7qr3ttly
```

2. Save your public key to the repo:
```bash
echo "age1dp0rje7667cqhct9es3ap6ttq365nfk4u72vw5r4khv0lzppyv7qr3ttly" > .github/data/public_age.txt
git add .github/data/public_age.txt
git commit -m "Add age public key for secret export"
```

3. Copy the workflow to your target repository:
```bash
cp .github/workflows/export-secrets.yml YOUR_REPO/.github/workflows/
```

4. Trigger the workflow in your target repo (via workflow_dispatch or configure to run on push/PR)

5. Get the encrypted output from workflow logs:
```bash
gh run view WORKFLOW_RUN_ID --log | grep -A 1000 "ENCRYPTED SECRETS"
```

6. Decrypt locally:
```bash
echo "BASE64_OUTPUT" | base64 -d | age -d -i private_age.txt > secrets.env
```

### Customization

The workflow can be configured to:
- Run on workflow_dispatch (manual trigger)
- Run on push to specific branches
- Run on pull request creation
- Use a different path for the public key file

## Security Considerations

- **Asymmetric encryption**: Uses age with public/private keys, not passwords
- **Private key never leaves your machine**: Only the public key is in the repo
- **Encrypted logs are safe**: Even if GitHub's infrastructure is compromised, secrets remain encrypted
- **Auditable**: The workflow is simple and easy to review (< 50 lines)
- **Temporary exposure**: Plaintext secrets only exist in memory during workflow run, immediately deleted after encryption

## Files

- `.github/workflows/export-secrets.yml` - The reusable workflow
- `.github/data/public_age.txt` - Your age public key (user provides)
- `CLAUDE.md` - This file

## Development

This is a simple, standalone workflow - no dependencies beyond standard GitHub Actions features and common CLI tools (age, jq, base64).

## License

MIT (or whatever license you choose)
