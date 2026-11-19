# NutriSync GCP Setup Script (PowerShell)
# This script helps set up Google Cloud Platform services for NutriSync

param(
    [string]$ProjectId = "nutrisync-gcp-dev",
    [string]$Region = "us-central1",
    [ValidateSet("development", "staging", "production")]
    [string]$Environment = "development"
)

# Configuration
$ServiceAccountName = "nutrisync-ai-service"

Write-Host "🚀 NutriSync GCP Setup" -ForegroundColor Blue
Write-Host "This script will help you set up Google Cloud Platform services for NutriSync"
Write-Host

# Check if gcloud is installed
try {
    $null = Get-Command gcloud -ErrorAction Stop
} catch {
    Write-Host "❌ Google Cloud CLI (gcloud) is not installed" -ForegroundColor Red
    Write-Host "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
}

# Get user input if not provided as parameters
if (-not $ProjectId -or $ProjectId -eq "nutrisync-gcp-dev") {
    $ProjectId = Read-Host "Enter GCP Project ID (default: nutrisync-gcp-dev)"
    if (-not $ProjectId) { $ProjectId = "nutrisync-gcp-dev" }
}

if (-not $Region -or $Region -eq "us-central1") {
    $Region = Read-Host "Enter GCP Region (default: us-central1)"
    if (-not $Region) { $Region = "us-central1" }
}

if (-not $Environment -or $Environment -eq "development") {
    Write-Host "Select environment:"
    Write-Host "1) development"
    Write-Host "2) staging"
    Write-Host "3) production"
    $envChoice = Read-Host "Enter choice (1-3)"
    
    switch ($envChoice) {
        "1" { $Environment = "development" }
        "2" { $Environment = "staging" }
        "3" { $Environment = "production" }
        default { 
            Write-Host "Invalid choice" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host
Write-Host "📋 Configuration Summary:" -ForegroundColor Yellow
Write-Host "Project ID: $ProjectId"
Write-Host "Region: $Region"
Write-Host "Environment: $Environment"
Write-Host

$confirm = Read-Host "Continue with this configuration? (y/N)"
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "Setup cancelled"
    exit 0
}

Write-Host
Write-Host "🔧 Setting up GCP project..." -ForegroundColor Blue

# Set the project
Write-Host "Setting project to $ProjectId..."
& gcloud config set project $ProjectId

# Enable required APIs
Write-Host "📡 Enabling required APIs..." -ForegroundColor Yellow
$apis = @(
    "speech.googleapis.com",
    "texttospeech.googleapis.com",
    "vision.googleapis.com",
    "translate.googleapis.com",
    "dialogflow.googleapis.com",
    "maps-backend.googleapis.com",
    "places-backend.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "Enabling $api..."
    & gcloud services enable $api
}

Write-Host "✅ APIs enabled successfully" -ForegroundColor Green

# Create service account
Write-Host "👤 Creating service account..." -ForegroundColor Yellow
$serviceAccountEmail = "$ServiceAccountName@$ProjectId.iam.gserviceaccount.com"

# Check if service account already exists
$existingAccount = & gcloud iam service-accounts describe $serviceAccountEmail 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Service account $serviceAccountEmail already exists"
} else {
    Write-Host "Creating service account: $ServiceAccountName"
    & gcloud iam service-accounts create $ServiceAccountName `
        --display-name="NutriSync AI Service Account" `
        --description="Service account for NutriSync AI services"
}

# Grant required roles
Write-Host "🔐 Granting IAM roles..." -ForegroundColor Yellow
$roles = @(
    "roles/speech.client",
    "roles/texttospeech.client",
    "roles/vision.client",
    "roles/translate.client",
    "roles/dialogflow.client",
    "roles/maps.client",
    "roles/places.client",
    "roles/run.invoker",
    "roles/cloudfunctions.invoker",
    "roles/monitoring.viewer",
    "roles/logging.viewer"
)

foreach ($role in $roles) {
    Write-Host "Granting role: $role"
    & gcloud projects add-iam-policy-binding $ProjectId `
        --member="serviceAccount:$serviceAccountEmail" `
        --role="$role"
}

Write-Host "✅ IAM roles granted successfully" -ForegroundColor Green

# Create and download service account key
Write-Host "🔑 Creating service account key..." -ForegroundColor Yellow
$keyFile = "assets/config/gcp/service-account-$Environment.json"

# Create the directory if it doesn't exist
$gcpDir = "assets/config/gcp"
if (-not (Test-Path $gcpDir)) {
    New-Item -ItemType Directory -Path $gcpDir -Force | Out-Null
}

# Generate the key
& gcloud iam service-accounts keys create $keyFile `
    --iam-account=$serviceAccountEmail

Write-Host "✅ Service account key created: $keyFile" -ForegroundColor Green

# Update environment configuration
Write-Host "⚙️ Updating environment configuration..." -ForegroundColor Yellow
$envFile = "assets/config/environments/$Environment.json"

if (Test-Path $envFile) {
    try {
        $config = Get-Content $envFile | ConvertFrom-Json
        $config.gcp.projectId = $ProjectId
        $config | ConvertTo-Json -Depth 10 | Set-Content $envFile
        Write-Host "✅ Environment configuration updated" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Could not automatically update environment file. Please manually update $envFile" -ForegroundColor Yellow
        Write-Host "Set gcp.projectId to: $ProjectId"
    }
} else {
    Write-Host "⚠️ Environment file not found: $envFile" -ForegroundColor Yellow
}

# Create Cloud Run services (placeholder)
Write-Host "☁️ Setting up Cloud Run services..." -ForegroundColor Yellow
Write-Host "Cloud Run services will be deployed in subsequent tasks"

# Create Cloud Functions (placeholder)
Write-Host "⚡ Setting up Cloud Functions..." -ForegroundColor Yellow
Write-Host "Cloud Functions will be deployed in subsequent tasks"

# Set up monitoring
Write-Host "📊 Setting up monitoring..." -ForegroundColor Yellow
Write-Host "Monitoring dashboards and alerts will be configured in subsequent tasks"

Write-Host
Write-Host "🎉 GCP setup completed successfully!" -ForegroundColor Green
Write-Host
Write-Host "📝 Next Steps:" -ForegroundColor Blue
Write-Host "1. Verify the service account key is properly placed in: $keyFile"
Write-Host "2. Update your environment variables if needed"
Write-Host "3. Test the configuration by running the Flutter app"
Write-Host "4. Proceed with implementing the AI services"
Write-Host
Write-Host "⚠️ Security Note:" -ForegroundColor Yellow
Write-Host "- Never commit service account keys to version control"
Write-Host "- Add service account files to .gitignore"
Write-Host "- Use environment variables or secret management in production"
Write-Host
Write-Host "📚 Documentation:" -ForegroundColor Blue
Write-Host "- GCP Console: https://console.cloud.google.com/home/dashboard?project=$ProjectId"
Write-Host "- Service Account: https://console.cloud.google.com/iam-admin/serviceaccounts?project=$ProjectId"
Write-Host "- APIs & Services: https://console.cloud.google.com/apis/dashboard?project=$ProjectId"