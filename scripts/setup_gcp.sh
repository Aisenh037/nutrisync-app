#!/bin/bash

# NutriSync GCP Setup Script
# This script helps set up Google Cloud Platform services for NutriSync

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_PROJECT_ID="nutrisync-gcp-dev"
DEFAULT_REGION="us-central1"
SERVICE_ACCOUNT_NAME="nutrisync-ai-service"

echo -e "${BLUE}🚀 NutriSync GCP Setup${NC}"
echo "This script will help you set up Google Cloud Platform services for NutriSync"
echo

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Google Cloud CLI (gcloud) is not installed${NC}"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get project ID
read -p "Enter GCP Project ID (default: $DEFAULT_PROJECT_ID): " PROJECT_ID
PROJECT_ID=${PROJECT_ID:-$DEFAULT_PROJECT_ID}

# Get region
read -p "Enter GCP Region (default: $DEFAULT_REGION): " REGION
REGION=${REGION:-$DEFAULT_REGION}

# Get environment
echo "Select environment:"
echo "1) development"
echo "2) staging"
echo "3) production"
read -p "Enter choice (1-3): " ENV_CHOICE

case $ENV_CHOICE in
    1) ENVIRONMENT="development" ;;
    2) ENVIRONMENT="staging" ;;
    3) ENVIRONMENT="production" ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
esac

echo
echo -e "${YELLOW}📋 Configuration Summary:${NC}"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo

read -p "Continue with this configuration? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Setup cancelled"
    exit 0
fi

echo
echo -e "${BLUE}🔧 Setting up GCP project...${NC}"

# Set the project
echo "Setting project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo -e "${YELLOW}📡 Enabling required APIs...${NC}"
APIS=(
    "speech.googleapis.com"
    "texttospeech.googleapis.com"
    "vision.googleapis.com"
    "translate.googleapis.com"
    "dialogflow.googleapis.com"
    "maps-backend.googleapis.com"
    "places-backend.googleapis.com"
    "run.googleapis.com"
    "cloudfunctions.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    "monitoring.googleapis.com"
    "logging.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo "Enabling $api..."
    gcloud services enable $api
done

echo -e "${GREEN}✅ APIs enabled successfully${NC}"

# Create service account
echo -e "${YELLOW}👤 Creating service account...${NC}"
SERVICE_ACCOUNT_EMAIL="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# Check if service account already exists
if gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL &>/dev/null; then
    echo "Service account $SERVICE_ACCOUNT_EMAIL already exists"
else
    echo "Creating service account: $SERVICE_ACCOUNT_NAME"
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --display-name="NutriSync AI Service Account" \
        --description="Service account for NutriSync AI services"
fi

# Grant required roles
echo -e "${YELLOW}🔐 Granting IAM roles...${NC}"
ROLES=(
    "roles/speech.client"
    "roles/texttospeech.client"
    "roles/vision.client"
    "roles/translate.client"
    "roles/dialogflow.client"
    "roles/maps.client"
    "roles/places.client"
    "roles/run.invoker"
    "roles/cloudfunctions.invoker"
    "roles/monitoring.viewer"
    "roles/logging.viewer"
)

for role in "${ROLES[@]}"; do
    echo "Granting role: $role"
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="$role"
done

echo -e "${GREEN}✅ IAM roles granted successfully${NC}"

# Create and download service account key
echo -e "${YELLOW}🔑 Creating service account key...${NC}"
KEY_FILE="assets/config/gcp/service-account-$ENVIRONMENT.json"

# Create the directory if it doesn't exist
mkdir -p "assets/config/gcp"

# Generate the key
gcloud iam service-accounts keys create $KEY_FILE \
    --iam-account=$SERVICE_ACCOUNT_EMAIL

echo -e "${GREEN}✅ Service account key created: $KEY_FILE${NC}"

# Update environment configuration
echo -e "${YELLOW}⚙️ Updating environment configuration...${NC}"
ENV_FILE="assets/config/environments/$ENVIRONMENT.json"

# Use jq to update the project ID if available, otherwise provide manual instructions
if command -v jq &> /dev/null; then
    # Update the GCP project ID in the environment file
    jq --arg project_id "$PROJECT_ID" '.gcp.projectId = $project_id' $ENV_FILE > tmp.$$.json && mv tmp.$$.json $ENV_FILE
    echo -e "${GREEN}✅ Environment configuration updated${NC}"
else
    echo -e "${YELLOW}⚠️ jq not found. Please manually update $ENV_FILE${NC}"
    echo "Set gcp.projectId to: $PROJECT_ID"
fi

# Create Cloud Run services (placeholder)
echo -e "${YELLOW}☁️ Setting up Cloud Run services...${NC}"
echo "Cloud Run services will be deployed in subsequent tasks"

# Create Cloud Functions (placeholder)
echo -e "${YELLOW}⚡ Setting up Cloud Functions...${NC}"
echo "Cloud Functions will be deployed in subsequent tasks"

# Set up monitoring
echo -e "${YELLOW}📊 Setting up monitoring...${NC}"
echo "Monitoring dashboards and alerts will be configured in subsequent tasks"

echo
echo -e "${GREEN}🎉 GCP setup completed successfully!${NC}"
echo
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "1. Verify the service account key is properly placed in: $KEY_FILE"
echo "2. Update your environment variables if needed"
echo "3. Test the configuration by running the Flutter app"
echo "4. Proceed with implementing the AI services"
echo
echo -e "${YELLOW}⚠️ Security Note:${NC}"
echo "- Never commit service account keys to version control"
echo "- Add service account files to .gitignore"
echo "- Use environment variables or secret management in production"
echo
echo -e "${BLUE}📚 Documentation:${NC}"
echo "- GCP Console: https://console.cloud.google.com/home/dashboard?project=$PROJECT_ID"
echo "- Service Account: https://console.cloud.google.com/iam-admin/serviceaccounts?project=$PROJECT_ID"
echo "- APIs & Services: https://console.cloud.google.com/apis/dashboard?project=$PROJECT_ID"