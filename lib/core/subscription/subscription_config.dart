/// Single source of truth for feature tiers and product identifiers.
///
/// RevenueCat entitlements must be configured in the RevenueCat dashboard
/// with the same identifiers defined here.
class SubscriptionConfig {
  SubscriptionConfig._();

  // ── RevenueCat API key ─────────────────────────────────────────────────────
  // Injected at build time: flutter build apk --dart-define=REVENUECAT_API_KEY=appl_xxx
  static const revenueCatApiKey =
      String.fromEnvironment('REVENUECAT_API_KEY');

  // ── Entitlement identifier (set in RevenueCat dashboard) ──────────────────
  static const premiumEntitlement = 'premium';

  // ── Product identifiers (must match Play Store / App Store) ───────────────
  static const monthlyProductId = 'nutrisync_premium_monthly';  // ₹199/mo
  static const yearlyProductId  = 'nutrisync_premium_yearly';   // ₹1499/yr

  // ── Feature → tier mapping ─────────────────────────────────────────────────
  /// Features accessible on the FREE tier.
  static const freeFeatures = {
    'basic_voice_queries',   // 5 voice logs/day
    'meal_logging',
    'basic_nutrition_info',
    'hinglish_support',
    'grocery_manual',        // manual grocery list
    'store_finder_basic',    // city-level store search
  };

  /// Features that require PREMIUM entitlement.
  static const premiumFeatures = {
    'unlimited_voice_queries',
    'personalized_meal_plans',
    'advanced_nutrition_analysis',
    'grocery_list_optimization',   // AI-generated from meal plan
    'calendar_integration',
    'store_finder_directions',     // navigation + directions
    'food_vision_unlimited',       // unlimited food photo scans
    'export_data',                 // PDF + email reports
    'family_profiles',
    'priority_support',
  };

  /// Free tier daily voice query limit.
  static const freeVoiceQueriesPerDay = 5;

  /// Free tier food vision scans per day.
  static const freeVisionScansPerDay = 3;

  // ── Upgrade prompt copy ───────────────────────────────────────────────────
  static Map<String, _UpgradePrompt> get upgradePrompts => {
    'unlimited_voice_queries': const _UpgradePrompt(
      title: 'Unlimited Voice Queries',
      body: 'You\'ve hit your daily limit. Upgrade to Premium for unlimited AI conversations.',
      benefits: ['Unlimited daily voice logs', 'Priority AI responses', '24/7 availability'],
    ),
    'personalized_meal_plans': const _UpgradePrompt(
      title: 'Personalised Meal Plans',
      body: 'Get custom meal plans built around your goals, region, and dietary needs.',
      benefits: ['AI-personalised planning', 'Regional cuisine focus', 'Dietary restrictions support'],
    ),
    'grocery_list_optimization': const _UpgradePrompt(
      title: 'Smart Grocery Lists',
      body: 'Auto-generate your weekly grocery list from your meal plan in one tap.',
      benefits: ['Auto-generated from meal plan', 'Budget estimation', 'Store section grouping'],
    ),
    'store_finder_directions': const _UpgradePrompt(
      title: 'Store Navigation',
      body: 'Get turn-by-turn directions to the best grocery stores near you.',
      benefits: ['Directions in Google Maps / Waze', 'Store hours & contact', 'Dietary filter'],
    ),
    'food_vision_unlimited': const _UpgradePrompt(
      title: 'Unlimited Food Scans',
      body: 'Scan any meal with your camera to instantly log nutrition.',
      benefits: ['Unlimited daily scans', 'Instant nutrition breakdown', 'Portion estimation'],
    ),
    'export_data': const _UpgradePrompt(
      title: 'Export Reports',
      body: 'Download and share your nutrition progress as a PDF or receive it by email.',
      benefits: ['Weekly PDF reports', 'Email delivery', 'Share with your doctor'],
    ),
  };

  static _UpgradePrompt defaultPrompt(String feature) => _UpgradePrompt(
    title: 'Premium Feature',
    body: 'Unlock $feature with a Premium subscription.',
    benefits: ['Enhanced functionality', 'Priority support', 'All premium features'],
  );
}

class _UpgradePrompt {
  const _UpgradePrompt({
    required this.title,
    required this.body,
    required this.benefits,
  });
  final String title;
  final String body;
  final List<String> benefits;
}
