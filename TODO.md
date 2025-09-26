# NutriSync OAuth Migration TODO

## OAuth Migration Plan

**Information Gathered:**
- Current implementation uses google_sign_in package with deprecated `signIn()` method on web, causing popup_closed errors and warnings.
- AuthService in lib/api/auth_service.dart handles signInWithGoogle using _googleSignIn.signIn(), which is deprecated for web.
- LoginScreen calls _handleGoogleSignIn() which invokes the service.
- pubspec.yaml already includes google_sign_in ^6.2.1, which supports web, but needs migration to Google Identity Services (GIS) for web.
- For web, use google_sign_in_web's renderButton and handle callbacks to avoid deprecation.
- Platform detection needed (kIsWeb) to use different flows: native signIn for mobile, rendered button for web.
- No additional dependencies needed; google_sign_in_web is bundled.

**Plan:**
- [ ] Update pubspec.yaml: Ensure google_sign_in_web is included (if separate), but since v6+ integrates, just update config if needed.
- [ ] Update lib/api/auth_service.dart:
  - Import 'package:google_sign_in_web/google_sign_in_web.dart' for web.
  - Modify signInWithGoogle to detect platform (import 'dart:io' show Platform; and flutter/foundation.dart for kIsWeb).
  - For web: Use GoogleSignInWeb.instance to render button and handle signInSilently or callback.
  - For non-web: Keep existing _googleSignIn.signIn().
  - Return AuthResult consistently.
- [ ] Update lib/screens/login_screen.dart:
  - Import kIsWeb.
  - Conditionally render Google button: For web, use GoogleSignInButton from google_sign_in_web; for mobile, keep IconButton.
  - Handle the callback to call authService.signInWithGoogle().
- [ ] Update lib/providers/providers.dart: No changes needed, as it references AuthService.
- [ ] Test: Run on web, verify no deprecation warnings, successful OAuth flow without popup errors.

**Dependent Files to be edited:**
- lib/api/auth_service.dart (main logic update)
- lib/screens/login_screen.dart (UI conditional rendering)
- pubspec.yaml (dependency confirmation)

**Followup steps:**
- [ ] Run `flutter pub get` after dependency updates.
- [ ] Test Google Sign-In on web: Click button, complete OAuth, verify user login and no errors in console.
- [ ] Test on mobile (if emulator available): Ensure native flow works.
- [ ] Handle any Firebase credential issues if arise.
- [ ] Restart app servers for hot reload to apply changes.
