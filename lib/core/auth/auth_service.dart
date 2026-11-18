import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../errors/api_exception.dart';
import '../models/user_model.dart';
import '../storage/storage_service.dart';

class AuthState {
  final bool? _isInitializing;
  final bool isLoading;
  final bool isAuthenticated;
  final bool isOfflineSession;
  final UserModel? user;
  final String? errorMessage;

  bool get isInitializing => _isInitializing ?? false;

  AuthState({
    bool? isInitializing,
    required this.isLoading,
    required this.isAuthenticated,
    this.isOfflineSession = false,
    this.user,
    this.errorMessage,
  }) : _isInitializing = isInitializing;

  factory AuthState.initial() => AuthState(isInitializing: true, isLoading: false, isAuthenticated: false, isOfflineSession: false);

  AuthState copyWith({
    bool? isInitializing,
    bool? isLoading,
    bool? isAuthenticated,
    bool? isOfflineSession,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      isInitializing: isInitializing ?? _isInitializing,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isOfflineSession: isOfflineSession ?? this.isOfflineSession,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthService extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final StorageService _storageService;
  bool _isInitializing = false;
  Timer? _initTimer;
  // Bumped on every login/logout so a slow logout can never wipe a newer session.
  int _sessionEpoch = 0;

  AuthService(this._apiClient, this._storageService) : super(AuthState.initial()) {
    _apiClient.setTokenRefreshHandler(_performTokenRefresh);
    _initializeAuth();
  }

  Future<bool> _performTokenRefresh() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await _apiClient.post(
        ApiEndpoints.refresh,
        body: {'refreshToken': refreshToken},
      );

      final data = response is Map<String, dynamic> && response.containsKey('data')
          ? response['data']
          : response;

      if (data is Map<String, dynamic>) {
        final newToken = data['token']?.toString() ?? '';
        final newRefreshToken = data['refreshToken']?.toString() ?? '';
        if (newToken.isNotEmpty) {
          _apiClient.setAuthToken(newToken);
          await _storageService.saveToken(newToken);
          if (newRefreshToken.isNotEmpty) {
            await _storageService.saveRefreshToken(newRefreshToken);
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[AuthDiag:AuthService] Token refresh failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      final rememberMe = await _storageService.getRememberMe();
      if (!rememberMe) {
        await _storageService.clearSession();
        _apiClient.setAuthToken(null);
        if (mounted) state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: false, isOfflineSession: false);
        return;
      }

      final token = await _storageService.getToken();
      final userJsonStr = await _storageService.getUserData();

      if (token == null || token.isEmpty) {
        if (mounted) state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: false, isOfflineSession: false);
        return;
      }

      _apiClient.setAuthToken(token);
      UserModel? cachedUser;
      if (userJsonStr != null && userJsonStr.isNotEmpty) {
        try {
          cachedUser = UserModel.fromJson(jsonDecode(userJsonStr));
        } catch (_) {}
      }

      // SEC-07: Authoritative Server Profile Verification on Startup
      try {
        final meResponse = await _apiClient.get(ApiEndpoints.me).timeout(const Duration(seconds: 4));
        final data = meResponse is Map<String, dynamic> && meResponse.containsKey('data')
            ? meResponse['data']
            : meResponse;

        if (data is Map<String, dynamic>) {
          final serverUser = UserModel.fromJson(data);
          await _storageService.saveUserData(jsonEncode(serverUser.toJson()));
          if (mounted) state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: true, isOfflineSession: false, user: serverUser);
          return;
        }
      } on UnauthorizedException catch (_) {
        // Stale or revoked token on server — purge local session
        await _storageService.clearSession();
        _apiClient.setAuthToken(null);
        if (mounted) state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: false, isOfflineSession: false);
        return;
      } on ForbiddenException catch (_) {
        await _storageService.clearSession();
        _apiClient.setAuthToken(null);
        if (mounted) state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: false, isOfflineSession: false);
        return;
      } catch (_) {
        // OBS-01 Remediation: Mark session as offline & unverified
        if (cachedUser != null) {
          if (mounted) state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: true, isOfflineSession: true, user: cachedUser);
          return;
        }
      }

      if (cachedUser != null) {
        if (mounted) state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: true, isOfflineSession: true, user: cachedUser);
      } else {
        if (mounted) state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: false, isOfflineSession: false);
      }
    } catch (e) {
      debugPrint('[AuthDiag:AuthService] Error initializing auth: $e');
      if (mounted) state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: false, isOfflineSession: false);
    } finally {
      _isInitializing = false;
    }
  }

  /// Revalidates session against backend when connectivity resumes
  Future<bool> revalidateSession() async {
    final token = await _storageService.getToken();
    if (token == null || token.isEmpty) {
      state = AuthState(isLoading: false, isAuthenticated: false, isOfflineSession: false);
      return false;
    }
    _apiClient.setAuthToken(token);
    try {
      final meResponse = await _apiClient.get(ApiEndpoints.me);
      final data = meResponse is Map<String, dynamic> && meResponse.containsKey('data')
          ? meResponse['data']
          : meResponse;

      if (data is Map<String, dynamic>) {
        final serverUser = UserModel.fromJson(data);
        await _storageService.saveUserData(jsonEncode(serverUser.toJson()));
        state = AuthState(isLoading: false, isAuthenticated: true, isOfflineSession: false, user: serverUser);
        return true;
      }
    } on UnauthorizedException catch (_) {
      await logout();
      return false;
    } on ForbiddenException catch (_) {
      await logout();
      return false;
    } catch (_) {
      // Still offline
    }
    return false;
  }

  Future<void> refreshCurrentUser() async {
    try {
      final meResponse = await _apiClient.get(ApiEndpoints.me);
      final data = meResponse is Map<String, dynamic> && meResponse.containsKey('data')
          ? meResponse['data']
          : meResponse;

      if (data is Map<String, dynamic>) {
        final serverUser = UserModel.fromJson(data);
        await _storageService.saveUserData(jsonEncode(serverUser.toJson()));
        if (mounted) {
          state = state.copyWith(user: serverUser);
        }
      }
    } catch (e) {
      debugPrint('[AuthService] refreshCurrentUser failed: $e');
    }
  }

  /// SEC-06: Production Authentication without Demo Fallback
  Future<bool> login(String email, String password, {bool rememberMe = true}) async {
    debugPrint('[AuthDiag:AuthService] login initiated for email length: ${email.length}');

    // Ensure absolute clean slate before any login attempt
    _sessionEpoch++;
    _apiClient.setAuthToken(null);
    try {
      await _storageService.clearSession();
    } catch (_) {}

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        body: {'email': email, 'password': password},
      );

      final data = response is Map<String, dynamic> && response.containsKey('data')
          ? response['data']
          : response;

      if (data == null || data is! Map<String, dynamic>) {
        throw ApiException('Invalid server response format.');
      }

      final token = data['token']?.toString() ?? '';
      final refreshToken = data['refreshToken']?.toString() ?? '';
      final userMap = data['user'] ?? data;

      if (token.isEmpty) {
        throw ApiException('Invalid server response: Missing authentication token.');
      }

      await _storageService.saveRememberMe(rememberMe);
      await _storageService.saveToken(token);
      if (refreshToken.isNotEmpty) {
        await _storageService.saveRefreshToken(refreshToken);
      } else {
        await _storageService.deleteRefreshToken();
      }

      _apiClient.setAuthToken(token);

      // Flow: login -> store fresh token -> fetch /users/me -> load role and permissions -> only then initialize dashboard
      UserModel user;
      try {
        final meResponse = await _apiClient.get(ApiEndpoints.me);
        final meData = meResponse is Map<String, dynamic> && meResponse.containsKey('data')
            ? meResponse['data']
            : meResponse;
        if (meData is Map<String, dynamic>) {
          user = UserModel.fromJson(meData);
        } else {
          user = UserModel.fromJson(userMap is Map<String, dynamic> ? userMap : {});
        }
      } on UnauthorizedException catch (_) {
        rethrow; // token rejected by the server: login must fail
      } on ForbiddenException catch (_) {
        rethrow;
      } catch (e) {
        // Transient /users/me failure (timeout/5xx): use the profile from the login response itself.
        debugPrint('[AuthDiag:AuthService] /users/me failed after login ($e); using login payload profile');
        user = UserModel.fromJson(userMap is Map<String, dynamic> ? userMap : {});
      }

      await _storageService.saveUserData(jsonEncode(user.toJson()));
      debugPrint('[AuthDiag:AuthService] login data and authoritative profile persisted successfully. ID: ${user.id}, Role: ${user.role}');

      state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: true, isOfflineSession: false, user: user);
      debugPrint('[AuthDiag:AuthService] login state updated to authenticated');
      return true;
    } on UnauthorizedException catch (e) {
      await _discardSession();
      debugPrint('[AuthDiag:AuthService] login UnauthorizedException: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message.isNotEmpty ? e.message : 'Invalid work email or password.',
      );
      return false;
    } on ForbiddenException catch (e) {
      await _discardSession();
      debugPrint('[AuthDiag:AuthService] login ForbiddenException: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message.isNotEmpty ? e.message : 'Account access is restricted or forbidden.',
      );
      return false;
    } on ApiException catch (e) {
      await _discardSession();
      debugPrint('[AuthDiag:AuthService] login ApiException: ${e.message}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e, st) {
      await _discardSession();
      debugPrint('[AuthDiag:AuthService] login unexpected error: $e \n $st');
      String userMessage = 'Unable to connect to HRMS server. Please check your network connection.';
      final errStr = e.toString();
      if (errStr.contains('Invalid work email or password') || errStr.contains('401')) {
        userMessage = 'Invalid work email or password.';
      } else if (errStr.contains('403')) {
        userMessage = 'Account access is restricted or forbidden.';
      } else if (errStr.contains('timed out') || errStr.contains('TimeoutException')) {
        userMessage = 'Request timed out. Please check your network connection.';
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: userMessage,
      );
      return false;
    }
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _apiClient.post(
        ApiEndpoints.register,
        body: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': password,
        },
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      throw Exception(e.toString());
    }
  }

  /// Removes any half-created session (token on the client + persisted keys).
  Future<void> _discardSession() async {
    _apiClient.setAuthToken(null);
    try {
      await _storageService.clearSession();
    } catch (_) {}
  }

  Future<void> logout() async {
    debugPrint('[AuthDiag:AuthService] logout initiated');
    final epoch = ++_sessionEpoch;
    final currentUser = state.user;
    final refreshToken = await _storageService.getRefreshToken();

    // 1. Drop the user from the UI immediately (avatar, header, router).
    state = AuthState(isInitializing: false, isLoading: false, isAuthenticated: false, isOfflineSession: false, user: null);

    // 2. Best-effort server logout with refresh token while the token is still on the client, bounded by a timeout.
    try {
      await _apiClient.post(ApiEndpoints.logout, body: {'refreshToken': refreshToken ?? ''}).timeout(const Duration(seconds: 5));
      debugPrint('[AuthDiag:AuthService] logout backend API call completed');
    } catch (e) {
      debugPrint('[AuthDiag:AuthService] logout backend API call error (ignored): $e');
    }

    // 3. Local cleanup - skipped if a newer login already started, so it cannot wipe that session.
    if (epoch != _sessionEpoch) {
      debugPrint('[AuthDiag:AuthService] logout cleanup skipped: newer session started');
      return;
    }
    _apiClient.setAuthToken(null);
    if (currentUser != null) {
      try {
        await _storageService.clearAccountCache(currentUser.id);
      } catch (_) {}
    }
    await _storageService.clearSession();
    debugPrint('[AuthDiag:AuthService] logout complete');
  }
}

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storageService = ref.watch(storageServiceProvider);
  return AuthService(apiClient, storageService);
});