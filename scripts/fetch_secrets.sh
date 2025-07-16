#!/bin/bash
# Bash script to fetch secrets from Google Secret Manager for development
# Usage: ./scripts/fetch_secrets.sh

PROJECT_ID="${1:-your-gcp-project-id}"
ENV_FILE="${2:-.env.local}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "Error: Google Cloud SDK is not installed. Please install it first."
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if authenticated
if ! gcloud auth list --format="value(account)" &> /dev/null; then
    echo "Not authenticated. Running 'gcloud auth login'..."
    gcloud auth login
fi

# Set the project
echo "Setting project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# List of secrets to fetch
secrets=(
    "firebase-api-key"
    "firebase-auth-domain"
    "firebase-project-id"
    "firebase-storage-bucket"
    "firebase-messaging-sender-id"
    "firebase-app-id"
    "firebase-measurement-id"
    "google-web-client-id"
)

# Create or clear the env file
cat > "$ENV_FILE" << EOF
# Auto-generated from Google Secret Manager
# Generated on: $(date)

EOF

# Fetch each secret
for secret in "${secrets[@]}"; do
    echo "Fetching secret: $secret"
    if value=$(gcloud secrets versions access latest --secret="$secret" 2>/dev/null); then
        env_var_name=$(echo "$secret" | tr '[:lower:]-' '[:upper:]_')
        echo "${env_var_name}=${value}" >> "$ENV_FILE"
        echo "✓ Successfully fetched $secret"
    else
        echo "✗ Secret '$secret' not found"
    fi
done

echo -e "\nSecrets have been written to: $ENV_FILE"
echo "Remember to add $ENV_FILE to your .gitignore!"