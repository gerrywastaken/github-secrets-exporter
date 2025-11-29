# GitHub Secrets Exporter

Securely export your GitHub repository secrets. They're encrypted with your personal key, so only you can decrypt them.

**WARNING**: If you are here because somebody is trying to add this to your repository. **STOP!**
They are a almost certainly a scammer. Delete their PR.

Additionally **nobody (not even you) ever needs to merge a pr with this in a workflow**.
It is for temporary use only by repository OWNERS and by design does not and should not be merged.

## Why?

GitHub Actions secrets are write-only by design. You can't read them through the UI or API. This makes it hard do things like:

- Audit what's currently set
- Recover a secret if Github is your last hope

This action lets you export all secrets safely by encrypting them with your public key.

## Quick Start

> **Want maximum security?** See [ADVANCED.md](ADVANCED.md) for forking and auditing the code yourself.

### 1. Install dependencies

- **[age](https://github.com/FiloSottile/age#installation)** (encryption tool)
- **[gh](https://cli.github.com/)** (Optional, you can do things manually, but it helps)

### 2. Generate your encryption key

```bash
TEMP_DIR=$(mktemp -d) # Use mktemp for secure storage (auto-deleted by system)
PRIVATE_KEY="$TEMP_DIR/private.key"
age-keygen -o "$PRIVATE_KEY"
```
This prints your public key - (the `age1...` part). Add the *public key* to the workflow in the ext step!

### 3. Create the workflow file

Create:  
`.github/workflows/export-secrets.yml`

```yaml
name: Export Secrets
on: pull_request

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: gerrywastaken/github-secrets-exporter@v1.1
        with:
          secrets_json: ${{ toJSON(secrets) }}
          public_encryption_key: '<age1...>'  # Paste your public key here
```

### 4. Create a PR to trigger the workflow

```bash
git checkout -b export-secrets
git add .github/workflows/export-secrets.yml
git commit -m "DO NOT MERGE: Export secrets"
git push -u origin export-secrets
gh pr create --fill
```

### 5. Download and delete the encrypted artifact

This opens an interactive menu to select and view your workflow run
```bash
gh run view --web
```

This opens an interactive menu where you can:
1. Select your "Export Secrets" workflow run
2. Browser opens **click summary** and **Scroll to bottom**
3. Download **then delete** the `encrypted-secrets` artifact

### 6. Decrypt your secrets

All sensitive data files live inside the temp dir so that it is easy to delete

```bash
pushd $TEMP_DIR # Move to the temp dir
mv ~/Downloads/encrypted-secrets.zip $TEMP_DIR
unzip encrypted-secrets.zip

echo "Your recovered secrets inside ${TEMP_DIR}/plaintext.json 🎉
echo "Makesure to move them somewhere secure because we are about to delete this directory"
age --decrypt --identity "$PRIVATE_KEY" < encrypted-secrets.age > plaintext.json

popd    # jumps back to the repo
```

### 7. Final cleanup

```bash
gh pr close -d export-secrets    # Closes the PR and delete remote and local branch
rm -rf "$TEMP_DIR"               # Delete temporary files
```


---

## Security

- Your public key is inline in the workflow (visible, auditable)
- Encrypted secrets stored as artifact with 1-day retention (not logs)
- Private key stored in `mktemp` (auto-cleanup by system, never in git)
- See [ADVANCED.md](ADVANCED.md) for the paranoid version

## License

MIT
