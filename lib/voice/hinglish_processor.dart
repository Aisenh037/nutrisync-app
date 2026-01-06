import 'dart:convert';
import 'dart:math' as math;

/// Hinglish text processing service for mixed Hindi-English language parsing
/// Handles food item extraction and nutrition query parsing from Hinglish descriptions
class HinglishProcessor {
  
  // Common Hindi food words with English translations
  static const Map<String, String> _hindiToEnglish = {
    // Basic foods
    'chawal': 'rice',
    'dal': 'lentils',
    'sabzi': 'vegetable',
    'roti': 'bread',
    'chapati': 'flatbread',
    'paratha': 'stuffed flatbread',
    'naan': 'leavened bread',
    'dahi': 'yogurt',
    'paneer': 'cottage cheese',
    'ghee': 'clarified butter',
    'makhan': 'butter',
    'dudh': 'milk',
    'chai': 'tea',
    'paani': 'water',
    'namak': 'salt',
    'cheeni': 'sugar',
    'mirch': 'chili',
    'pyaaz': 'onion',
    'lahsun': 'garlic',
    'adrak': 'ginger',
    
    // Vegetables
    'aloo': 'potato',
    'tamatar': 'tomato',
    'palak': 'spinach',
    'gobi': 'cauliflower',
    'bhindi': 'okra',
    'karela': 'bitter gourd',
    'lauki': 'bottle gourd',
    'baingan': 'eggplant',
    'shimla mirch': 'bell pepper',
    'gajar': 'carrot',
    'matar': 'peas',
    'methi': 'fenugreek',
    
    // Grains and pulses
    'moong': 'mung beans',
    'chana': 'chickpeas',
    'rajma': 'kidney beans',
    'masoor': 'red lentils',
    'toor': 'pigeon peas',
    'urad': 'black gram',
    'basmati': 'basmati rice',
    'jeera': 'cumin rice',
    'atta': 'wheat flour',
    'besan': 'gram flour',
    
    // Cooking methods
    'pakka': 'cooked',
    'kaccha': 'raw',
    'garam': 'hot',
    'thanda': 'cold',
    'meetha': 'sweet',
    'namkeen': 'salty',
    'teekha': 'spicy',
    'khatta': 'sour',
    
    // Quantities
    'thoda': 'little',
    'zyada': 'more',
    'kam': 'less',
    'poora': 'full',
    'aadha': 'half',
    'ek': 'one',
    'do': 'two',
    'teen': 'three',
    'char': 'four',
    'paanch': 'five',
  };

  // Common food patterns in Hinglish
  static const List<String> _foodPatterns = [
    // Meal patterns
    r'(\w+)\s+(khaya|khayi|khayenge|kha\s*liya)',  // ate something
    r'(maine|mene)\s+(\w+)\s+(khaya|khayi)',       // I ate something
    r'(\w+)\s+(banaya|banai|banayi)',              // made something
    r'(\w+)\s+(piya|peya|pi\s*liya)',             // drank something
    
    // Quantity patterns
    r'(\d+)\s*(katori|glass|roti|spoon|cup|plate)', // numbered portions
    r'(thoda|zyada|kam|aadha|poora)\s+(\w+)',      // quantity descriptors
    r'(\w+)\s+(ke\s+saath|with)',                   // food combinations
    
    // Cooking method patterns
    r'(\w+)\s+(mein|me)\s+(banaya|pakaya)',        // cooked in style
    r'(tadka|bhuna|dum|tawa|tandoor)\s+(\w+)',     // cooking methods
  ];

  // Ambiguous terms that need clarification
  static const Map<String, List<String>> _ambiguousTerms = {
    'lentils': ['moong dal', 'toor dal', 'masoor dal', 'chana dal', 'urad dal'],
    'vegetable': ['aloo sabzi', 'palak sabzi', 'gobi sabzi', 'bhindi sabzi'],
    'curry': ['chicken curry', 'mutton curry', 'paneer curry', 'vegetable curry'],
    'rice': ['plain rice', 'jeera rice', 'biryani', 'pulao'],
    'stuffed flatbread': ['aloo paratha', 'gobi paratha', 'paneer paratha', 'plain paratha'],
    'tea': ['milk tea', 'black tea', 'green tea', 'masala chai'],
    // Also include Hindi terms
    'dal': ['moong dal', 'toor dal', 'masoor dal', 'chana dal', 'urad dal'],
    'sabzi': ['aloo sabzi', 'palak sabzi', 'gobi sabzi', 'bhindi sabzi'],
    'paratha': ['aloo paratha', 'gobi paratha', 'paneer paratha', 'plain paratha'],
    'chai': ['milk tea', 'black tea', 'green tea', 'masala chai'],
  };

