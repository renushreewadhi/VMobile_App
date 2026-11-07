import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/api_exception.dart';

class ApiClient {
  final http.Client _httpClient;
  String? _authToken;

  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  String get baseUrl => AppConfig.apiBaseUrl;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _buildHeaders([Map<String, String>? extraHeaders]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  ApiException _handleException(dynamic e, [StackTrace? st]) {
    if (kDebugMode && st != null) {
      debugPrint('[ApiClient] Error: $e \n $st');
    }
    if (e is ApiException) return e;
    final errStr = e.toString();
    if (errStr.contains('ClientException') ||
        errStr.contains('SocketException') ||
        errStr.contains('Failed host lookup') ||
        errStr.contains('Connection refused') ||
        errStr.contains('Network is unreachable')) {
      return ApiException('Unable to connect to server. Please check your internet connection or server availability.');
    }
    if (errStr.contains('TimeoutException') || errStr.contains('timed out')) {
      return ApiException('Request timed out. Please try again.');
    }
    if (errStr.contains('HandshakeException')) {
      return ApiException('Secure connection failed. Please check device date/time or network settings.');
    }
    return ApiException(errStr.replaceFirst('Exception: ', '').replaceFirst('ApiException: ', ''));
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint, queryParams);
    final builtHeaders = _buildHeaders(headers);
    if (kDebugMode) {
      final tokenPresent = builtHeaders.containsKey('Authorization') && builtHeaders['Authorization']!.isNotEmpty;
      debugPrint('[ApiClient] GET ${uri.toString()} | Token Present: $tokenPresent');
    }
    try {
      final response = await _httpClient
          .get(uri, headers: builtHeaders)
          .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
      if (kDebugMode) {
        debugPrint('[ApiClient] Response Status: ${response.statusCode} | Length: ${response.body.length}');
      }
      return _processResponse(response);
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  Future<dynamic> post(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    final payload = body ?? data;
    final uri = _buildUri(endpoint);
    final builtHeaders = _buildHeaders(headers);
    final hasAuth = builtHeaders.containsKey('Authorization');
    debugPrint('[AuthDiag:ApiClient] POST ${uri.toString()} | Auth Header Present: $hasAuth');
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: builtHeaders,
            body: payload != null ? jsonEncode(payload) : null,
          )
          .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
      debugPrint('[AuthDiag:ApiClient] POST Response Status: ${response.statusCode} | Length: ${response.body.length}');
      return _processResponse(response);
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  Future<dynamic> put(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    final payload = body ?? data;
    final uri = _buildUri(endpoint);
    try {
      final response = await _httpClient
          .put(
            uri,
            headers: _buildHeaders(headers),
            body: payload != null ? jsonEncode(payload) : null,
          )
          .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
      return _processResponse(response);
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  Future<dynamic> patch(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    final payload = body ?? data;
    final uri = _buildUri(endpoint);
    try {
      final response = await _httpClient
          .patch(
            uri,
            headers: _buildHeaders(headers),
            body: payload != null ? jsonEncode(payload) : null,
          )
          .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
      return _processResponse(response);
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  Future<dynamic> delete(String endpoint, {Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint);
    try {
      final response = await _httpClient
          .delete(uri, headers: _buildHeaders(headers))
          .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
      return _processResponse(response);
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  Uri _buildUri(String endpoint, [Map<String, String>? queryParams]) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '${AppConfig.apiBaseUrl}$cleanEndpoint';
    return Uri.parse(fullUrl).replace(queryParameters: queryParams);
  }

  dynamic _processResponse(http.Response response) {
    dynamic responseJson;
    try {
      if (response.body.isNotEmpty) {
        responseJson = jsonDecode(response.body);
      }
    } catch (_) {
      responseJson = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseJson;
    }

    String errorMessage = 'Request failed with status: ${response.statusCode}';
    if (responseJson is Map<String, dynamic>) {
      if (responseJson['message'] != null && responseJson['message'].toString().trim().isNotEmpty) {
        errorMessage = responseJson['message'].toString();
      } else if (responseJson['error'] != null && responseJson['error'].toString().trim().isNotEmpty) {
        errorMessage = responseJson['error'].toString();
      } else if (responseJson['title'] != null && responseJson['title'].toString().trim().isNotEmpty) {
        errorMessage = responseJson['title'].toString();
      } else if (responseJson['errors'] != null) {
        final errors = responseJson['errors'];
        if (errors is Map<String, dynamic>) {
          final errorList = <String>[];
          errors.forEach((key, value) {
            if (value is List) {
              errorList.addAll(value.map((e) => e.toString()));
            } else if (value != null) {
              errorList.add(value.toString());
            }
          });
          if (errorList.isNotEmpty) {
            errorMessage = errorList.join(' ');
          }
        } else {
          errorMessage = errors.toString();
        }
      }
    }

    if (response.statusCode == 401) {
      throw UnauthorizedException(errorMessage.contains('status: 401') ? 'Invalid work email or password.' : errorMessage);
    } else if (response.statusCode == 403) {
      throw ForbiddenException(errorMessage.contains('status: 403') ? 'Account access is restricted or forbidden.' : errorMessage);
    } else if (response.statusCode == 404) {
      throw NotFoundException(errorMessage.contains('status: 404') ? 'Requested resource not found.' : errorMessage);
    } else if (response.statusCode >= 500) {
      final detail = (errorMessage.isNotEmpty && !errorMessage.startsWith('Request failed with status:'))
          ? errorMessage
          : 'Server error (${response.statusCode}). Please try again later.';
      throw ApiException(detail, statusCode: response.statusCode);
    } else {
      throw ApiException(errorMessage, statusCode: response.statusCode);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
