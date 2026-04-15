import 'package:flutter/foundation.dart';
import '../models/game_list.dart';
import '../services/api_service.dart';
import 'collection_provider.dart' show LoadState;

class ListProvider extends ChangeNotifier {
  List<GameList> _lists = [];
  LoadState _state = LoadState.idle;
  String? _error;

  List<GameList> get lists => _lists;
  LoadState get loadState => _state;
  String? get error => _error;
  bool get isLoading => _state == LoadState.loading;

  Future<void> load(String apiKey) async {
    _state = LoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _lists = await ApiService(apiKey).fetchLists();
      _state = LoadState.loaded;
    } on ApiException catch (e) {
      _error = e.message;
      _state = LoadState.error;
    } catch (_) {
      _error = 'No connection. Check your network.';
      _state = LoadState.error;
    }
    notifyListeners();
  }

  Future<GameList?> createList(String apiKey, String name,
      {String description = ''}) async {
    try {
      final created =
          await ApiService(apiKey).createList(name, description: description);
      _lists = [..._lists, created];
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateList(String apiKey, int listId,
      {String? name, String? description}) async {
    try {
      final updated = await ApiService(apiKey)
          .updateList(listId, name: name, description: description);
      _lists = [for (final l in _lists) l.id == listId ? updated : l];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteList(String apiKey, int listId) async {
    try {
      await ApiService(apiKey).deleteList(listId);
      _lists = _lists.where((l) => l.id != listId).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<GameList?> fetchDetail(String apiKey, int listId) async {
    try {
      return await ApiService(apiKey).fetchList(listId);
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> removeFromList(
      String apiKey, int listId, int entryId) async {
    try {
      await ApiService(apiKey).removeFromList(listId, entryId);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEntryNote(
      String apiKey, int listId, int entryId, String note) async {
    try {
      await ApiService(apiKey).updateEntryNote(listId, entryId, note);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }
}

