#!/bin/bash

# 📱 Local APK Build Script for NutriSync
# Build APK files locally without Google Play Store

echo "📱 Building NutriSync APK locally..."
echo "=================================="

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    echo "Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -1)"

# Setup Firebase configuration for building
echo "🔧 Setting up build configuration..."
GOOGLE_SERVICES_PATH="android/app/google-services.json"
EXAMPLE_PATH="config/secrets/google-services.example.json"

if [ ! -f "$GOOGLE_SERVICES_PATH" ]; then
    if [ -f "$EXAMPLE_PATH" ]; then
        echo "📋 Copying example Firebase config for build..."
        cp "$EXAMPLE_PATH" "$GOOGLE_SERVICES_PATH"
    else
        echo "⚠️  Creating minimal Firebase config for build..."
        cat > "$GOOGLE_SERVICES_PATH" << 'EOF'
{
  "project_info": {
    "project_number": "123456789",
    "project_id": "nutrisync-demo-build",
    "storage_bucket": "nutrisync-demo-build.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:123456789:android:abcdef123456",
        "android_client_info": {
          "package_name": "com.example.nutrisync"
        }
      },
      "oauth_client": [
        {
          "client_id": "123456789-demo.apps.googleusercontent.com",
          "client_type": 3
        }
      ],
      "api_key": [
        {
          "current_key": "AIzaSyDemoKeyForBuildPurposesOnly"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": [
            {
              "client_id": "123456789-demo.apps.googleusercontent.com",
              "client_type": 3
            }
          ]
        }
      }
    }
  ],
  "configuration_version": "1"
}
EOF
    fi
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Build APK for different architectures
echo "🔨 Building APK files..."

# Build universal APK (works on all Android devices)
echo "📦 Building universal APK..."
if flutter build apk --release; then
    echo "✅ Universal APK build successful"
else
    echo "❌ Universal APK build failed"
    exit 1
fi

# Build split APKs for smaller file sizes (optional)
echo "📦 Building split APKs..."
if flutter build apk --release --split-per-abi; then
    echo "✅ Split APK build successful"
else
    echo "⚠️  Split APK build failed, continuing with universal APK"
fi

# Create output directory
OUTPUT_DIR="build/apk-release"
mkdir -p "$OUTPUT_DIR"

# Copy APK files to output directory
echo "📁 Organizing APK files..."
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp build/app/outputs/flutter-apk/app-release.apk "$OUTPUT_DIR/nutrisync-universal.apk"
    echo "✅ Universal APK copied"
fi

if [ -f "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" ]; then
    cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$OUTPUT_DIR/nutrisync-arm64.apk"
    echo "✅ ARM64 APK copied"
fi

if [ -f "build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk" ]; then
    cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "$OUTPUT_DIR/nutrisync-arm32.apk"
    echo "✅ ARM32 APK copied"
fi

if [ -f "build/app/outputs/flutter-apk/app-x86_64-release.apk" ]; then
    cp build/app/outputs/flutter-apk/app-x86_64-release.apk "$OUTPUT_DIR/nutrisync-x86_64.apk"
    echo "✅ x86_64 APK copied"
fi

# Display results
echo ""
echo "✅ APK Build Complete!"
echo "======================"
echo "📁 APK files location: $OUTPUT_DIR/"
echo ""
echo "📱 Available APK files:"
for apk in "$OUTPUT_DIR"/*.apk; do
    if [ -f "$apk" ]; then
        size=$(du -h "$apk" | cut -f1)
        echo "  • $(basename "$apk") ($size)"
    fi
done

echo ""
echo "📲 Installation Instructions:"
echo "1. Transfer APK file to your Android device"
echo "2. Enable 'Install from Unknown Sources' in Settings"
echo "3. Tap the APK file to install"
echo ""
echo "🌐 Alternative: Upload to GitHub Releases for easy sharing"
echo "📧 Or share via email, cloud storage, or messaging apps"

# Generate QR code for easy sharing (if qrencode is available)
if command -v qrencode &> /dev/null; then
    echo ""
    echo "📱 Generating QR code for GitHub releases..."
    echo "https://github.com/Aisenh037/nutrisync-app/releases" | qrencode -t UTF8
fi

echo ""
echo "🎉 Ready to test on Android devices!"

# Cleanup temporary files
if [ -f "$GOOGLE_SERVICES_PATH" ] && [ -f "$EXAMPLE_PATH" ]; then
    if grep -q "demo-build\|DemoKeyForBuildPurposesOnly" "$GOOGLE_SERVICES_PATH"; then
        echo "🧹 Cleaning up temporary build files..."
        rm -f "$GOOGLE_SERVICES_PATH"
        echo "✅ Temporary Firebase config removed"
    fi
fi