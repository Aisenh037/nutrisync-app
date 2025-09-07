import 'package:cloud_firestore/cloud_firestore.dart';

/// Example UserModel class. Replace fields as needed.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final List<String> dietaryNeeds;
  final List<String> healthGoals;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.dietaryNeeds = const [],
    this.healthGoals = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'dietaryNeeds': dietaryNeeds,
      'healthGoals': healthGoals,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      dietaryNeeds: (map['dietaryNeeds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      healthGoals: (map['healthGoals'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  UserModel copyWith({
    String? name,
    String? email,
    List<String>? dietaryNeeds,
    List<String>? healthGoals,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      dietaryNeeds: dietaryNeeds ?? this.dietaryNeeds,
      healthGoals: healthGoals ?? this.healthGoals,
    );
  }
}

/// A result class for Firestore actions, containing either a user or an error message.
class FirestoreResult<T> {
  final T? data;
  final String? error;
  FirestoreResult({this.data, this.error});
}

/// Service for handling Firestore user profile operations.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get the grocery list for a user.
  Future<FirestoreResult<List<String>>> getGroceries(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final groceries = (doc.data()!['groceries'] as List?)?.map((e) => e.toString()).toList() ?? [];
        return FirestoreResult<List<String>>(data: List<String>.from(groceries));
      } else {
        return FirestoreResult<List<String>>(data: []);
      }
    } catch (e) {
      return FirestoreResult<List<String>>(error: 'Failed to fetch groceries: $e');
    }
  }

  /// Add a grocery item for a user.
  Future<FirestoreResult<void>> addGrocery(String uid, String item) async {
    try {
      await _db.collection('users').doc(uid).update({
        'groceries': FieldValue.arrayUnion([item])
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to add grocery: $e');
    }
  }

  /// Remove a grocery item for a user.
  Future<FirestoreResult<void>> removeGrocery(String uid, String item) async {
    try {
      await _db.collection('users').doc(uid).update({
        'groceries': FieldValue.arrayRemove([item])
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to remove grocery: $e');
    }
  }

  /// Get the meal plan for a user.
  Future<FirestoreResult<Map<String, List<String>>>> getMealPlan(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final mealPlanRaw = doc.data()!['mealPlan'] as Map<String, dynamic>?;
        final mealPlan = mealPlanRaw != null
            ? mealPlanRaw.map((k, v) => MapEntry(k, List<String>.from(v)))
            : <String, List<String>>{};
        return FirestoreResult<Map<String, List<String>>>(data: mealPlan);
      } else {
        return FirestoreResult<Map<String, List<String>>>(data: {});
      }
    } catch (e) {
      return FirestoreResult<Map<String, List<String>>>(error: 'Failed to fetch meal plan: $e');
    }
  }

  /// Set the meal plan for a user (overwrites all days).
  Future<FirestoreResult<void>> setMealPlan(String uid, Map<String, List<String>> mealPlan) async {
    try {
      await _db.collection('users').doc(uid).update({
        'mealPlan': mealPlan,
      });
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to set meal plan: $e');
    }
  }

  /// Add a meal to a specific day for a user.
  Future<FirestoreResult<void>> addMeal(String uid, String day, String meal) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final mealPlanRaw = data['mealPlan'] as Map<String, dynamic>? ?? {};
      final mealPlan = mealPlanRaw.map((k, v) => MapEntry(k, List<String>.from(v)));
      final meals = List<String>.from(mealPlan[day] ?? []);
      meals.add(meal);
      mealPlan[day] = meals;
      await _db.collection('users').doc(uid).set({'mealPlan': mealPlan}, SetOptions(merge: true));
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to add meal: $e');
    }
  }

  /// Remove a meal from a specific day for a user.
  Future<FirestoreResult<void>> removeMeal(String uid, String day, String meal) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final mealPlanRaw = data['mealPlan'] as Map<String, dynamic>? ?? {};
      final mealPlan = mealPlanRaw.map((k, v) => MapEntry(k, List<String>.from(v)));
      final meals = List<String>.from(mealPlan[day] ?? []);
      meals.remove(meal);
      mealPlan[day] = meals;
      await _db.collection('users').doc(uid).update({'mealPlan': mealPlan});
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to remove meal: $e');
    }
  }

  /// Create or update a user profile.
  /// Returns [FirestoreResult] with null data or error message.
  Future<FirestoreResult<void>> setUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.uid).set(user.toMap());
      return FirestoreResult<void>(data: null);
    } catch (e) {
      return FirestoreResult<void>(error: 'Failed to save user: $e');
    }
  }

  /// Get a user's profile by uid.
  /// Returns [FirestoreResult] with UserModel or error message.
  Future<FirestoreResult<UserModel>> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return FirestoreResult<UserModel>(data: UserModel.fromMap(doc.data()!));
      } else {
        return FirestoreResult<UserModel>(error: 'User not found');
      }
    } catch (e) {
      return FirestoreResult<UserModel>(error: 'Failed to fetch user: $e');
    }
  }
}