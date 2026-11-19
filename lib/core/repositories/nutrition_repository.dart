import '../../models/user_model.dart';

/// Abstract contract for all meal / nutrition data operations.
/// Concrete implementations: [FirestoreNutritionRepository] (production),
/// [MockNutritionRepository] (tests).
abstract class NutritionRepository {
  /// Returns the weekly meal plan keyed by day name.
  Future<Map<String, List<String>>> getMealPlan(String userId);

  /// Adds [meal] to [day] in the user's meal plan.
  Future<void> addMeal(String userId, String day, String meal);

  /// Removes [meal] from [day].
  Future<void> removeMeal(String userId, String day, String meal);

  /// Returns the user's grocery list.
  Future<List<String>> getGroceries(String userId);

  /// Adds [item] to the grocery list.
  Future<void> addGrocery(String userId, String item);

  /// Removes [item] from the grocery list.
  Future<void> removeGrocery(String userId, String item);
}

/// Abstract contract for user profile operations.
abstract class UserRepository {
  /// Fetches the user profile. Returns null if the document doesn't exist.
  Future<UserModel?> getUser(String userId);

  /// Creates or overwrites the user profile document.
  Future<void> setUser(UserModel user);

  /// Returns completion percentage 0.0–1.0.
  Future<double> getProfileCompletion(String userId);
}
