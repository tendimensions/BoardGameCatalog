import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/collection_item.dart';
import '../models/game.dart';

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
  Future<({Game game, bool addedToCollection})> scanBarcode(String upc) async {
    final resp = await http
        .post(
          _uri('/scan/barcode'),
          headers: _headers,
          body: jsonEncode({'upc': upc}),
        )
        .timeout(const Duration(seconds: 15));
    final body = await _checkResponse(resp);
    return (
      game: Game.fromJson(body['game'] as Map<String, dynamic>),
      addedToCollection: body['added_to_collection'] as bool? ?? false,
    );
  }
}
