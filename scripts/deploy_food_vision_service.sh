#!/bin/bash

# Deploy Food Vision Service to Google Cloud Run
# This script builds and deploys the food vision recognition service

set -e

echo "🍎 Deploying Food Vision Service to Google Cloud Run..."

# Configuration
PROJECT_ID=${GCP_PROJECT_ID:-"nutrisync-ai-project"}
REGION=${GCP_REGION:-"us-central1"}
SERVICE_NAME="food-vision-service"
SERVICE_DIR="cloud_services/food_vision_service"

# Check if we're in the right directory
if [ ! -d "$SERVICE_DIR" ]; then
    echo "❌ Error: $SERVICE_DIR directory not found. Please run from project root."
    exit 1
fi

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo "❌ Error: gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi

# Set the project
echo "📋 Setting GCP project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "🔧 Enabling required Google Cloud APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable vision.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Build and deploy using Cloud Build
echo "🏗️ Building and deploying Food Vision Service..."
cd $SERVICE_DIR

# Submit build to Cloud Build
gcloud builds submit --config cloudbuild.yaml \
    --substitutions=_SERVICE_NAME=$SERVICE_NAME

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
    --region=$REGION \
    --format="value(status.url)")

echo "✅ Food Vision Service deployed successfully!"
echo "🌐 Service URL: $SERVICE_URL"
echo "🔍 Health check: $SERVICE_URL/health"

# Test the health endpoint
echo "🏥 Testing health endpoint..."
if curl -f "$SERVICE_URL/health" > /dev/null 2>&1; then
    echo "✅ Health check passed!"
else
    echo "⚠️ Health check failed. Service may still be starting up."
fi

echo ""
echo "📋 Service Information:"
echo "   Project ID: $PROJECT_ID"
echo "   Region: $REGION"
echo "   Service Name: $SERVICE_NAME"
echo "   Service URL: $SERVICE_URL"
echo ""
echo "🔧 Available Endpoints:"
echo "   GET  $SERVICE_URL/health - Health check"
echo "   POST $SERVICE_URL/analyze-food - Analyze food image"
echo "   POST $SERVICE_URL/analyze-food-batch - Batch analyze food images"
echo "   POST $SERVICE_URL/lookup-nutrition - Look up nutrition information"
echo "   GET  $SERVICE_URL/search-foods?query=<food> - Search food items"
echo "   POST $SERVICE_URL/validate-confidence - Validate food confidence"
echo ""
echo "🎉 Food Vision Service deployment complete!"