  /// Process Hinglish text and extract food items
  FoodExtractionResult extractFoodItems(String hinglishText) {
    final normalizedText = _normalizeText(hinglishText);
    final translatedText = _translateHindiWords(normalizedText);
    
    final foodItems = <ExtractedFoodItem>[];
    final ambiguities = <FoodAmbiguity>[];
    
    // Extract food items using patterns and dictionary matching
    final words = translatedText.split(' ');
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i].toLowerCase();
      
      // Skip if not a food item
      if (!_isKnownFoodItem(word)) {
        continue;
      }
      
      // Check for compound food items (like "aloo sabzi" -> "potato vegetable")
      String? compoundFood = _checkCompoundFood(words, i);
      if (compoundFood != null) {
        if (i + 1 < words.length) {
          i++; // Skip the next word as it's part of compound
        }
        continue; // Skip individual processing for compound foods
      }
      
      final quantity = _extractQuantityBefore(words, i);
      final cookingMethod = _extractCookingMethodAround(words, i);
      
      final foodItem = ExtractedFoodItem(
        name: word,
        originalText: _getOriginalPhrase(hinglishText, word),
        quantity: quantity,
        cookingMethod: cookingMethod,
        confidence: _calculateConfidence(word, quantity, cookingMethod),
      );
      
      foodItems.add(foodItem);
      
