#!/bin/bash

# iOS Build Script for NutriSync
# Builds iOS app for different environments with proper configuration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Default values
ENVIRONMENT="development"
BUILD_TYPE="debug"
EXPORT_METHOD="development"
CLEAN_BUILD=false
ARCHIVE_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -m|--method)
            EXPORT_METHOD="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -a|--archive-only)
            ARCHIVE_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -e, --environment   Environment (development, staging, production)"
            echo "  -t, --type         Build type (debug, release)"
            echo "  -m, --method       Export method (development, ad-hoc, app-store)"
            echo "  -c, --clean        Clean build"
            echo "  -a, --archive-only Archive only, don't export IPA"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 -e production -t release -m app-store"
            echo "  $0 -e development -t debug -c"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate environment
case $ENVIRONMENT in
    development|staging|production)
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT"
        print_error "Valid environments: development, staging, production"
        exit 1
        ;;
esac

# Validate build type
case $BUILD_TYPE in
    debug|release)
        ;;
    *)
        print_error "Invalid build type: $BUILD_TYPE"
        print_error "Valid build types: debug, release"
        exit 1
        ;;
esac

# Set configuration based on build type
if [ "$BUILD_TYPE" = "release" ]; then
    CONFIGURATION="Release"
else
    CONFIGURATION="Debug"
fi

print_header "iOS Build Configuration"
echo "Environment: $ENVIRONMENT"
echo "Build Type: $BUILD_TYPE"
echo "Configuration: $CONFIGURATION"
echo "Export Method: $EXPORT_METHOD"
echo "Clean Build: $CLEAN_BUILD"
echo "Archive Only: $ARCHIVE_ONLY"

# Check prerequisites
print_header "Checking Prerequisites"

if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode is not installed or xcodebuild is not in PATH"
    exit 1
fi

print_success "All prerequisites are available"

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_header "Cleaning Build"
    
    flutter clean
    cd ios
    xcodebuild clean -workspace Runner.xcworkspace -scheme Runner
    cd ..
    
    print_success "Build cleaned"
fi

# Get Flutter dependencies
print_header "Getting Dependencies"
flutter pub get
print_success "Dependencies updated"

# Set up environment-specific configuration
print_header "Setting Up Environment Configuration"

# Copy Firebase configuration for the environment
FIREBASE_SOURCE="ios/Firebase/$ENVIRONMENT/GoogleService-Info.plist"
FIREBASE_TARGET="ios/Runner/GoogleService-Info.plist"

if [ -f "$FIREBASE_SOURCE" ]; then
    cp "$FIREBASE_SOURCE" "$FIREBASE_TARGET"
    print_success "Firebase configuration copied for $ENVIRONMENT"
else
    print_warning "Firebase configuration not found: $FIREBASE_SOURCE"
    print_warning "Using example configuration - update with actual values"
    
    FIREBASE_EXAMPLE="ios/Firebase/$ENVIRONMENT/GoogleService-Info.example.plist"
    if [ -f "$FIREBASE_EXAMPLE" ]; then
        cp "$FIREBASE_EXAMPLE" "$FIREBASE_TARGET"
        print_warning "Using example Firebase configuration"
    fi
fi

# Update environment configuration in Flutter
export ENVIRONMENT=$ENVIRONMENT
print_success "Environment configuration set"

# Build Flutter app
print_header "Building Flutter App"

if [ "$BUILD_TYPE" = "release" ]; then
    flutter build ios --release --no-codesign
else
    flutter build ios --debug --no-codesign
fi

print_success "Flutter build completed"

# Build and archive with Xcode
print_header "Building and Archiving with Xcode"

cd ios

# Set archive path
ARCHIVE_PATH="../build/ios/NutriSync-$ENVIRONMENT.xcarchive"

# Build archive
xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration $CONFIGURATION \
    -destination generic/platform=iOS \
    -archivePath "$ARCHIVE_PATH" \
    archive

print_success "Archive created: $ARCHIVE_PATH"

# Export IPA if not archive-only
if [ "$ARCHIVE_ONLY" = false ]; then
    print_header "Exporting IPA"
    
    # Create export options plist
    EXPORT_OPTIONS_PATH="../build/ios/ExportOptions.plist"
    
    cat > "$EXPORT_OPTIONS_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$EXPORT_METHOD</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
    
    # Export IPA
    IPA_PATH="../build/ios/NutriSync-$ENVIRONMENT"
    
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
        -exportPath "$IPA_PATH"
    
    print_success "IPA exported: $IPA_PATH/NutriSync.ipa"
fi

cd ..

print_header "Build Complete!"
print_success "iOS build completed successfully"

if [ "$ARCHIVE_ONLY" = false ]; then
    echo ""
    echo "📱 Build Artifacts:"
    echo "   Archive: build/ios/NutriSync-$ENVIRONMENT.xcarchive"
    echo "   IPA: build/ios/NutriSync-$ENVIRONMENT/NutriSync.ipa"
else
    echo ""
    echo "📱 Build Artifacts:"
    echo "   Archive: build/ios/NutriSync-$ENVIRONMENT.xcarchive"
fi

echo ""
echo "🚀 Next Steps:"
if [ "$EXPORT_METHOD" = "app-store" ]; then
    echo "   - Upload to App Store Connect using Xcode or altool"
    echo "   - Submit for App Store review"
elif [ "$EXPORT_METHOD" = "ad-hoc" ]; then
    echo "   - Distribute IPA to registered devices"
    echo "   - Upload to TestFlight for beta testing"
else
    echo "   - Install on development devices"
    echo "   - Test the build thoroughly"
fi