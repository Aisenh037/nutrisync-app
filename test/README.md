# Testing Guide for NutriSync Authentication

This guide explains how to test the username/password authentication functionality in the NutriSync app.

## Test Structure

```
test/
├── api/
│   ├── auth_service_test.dart      # Unit tests for AuthService
│   └── auth_property_test.dart     # Property-based tests
├── screens/
│   └── login_screen_test.dart      # Widget tests for LoginScreen
├── integration/
│   └── auth_integration_test.dart  # End-to-end integration tests
├── utils/
│   └── test_data.dart             # Test data and utilities
├── run_auth_tests.dart            # Test runner for all auth tests
└── README.md                      # This file
```

## Types of Tests

### 1. Unit Tests (`auth_service_test.dart`)
Tests individual functions in the AuthService class:
- ✅ Successful login with valid credentials
- ✅ Failed login with invalid credentials
- ✅ User registration
- ✅ Error handling for various scenarios
- ✅ Input validation

### 2. Widget Tests (`login_screen_test.dart`)
Tests the LoginScreen UI components:
- ✅ UI elements are displayed correctly
- ✅ Form validation works
- ✅ User interactions (typing, button clicks)
- ✅ Loading states
- ✅ Error message display
- ✅ Navigation between screens

### 3. Property-Based Tests (`auth_property_test.dart`)
Tests properties that should hold for all inputs:
- ✅ Email format validation
- ✅ Password length requirements
- ✅ Special character handling
- ✅ Consistent behavior
- ✅ Error message quality

### 4. Integration Tests (`auth_integration_test.dart`)
Tests complete user flows:
- ✅ Full login process
- ✅ Full signup process
- ✅ Form validation in real UI
- ✅ Navigation flows
- ✅ Logout functionality

## Running Tests

### Prerequisites

1. Install dependencies:
```bash
flutter pub get
```

2. Generate mock files (for unit tests):
```bash
flutter packages pub run build_runner build
```

### Running Individual Test Suites

```bash
# Run all authentication tests
flutter test test/run_auth_tests.dart

# Run unit tests only
flutter test test/api/auth_service_test.dart

# Run widget tests only
flutter test test/screens/login_screen_test.dart

# Run property-based tests only
flutter test test/api/auth_property_test.dart

# Run integration tests (requires device/emulator)
flutter test integration_test/auth_integration_test.dart
```

### Running All Tests

```bash
# Run all unit and widget tests
flutter test

# Run with coverage
flutter test --coverage
```

### Running Integration Tests

Integration tests require a device or emulator:

```bash
# On connected device/emulator
flutter test integration_test/auth_integration_test.dart

# On specific device
flutter test integration_test/auth_integration_test.dart -d <device_id>
```

## Test Data

The `test/utils/test_data.dart` file contains:

### Valid Test Credentials
- Email: `test@example.com`
- Password: `password123`

### Test Scenarios Covered

1. **Valid Inputs**:
   - Standard email/password combinations
   - Edge cases (very long emails, special characters)
   - Minimum valid password length

2. **Invalid Inputs**:
   - Empty fields
   - Invalid email formats
   - Passwords too short
   - Special characters and Unicode

3. **Error Conditions**:
   - Network errors
   - Firebase Auth errors
   - Validation errors

## Test Coverage

The tests cover:

- ✅ **Authentication Logic**: Login, signup, logout
- ✅ **Input Validation**: Email format, password strength
- ✅ **Error Handling**: Network errors, auth errors
- ✅ **UI Interactions**: Form submission, navigation
- ✅ **Edge Cases**: Special characters, long inputs
- ✅ **User Experience**: Loading states, error messages

## Debugging Tests

### Common Issues

1. **Mock Generation Fails**:
   ```bash
   flutter packages pub run build_runner clean
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```

2. **Firebase Tests Fail**:
   - Ensure Firebase is properly configured
   - Use `fake_cloud_firestore` for unit tests
   - Check network connectivity for integration tests

3. **Widget Tests Fail**:
   - Ensure all required providers are mocked
   - Check for async operations that need `pumpAndSettle()`

### Test Output

Successful test run should show:
```
✓ AuthService Tests
✓ LoginScreen Widget Tests  
✓ Authentication Property Tests
✓ Integration Tests

All tests passed!
```

## Adding New Tests

### For New Authentication Features

1. Add unit tests in `auth_service_test.dart`
2. Add widget tests in appropriate screen test file
3. Add property-based tests for new validation rules
4. Add integration tests for new user flows

### Test Naming Convention

- Unit tests: `test('should do something when condition')`
- Widget tests: `testWidgets('should display something when action')`
- Property tests: `test('Property: description of property')`

## Continuous Integration

These tests can be run in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run tests
  run: |
    flutter test --coverage
    flutter test integration_test/
```

## Manual Testing Checklist

In addition to automated tests, manually verify:

- [ ] Login with valid credentials works
- [ ] Login with invalid credentials shows error
- [ ] Signup creates new account
- [ ] Form validation prevents empty submissions
- [ ] Password visibility toggle works
- [ ] Navigation between login/signup works
- [ ] Logout functionality works
- [ ] Error messages are user-friendly
- [ ] Loading indicators appear during auth operations
- [ ] App handles network connectivity issues

## Security Testing

For production apps, also consider:

- [ ] Password strength requirements
- [ ] Rate limiting on login attempts
- [ ] Secure storage of credentials
- [ ] HTTPS enforcement
- [ ] Input sanitization
- [ ] SQL injection prevention (if using custom backend)