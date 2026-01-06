import 'package:flutter_test/flutter_test.dart';

// Import all auth test files
import 'api/auth_service_test.dart' as auth_service_tests;
import 'api/auth_property_test.dart' as auth_property_tests;
import 'screens/login_screen_test.dart' as login_screen_tests;

void main() {
  group('All Authentication Tests', () {
    group('AuthService Unit Tests', auth_service_tests.main);
    group('AuthService Property Tests', auth_property_tests.main);
    group('Login Screen Widget Tests', login_screen_tests.main);
  });
}