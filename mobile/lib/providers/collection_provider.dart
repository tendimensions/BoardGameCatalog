import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/collection_item.dart';
import '../services/api_service.dart';

enum LoadState { idle, loading, loaded, error }

/// Sentinel value for "in any list" — distinct from a real list ID.
const int kAnyListId = -1;

class CollectionProvider extends ChangeNotifier {
  List<CollectionItem> _items = [];
  LoadState _state = LoadState.idle;
  String? _error;
  String _query = '';

  // ── Active filters (Issue #23) ────────────────────────────────────────────
  /// When true, only show items without a linked barcode.
  bool _filterUnlinked = false;
  /// null = no list filter; [kAnyListId] = any list; positive int = specific list.
  int? _filterListId;

  bool get filterUnlinked => _filterUnlinked;
  int? get filterListId => _filterListId;
  bool get hasActiveFilter => _filterUnlinked || _filterListId != null;

  List<CollectionItem> get items => _filtered;
  LoadState get loadState => _state;
  String? get error => _error;
  bool get isLoading => _state == LoadState.loading;

  List<CollectionItem> get _filtered {
    var items = _items;

    // Text search
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      items = items.where((c) => c.game.title.toLowerCase().contains(q)).toList();
    }

    // Barcode not linked filter
    if (_filterUnlinked) {
      items = items.where((c) => c.game.upc.isEmpty).toList();
    }

    // In a list filter
    if (_filterListId != null) {
      if (_filterListId == kAnyListId) {
        items = items.where((c) => c.listIds.isNotEmpty).toList();
      } else {
        items = items.where((c) => c.listIds.contains(_filterListId)).toList();
      }
    }

    return items;
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  /// Update active filters. Pass [clearListFilter] to remove the list filter.
  void setFilter({
    bool? unlinked,
    int? listId,
    bool clearListFilter = false,
  }) {
    if (unlinked != null) _filterUnlinked = unlinked;
    if (clearListFilter) {
      _filterListId = null;
    } else if (listId != null) {
      _filterListId = listId;
    }
    notifyListeners();
  }

  /// Load from network; falls back to cache on error.
  Future<void> load(String apiKey) async {
    _state = LoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final fresh = await ApiService(apiKey).fetchAllCollection();
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
    final encoded = jsonEncode(
      items
          .map(
            (c) => {
              'id': c.id,
              'source': c.source,
              'acquisition_date': c.acquisitionDate,
              'notes': c.notes,
              'is_lent': c.isLent,
              'lent_to': c.lentTo,
              'lent_date': c.lentDate,
              'list_ids': c.listIds,
              'game': c.game.toJson(),
            },
          )
          .toList(),
    );
    await prefs.setString(AppConstants.collectionCacheKey, encoded);
    await prefs.setInt(
      AppConstants.collectionCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
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
