# Deploy Voice AI Service to Cloud Run
# This script builds and deploys the enhanced voice AI service

param(
    [string]$ProjectId = $env:GCP_PROJECT_ID,
    [string]$Region = $env:GCP_REGION
)

# Set default values if not provided
if (-not $ProjectId) { $ProjectId = "nutrisync-gcp-dev" }
if (-not $Region) { $Region = "us-central1" }

$ServiceName = "voice-ai-service"
$ImageName = "gcr.io/$ProjectId/$ServiceName"

Write-Host "🚀 Deploying Voice AI Service to Cloud Run" -ForegroundColor Green
Write-Host "Project ID: $ProjectId"
Write-Host "Region: $Region"
Write-Host "Service Name: $ServiceName"
Write-Host ""

# Check if gcloud is installed
try {
    $null = Get-Command gcloud -ErrorAction Stop
} catch {
    Write-Host "❌ gcloud CLI is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Check if user is authenticated
$activeAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
if (-not $activeAccount) {
    Write-Host "❌ Not authenticated with gcloud. Please run 'gcloud auth login'" -ForegroundColor Red
    exit 1
}

# Set the project
Write-Host "📋 Setting project to $ProjectId" -ForegroundColor Yellow
gcloud config set project $ProjectId

# Enable required APIs
Write-Host "🔧 Enabling required APIs" -ForegroundColor Yellow
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable speech.googleapis.com
gcloud services enable texttospeech.googleapis.com
gcloud services enable translate.googleapis.com

# Build and push the Docker image
Write-Host "🏗️ Building Docker image" -ForegroundColor Yellow
Set-Location cloud_services/voice_ai_service

# Build the image
docker build -t "${ImageName}:latest" .

# Push to Container Registry
Write-Host "📤 Pushing image to Container Registry" -ForegroundColor Yellow
docker push "${ImageName}:latest"

# Deploy to Cloud Run
Write-Host "🚀 Deploying to Cloud Run" -ForegroundColor Yellow
gcloud run deploy $ServiceName `
    --image "${ImageName}:latest" `
    --region $Region `
    --platform managed `
    --allow-unauthenticated `
    --memory 512Mi `
    --cpu 1 `
    --max-instances 10 `
    --timeout 300 `
    --set-env-vars "GCP_PROJECT_ID=$ProjectId" `
    --set-env-vars "GCP_REGION=$Region" `
    --set-env-vars "STT_LANGUAGE_CODE=en-US" `
    --set-env-vars "TTS_LANGUAGE_CODE=en-US" `
    --set-env-vars "TTS_VOICE_NAME=en-US-Neural2-F" `
    --set-env-vars "SUPPORTED_LANGUAGES=en,hi,es,fr" `
    --set-env-vars "PORT=8080"

# Get the service URL
$ServiceUrl = gcloud run services describe $ServiceName --region $Region --format 'value(status.url)'

Write-Host ""
Write-Host "✅ Voice AI Service deployed successfully!" -ForegroundColor Green
Write-Host "🌐 Service URL: $ServiceUrl" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Yellow
Write-Host "1. Test the service: curl $ServiceUrl/health"
Write-Host "2. Update your Flutter app configuration with the service URL"
Write-Host "3. Configure authentication if needed"
Write-Host ""

# Test the health endpoint
Write-Host "🔍 Testing health endpoint" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$ServiceUrl/health" -Method Get -TimeoutSec 10
    if ($response -match "healthy") {
        Write-Host "✅ Health check passed" -ForegroundColor Green
    } else {
        Write-Host "❌ Health check failed" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "🎉 Deployment complete!" -ForegroundColor Green

# Return to original directory
Set-Location ../..