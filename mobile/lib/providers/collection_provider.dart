import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/collection_item.dart';
import '../services/api_service.dart';

enum LoadState { idle, loading, loaded, error }

class CollectionProvider extends ChangeNotifier {
  List<CollectionItem> _items = [];
  LoadState _state = LoadState.idle;
  String? _error;
  String _query = '';

  List<CollectionItem> get items => _filtered;
  LoadState get loadState => _state;
  String? get error => _error;
  bool get isLoading => _state == LoadState.loading;

  List<CollectionItem> get _filtered {
    if (_query.isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items
        .where((c) => c.game.title.toLowerCase().contains(q))
        .toList();
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  /// Load from network; falls back to cache on error.
  Future<void> load(String apiKey) async {
    _state = LoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final fresh = await ApiService(apiKey).fetchCollection();
      _items = fresh;
      _state = LoadState.loaded;
      await _saveCache(fresh);
    } on ApiException catch (e) {
      _error = e.message;
      _state = LoadState.error;
      await _tryLoadCache();
    } catch (_) {
      _error = 'No connection — showing cached collection.';
      _state = LoadState.error;
      await _tryLoadCache();
    }
    notifyListeners();
  }

  Future<void> _saveCache(List<CollectionItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((c) => {
          'id': c.id,
          'source': c.source,
          'is_lent': c.isLent,
          'lent_to': c.lentTo,
          'game': c.game.toJson(),
        }).toList());
    await prefs.setString(AppConstants.collectionCacheKey, encoded);
    await prefs.setInt(
        AppConstants.collectionCacheTimeKey,
        DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _tryLoadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.collectionCacheKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = list
          .map((e) => CollectionItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (_state == LoadState.error && _items.isNotEmpty) {
        _error = 'Offline — showing cached collection.';
      }
    } catch (_) {
      // Cache corrupt — ignore
    }
  }
}
