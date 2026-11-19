# Deploy Food Vision Service to Google Cloud Run
# This script builds and deploys the food vision recognition service

param(
    [string]$ProjectId = $env:GCP_PROJECT_ID,
    [string]$Region = $env:GCP_REGION
)

# Set default values
if (-not $ProjectId) { $ProjectId = "nutrisync-ai-project" }
if (-not $Region) { $Region = "us-central1" }

$ServiceName = "food-vision-service"
$ServiceDir = "cloud_services/food_vision_service"

Write-Host "🍎 Deploying Food Vision Service to Google Cloud Run..." -ForegroundColor Green

# Check if we're in the right directory
if (-not (Test-Path $ServiceDir)) {
    Write-Host "❌ Error: $ServiceDir directory not found. Please run from project root." -ForegroundColor Red
    exit 1
}

# Check if gcloud is installed
try {
    $null = Get-Command gcloud -ErrorAction Stop
} catch {
    Write-Host "❌ Error: gcloud CLI not found. Please install Google Cloud SDK." -ForegroundColor Red
    exit 1
}

# Set the project
Write-Host "📋 Setting GCP project to $ProjectId..." -ForegroundColor Yellow
gcloud config set project $ProjectId

# Enable required APIs
Write-Host "🔧 Enabling required Google Cloud APIs..." -ForegroundColor Yellow
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable vision.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Build and deploy using Cloud Build
Write-Host "🏗️ Building and deploying Food Vision Service..." -ForegroundColor Yellow
Set-Location $ServiceDir

# Submit build to Cloud Build
gcloud builds submit --config cloudbuild.yaml --substitutions=_SERVICE_NAME=$ServiceName

# Get the service URL
$ServiceUrl = gcloud run services describe $ServiceName --region=$Region --format="value(status.url)"

Write-Host "✅ Food Vision Service deployed successfully!" -ForegroundColor Green
Write-Host "🌐 Service URL: $ServiceUrl" -ForegroundColor Cyan
Write-Host "🔍 Health check: $ServiceUrl/health" -ForegroundColor Cyan

# Test the health endpoint
Write-Host "🏥 Testing health endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$ServiceUrl/health" -Method Get -TimeoutSec 30
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Health check passed!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Health check returned status: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Health check failed. Service may still be starting up." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📋 Service Information:" -ForegroundColor Cyan
Write-Host "   Project ID: $ProjectId"
Write-Host "   Region: $Region"
Write-Host "   Service Name: $ServiceName"
Write-Host "   Service URL: $ServiceUrl"
Write-Host ""
Write-Host "🔧 Available Endpoints:" -ForegroundColor Cyan
Write-Host "   GET  $ServiceUrl/health - Health check"
Write-Host "   POST $ServiceUrl/analyze-food - Analyze food image"
Write-Host "   POST $ServiceUrl/analyze-food-batch - Batch analyze food images"
Write-Host "   POST $ServiceUrl/lookup-nutrition - Look up nutrition information"
Write-Host "   GET  $ServiceUrl/search-foods?query=<food> - Search food items"
Write-Host "   POST $ServiceUrl/validate-confidence - Validate food confidence"
Write-Host ""
Write-Host "🎉 Food Vision Service deployment complete!" -ForegroundColor Green

# Return to original directory
Set-Location ../..