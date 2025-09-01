import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

/// Comprehensive caching service for the application.
///
/// Provides in-memory and persistent caching with TTL support,
/// size limits, and automatic cleanup.
class CacheService {
  /// Singleton instance
  static final CacheService _instance = CacheService._internal();

  /// Factory constructor returns singleton
  factory CacheService() => _instance;

  /// Private constructor
  CacheService._internal();

  /// In-memory cache storage
  final Map<String, CacheEntry> _memoryCache = {};

  /// Cache size tracking
  int _currentMemorySize = 0;

  /// Maximum memory cache size (10MB default)
  static const int _maxMemorySize = 10 * 1024 * 1024; // 10MB

  /// Timer for periodic cleanup
  Timer? _cleanupTimer;

  /// SharedPreferences instance
  SharedPreferences? _prefs;

  /// Cache statistics
  final CacheStatistics _stats = CacheStatistics();

  /// Initialize the cache service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Start periodic cleanup
      _cleanupTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _performCleanup(),
      );

      LoggerService.info('Cache service initialized');
    } catch (e) {
      LoggerService.error('Failed to initialize cache service', error: e);
    }
  }

  /// Get value from cache (memory first, then persistent).
  ///
  /// @param key Cache key
  /// @param forceFresh Skip cache and return null
  /// @return Cached value or null if not found/expired
  Future<T?> get<T>(
    String key, {
    bool forceFresh = false,
  }) async {
    if (forceFresh) {
      _stats.recordMiss();
      return null;
    }

    // Try memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      _stats.recordHit();
      LoggerService.debug('Cache hit (memory): $key');
      return memoryEntry.value as T?;
    }

    // Try persistent cache
    if (_prefs != null && T == String ||
        T == int ||
        T == double ||
        T == bool ||
        T == List<String>) {
      final value = _getPersistent<T>(key);
      if (value != null) {
        // Check TTL for persistent cache
        final ttlKey = '_ttl_$key';
        final ttl = _prefs!.getInt(ttlKey);
        if (ttl == null || DateTime.now().millisecondsSinceEpoch < ttl) {
          _stats.recordHit();
          LoggerService.debug('Cache hit (persistent): $key');

          // Promote to memory cache
          _setMemory(
              key,
              value,
              Duration(
                milliseconds: ttl != null
                    ? ttl - DateTime.now().millisecondsSinceEpoch
                    : 3600000, // 1 hour default
              ));

          return value;
        }
      }
    }

    _stats.recordMiss();
    LoggerService.debug('Cache miss: $key');
    return null;
  }

  /// Set value in cache (both memory and persistent).
  ///
  /// @param key Cache key
  /// @param value Value to cache
  /// @param ttl Time to live
  /// @param persistentOnly Only store in persistent cache
  Future<void> set<T>(
    String key,
    T value, {
    Duration ttl = const Duration(hours: 1),
    bool persistentOnly = false,
  }) async {
    try {
      // Store in memory cache
      if (!persistentOnly) {
        _setMemory(key, value, ttl);
      }

      // Store in persistent cache if supported type
      if (_prefs != null && _isPersistableType<T>()) {
        await _setPersistent(key, value, ttl);
      }

      _stats.recordSet();
      LoggerService.debug('Cache set: $key (TTL: ${ttl.inSeconds}s)');
    } catch (e) {
      LoggerService.error('Failed to set cache (key: $key)', error: e);
    }
  }

  /// Get value from cache or compute it.
  ///
  /// If value is not in cache or expired, computes it using
  /// the provided function and caches the result.
  Future<T> getOrCompute<T>(
    String key,
    Future<T> Function() compute, {
    Duration ttl = const Duration(hours: 1),
    bool forceFresh = false,
  }) async {
    if (!forceFresh) {
      final cached = await get<T>(key);
      if (cached != null) {
        return cached;
      }
    }

    // Compute value
    final value = await compute();

    // Cache it
    await set(key, value, ttl: ttl);

    return value;
  }

  /// Remove value from cache.
  Future<void> remove(String key) async {
    // Remove from memory
    final removed = _memoryCache.remove(key);
    if (removed != null) {
      _currentMemorySize -= removed.sizeInBytes;
    }

    // Remove from persistent
    if (_prefs != null) {
      await _prefs!.remove(key);
      await _prefs!.remove('_ttl_$key');
    }

    _stats.recordEviction();
    LoggerService.debug('Cache removed: $key');
  }

  /// Clear all cache.
  Future<void> clear() async {
    // Clear memory cache
    _memoryCache.clear();
    _currentMemorySize = 0;

    // Clear persistent cache
    if (_prefs != null) {
      final keys = _prefs!.getKeys().toList();
      for (final key in keys) {
        // Only remove our cache entries
        if (!key.startsWith('_ttl_') && !key.contains('flutter.')) {
          await _prefs!.remove(key);
        }
      }
      // Remove TTL entries
      for (final key in keys) {
        if (key.startsWith('_ttl_')) {
          await _prefs!.remove(key);
        }
      }
    }

    LoggerService.debug('Cache cleared');
  }

  /// Clear cache by pattern.
  Future<void> clearPattern(String pattern) async {
    // Clear from memory
    final keysToRemove =
        _memoryCache.keys.where((key) => key.contains(pattern)).toList();

    for (final key in keysToRemove) {
      await remove(key);
    }

    LoggerService.debug('Cache pattern cleared: $pattern');
  }

  /// Get cache statistics.
  CacheStatistics getStatistics() => _stats.copy();

  /// Get cache size info.
  CacheSizeInfo getSizeInfo() {
    int persistentCount = 0;
    int persistentSize = 0;

    if (_prefs != null) {
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (!key.startsWith('_ttl_') && !key.contains('flutter.')) {
          persistentCount++;
          // Estimate size
          final value = _prefs!.get(key);
          if (value is String) {
            persistentSize += value.length * 2; // UTF-16
          } else {
            persistentSize += 8; // Rough estimate for numbers
          }
        }
      }
    }

    return CacheSizeInfo(
      memoryEntries: _memoryCache.length,
      memoryBytes: _currentMemorySize,
      persistentEntries: persistentCount,
      persistentBytes: persistentSize,
    );
  }

  /// Store in memory cache with LRU eviction.
  void _setMemory(String key, dynamic value, Duration ttl) {
    // Calculate size
    final size = _estimateSize(value);

    // Evict if necessary
    while (
        _currentMemorySize + size > _maxMemorySize && _memoryCache.isNotEmpty) {
      _evictOldest();
    }

    // Store entry
    _memoryCache[key] = CacheEntry(
      value: value,
      expiry: DateTime.now().add(ttl),
      sizeInBytes: size,
    );
    _currentMemorySize += size;
  }

  /// Get from persistent cache.
  T? _getPersistent<T>(String key) {
    if (T == String) {
      return _prefs!.getString(key) as T?;
    } else if (T == int) {
      return _prefs!.getInt(key) as T?;
    } else if (T == double) {
      return _prefs!.getDouble(key) as T?;
    } else if (T == bool) {
      return _prefs!.getBool(key) as T?;
    } else if (T == List<String>) {
      return _prefs!.getStringList(key) as T?;
    }
    return null;
  }

  /// Set in persistent cache.
  Future<void> _setPersistent<T>(String key, T value, Duration ttl) async {
    // Store value
    if (value is String) {
      await _prefs!.setString(key, value);
    } else if (value is int) {
      await _prefs!.setInt(key, value);
    } else if (value is double) {
      await _prefs!.setDouble(key, value);
    } else if (value is bool) {
      await _prefs!.setBool(key, value);
    } else if (value is List<String>) {
      await _prefs!.setStringList(key, value);
    }

    // Store TTL
    final ttlKey = '_ttl_$key';
    await _prefs!.setInt(
      ttlKey,
      DateTime.now().add(ttl).millisecondsSinceEpoch,
    );
  }

  /// Check if type is persistable.
  bool _isPersistableType<T>() {
    return T == String ||
        T == int ||
        T == double ||
        T == bool ||
        T == List<String>;
  }

  /// Estimate memory size of value.
  int _estimateSize(dynamic value) {
    if (value == null) return 0;

    if (value is String) {
      return value.length * 2; // UTF-16
    } else if (value is int || value is double) {
      return 8;
    } else if (value is bool) {
      return 1;
    } else if (value is List) {
      return value.fold<int>(0, (sum, item) => sum + _estimateSize(item));
    } else if (value is Map) {
      int size = 0;
      value.forEach((k, v) {
        size += _estimateSize(k) + _estimateSize(v);
      });
      return size;
    } else {
      // For objects, try to serialize and measure
      try {
        return json.encode(value).length * 2;
      } catch (_) {
        return 1024; // Default 1KB
      }
    }
  }

  /// Evict oldest entry from memory cache.
  void _evictOldest() {
    if (_memoryCache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    _memoryCache.forEach((key, entry) {
      if (oldestTime == null || entry.created.isBefore(oldestTime!)) {
        oldestTime = entry.created;
        oldestKey = key;
      }
    });

    if (oldestKey != null) {
      final removed = _memoryCache.remove(oldestKey);
      if (removed != null) {
        _currentMemorySize -= removed.sizeInBytes;
        _stats.recordEviction();
      }
    }
  }

  /// Perform periodic cleanup.
  void _performCleanup() {
    // Clean expired entries from memory
    final keysToRemove = <String>[];
    _memoryCache.forEach((key, entry) {
      if (entry.isExpired) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      LoggerService.debug(
        'Cache cleanup removed ${keysToRemove.length} expired entries',
      );
    }
  }

  /// Dispose of resources.
  void dispose() {
    _cleanupTimer?.cancel();
    _memoryCache.clear();
    LoggerService.info('Cache service disposed');
  }
}

/// Cache entry container.
@immutable
class CacheEntry {
  final dynamic value;
  final DateTime expiry;
  final DateTime created;
  final int sizeInBytes;

  CacheEntry({
    required this.value,
    required this.expiry,
    required this.sizeInBytes,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiry);

  Duration get timeToLive => expiry.difference(DateTime.now());
}

/// Cache statistics tracker.
class CacheStatistics {
  int _hits = 0;
  int _misses = 0;
  int _sets = 0;
  int _evictions = 0;

  int get hits => _hits;
  int get misses => _misses;
  int get sets => _sets;
  int get evictions => _evictions;

  double get hitRate => _hits + _misses > 0 ? _hits / (_hits + _misses) : 0.0;

  void recordHit() => _hits++;
  void recordMiss() => _misses++;
  void recordSet() => _sets++;
  void recordEviction() => _evictions++;

  CacheStatistics copy() {
    return CacheStatistics()
      .._hits = _hits
      .._misses = _misses
      .._sets = _sets
      .._evictions = _evictions;
  }

  Map<String, dynamic> toJson() => {
        'hits': _hits,
        'misses': _misses,
        'sets': _sets,
        'evictions': _evictions,
        'hitRate': hitRate,
      };
}

/// Cache size information.
@immutable
class CacheSizeInfo {
  final int memoryEntries;
  final int memoryBytes;
  final int persistentEntries;
  final int persistentBytes;

  const CacheSizeInfo({
    required this.memoryEntries,
    required this.memoryBytes,
    required this.persistentEntries,
    required this.persistentBytes,
  });

  int get totalEntries => memoryEntries + persistentEntries;
  int get totalBytes => memoryBytes + persistentBytes;

  Map<String, dynamic> toJson() => {
        'memory': {
          'entries': memoryEntries,
          'bytes': memoryBytes,
          'mb': (memoryBytes / 1024 / 1024).toStringAsFixed(2),
        },
        'persistent': {
          'entries': persistentEntries,
          'bytes': persistentBytes,
          'kb': (persistentBytes / 1024).toStringAsFixed(2),
        },
        'total': {
          'entries': totalEntries,
          'bytes': totalBytes,
        },
      };
}
