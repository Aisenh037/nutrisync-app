import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Performance Monitoring.
///
/// Usage:
///   final trace = PerformanceService.startTrace('voice_query');
///   // ... do work ...
///   await PerformanceService.stopTrace(trace);
///
/// Or with the helper:
///   final result = await PerformanceService.traceAsync(
///     'food_vision_scan',
///     () => foodVisionService.analyze(image),
///   );
class PerformanceService {
  PerformanceService._();

  static final FirebasePerformance _perf = FirebasePerformance.instance;

  // ── Named traces ────────────────────────────────────────────────────────────

  /// Voice AI round-trip: mic → STT → AI → TTS
  static const kVoiceQuery = 'voice_query';

  /// Food Vision: image capture → Gemini Vision → nutrition parse
  static const kFoodVisionScan = 'food_vision_scan';

  /// Meal plan generation: prompt → AI → Firestore save
  static const kMealPlanGenerate = 'meal_plan_generate';

  /// Grocery list optimization AI call
  static const kGroceryOptimize = 'grocery_optimize';

  /// Nearby-stores Cloud Function call
  static const kStoreFinder = 'store_finder';

  /// Firestore: initial meal-plan page load
  static const kMealPlanLoad = 'meal_plan_load';

  /// Firestore: initial grocery list load
  static const kGroceryLoad = 'grocery_load';

  // ── API: start / stop ────────────────────────────────────────────────────────

  static Trace? startTrace(String name) {
    if (kDebugMode) return null; // Skip in debug to keep logs clean
    try {
      final trace = _perf.newTrace(name);
      trace.start();
      return trace;
    } catch (e) {
      debugPrint('[Perf] startTrace($name) failed: $e');
      return null;
    }
  }

  static Future<void> stopTrace(Trace? trace, {String? attribute, String? value}) async {
    if (trace == null) return;
    try {
      if (attribute != null && value != null) {
        trace.putAttribute(attribute, value);
      }
      await trace.stop();
    } catch (e) {
      debugPrint('[Perf] stopTrace failed: $e');
    }
  }

  // ── API: convenience wrapper ──────────────────────────────────────────────

  /// Wraps [fn] in a performance trace named [traceName].
  /// Any exception from [fn] is re-thrown after the trace is stopped.
  static Future<T> traceAsync<T>(
    String traceName,
    Future<T> Function() fn, {
    Map<String, String> attributes = const {},
  }) async {
    final trace = startTrace(traceName);
    try {
      final result = await fn();
      for (final entry in attributes.entries) {
        trace?.putAttribute(entry.key, entry.value);
      }
      return result;
    } finally {
      await stopTrace(trace);
    }
  }

  // ── HTTP metric helpers ───────────────────────────────────────────────────

  /// Create an HTTP metric for manual Dio/http calls not auto-instrumented.
  static HttpMetric? newHttpMetric(String url, HttpMethod method) {
    if (kDebugMode) return null;
    try {
      return _perf.newHttpMetric(url, method);
    } catch (_) {
      return null;
    }
  }
}
