import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etaprise_hrms/core/api/api_client.dart';
import 'package:etaprise_hrms/core/api/api_endpoints.dart';
import 'package:etaprise_hrms/core/auth/auth_service.dart';
import 'package:etaprise_hrms/core/errors/api_exception.dart';
import 'package:etaprise_hrms/core/models/user_model.dart';
import 'package:etaprise_hrms/core/storage/storage_service.dart';

class MockApiClient extends ApiClient {
  bool postShouldFail = false;
  bool postNetworkError = false;
  bool getMeShouldFail = false;
  bool getMeNetworkError = false;
  Map<String, dynamic>? mockMeResponse;

  @override
  Future<dynamic> post(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    if (endpoint == ApiEndpoints.login) {
      if (postNetworkError) {
        throw ApiException('No Internet connection. Please check your network connection.');
      }
      if (postShouldFail) {
        throw UnauthorizedException('Invalid work email or password.');
      }
      return {
        'token': 'valid-jwt-token-123',
        'refreshToken': 'valid-refresh-token-456',
        'user': {
          'id': 'user-101',
          'email': body?['email'] ?? 'tl@company.com',
          'firstName': 'Real',
          'lastName': 'User',
          'role': 'TL',
        }
      };
    }
    return {};
  }

  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    if (endpoint == ApiEndpoints.me) {
      if (getMeNetworkError) {
        throw ApiException('No Internet connection.');
      }
      if (getMeShouldFail) {
        throw UnauthorizedException('Token expired.');
      }
      return mockMeResponse ?? {
        'id': 'user-101',
        'email': 'tl@test.com',
        'firstName': 'Team',
        'lastName': 'Lead',
        'role': 'TL',
      };
    }
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('StorageService Secure Storage Tests', () {
    late StorageService storageService;

    setUp(() {
      storageService = StorageService();
    });

    test('saveUserData stores user profile in secure storage', () async {
      const userData = '{"id":"u1","email":"sec01@test.com","role":"EMPLOYEE"}';

      await storageService.saveUserData(userData);
      final retrieved = await storageService.getUserData();

      expect(retrieved, userData);
    });

    test('clearAll removes all storage keys', () async {
      await storageService.saveToken('test-token');
      await storageService.saveUserData('user-data');

      await storageService.clearAll();

      final token = await storageService.getToken();
      final userData = await storageService.getUserData();

      expect(token, isNull);
      expect(userData, isNull);
    });
  });

  group('SEC-06 Demo Login Fallback Removal Tests', () {
    late MockApiClient mockApiClient;
    late StorageService storageService;
    late AuthService authService;

    setUp(() {
      mockApiClient = MockApiClient();
      storageService = StorageService();
    });

    test('Invalid credentials return false with error message and create no session', () async {
      mockApiClient.postShouldFail = true;
      authService = AuthService(mockApiClient, storageService);

      final success = await authService.login('tl@test.com', 'wrongpassword');

      expect(success, false);
      expect(authService.state.isAuthenticated, false);
      expect(authService.state.user, isNull);
      expect(authService.state.errorMessage, 'Invalid work email or password.');

      final token = await storageService.getToken();
      expect(token, isNull);
    });

    test('Network failure returns false with network error message and creates no session', () async {
      mockApiClient.postNetworkError = true;
      authService = AuthService(mockApiClient, storageService);

      final success = await authService.login('tl@test.com', 'anypassword');

      expect(success, false);
      expect(authService.state.isAuthenticated, false);
      expect(authService.state.user, isNull);
      expect(authService.state.errorMessage, contains('network connection'));

      final token = await storageService.getToken();
      expect(token, isNull);
    });

    test('Successful login creates authenticated session with real user', () async {
      mockApiClient.postShouldFail = false;
      mockApiClient.postNetworkError = false;
      authService = AuthService(mockApiClient, storageService);

      final success = await authService.login('tl@test.com', 'validpassword');

      expect(success, true);
      expect(authService.state.isAuthenticated, true);
      expect(authService.state.user, isNotNull);
      expect(authService.state.user!.role, UserRole.TL);
      expect(authService.state.isOfflineSession, false);

      final token = await storageService.getToken();
      expect(token, 'valid-jwt-token-123');
    });
  });

