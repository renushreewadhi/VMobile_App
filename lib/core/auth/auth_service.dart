import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/user_model.dart';
import '../storage/storage_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? errorMessage;

  AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.user,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(isLoading: true, isAuthenticated: false);

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthService extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final StorageService _storageService;

  AuthService(this._apiClient, this._storageService) : super(AuthState.initial()) {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final token = await _storageService.getToken();
      final userJsonStr = await _storageService.getUserData();

      if (token != null && token.isNotEmpty && userJsonStr != null) {
        _apiClient.setAuthToken(token);
        final userMap = jsonDecode(userJsonStr);
        final user = UserModel.fromJson(userMap);
        state = AuthState(isLoading: false, isAuthenticated: true, user: user);
      } else {
        state = AuthState(isLoading: false, isAuthenticated: false);
      }
    } catch (_) {
      state = AuthState(isLoading: false, isAuthenticated: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        body: {'email': email, 'password': password},
      );

      final data = response is Map<String, dynamic> && response.containsKey('data')
          ? response['data']
          : response;

      final token = data['token']?.toString() ?? '';
      final refreshToken = data['refreshToken']?.toString() ?? '';
      final userMap = data['user'] ?? data;

      final user = UserModel.fromJson(userMap);

      await _storageService.saveToken(token);
      if (refreshToken.isNotEmpty) {
        await _storageService.saveRefreshToken(refreshToken);
      }
      await _storageService.saveUserData(jsonEncode(user.toJson()));

      _apiClient.setAuthToken(token);

      state = AuthState(isLoading: false, isAuthenticated: true, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String role = 'EMPLOYEE',
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
          'role': role,
        },
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      throw Exception(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.logout, body: {});
    } catch (_) {}
    await _storageService.clearAll();
    _apiClient.setAuthToken(null);
    state = AuthState(isLoading: false, isAuthenticated: false, user: null);
  }
}


final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final authServiceProvider = StateNotifierProvider<AuthService, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storageService = ref.watch(storageServiceProvider);
  return AuthService(apiClient, storageService);
});