      // Check for ambiguity using original Hindi terms
      final originalWord = _getOriginalPhrase(hinglishText, word);
      if (_ambiguousTerms.containsKey(originalWord) || _ambiguousTerms.containsKey(word)) {
        final ambiguousTerm = _ambiguousTerms.containsKey(originalWord) ? originalWord : word;
        ambiguities.add(FoodAmbiguity(
          term: ambiguousTerm,
          possibleMeanings: _ambiguousTerms[ambiguousTerm]!,
          context: _getContextAround(words, i),
        ));
      }
    }
    
    return FoodExtractionResult(
      foodItems: foodItems,
      ambiguities: ambiguities,
      originalText: hinglishText,
      processedText: translatedText,
      confidence: _calculateOverallConfidence(foodItems),
    );
  }

  /// Parse nutrition-related queries from Hinglish text
  NutritionQueryResult parseNutritionQuery(String hinglishText) {
    final normalizedText = _normalizeText(hinglishText);
    final translatedText = _translateHindiWords(normalizedText);
    
    final queryType = _identifyQueryType(translatedText);
    final foodItems = extractFoodItems(hinglishText).foodItems;
    final nutritionConcerns = _extractNutritionConcerns(translatedText);
    
    return NutritionQueryResult(
      queryType: queryType,
      foodItems: foodItems,
      nutritionConcerns: nutritionConcerns,
      originalQuery: hinglishText,
      processedQuery: translatedText,
      requiresClarification: foodItems.any((item) => item.confidence < 0.7),
    );
  }

  /// Generate clarification questions for ambiguous food descriptions
  List<String> generateClarificationQuestions(List<FoodAmbiguity> ambiguities) {
    final questions = <String>[];
    
    for (final ambiguity in ambiguities) {
      final hinglishOptions = ambiguity.possibleMeanings
          .map((meaning) => _translateToHinglish(meaning))
          .join(', ');
      
      questions.add(
        'Aap ${ambiguity.term} se kya matlab hai? '
        'Options: $hinglishOptions'
      );
    }
    
    return questions;
  }

  /// Check if a word represents a known food item
  bool _isKnownFoodItem(String word) {
    // Skip numbers and common non-food words
    if (RegExp(r'^\d+$').hasMatch(word)) return false;
    const nonFoodWords = [
      'maine', 'mene', 'khaya', 'khayi', 'banaya', 'piya', 'aur', 'with', 'and', 'the', 'a', 'an',
      'ek', 'do', 'teen', 'char', 'paanch', 'one', 'two', 'three', 'four', 'five',
      'had', 'ate', 'drank', 'made', 'cooked', 'healthy', 'sehatmand', 'kya', 'hai', 'mujhe'
    ];
    if (nonFoodWords.contains(word)) return false;
    
    // Check in Hindi-English dictionary
    if (_hindiToEnglish.containsKey(word) || _hindiToEnglish.containsValue(word)) {
      return true;
    }
    
    // Check common English food words
    const commonFoods = [
      'rice', 'bread', 'milk', 'tea', 'coffee', 'water', 'juice',
      'chicken', 'mutton', 'fish', 'egg', 'vegetable', 'fruit',
      'curry', 'soup', 'salad', 'sandwich', 'pizza', 'burger',
      'makhani'
    ];
    
    return commonFoods.contains(word.toLowerCase());
  }

  /// Normalize Hinglish text for processing
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')  // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ')      // Normalize whitespace
        .trim();
  }

  /// Translate Hindi words to English equivalents
  String _translateHindiWords(String text) {
    String translated = text;
    
    for (final entry in _hindiToEnglish.entries) {
      translated = translated.replaceAll(
        RegExp(r'\b' + entry.key + r'\b'),
        entry.value,
      );
    }
    
    return translated;
  }

  /// Check for compound food items like "aloo sabzi"
  String? _checkCompoundFood(List<String> words, int index) {
    if (index + 1 >= words.length) return null;
    
    final word1 = words[index].toLowerCase();
    final word2 = words[index + 1].toLowerCase();
    
    // Common compound foods
    const compounds = {
      'aloo sabzi': 'potato vegetable',
      'palak paneer': 'spinach cottage cheese',
      'dal makhani': 'lentils makhani',
      'jeera rice': 'cumin rice',
      'masala chai': 'spiced tea',
    };
    
    final compound = '$word1 $word2';
    return compounds[compound];
  }

  /// Extract quantity information before a food item
  FoodQuantity? _extractQuantityBefore(List<String> words, int foodIndex) {
    // Check up to 2 words before for quantity
    for (int i = math.max(0, foodIndex - 2); i < foodIndex; i++) {
      final word = words[i].toLowerCase();
      
      // Check for numeric quantity (including Hindi numbers)
      double? amount = _parseNumber(word);
      if (amount != null) {
        final unit = _extractUnitAfter(words, i) ?? 'piece';
        return FoodQuantity(
          amount: amount,
          unit: unit,
        );
      }
      
      // Check for descriptive quantities
      const quantityMap = {
        'thoda': 0.5,
        'zyada': 2.0,
        'kam': 0.3,
        'aadha': 0.5,
        'poora': 1.0,
      };
      
      if (quantityMap.containsKey(word)) {
        return FoodQuantity(
          amount: quantityMap[word]!,
          unit: 'portion',
        );
      }
    }
    
    return null;
  }

  /// Parse number from text (including Hindi numbers)
  double? _parseNumber(String word) {
    // Try parsing as regular number
    final numMatch = RegExp(r'(\d+)').firstMatch(word);
    if (numMatch != null) {
      return double.parse(numMatch.group(1)!);
    }
    
    // Parse Hindi numbers
    const hindiNumbers = {
      'ek': 1.0, 'do': 2.0, 'teen': 3.0, 'char': 4.0, 'paanch': 5.0,
      'one': 1.0, 'two': 2.0, 'three': 3.0, 'four': 4.0, 'five': 5.0,
    };
    
    return hindiNumbers[word];
  }

  /// Extract cooking method around a food item
  String? _extractCookingMethodAround(List<String> words, int foodIndex) {
    // Check words before and after for cooking methods
    const cookingMethods = [
      'tadka', 'bhuna', 'dum', 'tawa', 'tandoor', 'steamed', 'fried',
      'boiled', 'roasted', 'grilled', 'baked'
    ];
    
    for (int i = math.max(0, foodIndex - 2); 
         i < math.min(words.length, foodIndex + 3); 
         i++) {
      if (cookingMethods.contains(words[i].toLowerCase())) {
        return words[i].toLowerCase();
      }
    }
    
    return null;
  }

  /// Extract measurement unit after a number
  String? _extractUnitAfter(List<String> words, int index) {
    const units = [
      'katori', 'glass', 'roti', 'spoon', 'cup', 'plate',
      'kg', 'gram', 'liter', 'ml', 'piece', 'slice'
    ];
    
    // Check current and next word for units
    for (int i = index; i < math.min(words.length, index + 3); i++) {
      final word = words[i].toLowerCase();
      if (units.contains(word)) {
        return word;
      }
    }
    
    return null;
  }

  /// Extract measurement unit (legacy method for compatibility)
  String? _extractUnit(List<String> words, int index) {
    return _extractUnitAfter(words, index);
  }

  /// Calculate confidence score for food item extraction
  double _calculateConfidence(String foodName, FoodQuantity? quantity, String? cookingMethod) {
    double confidence = 0.5; // Base confidence
    
    // Higher confidence for known Hindi/English foods
    if (_hindiToEnglish.containsKey(foodName) || _hindiToEnglish.containsValue(foodName)) {
      confidence += 0.3;
    }
    
    // Boost confidence if quantity is specified
    if (quantity != null) {
      confidence += 0.1;
    }
    
    // Boost confidence if cooking method is specified
    if (cookingMethod != null) {
      confidence += 0.1;
    }
    
    return math.min(1.0, confidence);
  }

  /// Calculate overall confidence for extraction result
  double _calculateOverallConfidence(List<ExtractedFoodItem> foodItems) {
    if (foodItems.isEmpty) return 0.0;
    
    final totalConfidence = foodItems
        .map((item) => item.confidence)
        .reduce((a, b) => a + b);
    
    return totalConfidence / foodItems.length;
  }

  /// Get original phrase from text for a translated word
  String _getOriginalPhrase(String originalText, String translatedWord) {
    // Find the Hindi equivalent if it exists
    for (final entry in _hindiToEnglish.entries) {
      if (entry.value == translatedWord) {
        if (originalText.toLowerCase().contains(entry.key)) {
          return entry.key;
        }
      }
    }
    
    return translatedWord;
  }

  /// Get context words around a specific index
  String _getContextAround(List<String> words, int index) {
    final start = math.max(0, index - 2);
    final end = math.min(words.length, index + 3);
    return words.sublist(start, end).join(' ');
  }

  /// Identify the type of nutrition query
  NutritionQueryType _identifyQueryType(String text) {
    if (text.contains('calorie') || text.contains('kitni calorie')) {
      return NutritionQueryType.calorieInquiry;
    } else if (text.contains('protein') || text.contains('kitna protein')) {
      return NutritionQueryType.proteinInquiry;
    } else if (text.contains('healthy') || text.contains('sehatmand')) {
      return NutritionQueryType.healthInquiry;
    } else if (text.contains('weight') || text.contains('vajan')) {
      return NutritionQueryType.weightManagement;
    } else if (text.contains('diabetes') || text.contains('sugar')) {
      return NutritionQueryType.medicalConcern;
    } else {
      return NutritionQueryType.generalNutrition;
    }
  }

  /// Extract nutrition concerns from text
  List<String> _extractNutritionConcerns(String text) {
    final concerns = <String>[];
    
    const concernKeywords = {
      'diabetes': ['diabetes', 'sugar', 'blood sugar'],
      'weight_loss': ['weight loss', 'vajan kam', 'patla'],
      'weight_gain': ['weight gain', 'vajan badhana', 'mota'],
      'high_bp': ['blood pressure', 'bp', 'hypertension'],
      'cholesterol': ['cholesterol', 'heart'],
    };
    
    for (final entry in concernKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          concerns.add(entry.key);
          break;
        }
      }
    }
    
    return concerns;
  }

  /// Translate English food terms back to Hinglish for user interaction
  String _translateToHinglish(String englishTerm) {
    for (final entry in _hindiToEnglish.entries) {
      if (entry.value == englishTerm) {
        return entry.key;
      }
    }
    return englishTerm;
  }
}

