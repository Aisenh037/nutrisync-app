import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'api_configuration_manager.dart';
import 'environment_config.dart';

/// Configuration Caching System
/// Handles caching, loading, and hot-reloading of configurations
class ConfigurationCache {
  static ConfigurationCache? _instance;
  static ConfigurationCache get instance => _instance ??= ConfigurationCache._();
  
  ConfigurationCache._();
  
  Map<String, CachedConfiguration>? _cache;
  String? _cacheDirectory;
  bool _isInitialized = false;
  
  /// Cache expiration time (30 minutes)
  static const Duration _cacheExpiration = Duration(minutes: 30);
  
  /// Maximum cache size (100 entries)
  static const int _maxCacheSize = 100;
  
  /// Initialize configuration cache
  Future<void> initialize() async {
    try {
      await _initializeCacheDirectory();
      await _loadCacheFromDisk();
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✓ Configuration Cache initialized');
        print('✓ Cache directory: $_cacheDirectory');
        print('✓ Cached configurations: ${_cache?.length ?? 0}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to initialize Configuration Cache: $e');
      }
      _cache = {};
      _isInitialized = false;
    }
  }
  
  /// Initialize cache directory
  Future<void> _initializeCacheDirectory() async {
    if (kIsWeb) {
      // Web doesn't support file system, use memory cache only
      _cacheDirectory = null;
      _cache = {};
      return;
    }
    
    try {
      final appDir = await getApplicationSupportDirectory();
      _cacheDirectory = '${appDir.path}/config_cache';
      
      final cacheDir = Directory(_cacheDirectory!);
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      _cache = {};
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to create cache directory: $e');
      }
      _cacheDirectory = null;
      _cache = {};
    }
  }
  
  /// Load cache from disk
  Future<void> _loadCacheFromDisk() async {
    if (_cacheDirectory == null) return;
    
    try {
      final cacheFile = File('$_cacheDirectory/config_cache.json');
      if (!await cacheFile.exists()) return;
      
      final cacheContent = await cacheFile.readAsString();
      final cacheData = json.decode(cacheContent) as Map<String, dynamic>;
      
      _cache = {};
      for (final entry in cacheData.entries) {
        final configData = entry.value as Map<String, dynamic>;
        _cache![entry.key] = CachedConfiguration.fromJson(configData);
      }
      
      // Remove expired entries
      _cleanExpiredEntries();
      
      if (kDebugMode) {
        print('✓ Loaded ${_cache!.length} configurations from cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to load cache from disk: $e');
      }
      _cache = {};
    }
  }
  
  /// Save cache to disk
  Future<void> _saveCacheToDisk() async {
    if (_cacheDirectory == null || _cache == null) return;
    
    try {
      final cacheFile = File('$_cacheDirectory/config_cache.json');
      final cacheData = <String, dynamic>{};
      
      for (final entry in _cache!.entries) {
        cacheData[entry.key] = entry.value.toJson();
      }
      
      await cacheFile.writeAsString(json.encode(cacheData));
      
      if (kDebugMode) {
        print('✓ Saved ${_cache!.length} configurations to cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to save cache to disk: $e');
      }
    }
  }
  
  /// Get cached configuration
  T? getCachedConfig<T>(String key, {Duration? maxAge}) {
    if (!_isInitialized || _cache == null) return null;
    
    final cached = _cache![key];
    if (cached == null) return null;
    
    // Check if cache is expired
    final age = maxAge ?? _cacheExpiration;
    if (DateTime.now().difference(cached.timestamp) > age) {
      _cache!.remove(key);
      return null;
    }
    
    try {
      if (T == String) {
        return cached.data as T;
      } else if (T == Map<String, dynamic>) {
        return cached.data as T;
      } else if (T == List<dynamic>) {
        return cached.data as T;
      } else {
        // Try to deserialize as JSON
        if (cached.data is String) {
          return json.decode(cached.data as String) as T;
        }
        return cached.data as T;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to deserialize cached config for key $key: $e');
      }
      _cache!.remove(key);
      return null;
    }
  }
  
  /// Cache configuration
  Future<void> cacheConfig<T>(String key, T data, {Duration? ttl}) async {
    if (!_isInitialized) return;
    
    _cache ??= {};
    
    // Enforce cache size limit
    if (_cache!.length >= _maxCacheSize) {
      _evictOldestEntry();
    }
    
    final cachedConfig = CachedConfiguration(
      key: key,
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl ?? _cacheExpiration,
    );
    
    _cache![key] = cachedConfig;
    
    // Save to disk asynchronously
    _saveCacheToDisk();
    
    if (kDebugMode) {
      print('✓ Cached configuration for key: $key');
    }
  }
  
  /// Remove cached configuration
  void removeCachedConfig(String key) {
    _cache?.remove(key);
    _saveCacheToDisk();
    
    if (kDebugMode) {
      print('✓ Removed cached configuration for key: $key');
    }
  }
  
  /// Check if configuration is cached and valid
  bool isCached(String key, {Duration? maxAge}) {
    if (!_isInitialized || _cache == null) return false;
    
    final cached = _cache![key];
    if (cached == null) return false;
    
    // Use the TTL from the cached item, or the provided maxAge, or default expiration
    final age = maxAge ?? cached.ttl;
    return DateTime.now().difference(cached.timestamp) <= age;
  }
  
  /// Get cache statistics
  CacheStatistics getCacheStatistics() {
    if (!_isInitialized || _cache == null) {
      return CacheStatistics(
        totalEntries: 0,
        validEntries: 0,
        expiredEntries: 0,
        cacheHitRate: 0.0,
        totalSize: 0,
      );
    }
    
    int validEntries = 0;
    int expiredEntries = 0;
    int totalSize = 0;
    
    for (final cached in _cache!.values) {
      if (DateTime.now().difference(cached.timestamp) <= cached.ttl) {
        validEntries++;
      } else {
        expiredEntries++;
      }
      
      // Estimate size
      try {
        final serialized = json.encode(cached.toJson());
        totalSize += serialized.length;
      } catch (e) {
        // Ignore serialization errors for size calculation
      }
    }
    
    return CacheStatistics(
      totalEntries: _cache!.length,
      validEntries: validEntries,
      expiredEntries: expiredEntries,
      cacheHitRate: validEntries / (_cache!.length > 0 ? _cache!.length : 1),
      totalSize: totalSize,
    );
  }
  
  /// Clean expired entries
  void _cleanExpiredEntries() {
    if (_cache == null) return;
    
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cache!.entries) {
      if (now.difference(entry.value.timestamp) > entry.value.ttl) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _cache!.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      if (kDebugMode) {
        print('✓ Cleaned ${expiredKeys.length} expired cache entries');
      }
      _saveCacheToDisk();
    }
  }
  
  /// Evict oldest entry to make room
  void _evictOldestEntry() {
    if (_cache == null || _cache!.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _cache!.entries) {
      if (oldestTime == null || entry.value.timestamp.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.timestamp;
      }
    }
    
    if (oldestKey != null) {
      _cache!.remove(oldestKey);
      if (kDebugMode) {
        print('✓ Evicted oldest cache entry: $oldestKey');
      }
    }
  }
  
  /// Clear all cache
  Future<void> clearCache() async {
    _cache?.clear();
    await _saveCacheToDisk();
    
    if (kDebugMode) {
      print('✓ Cleared all cache entries');
    }
  }
  
  /// Preload common configurations
  Future<void> preloadConfigurations() async {
    if (!_isInitialized) return;
    
    try {
      // Preload environment configuration
      final envConfig = EnvironmentConfig.instance;
      await cacheConfig('environment_config', {
        'environment': envConfig.environment,
        'firebase': envConfig.firebase,
        'api': envConfig.api,
        'features': envConfig.features,
      });
      
      // Preload API configurations if available
      if (ApiConfigurationManager.instance.isInitialized) {
        final apiConfigs = ApiConfigurationManager.instance.getAllConfigs();
        for (final entry in apiConfigs.entries) {
          await cacheConfig('api_config_${entry.key}', {
            'serviceName': entry.value.serviceName,
            'baseUrl': entry.value.baseUrl,
            'isEnabled': entry.value.isEnabled,
            'timeout': entry.value.timeout.inMilliseconds,
            'retryAttempts': entry.value.retryAttempts,
            'additionalConfig': entry.value.additionalConfig,
          });
        }
      }
      
      if (kDebugMode) {
        print('✓ Preloaded common configurations');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Failed to preload configurations: $e');
      }
    }
  }
  
  /// Hot reload configuration
  Future<void> hotReloadConfiguration(String configKey) async {
    // Remove from cache to force reload
    removeCachedConfig(configKey);
    
    // Trigger reload based on config type
    if (configKey.startsWith('api_config_')) {
      await ApiConfigurationManager.instance.reload();
    } else if (configKey == 'environment_config') {
      await EnvironmentConfig.instance.initialize();
    }
    
    // Preload the updated configuration
    await preloadConfigurations();
    
    if (kDebugMode) {
      print('✓ Hot reloaded configuration: $configKey');
    }
  }
  
  /// Watch for configuration file changes (if supported)
  void watchConfigurationFiles() {
    if (kIsWeb || _cacheDirectory == null) return;
    
    // This would implement file watching in a real application
    // For now, we'll just clean expired entries periodically
    _startPeriodicCleanup();
  }
  
  /// Start periodic cache cleanup
  void _startPeriodicCleanup() {
    // Clean expired entries every 5 minutes
    Stream.periodic(const Duration(minutes: 5)).listen((_) {
      _cleanExpiredEntries();
    });
  }
  
  /// Get all cached keys
  List<String> getCachedKeys() {
    return _cache?.keys.toList() ?? [];
  }
  
  /// Export cache for debugging
  Map<String, dynamic> exportCache() {
    if (_cache == null) return {};
    
    final exported = <String, dynamic>{};
    for (final entry in _cache!.entries) {
      exported[entry.key] = {
        'data': entry.value.data,
        'timestamp': entry.value.timestamp.toIso8601String(),
        'ttl': entry.value.ttl.inMilliseconds,
        'isExpired': DateTime.now().difference(entry.value.timestamp) > entry.value.ttl,
      };
    }
    
    return exported;
  }
  
  /// Reset cache (for testing)
  @visibleForTesting
  void reset() {
    _cache = null;
    _cacheDirectory = null;
    _isInitialized = false;
  }
}

