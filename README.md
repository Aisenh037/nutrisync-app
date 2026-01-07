# NutriSync - Voice-First AI Nutrition Assistant

[![CI/CD Pipeline](https://github.com/Aisenh037/nutrisync-app/actions/workflows/main.yml/badge.svg)](https://github.com/Aisenh037/nutrisync-app/actions/workflows/main.yml)
[![Firebase Hosting](https://img.shields.io/badge/Firebase-Hosted-orange.svg)](https://nutrisyncapp-97089.web.app)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![APK Available](https://img.shields.io/badge/APK-Download-green.svg)](https://github.com/Aisenh037/nutrisync-app/releases)

A comprehensive nutrition assistant app built with Flutter, featuring voice-first AI interactions, personalized meal recommendations, and cultural food intelligence specifically designed for Indian dietary patterns.

## 🌟 Features

### Core Functionality
- **Voice-First AI Assistant**: Natural language processing for nutrition queries in English and Hinglish
- **Personalized Meal Recommendations**: AI-powered suggestions based on health goals, dietary restrictions, and cultural preferences
- **Indian Food Intelligence**: Comprehensive database of Indian foods with regional variations and cooking methods
- **Meal Logging & Tracking**: Easy meal logging with nutrition analysis and progress tracking
- **Cultural Cooking Education**: Traditional Indian cooking tips with healthier alternatives
- **Calendar Integration**: Meal planning with calendar sync
- **Email Notifications**: Meal reminders and nutrition reports
- **Grocery Management**: Smart shopping lists based on meal plans

### Technical Features
- **Cross-Platform**: Flutter app for iOS, Android, and Web
- **Real-time Sync**: Firebase backend with real-time data synchronization
- **Offline Support**: Local data caching for offline functionality
- **Multi-language Support**: English and Hinglish language processing
- **Voice Processing**: Advanced speech-to-text and text-to-speech
- **AI Integration**: OpenAI GPT and Google Gemini support
- **Subscription Management**: Freemium model with premium features

## 🚀 Live Demo & Downloads

### **🌐 Web App (Live)**
- **URL**: [https://nutrisyncapp-97089.web.app](https://nutrisyncapp-97089.web.app)
- **Status**: ✅ Live and fully functional
- **Features**: Full app experience in your browser

### **📱 Android APK (Direct Download)**
- **Status**: ✅ Available for direct installation
- **Download**: [Latest Release](https://github.com/Aisenh037/nutrisync-app/releases)
- **No Play Store Required**: Install directly on any Android device
- **File Size**: ~15-25 MB (depending on architecture)

### **🍎 iOS App**
- **Status**: 🔄 In development
- **Distribution**: TestFlight (coming soon)

### **📦 APK Installation Guide**
1. **Download APK**: Get the latest APK from [GitHub Releases](https://github.com/Aisenh037/nutrisync-app/releases)
2. **Enable Unknown Sources**: Android Settings → Security → Unknown Sources → Enable
3. **Install**: Tap the downloaded APK file and follow prompts
4. **Launch**: Open NutriSync and start your nutrition journey!

## 🛠️ Technology Stack

- **Frontend**: Flutter 3.24.0+ (Dart 3.5.0+)
- **Backend**: Firebase (Firestore, Cloud Functions, Authentication, Storage, Hosting)
- **AI/ML**: OpenAI GPT, Google Gemini (configurable)
- **Voice Processing**: Flutter Speech-to-Text/Text-to-Speech with record package
- **State Management**: Riverpod
- **Testing**: Unit, Widget, Integration tests with Property-Based Testing
- **CI/CD**: GitHub Actions with multi-platform deployment
- **Deployment**: 
  - **Web**: Firebase Hosting (✅ Live)
  - **Android**: Direct APK distribution (✅ Available)
  - **iOS**: TestFlight (🔄 In Progress)

## 📊 Project Status

### ✅ **Completed Features**
- **Core App**: Voice-first AI nutrition assistant
- **Firebase Integration**: Authentication, Firestore, Cloud Functions
- **Voice Processing**: Speech-to-text, text-to-speech, Hinglish support
- **Cultural Intelligence**: Indian food database and recommendations
- **Meal Management**: Logging, planning, and tracking
- **Calendar Integration**: Meal scheduling and reminders
- **Email Service**: Notifications and reports
- **Grocery Management**: Smart shopping lists
- **Web Deployment**: Live on Firebase Hosting
- **APK Distribution**: Direct download without Play Store
- **CI/CD Pipeline**: Automated testing and deployment

### 🔄 **In Progress**
- **iOS App Store**: Preparing for TestFlight and App Store submission
- **Advanced Analytics**: User behavior and nutrition insights
- **Multi-language**: Expanding beyond English/Hinglish

### 📋 **Planned Features**
- **Fitness Tracker Integration**: Sync with popular fitness apps
- **Nutritionist Consultation**: Connect with certified nutritionists
- **Grocery Delivery**: Integration with local delivery services
- **Social Features**: Share meals and progress with friends

## 📱 APK Distribution (No Play Store Required!)

### **Why Direct APK Distribution?**
- **No $25 Play Store fee**: Save money on developer registration
- **Instant availability**: No waiting for store approval
- **Full control**: Direct distribution to users
- **No restrictions**: Bypass store policies and limitations

### **Building APK Locally**

#### **Windows (PowerShell)**
```powershell
# Run the automated build script
./scripts/build_local_apk.ps1

# Output: build/apk-release/
# - nutrisync-universal.apk (works on all devices)
# - nutrisync-arm64.apk (modern phones, smaller size)
# - nutrisync-arm32.apk (older phones)
# - nutrisync-x86_64.apk (emulators)
```

#### **Linux/Mac (Bash)**
```bash
# Run the automated build script
./scripts/build_local_apk.sh

# Or build manually
flutter clean
flutter pub get
flutter build apk --release
flutter build apk --release --split-per-abi
```

### **Distribution Methods**

#### **1. GitHub Releases (Recommended)**
```bash
# Create a new release
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1

# GitHub Actions will automatically:
# - Build APKs
# - Upload to GitHub Releases
# - Make available for public download
```

#### **2. Direct Sharing**
- **Email**: Attach APK files directly
- **Cloud Storage**: Google Drive, Dropbox, OneDrive
- **Messaging**: WhatsApp, Telegram, Discord
- **QR Codes**: Generate QR codes for easy sharing

#### **3. Firebase App Distribution**
```bash
# Setup Firebase App Distribution (optional)
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_APP_ID \
  --groups "testers" \
  --release-notes "Latest version with new features"
```

### **User Installation Instructions**

#### **For Android Users**
1. **Download APK**: 
   - From [GitHub Releases](https://github.com/Aisenh037/nutrisync-app/releases)
   - Or receive via email/messaging
2. **Enable Unknown Sources**:
   - Go to Settings → Security → Unknown Sources
   - Toggle ON (or allow for specific apps)
3. **Install**:
   - Tap the downloaded APK file
   - Tap "Install" when prompted
   - Wait for installation to complete
4. **Launch**:
   - Tap "Open" or find NutriSync in your app drawer
   - Grant necessary permissions when prompted

#### **APK Variants Guide**
- **nutrisync-universal.apk**: Choose this if unsure (works on all devices)
- **nutrisync-arm64.apk**: For modern phones (2017+), smaller file size
- **nutrisync-arm32.apk**: For older phones (pre-2017)
- **nutrisync-x86_64.apk**: For emulators and x86 devices

## 🚀 Quick Start

### **For Users (Just Want the App)**
1. **Web App**: Visit [https://nutrisyncapp-97089.web.app](https://nutrisyncapp-97089.web.app)
2. **Android APK**: Download from [GitHub Releases](https://github.com/Aisenh037/nutrisync-app/releases)
3. **iOS**: Coming soon via TestFlight

### **For Developers (Want to Build/Modify)**

#### **Prerequisites**
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24.0 or later)
- [Dart SDK](https://dart.dev/get-dart) (3.5.0 or later)
- [Node.js](https://nodejs.org/) (18.0 or later) - for Firebase Functions
- [Firebase CLI](https://firebase.google.com/docs/cli) - for deployment
- [Android Studio](https://developer.android.com/studio) - for Android development
- [Xcode](https://developer.apple.com/xcode/) (15.0 or later) - for iOS development (macOS only)

### 1. Clone the Repository

```bash
git clone https://github.com/Aisenh037/nutrisync-app.git
cd nutrisync-app
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

### **Web Deployment (Firebase Hosting)**
```bash
# Build web app
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting

# Live URL: https://nutrisyncapp-97089.web.app
```

### **Android APK (Direct Distribution)**
```bash
# Quick build with script
./scripts/build_local_apk.ps1  # Windows
./scripts/build_local_apk.sh   # Linux/Mac

# Manual build
flutter build apk --release                    # Universal APK
flutter build apk --release --split-per-abi    # Split APKs (smaller)

# Output: build/app/outputs/flutter-apk/
```

### **Android App Bundle (Play Store)**
```bash
# Build App Bundle for Play Store submission
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### **iOS Deployment**
```bash
# Build iOS app
flutter build ios --release

# Archive and upload via Xcode or Transporter
```

## 🔐 Security & Secrets Management

### **Local Development**
1. Copy `.env.example` to `.env` and fill in your values
2. Never commit actual secrets to version control
3. Use the provided example files as templates

### **CI/CD Secrets (GitHub Actions)**
Configure these repository secrets for automated deployment:
- `FIREBASE_TOKEN` - Firebase CLI token for deployment
- `ANDROID_KEYSTORE` (base64 encoded) - For signed APK builds
- `ANDROID_KEYSTORE_PASSWORD` - Keystore password
- `ANDROID_KEY_ALIAS` - Key alias
- `ANDROID_KEY_PASSWORD` - Key password

### **Firebase Configuration**
- **Development**: Uses demo configuration for local builds
- **Production**: Real Firebase project `nutrisyncapp-97089`
- **Auto-generation**: Build scripts create demo configs when needed

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

## 📞 Support & Links

### **Live App**
- **Web App**: [https://nutrisyncapp-97089.web.app](https://nutrisyncapp-97089.web.app)
- **Android APK**: [GitHub Releases](https://github.com/Aisenh037/nutrisync-app/releases)
- **Status Page**: [CI/CD Pipeline](https://github.com/Aisenh037/nutrisync-app/actions)

### **Documentation & Support**
- **Project Repository**: [GitHub](https://github.com/Aisenh037/nutrisync-app)
- **Issues & Bug Reports**: [GitHub Issues](https://github.com/Aisenh037/nutrisync-app/issues)
- **Feature Requests**: [GitHub Discussions](https://github.com/Aisenh037/nutrisync-app/discussions)
- **Build Guides**: See `docs/` folder for detailed guides

### **Technical Documentation**
- **APK Distribution**: [APK_BUILD_STATUS.md](APK_BUILD_STATUS.md)
- **CI/CD Pipeline**: [CI_CD_STATUS.md](CI_CD_STATUS.md)
- **Deployment Guide**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- **Firebase Setup**: [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)

## 🗺️ Roadmap

### **Completed ✅**
- [x] Voice-first AI nutrition assistant
- [x] Indian food cultural intelligence
- [x] Firebase backend integration
- [x] Web app deployment (Firebase Hosting)
- [x] Android APK distribution system
- [x] CI/CD pipeline with GitHub Actions
- [x] Comprehensive testing suite
- [x] Calendar and email integration
- [x] Grocery management features

### **In Progress 🔄**
- [ ] iOS App Store submission
- [ ] Advanced analytics and insights
- [ ] Performance optimizations
- [ ] Enhanced voice processing

### **Planned 📋**
- [ ] Fitness tracker integration (Fitbit, Google Fit, Apple Health)
- [ ] Nutritionist consultation platform
- [ ] Grocery delivery service integration
- [ ] Social features and meal sharing
- [ ] Multi-language support expansion
- [ ] Offline-first architecture improvements
- [ ] Advanced meal planning algorithms
- [ ] Integration with popular recipe platforms

---

## 🎉 **Ready to Use!**

**NutriSync is live and ready for users:**
- **🌐 Web**: [nutrisyncapp-97089.web.app](https://nutrisyncapp-97089.web.app)
- **📱 Android**: [Download APK](https://github.com/Aisenh037/nutrisync-app/releases)
- **🔧 Developers**: Clone and build locally

**No Play Store fees, no waiting for approval - start using NutriSync today!**

Made with ❤️ for healthier eating habits in India