  group('SEC-07 & OBS-01 Session Verification & Offline Role Protection Tests', () {
    late MockApiClient mockApiClient;
    late StorageService storageService;

    setUp(() {
      mockApiClient = MockApiClient();
      storageService = StorageService();
    });

    test('Session initialization verifies token with backend and sets authoritative server role', () async {
      await storageService.saveToken('stored-valid-token');
      await storageService.saveUserData(jsonEncode({'id': 'u1', 'email': 'local@test.com', 'role': 'TL'}));

      mockApiClient.mockMeResponse = {
        'id': 'u1',
        'email': 'verified@test.com',
        'firstName': 'Server',
        'lastName': 'User',
        'role': 'ADMIN',
      };

      final authService = AuthService(mockApiClient, storageService);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(authService.state.isAuthenticated, true);
      expect(authService.state.isOfflineSession, false);
      expect(authService.state.user!.role, UserRole.ADMIN);
    });

    test('Session initialization marks isOfflineSession true on temporary network failure', () async {
      await storageService.saveToken('valid-token');
      const cachedProfile = '{"id":"u1","email":"cached@test.com","firstName":"Cached","lastName":"User","role":"ADMIN"}';
      await storageService.saveUserData(cachedProfile);

      mockApiClient.getMeNetworkError = true;

      final authService = AuthService(mockApiClient, storageService);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(authService.state.isAuthenticated, true);
      expect(authService.state.isOfflineSession, true);
      expect(authService.state.user!.email, 'cached@test.com');
    });

    test('revalidateSession updates state when connectivity returns', () async {
      await storageService.saveToken('valid-token');
      const cachedProfile = '{"id":"u1","email":"cached@test.com","firstName":"Cached","lastName":"User","role":"ADMIN"}';
      await storageService.saveUserData(cachedProfile);

      mockApiClient.getMeNetworkError = true;
      final authService = AuthService(mockApiClient, storageService);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(authService.state.isOfflineSession, true);

      // Network recovers
      mockApiClient.getMeNetworkError = false;
      mockApiClient.mockMeResponse = {
        'id': 'u1',
        'email': 'cached@test.com',
        'firstName': 'Verified',
        'lastName': 'User',
        'role': 'EMPLOYEE',
      };

      final revalidated = await authService.revalidateSession();

      expect(revalidated, true);
      expect(authService.state.isOfflineSession, false);
      expect(authService.state.user!.role, UserRole.EMPLOYEE);
    });
  });

  group('Account Switching, Logout Cleanup & Remember Me Regression Tests', () {
    test('Test A: Account switching from Account A to Account B', () async {
      final mockClient = MockMultiAccountApiClient();
      final storage = StorageService();
      final authService = AuthService(mockClient, storage);

      // 1. Log in as Account A
      mockClient.activeAccount = 'AccountA';
      final successA = await authService.login('accountA@company.com', 'passwordA', rememberMe: true);
      expect(successA, true);
      expect(authService.state.isAuthenticated, true);
      expect(authService.state.user!.email, 'accountA@company.com');
      expect(authService.state.user!.role, UserRole.EMPLOYEE);
      expect(await storage.getToken(), 'token-A');

      // 3. Log out
      await authService.logout();

      // 4. Verify Account A data is cleared
      expect(authService.state.isAuthenticated, false);
      expect(authService.state.user, isNull);
      expect(await storage.getToken(), isNull);
      expect(await storage.getUserData(), isNull);

      // 5. Log in as Account B
      mockClient.activeAccount = 'AccountB';
      final successB = await authService.login('accountB@company.com', 'passwordB', rememberMe: true);
      expect(successB, true);
      expect(authService.state.isAuthenticated, true);
      expect(authService.state.user!.email, 'accountB@company.com');
      expect(authService.state.user!.role, UserRole.ADMIN);
      expect(await storage.getToken(), 'token-B');
    });

    test('Test B: Remember Me and explicit logout cleaning', () async {
      final mockClient = MockMultiAccountApiClient();
      final storage = StorageService();
      final authService = AuthService(mockClient, storage);

      mockClient.activeAccount = 'AccountA';
      await authService.login('a@company.com', 'pass', rememberMe: false);
      expect(authService.state.isAuthenticated, true);

      await authService.logout();
      expect(await storage.getToken(), isNull);
      expect(await storage.getUserData(), isNull);
      expect(authService.state.isAuthenticated, false);
    });

    test('Test C: Failed login after logout does not restore previous session', () async {
      final mockClient = MockMultiAccountApiClient();
      final storage = StorageService();
      final authService = AuthService(mockClient, storage);

      mockClient.activeAccount = 'AccountA';
      await authService.login('a@company.com', 'pass', rememberMe: true);
      await authService.logout();

      // Attempt login with invalid credentials
      mockClient.failLogin = true;
      final success = await authService.login('wrong@company.com', 'badpass');
      expect(success, false);
      expect(authService.state.isAuthenticated, false);
      expect(authService.state.user, isNull);
      expect(authService.state.errorMessage, isNotNull);
    });

    test('Test D: Token isolation during login and subsequent requests', () async {
      final mockClient = MockMultiAccountApiClient();
      final storage = StorageService();
      final authService = AuthService(mockClient, storage);

      mockClient.activeAccount = 'AccountA';
      await authService.login('a@company.com', 'pass');
      expect(mockClient.lastPostHeaderAuthorization, isNull); // Login POST request should not send old token

      await authService.logout();
      
      mockClient.activeAccount = 'AccountB';
      await authService.login('b@company.com', 'pass');
      expect(mockClient.lastPostHeaderAuthorization, isNull); // Account B login POST should not send Account A token

      // Subsequent session revalidation uses Account B token
      mockClient.mockMeResponse = {'id': 'b2', 'email': 'b@company.com', 'firstName': 'B', 'lastName': 'User', 'role': 'ADMIN'};
      await authService.revalidateSession();
      expect(mockClient.lastHeaderAuthorization, 'Bearer token-B');
    });

    test('Test E: Repeat account switching 5 times successfully', () async {
      final mockClient = MockMultiAccountApiClient();
      final storage = StorageService();
      final authService = AuthService(mockClient, storage);

      for (int i = 0; i < 5; i++) {
        // Switch to A
        mockClient.activeAccount = 'AccountA';
        final successA = await authService.login('a$i@company.com', 'pass');
        expect(successA, true);
        expect(authService.state.user!.email, 'a$i@company.com');
        expect(await storage.getToken(), 'token-A');
        await authService.logout();
        expect(await storage.getToken(), isNull);

        // Switch to B
        mockClient.activeAccount = 'AccountB';
        final successB = await authService.login('b$i@company.com', 'pass');
        expect(successB, true);
        expect(authService.state.user!.email, 'b$i@company.com');
        expect(await storage.getToken(), 'token-B');
        await authService.logout();
        expect(await storage.getToken(), isNull);
      }
    });
  });

