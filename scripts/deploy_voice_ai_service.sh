#!/bin/bash

# Deploy Voice AI Service to Cloud Run
# This script builds and deploys the enhanced voice AI service

set -e

# Configuration
PROJECT_ID=${GCP_PROJECT_ID:-"nutrisync-gcp-dev"}
REGION=${GCP_REGION:-"us-central1"}
SERVICE_NAME="voice-ai-service"
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Deploying Voice AI Service to Cloud Run${NC}"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Service Name: $SERVICE_NAME"
echo ""

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}❌ Not authenticated with gcloud. Please run 'gcloud auth login'${NC}"
    exit 1
fi

# Set the project
echo -e "${YELLOW}📋 Setting project to $PROJECT_ID${NC}"
gcloud config set project $PROJECT_ID

# Enable required APIs
echo -e "${YELLOW}🔧 Enabling required APIs${NC}"
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable speech.googleapis.com
gcloud services enable texttospeech.googleapis.com
gcloud services enable translate.googleapis.com

# Build and push the Docker image
echo -e "${YELLOW}🏗️  Building Docker image${NC}"
cd cloud_services/voice_ai_service

# Build the image
docker build -t $IMAGE_NAME:latest .

# Push to Container Registry
echo -e "${YELLOW}📤 Pushing image to Container Registry${NC}"
docker push $IMAGE_NAME:latest

# Deploy to Cloud Run
echo -e "${YELLOW}🚀 Deploying to Cloud Run${NC}"
gcloud run deploy $SERVICE_NAME \
    --image $IMAGE_NAME:latest \
    --region $REGION \
    --platform managed \
    --allow-unauthenticated \
    --memory 512Mi \
    --cpu 1 \
    --max-instances 10 \
    --timeout 300 \
    --set-env-vars "GCP_PROJECT_ID=$PROJECT_ID" \
    --set-env-vars "GCP_REGION=$REGION" \
    --set-env-vars "STT_LANGUAGE_CODE=en-US" \
    --set-env-vars "TTS_LANGUAGE_CODE=en-US" \
    --set-env-vars "TTS_VOICE_NAME=en-US-Neural2-F" \
    --set-env-vars "SUPPORTED_LANGUAGES=en,hi,es,fr" \
    --set-env-vars "PORT=8080"

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')

echo ""
echo -e "${GREEN}✅ Voice AI Service deployed successfully!${NC}"
echo -e "${GREEN}🌐 Service URL: $SERVICE_URL${NC}"
echo ""
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "1. Test the service: curl $SERVICE_URL/health"
echo "2. Update your Flutter app configuration with the service URL"
echo "3. Configure authentication if needed"
echo ""

# Test the health endpoint
echo -e "${YELLOW}🔍 Testing health endpoint${NC}"
if curl -s "$SERVICE_URL/health" | grep -q "healthy"; then
    echo -e "${GREEN}✅ Health check passed${NC}"
else
    echo -e "${RED}❌ Health check failed${NC}"
fi

echo -e "${GREEN}🎉 Deployment complete!${NC}"