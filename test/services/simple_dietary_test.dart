import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/dietary_substitution_service.dart';

void main() {
  test('simple dietary substitution service test', () {
    final service = DietarySubstitutionService();
    expect(service, isNotNull);
  });
}