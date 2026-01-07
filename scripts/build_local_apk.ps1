# Local APK Build Script for NutriSync (Windows PowerShell)
# Build APK files locally without Google Play Store

Write-Host "Building NutriSync APK locally..." -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Check Flutter installation
try {
    $flutterVersion = flutter --version 2>$null
    Write-Host "Flutter found: $($flutterVersion.Split("`n")[0])" -ForegroundColor Green
} catch {
    Write-Host "Flutter not found. Please install Flutter first." -ForegroundColor Red
    Write-Host "Visit: https://flutter.dev/docs/get-started/install" -ForegroundColor Yellow
    exit 1
}

# Setup Firebase configuration for building
Write-Host "Setting up build configuration..." -ForegroundColor Yellow
$googleServicesPath = "android/app/google-services.json"
$examplePath = "config/secrets/google-services.example.json"

if (-not (Test-Path $googleServicesPath)) {
    if (Test-Path $examplePath) {
        Write-Host "Copying example Firebase config for build..." -ForegroundColor Yellow
        Copy-Item $examplePath $googleServicesPath
    } else {
        Write-Host "Creating minimal Firebase config for build..." -ForegroundColor Yellow
        $minimalConfig = @'
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
'@
        $minimalConfig | Out-File -FilePath $googleServicesPath -Encoding UTF8
    }
}

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
flutter pub get

# Build APK for different architectures
Write-Host "Building APK files..." -ForegroundColor Cyan

try {
    # Build universal APK (works on all Android devices)
    Write-Host "Building universal APK..." -ForegroundColor Yellow
    flutter build apk --release

    # Build split APKs for smaller file sizes (optional)
    Write-Host "Building split APKs..." -ForegroundColor Yellow
    flutter build apk --release --split-per-abi

    # Create output directory
    $OUTPUT_DIR = "build/apk-release"
    New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null

    # Copy APK files to output directory
    Write-Host "Organizing APK files..." -ForegroundColor Yellow
    if (Test-Path "build/app/outputs/flutter-apk/app-release.apk") {
        Copy-Item "build/app/outputs/flutter-apk/app-release.apk" "$OUTPUT_DIR/nutrisync-universal.apk"
    }

    if (Test-Path "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk") {
        Copy-Item "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" "$OUTPUT_DIR/nutrisync-arm64.apk"
    }

    if (Test-Path "build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk") {
        Copy-Item "build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk" "$OUTPUT_DIR/nutrisync-arm32.apk"
    }

    if (Test-Path "build/app/outputs/flutter-apk/app-x86_64-release.apk") {
        Copy-Item "build/app/outputs/flutter-apk/app-x86_64-release.apk" "$OUTPUT_DIR/nutrisync-x86_64.apk"
    }

    # Display results
    Write-Host ""
    Write-Host "APK Build Complete!" -ForegroundColor Green
    Write-Host "===================" -ForegroundColor Green
    Write-Host "APK files location: $OUTPUT_DIR/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available APK files:" -ForegroundColor White
    Get-ChildItem "$OUTPUT_DIR/*.apk" -ErrorAction SilentlyContinue | ForEach-Object {
        $size = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  * $($_.Name) ($size MB)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "Installation Instructions:" -ForegroundColor Yellow
    Write-Host "1. Transfer APK file to your Android device" -ForegroundColor White
    Write-Host "2. Enable 'Install from Unknown Sources' in Settings" -ForegroundColor White
    Write-Host "3. Tap the APK file to install" -ForegroundColor White
    Write-Host ""
    Write-Host "Alternative: Upload to GitHub Releases for easy sharing" -ForegroundColor Cyan
    Write-Host "Or share via email, cloud storage, or messaging apps" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Ready to test on Android devices!" -ForegroundColor Green

} catch {
    Write-Host "Build failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common solutions:" -ForegroundColor Yellow
    Write-Host "1. Ensure Android SDK is properly installed" -ForegroundColor White
    Write-Host "2. Run 'flutter doctor' to check setup" -ForegroundColor White
    Write-Host "3. Try building with 'flutter build apk --debug' first" -ForegroundColor White
    Write-Host "4. Check if you have enough disk space" -ForegroundColor White
    exit 1
}

# Cleanup temporary files
if ((Test-Path $googleServicesPath) -and (Test-Path $examplePath)) {
    Write-Host "Cleaning up temporary build files..." -ForegroundColor Yellow
    # Only remove if we created it from example
    $content = Get-Content $googleServicesPath -Raw
    if ($content -match "demo-build" -or $content -match "DemoKeyForBuildPurposesOnly") {
        Remove-Item $googleServicesPath -ErrorAction SilentlyContinue
        Write-Host "Temporary Firebase config removed" -ForegroundColor Green
    }
}