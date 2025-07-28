# PowerShell script to set up secrets in Google Secret Manager
# Usage: .\scripts\setup_secrets.ps1 -ProjectId "your-project-id"

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectId
)

Write-Host "Setting up Google Cloud Secret Manager for project: $ProjectId" -ForegroundColor Cyan

# Enable Secret Manager API
Write-Host "`nEnabling Secret Manager API..." -ForegroundColor Yellow
& gcloud services enable secretmanager.googleapis.com --project=$ProjectId

# Function to create or update a secret
function Set-GCPSecret {
    param(
        [string]$SecretName,
        [string]$SecretValue
    )
    
    Write-Host "`nCreating/updating secret: $SecretName" -ForegroundColor Yellow
    
    # Check if secret exists
    $exists = & gcloud secrets describe $SecretName --project=$ProjectId 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        # Secret exists, create new version
        $SecretValue | & gcloud secrets versions add $SecretName --data-file=- --project=$ProjectId
        Write-Host "[OK] Updated secret: $SecretName" -ForegroundColor Green
    } else {
        # Create new secret
        & gcloud secrets create $SecretName --project=$ProjectId --replication-policy="automatic"
        $SecretValue | & gcloud secrets versions add $SecretName --data-file=- --project=$ProjectId
        Write-Host "[OK] Created secret: $SecretName" -ForegroundColor Green
    }
}

# Read current .env file if it exists
$envFile = ".env"
if (Test-Path $envFile) {
    Write-Host "`nReading existing .env file..." -ForegroundColor Yellow
    $envContent = Get-Content $envFile
    
    foreach ($line in $envContent) {
        if ($line -match "^([A-Z_]+)=(.+)$") {
            $key = $matches[1]
            $value = $matches[2]
            
            # Convert env var name to secret name (FIREBASE_API_KEY -> firebase-api-key)
            $secretName = $key.ToLower().Replace("_", "-")
            
            Set-GCPSecret -SecretName $secretName -SecretValue $value
        }
    }
} else {
    Write-Host "`nNo .env file found. Let's create secrets manually:" -ForegroundColor Yellow
    Write-Host "Example: Set-GCPSecret -SecretName 'firebase-api-key' -SecretValue 'your-api-key-here'"
}

Write-Host "`nSecret Manager setup complete!" -ForegroundColor Green
Write-Host "You can now use .\scripts\fetch_secrets.ps1 to fetch these secrets for local development." -ForegroundColor Cyan