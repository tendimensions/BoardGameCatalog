import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

enum AuthState { unknown, loggedOut, loggedIn }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthState _state = AuthState.unknown;
  String? _username;
  String? _apiKey;
  String? _error;

  AuthState get state => _state;
  String? get username => _username;
  String? get apiKey => _apiKey;
  String? get error => _error;
  bool get isLoggedIn => _state == AuthState.loggedIn;

  /// Called at app start to restore session from secure storage.
  Future<void> initialize() async {
    final key = await _authService.getApiKey();
    if (key == null || key.isEmpty) {
      _state = AuthState.loggedOut;
      notifyListeners();
      return;
    }
    _apiKey = key;
    try {
      final username = await ApiService(key).validateKey();
      _username = username;
      _state = AuthState.loggedIn;
    } on ApiException {
      // Stored key is no longer valid — treat as logged out
      await _authService.clearApiKey();
      _apiKey = null;
      _state = AuthState.loggedOut;
    } catch (_) {
      // Network error — keep key but mark logged in optimistically
      _state = AuthState.loggedIn;
    }
    notifyListeners();
  }

  /// Saves the pasted API key and validates it against the server.
  Future<void> login(String key) async {
    _error = null;
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      _error = 'Please enter your API key.';
      notifyListeners();
      return;
    }
    try {
      final username = await ApiService(trimmed).validateKey();
      await _authService.saveApiKey(trimmed);
      _apiKey = trimmed;
      _username = username;
      _state = AuthState.loggedIn;
      _error = null;
    } on ApiException catch (e) {
      _error = e.statusCode == 401 || e.statusCode == 403
          ? 'API key not recognised. Generate a new one at boardgames.tendimensions.com/accounts/api-keys/'
          : e.message;
    } catch (_) {
      _error = 'Could not reach the server. Check your connection and try again.';
    }
    notifyListeners();
  }

  /// Clears the stored key and returns to the setup screen.
  Future<void> logout() async {
    await _authService.clearApiKey();
    _apiKey = null;
    _username = null;
    _state = AuthState.loggedOut;
    _error = null;
    notifyListeners();
  }
}
