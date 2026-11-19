import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../error/app_exception.dart';
import 'nutrition_repository.dart';

/// Firestore-backed implementation of [NutritionRepository] and [UserRepository].
class FirestoreNutritionRepository implements NutritionRepository {
  FirestoreNutritionRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  // ── Meal plan ──────────────────────────────────────────────────────────────

  @override
  Future<Map<String, List<String>>> getMealPlan(String userId) async {
    try {
      final doc = await _userDoc(userId).get();
      if (!doc.exists || doc.data() == null) return {};
      final raw = doc.data()!['mealPlan'] as Map<String, dynamic>?;
      if (raw == null) return {};
      return raw.map((day, meals) => MapEntry(
            day,
            (meals as List).map((m) => m.toString()).toList(),
          ));
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to fetch meal plan', code: e.code, cause: e);
    }
  }

  @override
  Future<void> addMeal(String userId, String day, String meal) async {
    try {
      await _userDoc(userId).update({'mealPlan.$day': FieldValue.arrayUnion([meal])});
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to add meal', code: e.code, cause: e);
    }
  }

  @override
  Future<void> removeMeal(String userId, String day, String meal) async {
    try {
      await _userDoc(userId).update({'mealPlan.$day': FieldValue.arrayRemove([meal])});
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to remove meal', code: e.code, cause: e);
    }
  }

  // ── Groceries ──────────────────────────────────────────────────────────────

  @override
  Future<List<String>> getGroceries(String userId) async {
    try {
      final doc = await _userDoc(userId).get();
      if (!doc.exists || doc.data() == null) return [];
      final raw = doc.data()!['groceries'] as List?;
      return raw?.map((e) => e.toString()).toList() ?? [];
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to fetch groceries', code: e.code, cause: e);
    }
  }

  @override
  Future<void> addGrocery(String userId, String item) async {
    try {
      await _userDoc(userId).update({'groceries': FieldValue.arrayUnion([item])});
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to add grocery item', code: e.code, cause: e);
    }
  }

  @override
  Future<void> removeGrocery(String userId, String item) async {
    try {
      await _userDoc(userId).update({'groceries': FieldValue.arrayRemove([item])});
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to remove grocery item', code: e.code, cause: e);
    }
  }
}

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _userDoc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!);
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to fetch user profile', code: e.code, cause: e);
    }
  }

  @override
  Future<void> setUser(UserModel user) async {
    try {
      await _userDoc(user.uid).set(user.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw DatabaseException('Failed to save user profile', code: e.code, cause: e);
    }
  }

  @override
  Future<double> getProfileCompletion(String userId) async {
    final user = await getUser(userId);
    if (user == null) return 0.0;
    int filled = 0;
    const total = 5;
    if (user.name.isNotEmpty) filled++;
    if (user.email.isNotEmpty) filled++;
    if (user.dietaryNeeds.isNotEmpty) filled++;
    if (user.healthGoals.isNotEmpty) filled++;
    // region from onboarding stored in SharedPreferences
    filled++; // assume set if profile exists
    return filled / total;
  }
}
