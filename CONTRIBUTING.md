# Contributing to NutriSync

Thank you for your interest in contributing to NutriSync! This document provides guidelines and information for contributors.

## 🤝 Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. Please be respectful and constructive in all interactions.

## 🚀 Getting Started

### Prerequisites

1. Read the [README.md](README.md) and set up the development environment
2. Familiarize yourself with Flutter, Firebase, and the project architecture
3. Check existing [issues](https://github.com/yourusername/nutrisync/issues) and [discussions](https://github.com/yourusername/nutrisync/discussions)

### Development Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/nutrisync.git`
3. Set up the development environment as described in README.md
4. Create a new branch for your feature: `git checkout -b feature/your-feature-name`

## 📋 How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/yourusername/nutrisync/issues)
2. If not, create a new issue with:
   - Clear, descriptive title
   - Steps to reproduce the bug
   - Expected vs actual behavior
   - Screenshots/videos if applicable
   - Device/platform information
   - Flutter and Dart versions

### Suggesting Features

1. Check [Discussions](https://github.com/yourusername/nutrisync/discussions) for existing feature requests
2. Create a new discussion or issue with:
   - Clear description of the feature
   - Use case and benefits
   - Possible implementation approach
   - Any relevant mockups or examples

### Code Contributions

#### Types of Contributions Welcome

- **Bug fixes**: Fix existing issues
- **New features**: Implement new functionality
- **Performance improvements**: Optimize existing code
- **Documentation**: Improve docs, comments, or examples
- **Tests**: Add or improve test coverage
- **UI/UX improvements**: Enhance user interface and experience

#### Development Workflow

1. **Create an Issue**: For significant changes, create an issue first to discuss the approach
2. **Fork & Branch**: Fork the repo and create a feature branch
3. **Develop**: Write your code following our guidelines
4. **Test**: Ensure all tests pass and add new tests for your changes
5. **Document**: Update documentation if needed
6. **Submit PR**: Create a pull request with a clear description

## 🎯 Code Guidelines

### Flutter/Dart Standards

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `flutter format` to format code consistently
- Ensure `flutter analyze` passes without warnings
- Use meaningful variable and function names
- Add documentation comments for public APIs

### Code Structure

```
lib/
├── models/          # Data models
├── services/        # Business logic services
├── screens/         # UI screens
├── widgets/         # Reusable UI components
├── providers/       # State management (Riverpod)
├── utils/          # Utility functions
├── constants/      # App constants
└── main.dart       # App entry point
```

### State Management

- Use [Riverpod](https://riverpod.dev/) for state management
- Keep providers focused and single-purpose
- Use appropriate provider types (StateProvider, FutureProvider, etc.)

### Testing Requirements

- **Unit Tests**: Test business logic and services
- **Widget Tests**: Test UI components
- **Integration Tests**: Test complete user flows
- **Property-Based Tests**: Test correctness properties

```bash
# Run all tests
flutter test

# Run with coverage (minimum 80% required)
flutter test --coverage
```

### Firebase Functions

- Use TypeScript for Cloud Functions
- Follow Google's Cloud Functions best practices
- Include proper error handling and logging
- Write tests for all functions

## 📝 Pull Request Guidelines

### Before Submitting

- [ ] Code follows project style guidelines
- [ ] All tests pass (`flutter test`)
- [ ] Code coverage meets minimum requirements (80%)
- [ ] Documentation is updated if needed
- [ ] Commit messages are clear and descriptive

### PR Description Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Performance improvement
- [ ] Documentation update
- [ ] Other (please describe)

## Testing
- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Screenshots (if applicable)
Add screenshots or videos demonstrating the changes.

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Tests added for new functionality
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)
```

### Review Process

1. **Automated Checks**: CI/CD pipeline runs tests and quality checks
2. **Code Review**: Maintainers review code for quality and consistency
3. **Testing**: Changes are tested in staging environment
4. **Approval**: At least one maintainer approval required
5. **Merge**: Changes are merged to main branch

## 🧪 Testing Guidelines

### Writing Tests

- Test files should be in the `test/` directory
- Mirror the `lib/` structure in `test/`
- Use descriptive test names that explain what is being tested
- Group related tests using `group()` or `describe()`

### Test Categories

#### Unit Tests
```dart
// Example unit test
void main() {
  group('RecommendationEngine', () {
    test('should generate recommendations based on user preferences', () {
      // Arrange
      final engine = RecommendationEngine();
      final userProfile = UserProfile(healthGoals: ['weight_loss']);
      
      // Act
      final recommendations = engine.generateRecommendations(userProfile);
      
      // Assert
      expect(recommendations, isNotEmpty);
      expect(recommendations.first.calories, lessThan(300));
    });
  });
}
```

#### Widget Tests
```dart
// Example widget test
void main() {
  testWidgets('MealCard displays meal information correctly', (tester) async {
    // Arrange
    const meal = Meal(name: 'Dal Tadka', calories: 150);
    
    // Act
    await tester.pumpWidget(MaterialApp(
      home: MealCard(meal: meal),
    ));
    
    // Assert
    expect(find.text('Dal Tadka'), findsOneWidget);
    expect(find.text('150 cal'), findsOneWidget);
  });
}
```

#### Property-Based Tests
```dart
// Example property-based test
void main() {
  group('Nutrition Calculator Properties', () {
    test('total calories should equal sum of macronutrients', () {
      check((protein, carbs, fat) {
        final totalCalories = calculateTotalCalories(protein, carbs, fat);
        final expectedCalories = (protein * 4) + (carbs * 4) + (fat * 9);
        return totalCalories == expectedCalories;
      }).withExamples([
        [10.0, 20.0, 5.0], // Example values
        [0.0, 0.0, 0.0],   // Edge case: zero values
      ]);
    });
  });
}
```

## 🔧 Development Tools

### Recommended VS Code Extensions

- Dart
- Flutter
- Firebase
- GitLens
- Bracket Pair Colorizer
- Flutter Widget Snippets

### Useful Commands

```bash
# Development
flutter pub get              # Get dependencies
flutter pub upgrade          # Upgrade dependencies
flutter clean               # Clean build cache
flutter doctor              # Check Flutter installation

# Code Quality
flutter analyze             # Static analysis
flutter format .            # Format code
dart fix --apply           # Apply suggested fixes

# Testing
flutter test               # Run all tests
flutter test --coverage   # Run with coverage
flutter test test/unit/    # Run specific test directory

# Building
flutter build web          # Build web app
flutter build apk          # Build Android APK
flutter build appbundle    # Build Android App Bundle
flutter build ios         # Build iOS app
```

## 📚 Resources

### Documentation

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Riverpod Documentation](https://riverpod.dev/)

### Learning Resources

- [Flutter Codelabs](https://flutter.dev/docs/codelabs)
- [Dart Codelabs](https://dart.dev/codelabs)
- [Firebase Codelabs](https://firebase.google.com/codelabs)

### Community

- [Flutter Community](https://flutter.dev/community)
- [Dart Community](https://dart.dev/community)
- [Firebase Community](https://firebase.google.com/community)

## 🏷️ Issue Labels

We use the following labels to categorize issues:

- `bug`: Something isn't working
- `enhancement`: New feature or request
- `documentation`: Improvements or additions to documentation
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention is needed
- `priority: high`: High priority issue
- `priority: medium`: Medium priority issue
- `priority: low`: Low priority issue
- `area: ui`: User interface related
- `area: backend`: Backend/Firebase related
- `area: testing`: Testing related

## 🎉 Recognition

Contributors will be recognized in:

- README.md contributors section
- Release notes for significant contributions
- Special mentions in project updates

## ❓ Questions?

If you have questions about contributing:

1. Check existing [Discussions](https://github.com/yourusername/nutrisync/discussions)
2. Create a new discussion
3. Reach out to maintainers

Thank you for contributing to NutriSync! 🙏