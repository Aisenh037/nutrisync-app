import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../screens/subscription_screen.dart';
import '../services/subscription_service.dart';

/// Widget that gates premium features and shows upgrade prompts
class PremiumFeatureGate extends ConsumerWidget {
  final String featureName;
  final Widget child;
  final Widget? fallback;
  final bool showUpgradePrompt;

  const PremiumFeatureGate({
    super.key,
    required this.featureName,
    required this.child,
    this.fallback,
    this.showUpgradePrompt = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableFeatures = ref.watch(availableFeaturesProvider);

    return availableFeatures.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => fallback ?? _buildErrorWidget(error),
      data: (features) {
        final hasAccess = features?[featureName] ?? false;
        
        if (hasAccess) {
          return child;
        } else {
          return fallback ?? (showUpgradePrompt 
              ? _buildUpgradePrompt(context, ref) 
              : const SizedBox.shrink());
        }
      },
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text('Error: $error'),
        ],
      ),
    );
  }

  Widget _buildUpgradePrompt(BuildContext context, WidgetRef ref) {
    final subscriptionService = ref.read(subscriptionServiceProvider);
    final prompt = subscriptionService.getUpgradePrompt(featureName);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber[400]!, Colors.amber[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prompt['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Text(
            prompt['message'] as String,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          
          // Benefits list
          if (prompt['benefits'] != null) ...[
            ...((prompt['benefits'] as List).map((benefit) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.check, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit as String,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ))),
            const SizedBox(height: 16),
          ],
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.amber[700],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Upgrade to Premium',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget for showing query limit warnings
class QueryLimitWarning extends ConsumerWidget {
  const QueryLimitWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionStatus = ref.watch(subscriptionStatusProvider);

    return subscriptionStatus.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (status) {
        if (status == null) return const SizedBox.shrink();
        
        final queriesUsed = status['queriesUsed'] as int? ?? 0;
        final queriesLimit = status['queriesLimit'] as int? ?? 50;
        final remainingQueries = status['remainingQueries'] as int? ?? 0;
        final hasReachedLimit = status['hasReachedLimit'] as bool? ?? false;
        
        final usagePercentage = queriesLimit > 0 ? queriesUsed / queriesLimit : 0.0;
        
        // Show warning when usage is high or limit is reached
        if (usagePercentage < 0.8 && !hasReachedLimit) {
          return const SizedBox.shrink();
        }
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasReachedLimit ? Colors.red[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasReachedLimit ? Colors.red[200]! : Colors.orange[200]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasReachedLimit ? Icons.block : Icons.warning,
                    color: hasReachedLimit ? Colors.red[700] : Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasReachedLimit ? 'Query Limit Reached' : 'Query Limit Warning',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasReachedLimit ? Colors.red[700] : Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Text(
                hasReachedLimit
                    ? 'You\'ve used all $queriesLimit queries for this month. Upgrade to Premium for unlimited access.'
                    : 'You have $remainingQueries queries remaining this month.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: usagePercentage,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        hasReachedLimit ? Colors.red : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$queriesUsed/$queriesLimit',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              
              if (hasReachedLimit || usagePercentage > 0.9) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[600],
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Upgrade to Premium'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Mixin for handling premium feature access in screens
mixin PremiumFeatureMixin {
  Future<bool> checkFeatureAccess(WidgetRef ref, String featureName) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return false;
    
    final subscriptionService = ref.read(subscriptionServiceProvider);
    final result = await subscriptionService.hasFeatureAccess(user.uid, featureName);
    
    return result.data ?? false;
  }
  
  Future<bool> checkQueryLimit(WidgetRef ref) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return false;
    
    final subscriptionService = ref.read(subscriptionServiceProvider);
    final result = await subscriptionService.canMakeQuery(user.uid);
    
    return result.data ?? false;
  }
  
  Future<void> incrementQueryCount(WidgetRef ref) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    
    final subscriptionService = ref.read(subscriptionServiceProvider);
    await subscriptionService.incrementQueryCount(user.uid);
    
    // Refresh subscription status
    ref.invalidate(subscriptionStatusProvider);
  }
  
  void showUpgradeDialog(BuildContext context, String featureName) {
    final subscriptionService = SubscriptionService();
    final prompt = subscriptionService.getUpgradePrompt(featureName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 8),
            Text(prompt['title'] as String),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prompt['message'] as String),
            const SizedBox(height: 16),
            if (prompt['benefits'] != null) ...[
              const Text(
                'Premium Benefits:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...((prompt['benefits'] as List).map((benefit) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(benefit as String, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ))),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[600]),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
}