# NutriSync - Voice-First AI Nutrition Assistant

[![CI/CD Pipeline](https://github.com/yourusername/nutrisync/actions/workflows/main.yml/badge.svg)](https://github.com/yourusername/nutrisync/actions/workflows/main.yml)
[![codecov](https://codecov.io/gh/yourusername/nutrisync/branch/main/graph/badge.svg)](https://codecov.io/gh/yourusername/nutrisync)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive nutrition assistant app built with Flutter, featuring voice-first AI interactions, personalized meal recommendations, and cultural food intelligence specifically designed for Indian dietary patterns.

## 🌟 Features

### Core Functionality
- **Voice-First AI Assistant**: Natural language processing for nutrition queries in English and Hinglish
- **Personalized Meal Recommendations**: AI-powered suggestions based on health goals, dietary restrictions, and cultural preferences
- **Indian Food Intelligence**: Comprehensive database of Indian foods with regional variations and cooking methods
- **Meal Logging & Tracking**: Easy meal logging with nutrition analysis and progress tracking
- **Cultural Cooking Education**: Traditional Indian cooking tips with healthier alternatives

### Technical Features
- **Cross-Platform**: Flutter app for iOS, Android, and Web
- **Real-time Sync**: Firebase backend with real-time data synchronization
- **Offline Support**: Local data caching for offline functionality
- **Multi-language Support**: English and Hinglish language processing
- **Subscription Management**: Freemium model with premium features

## 🚀 Live Demo

- **Web App**: [https://nutrisyncapp-97089.web.app](https://nutrisyncapp-97089.web.app)
- **Android**: Available on Google Play Store (coming soon)
- **iOS**: Available on App Store (coming soon)

## 🛠️ Technology Stack

- **Frontend**: Flutter 3.24.0+ (Dart)
- **Backend**: Firebase (Firestore, Cloud Functions, Authentication, Storage)
- **AI/ML**: OpenAI GPT, Google Gemini (configurable)
- **Voice Processing**: Flutter Speech-to-Text/Text-to-Speech
- **State Management**: Riverpod
- **Testing**: Unit, Widget, and Integration tests with Property-Based Testing
- **CI/CD**: GitHub Actions with multi-platform deployment
- **Deployment**: Firebase Hosting (Web), Google Play Store (Android), App Store (iOS)

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24.0 or later)
- [Dart SDK](https://dart.dev/get-dart) (3.5.0 or later)
- [Node.js](https://nodejs.org/) (18.0 or later) - for Firebase Functions
- [Firebase CLI](https://firebase.google.com/docs/cli) - for deployment
- [Android Studio](https://developer.android.com/studio) - for Android development
- [Xcode](https://developer.apple.com/xcode/) (15.0 or later) - for iOS development (macOS only)
- [CocoaPods](https://cocoapods.org/) - for iOS dependency management (macOS only)
- [Xcode](https://developer.apple.com/xcode/) - for iOS development (macOS only)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/nutrisync.git
cd nutrisync
```

### 2. Install Dependencies

```bash
# Flutter dependencies
flutter pub get

# Firebase Functions dependencies
cd functions
npm install
cd ..
```

### 3. Configure Firebase

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable the following services:
   - Authentication (Email/Password, Google Sign-In)
   - Firestore Database
   - Cloud Storage
   - Cloud Functions
   - Firebase Hosting

3. Copy configuration files:
```bash
# Copy example configuration files
cp config/secrets/.env.example .env
cp config/secrets/firebase-config.example.js web/firebase-config.js
cp config/secrets/google-services.example.json android/app/google-services.json
```

4. Update the configuration files with your Firebase project details

### 4. Generate Firebase Options

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Generate Firebase options for Flutter
flutterfire configure
```

### 5. Set Up Firestore Security Rules

```bash
# Deploy Firestore rules and indexes
firebase deploy --only firestore:rules,firestore:indexes
```

### 6. Run the Application

```bash
# Run on web
flutter run -d chrome

# Run on Android (with device/emulator connected)
flutter run -d android

# Run on iOS (macOS only, with device/simulator)
flutter run -d ios
```

## 🔧 Development Setup

### Environment Configuration

The app supports multiple environments (development, staging, production). Configure environment-specific settings in:

- `config/environments/development.json`
- `config/environments/staging.json`
- `config/environments/production.json`

### Firebase Functions Development

```bash
cd functions

# Install dependencies
npm install

# Run functions locally
npm run serve

# Deploy functions
firebase deploy --only functions
```

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run Firebase Functions tests
cd functions
npm test
```

### Code Quality

```bash
# Run Flutter analyzer
flutter analyze

# Format code
flutter format .

# Run linting
cd functions
npm run lint
```

## 📱 Building for Production

### Web Deployment

```bash
# Build web app
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### Android Deployment

1. Configure app signing in `android/app/build.gradle`
2. Build release APK/AAB:

```bash
# Build APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

### iOS Deployment

```bash
# Build iOS app
flutter build ios --release
```

## 🔐 Security & Secrets Management

### Local Development

1. Copy `.env.example` to `.env` and fill in your values
2. Never commit actual secrets to version control
3. Use the provided example files as templates

### CI/CD Secrets

For GitHub Actions deployment, configure these repository secrets:

- `FIREBASE_SERVICE_ACCOUNT_DEV`
- `FIREBASE_SERVICE_ACCOUNT_STAGING`
- `FIREBASE_SERVICE_ACCOUNT_PROD`
- `ANDROID_KEYSTORE` (base64 encoded)
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `GOOGLE_PLAY_SERVICE_ACCOUNT`

## 🧪 Testing

The project includes comprehensive testing:

- **Unit Tests**: Core business logic testing
- **Widget Tests**: UI component testing
- **Integration Tests**: End-to-end flow testing
- **Property-Based Tests**: Correctness validation with random inputs

```bash
# Run specific test suites
flutter test test/unit/
flutter test test/widget/
flutter test test/integration/

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 📚 API Documentation

### Firebase Functions Endpoints

- `POST /generateRecommendations` - Get personalized meal recommendations
- `POST /processVoiceInteraction` - Process voice input and return response
- `POST /seedIndianFoods` - Seed database with Indian food data (admin only)
- `GET /healthCheck` - Health check endpoint

### Flutter Services

- `RecommendationEngine` - AI-powered meal recommendations
- `HinglishProcessor` - Voice and text processing for Indian languages
- `MealLoggerService` - Meal tracking and nutrition analysis
- `UserProfileService` - User profile and preferences management

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`flutter test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Code Style

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter format` to format code
- Ensure `flutter analyze` passes without warnings
- Write tests for new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase team for the comprehensive backend services
- OpenAI and Google for AI/ML capabilities
- The open-source community for various packages and tools

## 📞 Support

- **Documentation**: [Project Wiki](https://github.com/yourusername/nutrisync/wiki)
- **Issues**: [GitHub Issues](https://github.com/yourusername/nutrisync/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/nutrisync/discussions)
- **Email**: support@nutrisync.app

## 🗺️ Roadmap

- [ ] iOS App Store release
- [ ] Advanced meal planning features
- [ ] Integration with fitness trackers
- [ ] Nutritionist consultation features
- [ ] Multi-language support expansion
- [ ] Grocery delivery integration

---

Made with ❤️ for healthier eating habits in India