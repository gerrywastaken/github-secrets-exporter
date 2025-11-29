#!/bin/bash
set -euo pipefail

# GitHub Secrets Exporter - Interactive Script
# This script helps you safely export repository secrets

echo "=========================================="
echo "GitHub Secrets Exporter"
echo "=========================================="
echo ""

# Check if age is installed
if ! command -v age &> /dev/null; then
    echo "Error: 'age' is not installed."
    echo "Install it from: https://github.com/FiloSottile/age#installation"
    exit 1
fi

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "Error: 'gh' (GitHub CLI) is not installed."
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

echo "Step 1: Generate encryption key"
echo "================================"
echo ""

# Create temporary directory for sensitive files
TEMP_DIR=$(mktemp -d)
PRIVATE_KEY="$TEMP_DIR/private.key"

# Ensure cleanup on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Generating age keypair in temporary directory: $TEMP_DIR"
age-keygen -o "$PRIVATE_KEY" 2>&1 | tee "$TEMP_DIR/keygen-output.txt"

# Extract public key from output
PUBLIC_KEY=$(grep "^Public key:" "$TEMP_DIR/keygen-output.txt" | cut -d' ' -f3)

if [ -z "$PUBLIC_KEY" ]; then
    echo "Error: Could not extract public key"
    exit 1
fi

echo ""
echo "✓ Public key: $PUBLIC_KEY"
echo ""

echo "Step 2: Create workflow file"
echo "============================="
echo ""

WORKFLOW_FILE=".github/workflows/export-secrets.yml"

# Check if workflow already exists
if [ -f "$WORKFLOW_FILE" ]; then
    echo "Warning: $WORKFLOW_FILE already exists!"
    read -p "Do you want to overwrite it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Create .github/workflows directory if it doesn't exist
mkdir -p .github/workflows

# Create workflow file
cat > "$WORKFLOW_FILE" <<EOF
name: Export Secrets
on: pull_request

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: gerrywastaken/github-secrets-exporter@v1.1
        with:
          secrets_json: \${{ toJSON(secrets) }}
          public_encryption_key: '$PUBLIC_KEY'
EOF

echo "✓ Created $WORKFLOW_FILE"
echo ""

echo "Step 3: Create PR and trigger workflow"
echo "======================================="
echo ""

# Generate unique branch name
BRANCH_NAME="export-secrets-$(date +%s)"

git checkout -b "$BRANCH_NAME"
git add "$WORKFLOW_FILE"
git commit -m "DO NOT MERGE: Export secrets"
git push -u origin "$BRANCH_NAME"

echo ""
echo "Creating pull request..."
PR_URL=$(gh pr create --fill --json url --jq '.url')

echo "✓ PR created: $PR_URL"
echo ""

echo "Step 4: Watch workflow and download artifact"
echo "============================================="
echo ""

echo "Waiting for workflow to start..."

# Wait for workflow run to appear (with retry)
MAX_RETRIES=20
RETRY_DELAY=3
RUN_ID=""

for i in $(seq 1 $MAX_RETRIES); do
    RUN_ID=$(gh run list --branch "$BRANCH_NAME" --workflow=export-secrets.yml --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")

    if [ -n "$RUN_ID" ] && [ "$RUN_ID" != "null" ]; then
        echo "✓ Workflow run detected (ID: $RUN_ID)"
        break
    fi

    if [ $i -eq $MAX_RETRIES ]; then
        echo "Error: Workflow run not found after ${MAX_RETRIES} attempts ($(($MAX_RETRIES * $RETRY_DELAY))s)"
        echo "This may indicate:"
        echo "  - GitHub is experiencing delays"
        echo "  - The workflow failed to trigger"
        echo "  - There's an issue with the workflow file"
        exit 1
    fi

    echo "Waiting for workflow to appear... (attempt $i/$MAX_RETRIES)"
    sleep $RETRY_DELAY
done

echo ""

# Watch the workflow
if ! gh run watch "$RUN_ID"; then
    echo ""
    echo "Note: Workflow may have already completed."
    echo "Attempting to download artifact anyway..."
fi

echo ""
echo "Downloading encrypted secrets..."

# Download to temp directory
cd "$TEMP_DIR"
gh run download "$RUN_ID" --name encrypted-secrets

echo "✓ Downloaded encrypted secrets"
echo ""

echo "Step 5: Decrypt secrets"
echo "======================="
echo ""

echo "Decrypting..."
echo ""
echo "==================== YOUR SECRETS ===================="
age --decrypt --identity "$PRIVATE_KEY" < encrypted-secrets.age
echo ""
echo "======================================================"
echo ""

echo "Step 6: Cleanup"
echo "==============="
echo ""

# Return to original directory
cd - > /dev/null

echo "Closing PR..."
gh pr close

echo "Deleting workflow run and artifacts from GitHub..."
gh run delete "$RUN_ID"

echo "Deleting workflow file..."
git checkout -
git branch -D "$BRANCH_NAME"

read -p "Delete the workflow file from remote? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push origin --delete "$BRANCH_NAME"
    echo "✓ Remote branch deleted"
fi

echo ""
echo "✓ Cleanup complete!"
echo ""
echo "IMPORTANT REMINDERS:"
echo "  • Save your decrypted secrets somewhere secure NOW"
echo "  • The private key and encrypted files are in: $TEMP_DIR"
echo "  • They will be automatically deleted when this script exits"
echo "  • The workflow file ($WORKFLOW_FILE) still exists locally"
echo ""

read -p "Press Enter to exit (this will delete temporary files)..."
