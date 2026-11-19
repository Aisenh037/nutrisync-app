import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/subscription/subscription_config.dart';
import '../core/error/app_exception.dart';

/// Subscription entitlement state returned to the UI layer.
class EntitlementStatus {
  const EntitlementStatus({
    required this.isPremium,
    required this.activeProductId,
    required this.willRenew,
    required this.expirationDate,
  });

  final bool isPremium;
  final String? activeProductId;    // e.g. 'nutrisync_premium_monthly'
  final bool willRenew;
  final DateTime? expirationDate;

  static const free = EntitlementStatus(
    isPremium: false,
    activeProductId: null,
    willRenew: false,
    expirationDate: null,
  );
}

/// Available purchase packages shown on the paywall.
class OfferingsSnapshot {
  const OfferingsSnapshot({
    this.monthly,
    this.yearly,
    this.currentOfferingId,
  });

  final Package? monthly;
  final Package? yearly;
  final String? currentOfferingId;

  bool get isEmpty => monthly == null && yearly == null;
}

/// RevenueCat-backed subscription service.
///
/// Replaces the Firestore-based [SubscriptionService] for entitlement checks
/// and in-app purchases.  Daily usage counters (voice queries, vision scans)
/// remain in Firestore via [SubscriptionService].
class RevenueCatSubscriptionService {
  RevenueCatSubscriptionService._();
  static final RevenueCatSubscriptionService instance =
      RevenueCatSubscriptionService._();

  bool _configured = false;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> configure() async {
    if (_configured) return;
    final apiKey = SubscriptionConfig.revenueCatApiKey;
    if (apiKey.isEmpty) {
      debugPrint('[RevenueCat] API key not set — skipping configure');
      return;
    }
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
    final config = PurchasesConfiguration(apiKey);
    await Purchases.configure(config);
    _configured = true;
  }

  /// Call after Firebase Auth signs in so RevenueCat links purchases to the uid.
  Future<void> identifyUser(String uid) async {
    if (!_configured) return;
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      debugPrint('[RevenueCat] identifyUser error: $e');
    }
  }

  /// Call on sign-out so RevenueCat resets to anonymous.
  Future<void> signOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('[RevenueCat] signOut error: $e');
    }
  }

  // ── Entitlement check ─────────────────────────────────────────────────────

  /// Returns the current entitlement status without making a network call if
  /// the cache is fresh.
  Future<EntitlementStatus> getEntitlementStatus() async {
    if (!_configured) return EntitlementStatus.free;
    try {
      final info = await Purchases.getCustomerInfo();
      return _mapToStatus(info);
    } on PurchasesErrorCode catch (e) {
      throw SubscriptionException(
        'Failed to fetch entitlement status',
        code: e.name,
        cause: e,
      );
    }
  }

  /// Returns `true` when the user holds the premium entitlement.
  Future<bool> isPremium() async {
    final status = await getEntitlementStatus();
    return status.isPremium;
  }

  /// Returns `true` when [featureName] is accessible for the current user.
  Future<bool> hasFeatureAccess(String featureName) async {
    // Free features are always accessible
    if (SubscriptionConfig.freeFeatures.contains(featureName)) return true;
    // Premium features require the entitlement
    if (SubscriptionConfig.premiumFeatures.contains(featureName)) {
      return isPremium();
    }
    // Unknown feature — deny by default
    return false;
  }

  // ── Offerings / paywall ───────────────────────────────────────────────────

  Future<OfferingsSnapshot> getOfferings() async {
    if (!_configured) return const OfferingsSnapshot();
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return const OfferingsSnapshot();

      Package? monthly;
      Package? yearly;

      for (final pkg in current.availablePackages) {
        final id = pkg.storeProduct.identifier;
        if (id == SubscriptionConfig.monthlyProductId) monthly = pkg;
        if (id == SubscriptionConfig.yearlyProductId) yearly = pkg;
      }

      return OfferingsSnapshot(
        monthly: monthly,
        yearly: yearly,
        currentOfferingId: current.identifier,
      );
    } on PurchasesErrorCode catch (e) {
      throw SubscriptionException(
        'Failed to fetch offerings',
        code: e.name,
        cause: e,
      );
    }
  }

  // ── Purchase flow ─────────────────────────────────────────────────────────

  /// Initiates a purchase for the given [package].
  /// Returns the resulting [EntitlementStatus]; throws [SubscriptionException]
  /// on failure (including user cancellation, which carries code 'userCancelled').
  Future<EntitlementStatus> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return _mapToStatus(result.customerInfo);
    } on PurchasesErrorCode catch (e) {
      throw SubscriptionException(
        e == PurchasesErrorCode.purchaseCancelledError
            ? 'Purchase cancelled'
            : 'Purchase failed',
        code: e.name,
        cause: e,
      );
    }
  }

  /// Restores previously purchased subscriptions.
  Future<EntitlementStatus> restorePurchases() async {
    if (!_configured) return EntitlementStatus.free;
    try {
      final info = await Purchases.restorePurchases();
      return _mapToStatus(info);
    } on PurchasesErrorCode catch (e) {
      throw SubscriptionException(
        'Failed to restore purchases',
        code: e.name,
        cause: e,
      );
    }
  }

  // ── Customer info stream ──────────────────────────────────────────────────

  /// Emits a new [EntitlementStatus] whenever RevenueCat pushes an update
  /// (e.g. server-side renewal, billing retry, subscription cancellation).
  Stream<EntitlementStatus> get entitlementStream {
    final streamController = StreamController<EntitlementStatus>.broadcast();
    void listener(CustomerInfo info) {
      if (!streamController.isClosed) {
        streamController.add(_mapToStatus(info));
      }
    }
    Purchases.addCustomerInfoUpdateListener(listener);
    streamController.onCancel = () {
      Purchases.removeCustomerInfoUpdateListener(listener);
      streamController.close();
    };
    return streamController.stream;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  EntitlementStatus _mapToStatus(CustomerInfo info) {
    final entitlement =
        info.entitlements.active[SubscriptionConfig.premiumEntitlement];

    if (entitlement == null) return EntitlementStatus.free;

    return EntitlementStatus(
      isPremium: true,
      activeProductId: entitlement.productIdentifier,
      willRenew: entitlement.willRenew,
      expirationDate: entitlement.expirationDate != null
          ? DateTime.tryParse(entitlement.expirationDate!)
          : null,
    );
  }
}
