import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'environment_config.dart';

/// Secure API Key Management System
///
/// Key loading priority (highest to lowest):
///   1. flutter_secure_storage  — previously cached keys (from Remote Config fetch)
///   2. --dart-define at build time — CI/CD injected keys
///   3. null                    — service is unavailable, handle gracefully
///
/// Keys must NEVER be placed in assets/ or committed to source control.
/// For production: fetch keys from Firebase Remote Config on first launch,
/// then persist them here via [storeApiKey].
class SecureKeyManager {
  static SecureKeyManager? _instance;
  static SecureKeyManager get instance => _instance ??= SecureKeyManager._();

  SecureKeyManager._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _storagePrefix = 'nutrisync_key_';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Build-time keys injected via `flutter run --dart-define=ELEVENLABS_API_KEY=...`
  static const _buildTimeKeys = {
    'elevenlabs': String.fromEnvironment('ELEVENLABS_API_KEY'),
    'googlemaps': String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
    'googleplaces': String.fromEnvironment('GOOGLE_PLACES_API_KEY'),
    'openai': String.fromEnvironment('OPENAI_API_KEY'),
    'firebase': String.fromEnvironment('FIREBASE_API_KEY'),
  };

  Future<void> initialize() async {
    _isInitialized = true;
    if (kDebugMode) {
      print('✓ SecureKeyManager initialized (flutter_secure_storage backend)');
    }
  }

  /// Retrieve API key for [serviceName].
  /// Returns null if not configured — callers must handle this gracefully.
  Future<String?> getApiKey(String serviceName) async {
    // 1. Check on-device secure storage (previously fetched + cached keys)
    try {
      final stored = await _storage.read(key: '$_storagePrefix$serviceName');
      if (stored != null && stored.isNotEmpty && _isValidKey(stored, serviceName)) {
        return stored;
      }
    } catch (e) {
      if (kDebugMode) print('⚠ SecureStorage read failed for $serviceName: $e');
    }

    // 2. Fall back to build-time --dart-define injection
    final buildKey = _buildTimeKeys[serviceName] ?? '';
    if (buildKey.isNotEmpty && _isValidKey(buildKey, serviceName)) {
      return buildKey;
    }

    if (kDebugMode) {
      print('⚠ No key found for $serviceName. '
          'Inject via --dart-define or store via storeApiKey() after Remote Config fetch.');
    }
    return null;
  }

  /// Synchronous getter — only returns build-time keys, not stored ones.
  /// Use [getApiKey] (async) for full resolution.
  String? getApiKeySync(String serviceName) {
    final buildKey = _buildTimeKeys[serviceName] ?? '';
    if (buildKey.isNotEmpty && _isValidKey(buildKey, serviceName)) {
      return buildKey;
    }
    return null;
  }

  /// Persist an API key received at runtime (e.g. from Firebase Remote Config).
  /// Stored in platform secure storage — never on disk in plaintext.
  Future<void> storeApiKey(String serviceName, String apiKey) async {
    if (!_isValidKey(apiKey, serviceName)) {
      throw ArgumentError('Invalid API key format for service: $serviceName');
    }
    await _storage.write(key: '$_storagePrefix$serviceName', value: apiKey);
    if (kDebugMode) print('✓ Stored key for $serviceName in secure storage');
  }

  /// Remove a stored key (e.g. on logout or key rotation).
  Future<void> removeApiKey(String serviceName) async {
    await _storage.delete(key: '$_storagePrefix$serviceName');
    if (kDebugMode) print('✓ Removed key for $serviceName');
  }

  /// Remove all stored keys from secure storage.
  Future<void> clearAllKeys() async {
    for (final service in _buildTimeKeys.keys) {
      await _storage.delete(key: '$_storagePrefix$service');
    }
    if (kDebugMode) print('✓ Cleared all stored API keys');
  }

  bool hasApiKey(String serviceName) {
    return getApiKeySync(serviceName) != null;
  }

  bool _isValidKey(String key, String serviceName) {
    if (key.isEmpty ||
        key.startsWith('YOUR_') ||
        key.startsWith('REPLACE_') ||
        key.startsWith('DEV_') ||
        key.startsWith('DEMO_')) {
      return false;
    }
    switch (serviceName) {
      case 'elevenlabs':
        return key.length >= 32 && !key.contains(' ');
      case 'googlemaps':
      case 'googleplaces':
        return key.startsWith('AIza') && key.length == 39;
      case 'openai':
        return key.startsWith('sk-') && key.length >= 40;
      default:
        return key.length >= 10;
    }
  }

  /// Security audit — returns status of each known key.
  Future<Map<String, KeySecurityStatus>> getSecuritySummary() async {
    final summary = <String, KeySecurityStatus>{};
    for (final service in _buildTimeKeys.keys) {
      final key = await getApiKey(service);
      if (key == null) {
        summary[service] = KeySecurityStatus.missing;
      } else if (!_isValidKey(key, service)) {
        summary[service] = KeySecurityStatus.invalid;
      } else {
        // Check if it came from secure storage (runtime) vs build-time
        final stored = await _storage.read(key: '$_storagePrefix$service');
        summary[service] = (stored != null && stored.isNotEmpty)
            ? KeySecurityStatus.secureStorage
            : KeySecurityStatus.buildTime;
      }
    }
    return summary;
  }

  // ── Test helpers ──────────────────────────────────────────────────────────

  @visibleForTesting
  Future<void> storeKeyForTesting(String serviceName, String key) async {
    await _storage.write(key: '$_storagePrefix$serviceName', value: key);
  }

  @visibleForTesting
  Future<void> clearAllForTesting() async {
    await clearAllKeys();
    _isInitialized = false;
  }
}

enum KeySecurityStatus {
  /// Key not configured anywhere.
  missing,
  /// Key present but fails format validation.
  invalid,
  /// Key injected via --dart-define at build time.
  buildTime,
  /// Key stored in platform secure storage (best — from runtime fetch).
  secureStorage,
}

extension KeySecurityStatusExtension on KeySecurityStatus {
  String get description {
    switch (this) {
      case KeySecurityStatus.missing:
        return 'API key is missing — service unavailable';
      case KeySecurityStatus.invalid:
        return 'API key fails format validation';
      case KeySecurityStatus.buildTime:
        return 'Key injected at build time via --dart-define';
      case KeySecurityStatus.secureStorage:
        return 'Key in platform secure storage (Keychain / EncryptedSharedPrefs)';
    }
  }

  bool get isUsable =>
      this == KeySecurityStatus.buildTime ||
      this == KeySecurityStatus.secureStorage;
}
