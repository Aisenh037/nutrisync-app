# Voice-First AI Agent

This directory contains the core implementation of the Belly Buster Voice-First AI Agent, a digital dietician designed specifically for the Indian middle class.

## Architecture Overview

The Voice-First AI Agent follows a microservices architecture with the following components:

### Voice Components (`/voice/`)
- **VoiceInterface**: Handles speech-to-text and text-to-speech with ElevenLabs
- **ConversationContextManager**: Session management and context preservation
- **HinglishProcessor**: Processes mixed Hindi-English language inputs with food extraction

### Nutrition Components (`/nutrition/`)
- **NutritionIntelligenceCore**: Central orchestrator for nutrition services
- **MealLoggerService**: Automated meal tracking and nutritional calculation
- **RecommendationEngine**: Personalized meal and nutrition recommendations

### Cultural Components (`/cultural/`)
- **CulturalContextEngine**: Understands Indian food context and cooking methods
- **IndianFoodDatabase**: Comprehensive nutritional database for Indian foods

### Services (`/services/`)
- **VoiceFirstAIService**: Main service coordinator
- **GroceryManagerService**: Shopping list generation and management
- **CalendarIntegrationService**: Meal timing and scheduling

## Key Features

1. **Voice-First Interaction**: Sub-3-second response times in Hinglish
2. **Cultural Awareness**: Deep understanding of Indian dietary patterns
3. **Automated Meal Logging**: Voice-based meal tracking with nutrition calculation
4. **Personalized Recommendations**: Based on user goals and medical conditions
5. **Grocery Management**: Automatic shopping list generation
6. **Calendar Integration**: Schedule-aware meal planning

## Configuration

See `config.dart` for all configuration constants including:
- ElevenLabs API settings
- Indian measurement units
- Subscription pricing
- Nutrition targets

## Usage

Import the main components using:

```dart
import 'package:nutrisync/voice_first_ai/index.dart';
```

## Implementation Status

### Completed Components ✅
- **Voice Interface Layer**: Complete with ElevenLabs integration (28 tests passing)
- **Conversation Context Management**: Full session and interruption handling (25 tests passing)
- **Cultural Context Engine**: Indian food understanding and cooking methods (25 tests passing)
- **Indian Food Database**: Comprehensive Firestore integration (7 tests passing)
- **Hinglish Processor**: Mixed language parsing and food extraction (20 tests passing)

### Total Test Coverage: 105 tests passing

### Next Steps
- Meal Logger Service implementation
- Nutrition Intelligence Core development
- Recommendation Engine creation

Individual components are implemented according to the plan in `.kiro/specs/voice-first-ai-agent/tasks.md`.