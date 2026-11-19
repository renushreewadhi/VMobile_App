import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/api_exception.dart';
import 'api_endpoints.dart';

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
    if (e is SocketException || e is HttpException || e is http.ClientException) {
      return ApiException('Unable to connect to server. Please check your internet connection or server availability.');
    }
    if (e is TimeoutException) {
      return ApiException('Request timed out. Please try again.');
    }
    if (e is HandshakeException) {
      return ApiException('Secure connection failed. Please check device date/time or network settings.');
    }
    final errStr = e.toString();
    if (errStr.contains('Failed host lookup') ||
        errStr.contains('Connection refused') ||
        errStr.contains('Network is unreachable')) {
      return ApiException('Unable to connect to server. Please check your internet connection or server availability.');
    }
    return ApiException(errStr.replaceFirst('Exception: ', '').replaceFirst('ApiException: ', ''));
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams, Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint, queryParams);
    try {
      return await _retryWithTokenRefresh(
        () => _httpClient.get(uri, headers: _buildHeaders(headers)).timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds)),
        endpoint,
      );
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  Future<dynamic> post(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    final payload = body ?? data;
    final uri = _buildUri(endpoint);
    try {
      return await _retryWithTokenRefresh(
        () => _httpClient
            .post(
              uri,
              headers: _buildHeaders(headers),
              body: payload != null ? jsonEncode(payload) : null,
            )
            .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds)),
        endpoint,
      );
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  Future<dynamic> put(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    final payload = body ?? data;
    final uri = _buildUri(endpoint);
    try {
      return await _retryWithTokenRefresh(
        () => _httpClient
            .put(
              uri,
              headers: _buildHeaders(headers),
              body: payload != null ? jsonEncode(payload) : null,
            )
            .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds)),
        endpoint,
      );
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  Future<dynamic> patch(String endpoint, {dynamic body, dynamic data, Map<String, String>? headers}) async {
    final payload = body ?? data;
    final uri = _buildUri(endpoint);
    try {
      return await _retryWithTokenRefresh(
        () => _httpClient
            .patch(
              uri,
              headers: _buildHeaders(headers),
              body: payload != null ? jsonEncode(payload) : null,
            )
            .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds)),
        endpoint,
      );
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  Future<dynamic> delete(String endpoint, {Map<String, String>? headers}) async {
    final uri = _buildUri(endpoint);
    try {
      return await _retryWithTokenRefresh(
        () => _httpClient
            .delete(uri, headers: _buildHeaders(headers))
            .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds)),
        endpoint,
      );
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  /// Sends a multipart HTTP request for file uploads (images, documents, receipts).
  Future<dynamic> postMultipart(
    String endpoint, {
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
    Map<String, String>? headers,
    String method = 'POST',
  }) async {
    final duplicatedFiles = <Map<String, dynamic>>[];
    if (files != null) {
      for (final file in files) {
        final bytes = await file.finalize().toBytes();
        duplicatedFiles.add({
          'field': file.field,
          'bytes': bytes,
          'filename': file.filename,
          'contentType': file.contentType,
        });
      }
    }

    final uri = _buildUri(endpoint);
    try {
      return await _retryWithTokenRefresh(
        () async {
          final request = http.MultipartRequest(method, uri);
          final builtHeaders = _buildHeaders(headers);
          builtHeaders.remove('Content-Type');
          request.headers.addAll(builtHeaders);

          if (fields != null) {
            request.fields.addAll(fields);
          }
          if (duplicatedFiles.isNotEmpty) {
            for (final f in duplicatedFiles) {
              request.files.add(
                http.MultipartFile.fromBytes(
                  f['field'] as String,
                  f['bytes'] as Uint8List,
                  filename: f['filename'] as String?,
                  contentType: f['contentType'],
                ),
              );
            }
          }

          final streamedResponse = await _httpClient
              .send(request)
              .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds));
          return await http.Response.fromStream(streamedResponse);
        },
        endpoint,
      );
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  /// Explicitly downloads binary content (PDF payslips, documents, images) as raw bytes for any 2xx response.
  Future<Uint8List> getBytes(
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    try {
      final response = await _retryWithTokenRefresh(
        () => _httpClient
            .get(uri, headers: _buildHeaders(headers))
            .timeout(const Duration(seconds: AppConfig.requestTimeoutSeconds)),
        endpoint,
      );
      if (response is Uint8List) return response;
      if (response is http.Response) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response.bodyBytes;
        } else {
          _processResponse(response, endpoint);
        }
      }
      return Uint8List(0);
    } catch (e, st) {
      throw _handleException(e, st);
    }
  }

  Uri _buildUri(String endpoint, [Map<String, String>? queryParams]) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return Uri.parse(endpoint).replace(queryParameters: queryParams);
    }
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '${AppConfig.apiBaseUrl}$cleanEndpoint';
    return Uri.parse(fullUrl).replace(queryParameters: queryParams);
  }

  bool _isRefreshing = false;
  final List<Completer<bool>> _refreshCompleters = [];
  Future<bool> Function()? _onTokenRefresh;

  void setTokenRefreshHandler(Future<bool> Function() refreshHandler) {
    _onTokenRefresh = refreshHandler;
  }

  /// Downloads binary stream (PDF payslips, documents) directly to disk in chunks with magic header validation.
  Future<File> getBinaryStreamToFile(
    String endpoint, {
    required File targetFile,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, queryParams);

    if (!targetFile.parent.existsSync()) {
      await targetFile.parent.create(recursive: true);
    }

    final tempFile = File('${targetFile.path}.tmp');
    if (await tempFile.exists()) await tempFile.delete();

    try {
      await _retryWithTokenRefresh(
        () async {
          final request = http.Request('GET', uri);
          request.headers.addAll(_buildHeaders(headers));

          final streamedResponse = await _httpClient.send(request).timeout(
            const Duration(seconds: AppConfig.requestTimeoutSeconds),
          );

          if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
            final responseBody = await streamedResponse.stream.bytesToString();
            return http.Response(responseBody, streamedResponse.statusCode, headers: streamedResponse.headers);
          }

          if (await tempFile.exists()) await tempFile.delete();
          final sink = tempFile.openWrite();
          await streamedResponse.stream.pipe(sink);
          await sink.flush();
          await sink.close();

          return http.Response('', 200, headers: streamedResponse.headers);
        },
        endpoint,
      );

      final length = await tempFile.length();
      if (length < 4) {
        if (await tempFile.exists()) await tempFile.delete();
        throw ApiException('Downloaded file is empty or invalid.');
      }

      final bytes = await tempFile.openRead(0, 4).first;
      final isPdf = bytes.length >= 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;

      if (!isPdf) {
        if (await tempFile.exists()) await tempFile.delete();
        throw ApiException('Downloaded file failed PDF magic header validation.');
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      return await tempFile.rename(targetFile.path);
    } catch (e, st) {
      if (await tempFile.exists()) {
        try { await tempFile.delete(); } catch (_) {}
      }
      throw _handleException(e, st);
    }
  }

  /// Handles 401 token expiry retry loop using race-free single refresh locking and completer queueing.
  Future<dynamic> _retryWithTokenRefresh(Future<http.Response> Function() requestExec, String endpoint) async {
    http.Response response = await requestExec();
    if (response.statusCode == 401 &&
        _onTokenRefresh != null &&
        !endpoint.contains(ApiEndpoints.login) &&
        !endpoint.contains(ApiEndpoints.refresh)) {

      Completer<bool>? currentCompleter;
      bool shouldRefresh = false;

      if (_isRefreshing) {
        currentCompleter = Completer<bool>();
        _refreshCompleters.add(currentCompleter);
      } else {
        _isRefreshing = true;
        shouldRefresh = true;
      }

      if (!shouldRefresh && currentCompleter != null) {
        final refreshed = await currentCompleter.future;
        if (refreshed) {
          response = await requestExec();
        }
      } else if (shouldRefresh) {
        bool success = false;
        try {
          success = await _onTokenRefresh!();
        } catch (_) {
          success = false;
        } finally {
          _isRefreshing = false;
          final pending = List<Completer<bool>>.from(_refreshCompleters);
          _refreshCompleters.clear();
          for (final c in pending) {
            if (!c.isCompleted) c.complete(success);
          }
        }

        if (success) {
          response = await requestExec();
        }
      }
    }
    return _processResponse(response, endpoint);
  }

  dynamic _processResponse(http.Response response, [String? endpoint]) {
    if (kDebugMode) {
      debugPrint('[ApiClient] Response [${response.statusCode}] for endpoint: ${endpoint ?? 'unknown'}. Body: ${response.body}');
    }
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final isBinary = contentType.contains('application/pdf') ||
        contentType.contains('octet-stream') ||
        contentType.contains('image/') ||
        contentType.contains('application/vnd.ms-excel') ||
        contentType.contains('spreadsheetml') ||
        contentType.contains('zip');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (isBinary) {
        return response.bodyBytes;
      }
      dynamic responseJson;
      try {
        if (response.body.isNotEmpty) {
          responseJson = jsonDecode(response.body);
        }
      } catch (_) {
        responseJson = response.body;
      }
      return responseJson;
    }

    dynamic responseJson;
    try {
      if (response.body.isNotEmpty) {
        responseJson = jsonDecode(response.body);
      }
    } catch (_) {
      responseJson = response.body;
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
      final isLogin = endpoint != null && (endpoint.contains(ApiEndpoints.login) || endpoint.contains('login'));
      final defaultMsg = isLogin
          ? 'Invalid work email or password.'
          : 'Session expired or unauthorized. Please log in again.';
      throw UnauthorizedException(
        (errorMessage.contains('status: 401') || errorMessage.isEmpty)
            ? defaultMsg
            : errorMessage,
      );
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
