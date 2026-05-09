import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/bgg_candidate.dart';
import '../models/collection_item.dart';
import '../models/game.dart';
import '../models/game_list.dart';
import '../models/game_list_entry.dart';
import '../models/scan_result.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Returned by [ApiService.scanBarcode] to cover all three GameUPC scenarios.
class ScanBarcodeResponse {
  final Game? game;
  final bool addedToCollection;
  final bool? addedToList;
  final bool? alreadyOnList;
  final String? activeListName;
  final bool needsSelection;
  final String? upc;
  final List<BggCandidate>? suggestions;

  const ScanBarcodeResponse({
    this.game,
    this.addedToCollection = false,
    this.addedToList,
    this.alreadyOnList,
    this.activeListName,
    this.needsSelection = false,
    this.upc,
    this.suggestions,
  });
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

  /// Submits a barcode scan. Returns a [ScanBarcodeResponse].
  ///
  /// Three outcomes:
  ///   - game resolved (Case 1): [ScanBarcodeResponse.game] is set
  ///   - needs selection (Case 2): [ScanBarcodeResponse.needsSelection] is true,
  ///     [ScanBarcodeResponse.suggestions] holds the candidates
  ///   - unknown barcode (Case 3): throws [ApiException] with statusCode 404
  ///
  /// Pass [listId] to scan in Mode B (Add to List — REQ-GL-035 through REQ-GL-040).
  Future<ScanBarcodeResponse> scanBarcode(String upc, {int? listId}) async {
    final payload = <String, dynamic>{'upc': upc};
    if (listId != null) payload['list_id'] = listId;

    final resp = await http
        .post(
          _uri('/scan/barcode'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    // 404 = Case 3 — let the caller handle it as ApiException
    final body = await _checkResponse(resp);

    // Case 2 — ambiguous, needs user selection
    if (body['status'] == 'needs_selection') {
      final rawSuggestions = body['suggestions'] as List<dynamic>;
      return ScanBarcodeResponse(
        needsSelection: true,
        upc: body['upc'] as String?,
        activeListName: body['active_list_name'] as String?,
        suggestions: rawSuggestions
            .map((e) => BggCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }

    // Case 1 — resolved
    return ScanBarcodeResponse(
      game: Game.fromJson(body['game'] as Map<String, dynamic>),
      addedToCollection: body['added_to_collection'] as bool? ?? false,
      addedToList: body['added_to_list'] as bool?,
      alreadyOnList: body['already_on_list'] as bool?,
      activeListName: body['active_list_name'] as String?,
    );
  }

  /// Confirms a candidate selection for Case 2 (ambiguous barcode).
  /// Returns the resolved [Game] and whether the mapping was submitted to GameUPC.
  Future<({Game game, bool addedToCollection, bool submittedToGameUpc})>
      confirmScan(String upc, int bggId) async {
    final resp = await http
        .post(
          _uri('/scan/confirm'),
          headers: _headers,
          body: jsonEncode({'upc': upc, 'bgg_id': bggId}),
        )
        .timeout(const Duration(seconds: 20));
    final body = await _checkResponse(resp);
    return (
      game: Game.fromJson(body['game'] as Map<String, dynamic>),
      addedToCollection: body['added_to_collection'] as bool? ?? false,
      submittedToGameUpc: body['submitted_to_gameupc'] as bool? ?? false,
    );
  }

  /// Links a saved unlinked barcode to a game.
  ///
  /// Supply [gameId] to link to an existing collection game (Case 3, "My Collection" tab).
  /// Supply [bggId] to link via a BGG search result (Case 3, "Search BGG" tab).
  /// Exactly one of the two must be non-null.
  Future<({Game game, bool submittedToGameUpc})> linkBarcode(
      String upc, {int? gameId, int? bggId}) async {
    assert(
      (gameId == null) != (bggId == null),
      'Exactly one of gameId or bggId must be provided',
    );
    final payload = <String, dynamic>{'upc': upc};
    if (gameId != null) payload['game_id'] = gameId;
    if (bggId != null) payload['bgg_id'] = bggId;

    final resp = await http
        .post(
          _uri('/scan/link'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
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

  /// Searches BGG by game name. Returns up to 10 results with thumbnails.
  /// Games already in the user's collection are annotated with [alreadyOwned].
  Future<List<BggSearchResult>> searchBgg(String query) async {
    final resp = await http
        .get(_uri('/games/search', {'q': query}), headers: _headers)
        .timeout(const Duration(seconds: 20));
    final body = await _checkResponse(resp);
    final list = body['games'] as List<dynamic>;
    return list
        .map((e) => BggSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Runs the three-case GameUPC integration test. Returns the raw result list.
  Future<({String environment, List<Map<String, dynamic>> results})>
      testGameUpc() async {
    final resp = await http
        .post(_uri('/gameupc/test'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    final body = await _checkResponse(resp);
    return (
      environment: body['environment'] as String,
      results: (body['results'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
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

/// A BGG game search result returned by [ApiService.searchBgg].
class BggSearchResult {
  final int bggId;
  final String title;
  final int? yearPublished;
  final int? minPlayers;
  final int? maxPlayers;
  final int? playingTime;
  final String thumbnailUrl;
  final String imageUrl;
  final bool alreadyOwned;

  const BggSearchResult({
    required this.bggId,
    required this.title,
    this.yearPublished,
    this.minPlayers,
    this.maxPlayers,
    this.playingTime,
    required this.thumbnailUrl,
    required this.imageUrl,
    required this.alreadyOwned,
  });

  factory BggSearchResult.fromJson(Map<String, dynamic> json) {
    return BggSearchResult(
      bggId: json['bgg_id'] as int,
      title: json['title'] as String,
      yearPublished: json['year_published'] as int?,
      minPlayers: json['min_players'] as int?,
      maxPlayers: json['max_players'] as int?,
      playingTime: json['playing_time'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      alreadyOwned: json['already_owned'] as bool? ?? false,
    );
  }
}
