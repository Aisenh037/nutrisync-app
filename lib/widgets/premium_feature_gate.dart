import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/providers.dart';
import '../screens/subscription_screen.dart';
import '../core/subscription/subscription_config.dart';

// ── Feature gate ──────────────────────────────────────────────────────────────

/// Gates premium features.  Shows a shimmer placeholder while the entitlement
/// status is loading, an upgrade card when the user is on the free tier, or
/// [child] when access is granted.
class PremiumFeatureGate extends ConsumerWidget {
  const PremiumFeatureGate({
    super.key,
    required this.featureName,
    required this.child,
    this.fallback,
    this.showUpgradePrompt = true,
  });

  final String featureName;
  final Widget child;

  /// Custom widget to show instead of the upgrade card.
  final Widget? fallback;

  /// When `false` and the user lacks access, renders [SizedBox.shrink].
  final bool showUpgradePrompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementStatusProvider);

    return entitlement.when(
      loading: () => _GateSkeleton(featureName: featureName),
      error: (_, __) =>
          fallback ?? (showUpgradePrompt ? _UpgradeCard(featureName: featureName) : const SizedBox.shrink()),
      data: (status) {
        final features = ref.read(availableFeaturesProvider);
        final hasAccess = features[featureName] ?? false;

        if (hasAccess) return child;
        return fallback ??
            (showUpgradePrompt
                ? _UpgradeCard(featureName: featureName)
                : const SizedBox.shrink());
      },
    );
  }
}

// ── Shimmer skeleton shown while loading ──────────────────────────────────────

class _GateSkeleton extends StatelessWidget {
  const _GateSkeleton({required this.featureName});
  final String featureName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[600]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 180,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ── Upgrade prompt card ───────────────────────────────────────────────────────

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.featureName});
  final String featureName;

  @override
  Widget build(BuildContext context) {
    final prompts = SubscriptionConfig.upgradePrompts;
    final prompt = prompts[featureName] ?? SubscriptionConfig.defaultPrompt(featureName);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber[400]!, Colors.amber[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  prompt.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            prompt.body,
            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          ...prompt.benefits.map(
            (b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.amber[800],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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

// ── Query limit banner ────────────────────────────────────────────────────────

/// Shows a warning bar when the user is approaching or has hit their daily
/// voice query limit (free tier only).
class QueryLimitWarning extends ConsumerWidget {
  const QueryLimitWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Premium users never see this banner.
    if (ref.watch(isPremiumProvider)) return const SizedBox.shrink();

    final subscriptionStatus = ref.watch(subscriptionStatusProvider);

    return subscriptionStatus.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        if (status == null) return const SizedBox.shrink();

        final queriesUsed = status['queriesUsed'] as int? ?? 0;
        final queriesLimit = status['queriesLimit'] as int? ??
            SubscriptionConfig.freeVoiceQueriesPerDay;
        final hasReachedLimit = status['hasReachedLimit'] as bool? ?? false;
        final remaining = queriesLimit - queriesUsed;
        final usageRatio =
            queriesLimit > 0 ? queriesUsed / queriesLimit : 0.0;

        if (usageRatio < 0.8 && !hasReachedLimit) return const SizedBox.shrink();

        final accent = hasReachedLimit ? Colors.red : Colors.orange;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasReachedLimit ? Icons.block : Icons.warning_amber,
                    color: accent.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasReachedLimit ? 'Daily limit reached' : 'Running low',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accent.shade700,
                        fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                hasReachedLimit
                    ? 'You\'ve used all $queriesLimit voice queries today. Upgrade for unlimited access.'
                    : '$remaining voice quer${remaining == 1 ? 'y' : 'ies'} left today.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: usageRatio.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade300,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(accent.shade600),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$queriesUsed/$queriesLimit',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (hasReachedLimit || usageRatio > 0.9) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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

// ── Mixin for screens that need programmatic feature checks ───────────────────

mixin PremiumFeatureMixin {
  Future<bool> checkFeatureAccess(WidgetRef ref, String featureName) async {
    return ref.read(revenueCatServiceProvider).hasFeatureAccess(featureName);
  }

  Future<bool> checkQueryLimit(WidgetRef ref) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return false;
    final result = await ref
        .read(subscriptionServiceProvider)
        .canMakeQuery(user.uid);
    return result.data ?? false;
  }

  Future<void> incrementQueryCount(WidgetRef ref) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    await ref.read(subscriptionServiceProvider).incrementQueryCount(user.uid);
    ref.invalidate(subscriptionStatusProvider);
  }

  void showUpgradeDialog(BuildContext context, String featureName) {
    final prompts = SubscriptionConfig.upgradePrompts;
    final prompt = prompts[featureName] ?? SubscriptionConfig.defaultPrompt(featureName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(prompt.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prompt.body),
            const SizedBox(height: 14),
            const Text('What you get:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...prompt.benefits.map(
              (b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(b, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
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
