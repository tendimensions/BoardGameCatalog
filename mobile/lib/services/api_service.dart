import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/collection_item.dart';
import '../models/game.dart';
import '../models/game_list.dart';
import '../models/game_list_entry.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  final String apiKey;

  ApiService(this.apiKey);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _uri(String path, [Map<String, String>? queryParams]) =>
      Uri.parse('${AppConstants.apiBaseUrl}$path').replace(
        queryParameters: queryParams,
      );

  Future<Map<String, dynamic>> _checkResponse(http.Response resp) {
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw ApiException(resp.statusCode, 'Invalid or expired API key.');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final msg = body['error'] as String? ?? 'Unexpected error (${resp.statusCode})';
      throw ApiException(resp.statusCode, msg);
    }
    return Future.value(body);
  }

  /// Validates the API key by fetching the user profile.
  /// Returns the username on success, throws [ApiException] on failure.
  Future<String> validateKey() async {
    final resp = await http
        .get(_uri('/users/profile'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    final body = await _checkResponse(resp);
    return body['username'] as String;
  }

  /// Fetches the full collection. Throws [ApiException] on error.
  Future<List<CollectionItem>> fetchCollection({
    String query = '',
    String sort = 'title',
    String order = 'asc',
    int limit = 200,
    int offset = 0,
  }) async {
    final params = {
      if (query.isNotEmpty) 'q': query,
      'sort': sort,
      'order': order,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final resp = await http
        .get(_uri('/collection', params), headers: _headers)
        .timeout(const Duration(seconds: 15));
    final body = await _checkResponse(resp);
    final list = body['games'] as List<dynamic>;
    return list
        .map((e) => CollectionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Submits a barcode scan. Returns a [Game] and whether it was newly added.
  /// Pass [listId] to scan in Mode B (Add to List — REQ-GL-035 through REQ-GL-040).
  /// Throws [ApiException] with statusCode 404 when the barcode is unknown.
  Future<({Game game, bool addedToCollection, bool? addedToList, bool? alreadyOnList, String? activeListName})>
      scanBarcode(String upc, {int? listId}) async {
    final payload = <String, dynamic>{'upc': upc};
    if (listId != null) payload['list_id'] = listId;

    final resp = await http
        .post(
          _uri('/scan/barcode'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    final body = await _checkResponse(resp);
    return (
      game: Game.fromJson(body['game'] as Map<String, dynamic>),
      addedToCollection: body['added_to_collection'] as bool? ?? false,
      addedToList: body['added_to_list'] as bool?,
      alreadyOnList: body['already_on_list'] as bool?,
      activeListName: body['active_list_name'] as String?,
    );
  }

  /// Links a saved unlinked barcode to a game in the user's collection and
  /// submits the mapping to GameUPC.com (REQ-CM-045, REQ-CM-046).
  /// Returns the updated [Game] and whether GameUPC accepted the submission.
  Future<({Game game, bool submittedToGameUpc})> linkBarcode(
      String upc, int gameId) async {
    final resp = await http
        .post(
          _uri('/scan/link'),
          headers: _headers,
          body: jsonEncode({'upc': upc, 'game_id': gameId}),
        )
        .timeout(const Duration(seconds: 15));
    final body = await _checkResponse(resp);
    return (
      game: Game.fromJson(body['game'] as Map<String, dynamic>),
      submittedToGameUpc: body['submitted_to_gameupc'] as bool? ?? false,
    );
  }

  /// Discards a saved unlinked barcode without linking it to any game (REQ-CM-048).
  Future<void> discardBarcode(String upc) async {
    await http
        .delete(_uri('/scan/unlinked/$upc'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    // Silent — server returns 204 or ignores missing records.
  }

  // ── Game Lists ──────────────────────────────────────────────────────────────

  /// Returns all lists for the authenticated user.
  Future<List<GameList>> fetchLists() async {
    final resp = await http
        .get(_uri('/lists'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw ApiException(resp.statusCode, 'Invalid or expired API key.');
    }
    if (resp.statusCode >= 400) {
      final err = jsonDecode(resp.body) as Map<String, dynamic>;
      final msg = err['error'] as String? ?? 'Unexpected error (${resp.statusCode})';
      throw ApiException(resp.statusCode, msg);
    }
    return (jsonDecode(resp.body) as List<dynamic>)
        .map((e) => GameList.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns a single list with all its entries.
  Future<GameList> fetchList(int listId) async {
    final resp = await http
        .get(_uri('/lists/$listId'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    final body = await _checkResponse(resp);
    return GameList.fromJson(body);
  }

  /// Creates a new list. Returns the created [GameList].
  Future<GameList> createList(String name, {String description = ''}) async {
    final resp = await http
        .post(
          _uri('/lists'),
          headers: _headers,
          body: jsonEncode({'name': name, 'description': description}),
        )
        .timeout(const Duration(seconds: 10));
    final body = await _checkResponse(resp);
    return GameList.fromJson(body);
  }

  /// Updates a list's name and/or description.
  Future<GameList> updateList(int listId, {String? name, String? description}) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (description != null) payload['description'] = description;
    final resp = await http
        .patch(
          _uri('/lists/$listId'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));
    final body = await _checkResponse(resp);
    return GameList.fromJson(body);
  }

  /// Deletes a list.
  Future<void> deleteList(int listId) async {
    await http
        .delete(_uri('/lists/$listId'), headers: _headers)
        .timeout(const Duration(seconds: 10));
  }

  /// Adds a game to a list. Returns the new [GameListEntry].
  Future<GameListEntry> addToList(int listId, int gameId, {String note = ''}) async {
    final resp = await http
        .post(
          _uri('/lists/$listId/entries'),
          headers: _headers,
          body: jsonEncode({'game_id': gameId, 'note': note}),
        )
        .timeout(const Duration(seconds: 10));
    final body = await _checkResponse(resp);
    return GameListEntry.fromJson(body);
  }

  /// Updates the note on a list entry.
  Future<GameListEntry> updateEntryNote(int listId, int entryId, String note) async {
    final resp = await http
        .patch(
          _uri('/lists/$listId/entries/$entryId'),
          headers: _headers,
          body: jsonEncode({'note': note}),
        )
        .timeout(const Duration(seconds: 10));
    final body = await _checkResponse(resp);
    return GameListEntry.fromJson(body);
  }

  /// Removes a game from a list.
  Future<void> removeFromList(int listId, int entryId) async {
    await http
        .delete(_uri('/lists/$listId/entries/$entryId'), headers: _headers)
        .timeout(const Duration(seconds: 10));
  }
}