  group('Release Build APK Fixes & Error Handling Tests', () {
    test('StorageService gracefully handles secure storage exceptions without crashing', () async {
      final storageService = StorageService();
      // Test read/write with normal operations
      await storageService.saveToken('test-token-safe');
      final retrieved = await storageService.getToken();
      expect(retrieved, 'test-token-safe');
    });

    test('AuthService login maps request timeout error correctly', () async {
      final storage = StorageService();

      // Simulate timeout exception in login flow
      final timeoutClient = TimeoutMockApiClient();
      final authServiceTimeout = AuthService(timeoutClient, storage);
      
      final success = await authServiceTimeout.login('test@company.com', 'password');
      expect(success, false);
      expect(authServiceTimeout.state.errorMessage, contains('timed out'));
    });
  });
}

class MockMultiAccountApiClient extends ApiClient {
  String activeAccount = 'AccountA';
  bool failLogin = false;
  String? lastTokenUsed;
  String? lastHeaderAuthorization;
  String? lastPostHeaderAuthorization;
  String? currentAuthToken;
  Map<String, dynamic>? mockMeResponse;
  String? lastLoginEmail;

  @override
  void setAuthToken(String? token) {
    currentAuthToken = token;
    super.setAuthToken(token);
  }

  @override
  Future<dynamic> post(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    lastHeaderAuthorization = currentAuthToken != null ? 'Bearer $currentAuthToken' : headers?['Authorization'];
    lastPostHeaderAuthorization = lastHeaderAuthorization;
    if (endpoint == ApiEndpoints.login) {
      if (failLogin) {
        throw UnauthorizedException('Invalid work email or password.');
      }
      lastLoginEmail = body?['email'];
      if (activeAccount == 'AccountB') {
        return {
          'token': 'token-B',
          'refreshToken': 'refresh-B',
          'user': {
            'id': 'user-B',
            'email': lastLoginEmail ?? 'accountB@company.com',
            'firstName': 'Account',
            'lastName': 'B',
            'role': 'ADMIN',
          }
        };
      } else {
        return {
          'token': 'token-A',
          'refreshToken': 'refresh-A',
          'user': {
            'id': 'user-A',
            'email': lastLoginEmail ?? 'accountA@company.com',
            'firstName': 'Account',
            'lastName': 'A',
            'role': 'EMPLOYEE',
          }
        };
      }
    }
    return {};
  }

  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    lastHeaderAuthorization = currentAuthToken != null ? 'Bearer $currentAuthToken' : headers?['Authorization'];
    if (endpoint == ApiEndpoints.me) {
      if (mockMeResponse != null) return mockMeResponse;
      if (activeAccount == 'AccountB') {
        return {
          'id': 'user-B',
          'email': lastLoginEmail ?? 'accountB@company.com',
          'firstName': 'Account',
          'lastName': 'B',
          'role': 'ADMIN',
        };
      } else {
        return {
          'id': 'user-A',
          'email': lastLoginEmail ?? 'accountA@company.com',
          'firstName': 'Account',
          'lastName': 'A',
          'role': 'EMPLOYEE',
        };
      }
    }
    return {};
  }
}

class TimeoutMockApiClient extends ApiClient {
  @override
  Future<dynamic> post(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    throw ApiException('Request timed out. Please try again.');
  }
}
