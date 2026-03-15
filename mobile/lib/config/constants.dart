class AppConstants {
  static const String apiBaseUrl = 'https://boardgames.tendimensions.com/api/v1';
  static const String apiKeyStorageKey = 'bgc_api_key';
  static const String collectionCacheKey = 'bgc_collection_cache';
  static const String collectionCacheTimeKey = 'bgc_collection_cache_time';

  /// Cache is considered stale after this duration.
  static const Duration collectionCacheTtl = Duration(hours: 1);
}
