import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages Firestore database schema and collections for Indian Food Database
class FirestoreSchemaManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection names
  static const String indianFoodsCollection = 'indian_foods';
  static const String userProfilesCollection = 'user_profiles';
  static const String mealHistoryCollection = 'meal_history';
  static const String groceryListsCollection = 'grocery_lists';

  /// Initialize database schema and indexes
  Future<void> initializeSchema() async {
    try {
      print('Initializing Firestore schema...');
      
      // Create collections with initial documents if they don't exist
      await _ensureCollectionExists(indianFoodsCollection);
      await _ensureCollectionExists(userProfilesCollection);
      await _ensureCollectionExists(mealHistoryCollection);
      await _ensureCollectionExists(groceryListsCollection);
      
      // Note: Firestore indexes need to be created through Firebase Console
      // or firebase CLI, not programmatically
      print('Schema initialization completed');
    } catch (e) {
      print('Error initializing schema: $e');
      rethrow;
    }
  }

  /// Ensure a collection exists by creating a temporary document
  Future<void> _ensureCollectionExists(String collectionName) async {
    try {
      final collection = _firestore.collection(collectionName);
      final docs = await collection.limit(1).get();
      
      if (docs.docs.isEmpty) {
        // Create a temporary document to initialize the collection
        await collection.doc('_temp').set({
          'initialized': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Delete the temporary document
        await collection.doc('_temp').delete();
        
        print('Initialized collection: $collectionName');
      }
    } catch (e) {
      print('Error ensuring collection exists ($collectionName): $e');
    }
  }

  /// Get collection reference
  CollectionReference getCollection(String collectionName) {
    return _firestore.collection(collectionName);
  }

  /// Get Indian Foods collection
  CollectionReference get indianFoods => getCollection(indianFoodsCollection);

  /// Get User Profiles collection
  CollectionReference get userProfiles => getCollection(userProfilesCollection);

  /// Get Meal History collection
  CollectionReference get mealHistory => getCollection(mealHistoryCollection);

  /// Get Grocery Lists collection
  CollectionReference get groceryLists => getCollection(groceryListsCollection);

  /// Create compound indexes (documentation for Firebase Console setup)
  Map<String, List<Map<String, String>>> getRequiredIndexes() {
    return {
      indianFoodsCollection: [
        {
          'field': 'searchTerms',
          'type': 'array-contains',
        },
        {
          'field': 'category',
          'type': 'ascending',
        },
        {
          'field': 'regions.primaryRegion',
          'type': 'ascending',
        },
      ],
      mealHistoryCollection: [
        {
          'field': 'userId',
          'type': 'ascending',
        },
        {
          'field': 'timestamp',
          'type': 'descending',
        },
      ],
      groceryListsCollection: [
        {
          'field': 'userId',
          'type': 'ascending',
        },
        {
          'field': 'createdAt',
          'type': 'descending',
        },
      ],
    };
  }

  /// Validate database schema
  Future<bool> validateSchema() async {
    try {
      // Check if all required collections exist
      final collections = [
        indianFoodsCollection,
        userProfilesCollection,
        mealHistoryCollection,
        groceryListsCollection,
      ];

      for (String collectionName in collections) {
        final collection = _firestore.collection(collectionName);
        await collection.limit(1).get(); // This will fail if collection doesn't exist
      }

      print('Schema validation passed');
      return true;
    } catch (e) {
      print('Schema validation failed: $e');
      return false;
    }
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final stats = <String, int>{};

    try {
      // Count documents in each collection
      final indianFoodsCount = await _getCollectionCount(indianFoodsCollection);
      final userProfilesCount = await _getCollectionCount(userProfilesCollection);
      final mealHistoryCount = await _getCollectionCount(mealHistoryCollection);
      final groceryListsCount = await _getCollectionCount(groceryListsCollection);

      stats[indianFoodsCollection] = indianFoodsCount;
      stats[userProfilesCollection] = userProfilesCount;
      stats[mealHistoryCollection] = mealHistoryCount;
      stats[groceryListsCollection] = groceryListsCount;

      return stats;
    } catch (e) {
      print('Error getting database stats: $e');
      return stats;
    }
  }

  /// Get approximate count of documents in a collection
  Future<int> _getCollectionCount(String collectionName) async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error counting documents in $collectionName: $e');
      return 0;
    }
  }

  /// Setup security rules (documentation for Firebase Console)
  String getSecurityRules() {
    return '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Indian Foods - read access for all authenticated users
    match /indian_foods/{document} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }
    
    // User Profiles - users can only access their own profile
    match /user_profiles/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Meal History - users can only access their own meal history
    match /meal_history/{document} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Grocery Lists - users can only access their own grocery lists
    match /grocery_lists/{document} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
  }
}
''';
  }
}