# PowerShell script to fetch secrets from Google Secret Manager for development
# Usage: .\scripts\fetch_secrets.ps1

param(
    [string]$ProjectId = "your-gcp-project-id",
    [string]$EnvFile = ".env.local"
)

# Check if gcloud is installed
if (!(Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Error "Google Cloud SDK is not installed. Please install it first."
    Write-Host "Download from: https://cloud.google.com/sdk/docs/install"
    exit 1
}

# Check if authenticated
$authList = gcloud auth list --format="value(account)" 2>$null
if (!$authList) {
    Write-Host "Not authenticated. Running 'gcloud auth login'..."
    gcloud auth login
}

# Set the project
Write-Host "Setting project to: $ProjectId"
gcloud config set project $ProjectId

# List of secrets to fetch
$secrets = @(
    "firebase-api-key",
    "firebase-auth-domain",
    "firebase-project-id",
    "firebase-storage-bucket",
    "firebase-messaging-sender-id",
    "firebase-app-id",
    "firebase-measurement-id",
    "google-web-client-id"
)

# Create or clear the env file
"# Auto-generated from Google Secret Manager" | Out-File -FilePath $EnvFile -Encoding UTF8
"# Generated on: $(Get-Date)" | Out-File -FilePath $EnvFile -Append -Encoding UTF8
"" | Out-File -FilePath $EnvFile -Append -Encoding UTF8

# Fetch each secret
foreach ($secret in $secrets) {
    Write-Host "Fetching secret: $secret"
    try {
        $value = gcloud secrets versions access latest --secret=$secret 2>$null
        if ($LASTEXITCODE -eq 0) {
            $envVarName = $secret.ToUpper().Replace("-", "_")
            "$envVarName=$value" | Out-File -FilePath $EnvFile -Append -Encoding UTF8
            Write-Host "[OK] Successfully fetched $secret" -ForegroundColor Green
        } else {
            Write-Host "[!] Secret '$secret' not found" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "X Error fetching ${secret}: $_" -ForegroundColor Red
    }
}

Write-Host "`nSecrets have been written to: $EnvFile" -ForegroundColor Cyan
Write-Host "Remember to add $EnvFile to your .gitignore!" -ForegroundColor Yellow