// Data models for Hinglish processing results

class FoodExtractionResult {
  final List<ExtractedFoodItem> foodItems;
  final List<FoodAmbiguity> ambiguities;
  final String originalText;
  final String processedText;
  final double confidence;

  FoodExtractionResult({
    required this.foodItems,
    required this.ambiguities,
    required this.originalText,
    required this.processedText,
    required this.confidence,
  });
}

class ExtractedFoodItem {
  final String name;
  final String originalText;
  final FoodQuantity? quantity;
  final String? cookingMethod;
  final double confidence;

  ExtractedFoodItem({
    required this.name,
    required this.originalText,
    this.quantity,
    this.cookingMethod,
    required this.confidence,
  });
}

class FoodQuantity {
  final double amount;
  final String unit;

  FoodQuantity({
    required this.amount,
    required this.unit,
  });
}

class FoodAmbiguity {
  final String term;
  final List<String> possibleMeanings;
  final String context;

  FoodAmbiguity({
    required this.term,
    required this.possibleMeanings,
    required this.context,
  });
}

class NutritionQueryResult {
  final NutritionQueryType queryType;
  final List<ExtractedFoodItem> foodItems;
  final List<String> nutritionConcerns;
  final String originalQuery;
  final String processedQuery;
  final bool requiresClarification;

  NutritionQueryResult({
    required this.queryType,
    required this.foodItems,
    required this.nutritionConcerns,
    required this.originalQuery,
    required this.processedQuery,
    required this.requiresClarification,
  });
}

enum NutritionQueryType {
  calorieInquiry,
  proteinInquiry,
  healthInquiry,
  weightManagement,
  medicalConcern,
  generalNutrition,
}