#!/bin/bash

# NutriSync Development Setup Script
# This script helps set up the development environment for NutriSync

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

check_command() {
    if command -v $1 &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

# Main setup function
main() {
    print_header "NutriSync Development Setup"
    
    echo "This script will help you set up the NutriSync development environment."
    echo "Please make sure you have the following prerequisites installed:"
    echo "- Flutter SDK (3.24.0+)"
    echo "- Node.js (18+)"
    echo "- Firebase CLI"
    echo "- Git"
    echo ""
    
    read -p "Continue with setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    # Check prerequisites
    print_header "Checking Prerequisites"
    
    MISSING_DEPS=0
    
    if ! check_command "flutter"; then
        MISSING_DEPS=1
        echo "Please install Flutter: https://flutter.dev/docs/get-started/install"
    fi
    
    if ! check_command "node"; then
        MISSING_DEPS=1
        echo "Please install Node.js: https://nodejs.org/"
    fi
    
    if ! check_command "firebase"; then
        MISSING_DEPS=1
        echo "Please install Firebase CLI: npm install -g firebase-tools"
    fi
    
    if ! check_command "git"; then
        MISSING_DEPS=1
        echo "Please install Git: https://git-scm.com/"
    fi
    
    if [ $MISSING_DEPS -eq 1 ]; then
        print_error "Please install missing dependencies and run this script again."
        exit 1
    fi
    
    # Check Flutter version
    print_header "Checking Flutter Version"
    FLUTTER_VERSION=$(flutter --version | head -n 1 | cut -d ' ' -f 2)
    echo "Flutter version: $FLUTTER_VERSION"
    
    # Install dependencies
    print_header "Installing Dependencies"
    
    print_success "Installing Flutter dependencies..."
    flutter pub get
    
    print_success "Installing Firebase Functions dependencies..."
    cd functions
    npm install
    cd ..
    
    # Setup configuration files
    print_header "Setting Up Configuration Files"
    
    # Copy example files if they don't exist
    if [ ! -f ".env" ]; then
        cp config/secrets/.env.example .env
        print_success "Created .env file from example"
        print_warning "Please edit .env file with your actual configuration values"
    else
        print_warning ".env file already exists"
    fi
    
    if [ ! -f "android/key.properties" ]; then
        cp config/secrets/key.properties.example android/key.properties
        print_success "Created android/key.properties from example"
        print_warning "Please edit android/key.properties with your keystore information"
    else
        print_warning "android/key.properties already exists"
    fi
    
    # Firebase setup
    print_header "Firebase Setup"
    
    echo "Do you want to configure Firebase now? This requires:"
    echo "1. A Firebase project created at https://console.firebase.google.com/"
    echo "2. Firebase CLI authentication (firebase login)"
    echo ""
    read -p "Configure Firebase? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_success "Checking Firebase authentication..."
        
        if firebase projects:list &> /dev/null; then
            print_success "Firebase CLI is authenticated"
            
            echo ""
            echo "Available Firebase projects:"
            firebase projects:list
            echo ""
            
            read -p "Enter your Firebase project ID: " PROJECT_ID
            
            if [ ! -z "$PROJECT_ID" ]; then
                print_success "Configuring Flutter for Firebase..."
                
                # Install flutterfire CLI if not present
                if ! command -v flutterfire &> /dev/null; then
                    print_success "Installing FlutterFire CLI..."
                    dart pub global activate flutterfire_cli
                fi
                
                # Configure FlutterFire
                flutterfire configure --project=$PROJECT_ID
                
                print_success "Firebase configuration completed!"
            else
                print_warning "No project ID provided, skipping Firebase configuration"
            fi
        else
            print_error "Firebase CLI not authenticated. Please run 'firebase login' first."
        fi
    else
        print_warning "Skipping Firebase configuration"
        print_warning "You can configure it later by running: flutterfire configure"
    fi
    
    # Run tests
    print_header "Running Tests"
    
    read -p "Run tests to verify setup? (Y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_success "Running Flutter tests..."
        flutter test
        
        print_success "Running Firebase Functions tests..."
        cd functions
        npm test
        cd ..
        
        print_success "All tests passed!"
    else
        print_warning "Skipping tests"
    fi
    
    # Final instructions
    print_header "Setup Complete!"
    
    echo -e "${GREEN}🎉 NutriSync development environment is ready!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Edit .env file with your actual configuration values"
    echo "2. Configure Firebase if you haven't already:"
    echo "   - Create a Firebase project at https://console.firebase.google.com/"
    echo "   - Run: firebase login"
    echo "   - Run: flutterfire configure"
    echo "3. For Android development:"
    echo "   - Edit android/key.properties with your keystore information"
    echo "   - Copy google-services.json to android/app/"
    echo "4. Start developing:"
    echo "   - Run: flutter run -d chrome (for web)"
    echo "   - Run: flutter run -d android (for Android)"
    echo ""
    echo "For more information, see:"
    echo "- README.md for detailed setup instructions"
    echo "- CONTRIBUTING.md for contribution guidelines"
    echo "- docs/DEPLOYMENT.md for deployment information"
    echo ""
    print_success "Happy coding! 🚀"
}

# Run main function
main "$@"