import 'package:flutter_test/flutter_test.dart';
import '../../lib/voice/hinglish_processor.dart';

void main() {
  late HinglishProcessor processor;

  setUp(() {
    processor = HinglishProcessor();
  });

  group('HinglishProcessor - Core Functionality', () {
    test('should extract simple Hindi food items', () {
      final result = processor.extractFoodItems('maine dal chawal khaya');
      
      expect(result.foodItems.length, equals(2));
      expect(result.foodItems.any((item) => item.name == 'lentils'), isTrue);
      expect(result.foodItems.any((item) => item.name == 'rice'), isTrue);
      expect(result.confidence, greaterThan(0.5));
    });

    test('should extract food items with quantities', () {
      final result = processor.extractFoodItems('do katori dal aur teen roti khaya');
      
      expect(result.foodItems.length, equals(2));
      
      final dalItem = result.foodItems.firstWhere((item) => item.name == 'lentils');
      expect(dalItem.quantity?.amount, equals(2.0));
      expect(dalItem.quantity?.unit, equals('katori'));
      
      final rotiItem = result.foodItems.firstWhere((item) => item.name == 'bread');
      expect(rotiItem.quantity?.amount, equals(3.0));
      expect(rotiItem.quantity?.unit, equals('piece'));
    });

    test('should extract food items with cooking methods', () {
      final result = processor.extractFoodItems('tadka dal aur tawa roti banaya');
      
      expect(result.foodItems.length, equals(2));
      
      final dalItem = result.foodItems.firstWhere((item) => item.name == 'lentils');
      expect(dalItem.cookingMethod, equals('tadka'));
      
      final rotiItem = result.foodItems.firstWhere((item) => item.name == 'bread');
      expect(rotiItem.cookingMethod, equals('tawa'));
    });

    test('should handle mixed Hindi-English text', () {
      final result = processor.extractFoodItems('I had aloo sabzi with rice');
      
      expect(result.foodItems.length, greaterThanOrEqualTo(2));
      expect(result.foodItems.any((item) => item.name == 'potato'), isTrue);
      expect(result.foodItems.any((item) => item.name == 'rice'), isTrue);
    });

    test('should identify ambiguous food terms', () {
      final result = processor.extractFoodItems('dal aur sabzi khaya');
      
      expect(result.ambiguities.length, equals(2));
      expect(result.ambiguities.any((amb) => amb.term == 'lentils' || amb.term == 'dal'), isTrue);
      expect(result.ambiguities.any((amb) => amb.term == 'vegetable' || amb.term == 'sabzi'), isTrue);
    });

    test('should handle empty or invalid input', () {
      final result1 = processor.extractFoodItems('');
      expect(result1.foodItems.length, equals(0));
      expect(result1.confidence, equals(0.0));

      final result2 = processor.extractFoodItems('hello world test');
      expect(result2.foodItems.length, equals(0));
    });

    test('should preserve original text references', () {
      final result = processor.extractFoodItems('maine aloo sabzi khaya');
      
      final alooItem = result.foodItems.firstWhere((item) => item.name == 'potato');
      expect(alooItem.originalText, equals('aloo'));
    });
  });

  group('HinglishProcessor - Nutrition Query Parsing', () {
    test('should identify calorie inquiry queries', () {
      final result1 = processor.parseNutritionQuery('dal mein kitni calorie hai?');
      expect(result1.queryType, equals(NutritionQueryType.calorieInquiry));

      final result2 = processor.parseNutritionQuery('how many calories in rice?');
      expect(result2.queryType, equals(NutritionQueryType.calorieInquiry));
    });

    test('should identify protein inquiry queries', () {
      final result = processor.parseNutritionQuery('paneer mein kitna protein hai?');
      expect(result.queryType, equals(NutritionQueryType.proteinInquiry));
    });

    test('should identify health inquiry queries', () {
      final result1 = processor.parseNutritionQuery('kya dal healthy hai?');
      expect(result1.queryType, equals(NutritionQueryType.healthInquiry));

      final result2 = processor.parseNutritionQuery('is rice sehatmand?');
      expect(result2.queryType, equals(NutritionQueryType.healthInquiry));
    });

    test('should identify weight management queries', () {
      final result1 = processor.parseNutritionQuery('weight loss ke liye kya khana chahiye?');
      expect(result1.queryType, equals(NutritionQueryType.weightManagement));

      final result2 = processor.parseNutritionQuery('vajan kam karne ke liye diet');
      expect(result2.queryType, equals(NutritionQueryType.weightManagement));
    });

    test('should identify medical concern queries', () {
      final result1 = processor.parseNutritionQuery('diabetes mein kya kha sakte hai?');
      expect(result1.queryType, equals(NutritionQueryType.medicalConcern));

      final result2 = processor.parseNutritionQuery('sugar patient ke liye food');
      expect(result2.queryType, equals(NutritionQueryType.medicalConcern));
    });

    test('should extract nutrition concerns from queries', () {
      final result = processor.parseNutritionQuery(
        'mujhe diabetes hai aur weight loss karna hai, kya khana chahiye?'
      );
      
      expect(result.nutritionConcerns.contains('diabetes'), isTrue);
      expect(result.nutritionConcerns.contains('weight_loss'), isTrue);
    });
  });

  group('HinglishProcessor - Clarification Questions', () {
    test('should generate clarification questions for ambiguous terms', () {
      final ambiguities = [
        FoodAmbiguity(
          term: 'lentils',
          possibleMeanings: ['moong dal', 'toor dal', 'masoor dal'],
          context: 'dal khaya',
        ),
      ];

      final questions = processor.generateClarificationQuestions(ambiguities);
      
      expect(questions.length, equals(1));
      expect(questions[0].contains('lentils se kya matlab hai'), isTrue);
    });

    test('should handle empty ambiguities list', () {
      final questions = processor.generateClarificationQuestions([]);
      expect(questions.length, equals(0));
    });
  });

  group('HinglishProcessor - Edge Cases', () {
    test('should handle text with numbers and special characters', () {
      final result = processor.extractFoodItems('2 katori dal, 3 roti & 1 glass milk!');
      
      expect(result.foodItems.length, greaterThanOrEqualTo(3));
      
      final dalItem = result.foodItems.firstWhere((item) => item.name == 'lentils');
      expect(dalItem.quantity?.amount, equals(2.0));
      
      final rotiItem = result.foodItems.firstWhere((item) => item.name == 'bread');
      expect(rotiItem.quantity?.amount, equals(3.0));
      
      final milkItem = result.foodItems.firstWhere((item) => item.name == 'milk');
      expect(milkItem.quantity?.amount, equals(1.0));
    });

    test('should handle repeated food items', () {
      final result = processor.extractFoodItems('dal khaya, phir dal khaya, aur dal khaya');
      
      expect(result.foodItems.length, equals(3));
      expect(result.foodItems.every((item) => item.name == 'lentils'), isTrue);
    });

    test('should handle very long text descriptions', () {
      final longText = 'subah uthke maine chai piya, phir breakfast mein do paratha aur achar khaya, '
          'lunch mein dal chawal aur sabzi thi, evening mein samosa aur chai li, '
          'dinner mein roti sabzi aur dahi khaya';
      
      final result = processor.extractFoodItems(longText);
      
      expect(result.foodItems.length, greaterThan(5));
      expect(result.confidence, greaterThan(0.0));
    });
  });

  group('HinglishProcessor - Integration Scenarios', () {
    test('should handle typical meal logging scenario', () {
      final result = processor.extractFoodItems(
        'Maine breakfast mein do aloo paratha, thoda dahi aur ek cup chai li'
      );
      
      expect(result.foodItems.length, greaterThanOrEqualTo(3));
      expect(result.foodItems.any((item) => item.name == 'stuffed flatbread' || item.name == 'potato'), isTrue);
      expect(result.foodItems.any((item) => item.name == 'yogurt'), isTrue);
      expect(result.foodItems.any((item) => item.name == 'tea'), isTrue);
    });

    test('should handle nutrition inquiry with food context', () {
      final result = processor.parseNutritionQuery(
        'Kya paneer makhani healthy hai? Mujhe weight loss karna hai'
      );
      
      expect(result.queryType, equals(NutritionQueryType.healthInquiry));
      expect(result.nutritionConcerns.contains('weight_loss'), isTrue);
      expect(result.foodItems.any((item) => item.name == 'makhani'), isTrue);
    });
  });
}