/// Cached Configuration Model
class CachedConfiguration {
  final String key;
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;
  
  const CachedConfiguration({
    required this.key,
    required this.data,
    required this.timestamp,
    required this.ttl,
  });
  
  /// Check if cache entry is expired
  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
  
  /// Get remaining time until expiration
  Duration get remainingTime {
    final elapsed = DateTime.now().difference(timestamp);
    return ttl - elapsed;
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'ttl': ttl.inMilliseconds,
    };
  }
  
  /// Create from JSON
  factory CachedConfiguration.fromJson(Map<String, dynamic> json) {
    return CachedConfiguration(
      key: json['key'] as String,
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp'] as String),
      ttl: Duration(milliseconds: json['ttl'] as int),
    );
  }
}

/// Cache Statistics
class CacheStatistics {
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;
  final double cacheHitRate;
  final int totalSize;
  
  const CacheStatistics({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
    required this.cacheHitRate,
    required this.totalSize,
  });
  
  /// Get cache efficiency percentage
  double get efficiency => cacheHitRate * 100;
  
  /// Get formatted size
  String get formattedSize {
    if (totalSize < 1024) return '${totalSize}B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)}KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  @override
  String toString() {
    return 'CacheStatistics(total: $totalEntries, valid: $validEntries, '
           'expired: $expiredEntries, hitRate: ${efficiency.toStringAsFixed(1)}%, '
           'size: $formattedSize)';
  }
}