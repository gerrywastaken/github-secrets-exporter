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

### 1. Install age

**macOS:**
```bash
brew install age
```

**Linux:**
```bash
sudo apt-get install age
```

### 2. Generate your key pair

```bash
age-keygen -o private_age.txt
```

This outputs:
```
Public key: age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

**Keep `private_age.txt` safe and private!** Never commit it.

### 3. Add your public key to the repo

```bash
mkdir -p .github/data
echo "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p" > .github/data/public_age.txt
git add .github/data/public_age.txt
git commit -m "Add age public key for secret export"
git push
```

### 4. Add the workflow

Copy `.github/workflows/export-secrets.yml` to your target repository.

### 5. Run the workflow

Go to Actions → "Export Secrets (Encrypted)" → Run workflow

### 6. Get the encrypted output

```bash
gh run view --log | grep -A 1000 "ENCRYPTED SECRETS"
```

Copy the long base64 string.

### 7. Decrypt locally

```bash
echo "PASTE_BASE64_HERE" | base64 -d | age -d -i private_age.txt
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
