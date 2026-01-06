import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/subscription_service.dart';

/// Screen for managing user subscriptions and viewing tier benefits
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isLoading = false;

  Future<void> _upgradeToPremium() async {
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).asData?.value;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final subscriptionService = ref.read(subscriptionServiceProvider);
      
      // In a real app, you'd integrate with payment processing here
      // For now, we'll simulate a successful upgrade
      final expiryDate = DateTime.now().add(const Duration(days: 30));
      
      final result = await subscriptionService.upgradeToPremium(
        uid: user.uid,
        expiresAt: expiryDate,
      );

      if (result.error != null) {
        throw Exception(result.error);
      }

      // Refresh providers
      ref.invalidate(subscriptionStatusProvider);
      ref.invalidate(availableFeaturesProvider);
      ref.invalidate(userProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully upgraded to Premium!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upgrade failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionStatus = ref.watch(subscriptionStatusProvider);
    final availableFeatures = ref.watch(availableFeaturesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Subscription', style: TextStyle(color: Color(0xFF2D5B42))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2D5B42)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: subscriptionStatus.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(subscriptionStatusProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (status) => _buildSubscriptionContent(status, availableFeatures.asData?.value),
      ),
    );
  }

  Widget _buildSubscriptionContent(Map<String, dynamic>? status, Map<String, bool>? features) {
    if (status == null) {
      return const Center(child: Text('No subscription data available'));
    }

    final isPremium = status['isPremium'] as bool? ?? false;
    final tier = status['tier'] as String? ?? 'free';
    final queriesUsed = status['queriesUsed'] as int? ?? 0;
    final queriesLimit = status['queriesLimit'] as int? ?? 50;
    final remainingQueries = status['remainingQueries'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current subscription status
          _buildCurrentStatusCard(isPremium, tier, queriesUsed, queriesLimit, remainingQueries),
          
          const SizedBox(height: 24),
          
          // Usage statistics
          _buildUsageCard(queriesUsed, queriesLimit, remainingQueries),
          
          const SizedBox(height: 24),
          
          // Feature comparison
          _buildFeatureComparison(features ?? {}),
          
          const SizedBox(height: 24),
          
          // Upgrade/manage subscription
          if (!isPremium) _buildUpgradeCard(),
          if (isPremium) _buildManageSubscriptionCard(status),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard(bool isPremium, String tier, int queriesUsed, int queriesLimit, int remainingQueries) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isPremium 
                ? [Colors.amber[400]!, Colors.amber[600]!]
                : [Colors.blue[400]!, Colors.blue[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPremium ? Icons.star : Icons.person,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  isPremium ? 'Premium Member' : 'Free Member',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPremium 
                  ? 'Enjoy unlimited access to all features'
                  : 'Upgrade to unlock premium features',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            if (isPremium) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(int queriesUsed, int queriesLimit, int remainingQueries) {
    final usagePercentage = queriesLimit > 0 ? queriesUsed / queriesLimit : 0.0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Usage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$queriesUsed / $queriesLimit queries used'),
                Text('$remainingQueries remaining', style: const TextStyle(color: Colors.green)),
              ],
            ),
            const SizedBox(height: 8),
            
            LinearProgressIndicator(
              value: usagePercentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                usagePercentage > 0.8 ? Colors.red : Colors.green,
              ),
            ),
            
            if (usagePercentage > 0.8) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You\'re running low on queries. Consider upgrading to Premium for unlimited access.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureComparison(Map<String, bool> features) {
    final freeFeatures = [
      {'name': 'Basic Voice Queries', 'free': true, 'premium': true, 'icon': Icons.mic},
      {'name': 'Meal Logging', 'free': true, 'premium': true, 'icon': Icons.restaurant},
      {'name': 'Basic Nutrition Info', 'free': true, 'premium': true, 'icon': Icons.info},
      {'name': 'Hinglish Support', 'free': true, 'premium': true, 'icon': Icons.language},
    ];

    final premiumFeatures = [
      {'name': 'Unlimited Voice Queries', 'free': false, 'premium': true, 'icon': Icons.all_inclusive},
      {'name': 'Personalized Meal Plans', 'free': false, 'premium': true, 'icon': Icons.calendar_today},
      {'name': 'Advanced Nutrition Analysis', 'free': false, 'premium': true, 'icon': Icons.analytics},
      {'name': 'Smart Grocery Lists', 'free': false, 'premium': true, 'icon': Icons.shopping_cart},
      {'name': 'Calendar Integration', 'free': false, 'premium': true, 'icon': Icons.event},
      {'name': 'Priority Support', 'free': false, 'premium': true, 'icon': Icons.support_agent},
      {'name': 'Export Data', 'free': false, 'premium': true, 'icon': Icons.download},
      {'name': 'Family Profiles', 'free': false, 'premium': true, 'icon': Icons.family_restroom},
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Features Comparison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
            ),
            const SizedBox(height: 16),
            
            // Header
            Row(
              children: [
                const Expanded(flex: 2, child: Text('Feature', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(child: Text('Free', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(child: Text('Premium', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(),
            
            // Free features
            ...freeFeatures.map((feature) => _buildFeatureRow(feature)),
            
            const SizedBox(height: 8),
            const Text(
              'Premium Features',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 8),
            
            // Premium features
            ...premiumFeatures.map((feature) => _buildFeatureRow(feature)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(Map<String, dynamic> feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(feature['icon'] as IconData, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(child: Text(feature['name'] as String)),
              ],
            ),
          ),
          Expanded(
            child: Icon(
              (feature['free'] as bool) ? Icons.check : Icons.close,
              color: (feature['free'] as bool) ? Colors.green : Colors.red,
            ),
          ),
          Expanded(
            child: Icon(
              (feature['premium'] as bool) ? Icons.check : Icons.close,
              color: (feature['premium'] as bool) ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.amber[400]!, Colors.amber[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlock unlimited voice queries, personalized meal plans, and advanced nutrition analysis.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                const Text(
                  '₹299/month',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Best Value',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _upgradeToPremium,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.amber[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Upgrade Now',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageSubscriptionCard(Map<String, dynamic> status) {
    final expiresAt = status['expiresAt'] as String?;
    final expiryDate = expiresAt != null ? DateTime.parse(expiresAt) : null;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Subscription',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5B42)),
            ),
            const SizedBox(height: 16),
            
            if (expiryDate != null) ...[
              Row(
                children: [
                  const Icon(Icons.event, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Expires on: ${_formatDate(expiryDate)}'),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implement subscription management
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Subscription management coming soon!')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2D5B42)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Manage', style: TextStyle(color: Color(0xFF2D5B42))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implement cancel subscription
                      _showCancelDialog();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your Premium subscription? You\'ll lose access to premium features at the end of your billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Premium'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement actual cancellation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Subscription cancellation coming soon!')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}