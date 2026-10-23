import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/api_exception.dart';

class ApiClient {
  final http.Client _httpClient;
  String? _authToken;

  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

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

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint, queryParams);
    try {
      final response = await _httpClient
          .get(uri, headers: _buildHeaders(headers))
          .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
      return _processResponse(response);
    } on SocketException {
      throw ApiException('No Internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<dynamic> post(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    final payload = body ?? data;
    final uri = _buildUri(endpoint);
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(headers),
            body: payload != null ? jsonEncode(payload) : null,
          )
          .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
      return _processResponse(response);
    } on SocketException {
      throw ApiException('No Internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: ${e.toString()}');
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
    } on SocketException {
      throw ApiException('No Internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<dynamic> delete(String endpoint, {Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint);
    try {
      final response = await _httpClient
          .delete(uri, headers: _buildHeaders(headers))
          .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
      return _processResponse(response);
    } on SocketException {
      throw ApiException('No Internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: ${e.toString()}');
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
      if (responseJson.containsKey('message') && responseJson['message'] != null) {
        errorMessage = responseJson['message'].toString();
      } else if (responseJson.containsKey('error') && responseJson['error'] != null) {
        errorMessage = responseJson['error'].toString();
      }
    }

    if (response.statusCode == 401) {
      throw UnauthorizedException(errorMessage);
    } else if (response.statusCode == 403) {
      throw ForbiddenException(errorMessage);
    } else if (response.statusCode == 404) {
      throw NotFoundException(errorMessage);
    } else {
      throw ApiException(errorMessage, statusCode: response.statusCode);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

