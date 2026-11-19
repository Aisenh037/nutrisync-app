# Food Vision Service

A Google Cloud Run service that provides food recognition and nutrition analysis using GCP Vision API and nutrition databases.

## Features

- **Food Detection**: Uses GCP Vision API to identify food items in images
- **Portion Estimation**: Estimates portion sizes based on visual analysis
- **Nutrition Analysis**: Provides detailed nutrition information from USDA and local databases
- **Multi-food Detection**: Handles multiple food items in a single image
- **Confidence Scoring**: Provides confidence scores for food identification
- **User Validation**: Allows users to confirm or correct food identification
- **Batch Processing**: Supports analyzing multiple images simultaneously

## API Endpoints

### Health Check
- **GET** `/health` - Service health status

### Food Analysis
- **POST** `/analyze-food` - Analyze a single food image
- **POST** `/analyze-food-batch` - Analyze multiple food images

### Nutrition Services
- **POST** `/lookup-nutrition` - Look up nutrition information for a food item
- **GET** `/search-foods` - Search for food items in the database

### Validation
- **POST** `/validate-confidence` - Validate food identification with user feedback

## Request/Response Examples

### Analyze Food Image

**Request:**
```json
{
  "imageContent": "base64-encoded-image-data",
  "userId": "user123",
  "context": {"source": "mobile_app"},
  "confidenceThreshold": 0.7
}
```

**Response:**
```json
{
  "detectedFoods": [
    {
      "name": "Apple",
      "category": "Fruits",
      "confidence": 0.95,
      "portionEstimate": {
        "estimatedGrams": 150.0,
        "portionSize": "1 medium fruit",
        "confidence": 0.8,
        "method": "visual_estimation"
      },
      "nutritionInfo": {
        "calories": 78.0,
        "protein": 0.45,
        "carbohydrates": 21.0,
        "fat": 0.3,
        "fiber": 3.6,
        "sugar": 15.0,
        "sodium": 1.5,
        "vitamins": {"vitamin_c": 15.0},
        "minerals": {"iron": 0.75},
        "source": "USDA"
      },
      "boundingBox": {
        "x": 0.1,
        "y": 0.2,
        "width": 0.3,
        "height": 0.4
      },
      "alternativeNames": ["seb", "सेब"]
    }
  ],
  "isFood": true,
  "overallConfidence": 0.95,
  "metadata": {
    "total_objects": 1,
    "total_labels": 5,
    "food_labels": 3,
    "enhanced_nutrition": true,
    "processing_time": "2024-01-08T10:30:00Z"
  }
}
```

### Nutrition Lookup

**Request:**
```json
{
  "foodName": "apple",
  "portionGrams": 150.0,
  "portionDescription": "1 medium fruit"
}
```

**Response:**
```json
{
  "nutritionInfo": {
    "calories": 78.0,
    "protein": 0.45,
    "carbohydrates": 21.0,
    "fat": 0.3,
    "fiber": 3.6,
    "sugar": 15.0,
    "sodium": 1.5,
    "vitamins": {"vitamin_c": 15.0},
    "minerals": {"iron": 0.75},
    "source": "USDA"
  },
  "matchedFoods": ["apple", "red apple", "green apple"],
  "confidence": 0.9
}
```

## Configuration

### Environment Variables

- `GCP_PROJECT_ID` - Google Cloud Project ID
- `GCP_REGION` - Google Cloud Region (default: us-central1)
- `GOOGLE_APPLICATION_CREDENTIALS` - Path to service account key file
- `GOOGLE_APPLICATION_CREDENTIALS_JSON` - Service account key as JSON string
- `USDA_API_KEY` - USDA FoodData Central API key (optional)
- `PORT` - Server port (default: 8080)

### Service Account Permissions

The service account needs the following permissions:
- `vision.images.annotate` - For Vision API access
- `cloudsql.client` - If using Cloud SQL for nutrition database
- `storage.objects.get` - If storing images in Cloud Storage

## Deployment

### Using Cloud Build

```bash
# Deploy to Cloud Run
gcloud builds submit --config cloudbuild.yaml

# Or use the deployment script
./scripts/deploy_food_vision_service.sh
```

### Manual Deployment

```bash
# Build the container
docker build -t gcr.io/PROJECT_ID/food-vision-service .

# Push to Container Registry
docker push gcr.io/PROJECT_ID/food-vision-service

# Deploy to Cloud Run
gcloud run deploy food-vision-service \
  --image gcr.io/PROJECT_ID/food-vision-service \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated
```

## Development

### Local Development

```bash
# Install dependencies
dart pub get

# Generate JSON serialization code
dart run build_runner build

# Run the server
dart run bin/server.dart
```

### Testing

```bash
# Run all tests
dart test

# Run specific test file
dart test test/services/gcp_vision_service_test.dart
```

## Architecture

### Components

1. **GCP Vision Service** - Handles Vision API integration
2. **Nutrition Database Service** - Manages nutrition data lookup
3. **Food Vision Service** - Main service orchestrator
4. **Server** - HTTP server with REST API endpoints

### Data Flow

1. Client sends image data to `/analyze-food` endpoint
2. Service decodes base64 image and sends to Vision API
3. Vision API returns object detection and label results
4. Service processes results to identify food items
5. Service estimates portion sizes based on bounding boxes
6. Service looks up nutrition information from databases
7. Service returns comprehensive food analysis to client

### Nutrition Data Sources

1. **USDA FoodData Central** - Primary nutrition database
2. **Local Database** - Common Indian and international foods
3. **Default Values** - Fallback nutrition estimates

## Error Handling

The service implements comprehensive error handling:

- **Network Errors** - Graceful degradation with fallback responses
- **API Limits** - Rate limiting and retry mechanisms
- **Invalid Images** - Proper error messages for non-food images
- **Missing Data** - Default nutrition values when lookup fails

## Performance

- **Concurrent Processing** - Handles multiple requests simultaneously
- **Batch Operations** - Efficient processing of multiple images
- **Caching** - Nutrition data caching for frequently accessed foods
- **Resource Limits** - Configurable memory and CPU limits

## Security

- **Authentication** - Service account authentication for GCP APIs
- **Input Validation** - Validates all input parameters
- **Rate Limiting** - Prevents abuse and manages costs
- **Error Sanitization** - Prevents information leakage in error messages

## Monitoring

The service provides health checks and logging:

- **Health Endpoint** - `/health` for service monitoring
- **Structured Logging** - JSON logs for Cloud Logging
- **Error Tracking** - Comprehensive error logging with stack traces
- **Performance Metrics** - Request timing and success rates

## Cost Optimization

- **Efficient API Usage** - Minimizes Vision API calls
- **Smart Caching** - Reduces database lookups
- **Resource Management** - Optimized container resource usage
- **Batch Processing** - Reduces per-request overhead