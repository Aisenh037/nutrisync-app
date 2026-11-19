# Voice AI Service - Cloud Run

Enhanced voice processing service for NutriSync using Google Cloud Platform Speech-to-Text and Text-to-Speech APIs.

## Features

- **Enhanced Speech-to-Text**: High-accuracy speech recognition with nutrition-specific vocabulary
- **Natural Text-to-Speech**: Multi-language voice synthesis with natural-sounding voices
- **Complete Voice Processing**: End-to-end voice interaction processing (STT + NLP + TTS)
- **Language Detection**: Automatic language detection for multi-language support
- **Nutrition Vocabulary**: Specialized vocabulary for food and nutrition terms
- **Scalable Architecture**: Cloud Run deployment with automatic scaling

## API Endpoints

### Health Check
```
GET /health
```
Returns service health status.

### Speech-to-Text
```
POST /speech-to-text
Content-Type: application/json

{
  "audioContent": "base64-encoded-audio",
  "languageCode": "en-US",
  "speechContexts": ["dal", "chawal", "roti"]
}
```

### Text-to-Speech
```
POST /text-to-speech
Content-Type: application/json

{
  "text": "Hello, how can I help you with nutrition today?",
  "languageCode": "en-US",
  "voiceName": "en-US-Neural2-F"
}
```

### Enhanced Voice Processing
```
POST /process-voice
Content-Type: application/json

{
  "audioContent": "base64-encoded-audio",
  "userId": "user123",
  "sessionId": "session456",
  "languageCode": "en-US",
  "context": {
    "userPreferences": {},
    "recentMeals": []
  }
}
```

### Language Detection
```
POST /detect-language
Content-Type: application/json

{
  "text": "Sample text for language detection"
}
```

### Nutrition Vocabulary
```
GET /nutrition-vocabulary
```
Returns the complete nutrition vocabulary used for speech context.

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GCP_PROJECT_ID` | Google Cloud Project ID | `nutrisync-gcp-dev` |
| `GCP_REGION` | GCP Region | `us-central1` |
| `STT_LANGUAGE_CODE` | Speech-to-Text language | `en-US` |
| `STT_MODEL` | Speech recognition model | `latest_long` |
| `STT_USE_ENHANCED` | Use enhanced model | `true` |
| `TTS_LANGUAGE_CODE` | Text-to-Speech language | `en-US` |
| `TTS_VOICE_NAME` | Voice name | `en-US-Neural2-F` |
| `TTS_AUDIO_ENCODING` | Audio encoding | `MP3` |
| `SUPPORTED_LANGUAGES` | Comma-separated languages | `en,hi,es,fr` |
| `PORT` | Server port | `8080` |

### Service Account

The service requires a Google Cloud service account with the following permissions:
- Cloud Speech API
- Cloud Text-to-Speech API
- Cloud Translation API (optional)

Set the service account credentials as:
```bash
export GOOGLE_APPLICATION_CREDENTIALS_JSON='{"type":"service_account",...}'
```

## Deployment

### Prerequisites

1. Google Cloud SDK installed and authenticated
2. Docker installed
3. Required GCP APIs enabled:
   - Cloud Run API
   - Cloud Build API
   - Container Registry API
   - Cloud Speech API
   - Cloud Text-to-Speech API

### Deploy to Cloud Run

#### Using the deployment script (recommended):

**Linux/macOS:**
```bash
./scripts/deploy_voice_ai_service.sh
```

**Windows:**
```powershell
.\scripts\deploy_voice_ai_service.ps1
```

#### Manual deployment:

1. Build the Docker image:
```bash
cd cloud_services/voice_ai_service
docker build -t gcr.io/YOUR_PROJECT_ID/voice-ai-service .
```

2. Push to Container Registry:
```bash
docker push gcr.io/YOUR_PROJECT_ID/voice-ai-service
```

3. Deploy to Cloud Run:
```bash
gcloud run deploy voice-ai-service \
  --image gcr.io/YOUR_PROJECT_ID/voice-ai-service \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10
```

### Using Cloud Build

Deploy using the included `cloudbuild.yaml`:

```bash
gcloud builds submit --config cloudbuild.yaml
```

## Development

### Local Development

1. Install dependencies:
```bash
dart pub get
```

2. Set environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. Run the service:
```bash
dart run bin/server.dart
```

The service will be available at `http://localhost:8080`.

### Testing

Test the service endpoints:

```bash
# Health check
curl http://localhost:8080/health

# Get nutrition vocabulary
curl http://localhost:8080/nutrition-vocabulary
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │───▶│  Cloud Run       │───▶│  GCP APIs       │
│                 │    │  Voice AI        │    │                 │
│ - Voice Input   │    │  Service         │    │ - Speech-to-Text│
│ - Audio Playback│    │                  │    │ - Text-to-Speech│
│ - UI Integration│    │ - STT Processing │    │ - Translation   │
└─────────────────┘    │ - TTS Generation │    └─────────────────┘
                       │ - NLP Processing │
                       │ - Context Mgmt   │
                       └──────────────────┘
```

## Nutrition Vocabulary

The service includes specialized vocabulary for:
- Indian foods (dal, chawal, roti, sabzi, etc.)
- International foods (rice, bread, chicken, etc.)
- Vegetables and fruits
- Measurements (cup, tablespoon, gram, etc.)
- Cooking methods (boiled, fried, grilled, etc.)
- Hinglish phrases (khaya, thoda, zyada, etc.)

## Performance

- **Response Time**: < 3 seconds for complete voice processing
- **Accuracy**: 95%+ for nutrition-related speech
- **Scalability**: Auto-scaling from 0 to 10 instances
- **Memory**: 512Mi per instance
- **CPU**: 1 vCPU per instance

## Monitoring

The service includes:
- Health check endpoint for monitoring
- Structured logging for debugging
- Error handling with detailed error messages
- Request/response logging for analysis

## Security

- Service account authentication for GCP APIs
- Input validation for all endpoints
- Rate limiting (handled by Cloud Run)
- CORS support for web clients

## Troubleshooting

### Common Issues

1. **Authentication errors**: Ensure service account has proper permissions
2. **Audio format issues**: Ensure audio is properly base64 encoded
3. **Language detection failures**: Check supported languages configuration
4. **High latency**: Monitor Cloud Run metrics and adjust resources

### Logs

View service logs:
```bash
gcloud logs read --service=voice-ai-service --limit=50
```

### Health Check

The service provides a health endpoint that returns:
```json
{
  "status": "healthy",
  "service": "voice-ai"
}
```