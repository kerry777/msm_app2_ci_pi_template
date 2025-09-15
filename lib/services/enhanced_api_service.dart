import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/analytics_data.dart';

class EnhancedApiService {
  static final EnhancedApiService _instance = EnhancedApiService._internal();
  factory EnhancedApiService() => _instance;
  EnhancedApiService._internal();

  // HTTP 클라이언트 설정
  late http.Client _client;
  static String? _token;
  static String get baseUrl => AppConfig.apiBaseUrl;

  // 캐시 관리
  final Map<String, CachedResponse> _cache = {};
  final Map<String, Timer> _cacheTimers = {};

  // 요청 큐 관리
  final Map<String, Future<http.Response>> _requestQueue = {};

  // 연결 상태 관리
  bool _isOnline = true;
  Timer? _heartbeatTimer;
  final StreamController<ConnectionStatus> _connectionController = StreamController<ConnectionStatus>.broadcast();

  // 재시도 설정
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 1);
  static const Duration requestTimeout = Duration(seconds: 30);

  // 초기화
  Future<void> init() async {
    _client = http.Client();
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');

    _startConnectionMonitoring();
    await _loadCacheFromDisk();
  }

  // 연결 상태 모니터링
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;
  bool get isOnline => _isOnline;

  void _startConnectionMonitoring() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkConnection();
    });
  }

  Future<void> _checkConnection() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/v1/health'))
          .timeout(const Duration(seconds: 5));

      final wasOnline = _isOnline;
      _isOnline = response.statusCode == 200;

      if (wasOnline != _isOnline) {
        _connectionController.add(_isOnline
            ? ConnectionStatus.online
            : ConnectionStatus.offline);
      }
    } catch (e) {
      final wasOnline = _isOnline;
      _isOnline = false;

      if (wasOnline) {
        _connectionController.add(ConnectionStatus.offline);
      }
    }
  }

  // 토큰 관리
  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // 강화된 API 요청
  Future<ApiResponse<T>> request<T>({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool useCache = true,
    Duration? cacheTimeout,
    int? retries,
    bool requiresAuth = true,
  }) async {
    final cacheKey = _generateCacheKey(endpoint, method, body);

    // 캐시 확인
    if (useCache && method.toUpperCase() == 'GET') {
      final cached = _getCachedResponse(cacheKey);
      if (cached != null) {
        return ApiResponse<T>(
          success: true,
          data: cached.data,
          fromCache: true,
        );
      }
    }

    // 중복 요청 방지
    if (_requestQueue.containsKey(cacheKey)) {
      try {
        final response = await _requestQueue[cacheKey]!;
        return _processResponse<T>(response, fromCache: false);
      } catch (e) {
        _requestQueue.remove(cacheKey);
        rethrow;
      }
    }

    // 새 요청 생성
    final future = _makeRequest(
      endpoint: endpoint,
      method: method,
      body: body,
      headers: headers,
      retries: retries ?? maxRetries,
      requiresAuth: requiresAuth,
    );

    _requestQueue[cacheKey] = future;

    try {
      final response = await future;
      final result = _processResponse<T>(response, fromCache: false);

      // 성공시 캐시 저장
      if (result.success && useCache && method.toUpperCase() == 'GET') {
        _setCachedResponse(
          cacheKey,
          result.data,
          cacheTimeout ?? const Duration(minutes: 5),
        );
      }

      return result;
    } finally {
      _requestQueue.remove(cacheKey);
    }
  }

  // 실제 HTTP 요청 수행
  Future<http.Response> _makeRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required int retries,
    required bool requiresAuth,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      ...?headers,
    };

    if (requiresAuth && _token != null) {
      requestHeaders['Authorization'] = 'Bearer $_token';
    }

    http.Response? response;
    Duration delay = initialRetryDelay;

    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        switch (method.toUpperCase()) {
          case 'GET':
            response = await _client.get(uri, headers: requestHeaders)
                .timeout(requestTimeout);
            break;
          case 'POST':
            response = await _client.post(
              uri,
              headers: requestHeaders,
              body: body != null ? json.encode(body) : null,
            ).timeout(requestTimeout);
            break;
          case 'PUT':
            response = await _client.put(
              uri,
              headers: requestHeaders,
              body: body != null ? json.encode(body) : null,
            ).timeout(requestTimeout);
            break;
          case 'DELETE':
            response = await _client.delete(uri, headers: requestHeaders)
                .timeout(requestTimeout);
            break;
          default:
            throw ApiException('Unsupported HTTP method: $method', 400);
        }

        // 성공 응답 또는 재시도하지 않을 오류
        if (response.statusCode < 500 || attempt == retries) {
          return response;
        }

      } catch (e) {
        if (attempt == retries) {
          if (e is TimeoutException) {
            throw ApiException('Request timeout', 408);
          } else if (e is SocketException) {
            throw ApiException('Network error: ${e.message}', 0);
          } else {
            rethrow;
          }
        }
      }

      // 재시도 전 대기
      if (attempt < retries) {
        await Future.delayed(delay);
        delay *= 2; // 지수 백오프
      }
    }

    return response!;
  }

  // 응답 처리
  ApiResponse<T> _processResponse<T>(http.Response response, {required bool fromCache}) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        return ApiResponse<T>(
          success: true,
          data: data,
          statusCode: response.statusCode,
          fromCache: fromCache,
        );
      } else {
        final errorData = json.decode(response.body);
        return ApiResponse<T>(
          success: false,
          error: ApiError(
            code: response.statusCode,
            message: errorData['message'] ?? 'Unknown error',
            details: errorData,
          ),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        error: ApiError(
          code: response.statusCode,
          message: 'Response parsing failed: $e',
        ),
        statusCode: response.statusCode,
      );
    }
  }

  // 캐시 관리
  String _generateCacheKey(String endpoint, String method, Map<String, dynamic>? body) {
    final bodyStr = body != null ? json.encode(body) : '';
    return '$method:$endpoint:$bodyStr'.hashCode.toString();
  }

  CachedResponse? _getCachedResponse(String key) {
    final cached = _cache[key];
    if (cached == null) return null;

    if (DateTime.now().isAfter(cached.expiry)) {
      _cache.remove(key);
      _cacheTimers[key]?.cancel();
      _cacheTimers.remove(key);
      return null;
    }

    return cached;
  }

  void _setCachedResponse(String key, dynamic data, Duration timeout) {
    final expiry = DateTime.now().add(timeout);
    _cache[key] = CachedResponse(data: data, expiry: expiry);

    // 만료 타이머 설정
    _cacheTimers[key]?.cancel();
    _cacheTimers[key] = Timer(timeout, () {
      _cache.remove(key);
      _cacheTimers.remove(key);
    });
  }

  // 캐시 디스크 저장/로드
  Future<void> _loadCacheFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString('api_cache');
      if (cacheJson != null) {
        final cacheData = json.decode(cacheJson) as Map<String, dynamic>;

        for (final entry in cacheData.entries) {
          final itemData = entry.value as Map<String, dynamic>;
          final expiry = DateTime.parse(itemData['expiry']);

          if (DateTime.now().isBefore(expiry)) {
            _cache[entry.key] = CachedResponse(
              data: itemData['data'],
              expiry: expiry,
            );
          }
        }
      }
    } catch (e) {
      print('캐시 로드 오류: $e');
    }
  }

  Future<void> _saveCacheToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = <String, dynamic>{};

      for (final entry in _cache.entries) {
        cacheData[entry.key] = {
          'data': entry.value.data,
          'expiry': entry.value.expiry.toIso8601String(),
        };
      }

      await prefs.setString('api_cache', json.encode(cacheData));
    } catch (e) {
      print('캐시 저장 오류: $e');
    }
  }

  // 특화된 API 메서드들
  Future<ApiResponse<List<Map<String, dynamic>>>> getSalesSummary({
    required String fromDate,
    required String toDate,
    String period = 'daily',
    bool useCache = true,
  }) async {
    return request<List<Map<String, dynamic>>>(
      endpoint: '/api/v1/sales/summary',
      method: 'GET',
      body: {
        'startDate': fromDate,
        'endDate': toDate,
        'period': period,
      },
      useCache: useCache,
      cacheTimeout: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getHospitalAnalysis({
    required String fromDate,
    required String toDate,
    int topN = 10,
    String? regionFilter,
    bool useCache = true,
  }) async {
    final body = <String, dynamic>{
      'startDate': fromDate,
      'endDate': toDate,
      'topN': topN,
    };

    if (regionFilter != null) {
      body['regionFilter'] = regionFilter;
    }

    return request<List<Map<String, dynamic>>>(
      endpoint: '/api/v1/sales/hospital-analysis',
      method: 'GET',
      body: body,
      useCache: useCache,
      cacheTimeout: const Duration(minutes: 15),
    );
  }

  Future<ApiResponse<List<Map<String, dynamic>>>> getProductAnalysis({
    required String fromDate,
    required String toDate,
    int topN = 10,
    String? categoryFilter,
    bool useCache = true,
  }) async {
    final body = <String, dynamic>{
      'startDate': fromDate,
      'endDate': toDate,
      'topN': topN,
    };

    if (categoryFilter != null) {
      body['categoryFilter'] = categoryFilter;
    }

    return request<List<Map<String, dynamic>>>(
      endpoint: '/api/v1/sales/product-analysis',
      method: 'GET',
      body: body,
      useCache: useCache,
      cacheTimeout: const Duration(minutes: 15),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getRealTimeData({
    String? filter,
    bool useCache = false, // 실시간 데이터는 캐시 사용 안함
  }) async {
    return request<Map<String, dynamic>>(
      endpoint: '/api/v1/realtime/data',
      method: 'GET',
      body: filter != null ? {'filter': filter} : null,
      useCache: useCache,
    );
  }

  // 배치 요청 (여러 API를 한번에)
  Future<List<ApiResponse>> batchRequest(List<BatchRequest> requests) async {
    final futures = requests.map((req) => request<dynamic>(
      endpoint: req.endpoint,
      method: req.method,
      body: req.body,
      headers: req.headers,
      useCache: req.useCache,
      cacheTimeout: req.cacheTimeout,
    ));

    return await Future.wait(futures);
  }

  // 오프라인 지원
  Future<ApiResponse<T>> getWithOfflineSupport<T>({
    required String endpoint,
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    if (_isOnline) {
      try {
        final response = await request<T>(
          endpoint: endpoint,
          method: 'GET',
          body: body,
          useCache: true,
          cacheTimeout: const Duration(hours: 1),
        );

        if (response.success) {
          // 오프라인용 백업 데이터 저장
          await _saveOfflineData(endpoint, body, response.data);
        }

        return response;
      } catch (e) {
        // 온라인 요청 실패시 오프라인 데이터 사용
        return _getOfflineData<T>(endpoint, body, parser);
      }
    } else {
      // 오프라인 상태에서는 캐시된 데이터 사용
      return _getOfflineData<T>(endpoint, body, parser);
    }
  }

  Future<void> _saveOfflineData(String endpoint, Map<String, dynamic>? body, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'offline_${_generateCacheKey(endpoint, 'GET', body)}';
      await prefs.setString(key, json.encode({
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      print('오프라인 데이터 저장 오류: $e');
    }
  }

  Future<ApiResponse<T>> _getOfflineData<T>(
    String endpoint,
    Map<String, dynamic>? body,
    T Function(Map<String, dynamic>) parser,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'offline_${_generateCacheKey(endpoint, 'GET', body)}';
      final dataJson = prefs.getString(key);

      if (dataJson != null) {
        final data = json.decode(dataJson);
        return ApiResponse<T>(
          success: true,
          data: parser(data['data']),
          fromCache: true,
          isOffline: true,
        );
      }
    } catch (e) {
      print('오프라인 데이터 로드 오류: $e');
    }

    return ApiResponse<T>(
      success: false,
      error: ApiError(
        code: 0,
        message: '오프라인 데이터를 사용할 수 없습니다.',
      ),
      isOffline: true,
    );
  }

  // 캐시 관리 메서드들
  void clearCache() {
    _cache.clear();
    for (final timer in _cacheTimers.values) {
      timer.cancel();
    }
    _cacheTimers.clear();
  }

  void clearCacheByPattern(String pattern) {
    final keysToRemove = _cache.keys.where((key) => key.contains(pattern)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTimers[key]?.cancel();
      _cacheTimers.remove(key);
    }
  }

  int get cacheSize => _cache.length;

  // 성능 메트릭
  final Map<String, PerformanceMetric> _metrics = {};

  PerformanceMetric? getMetric(String endpoint) {
    return _metrics[endpoint];
  }

  Map<String, PerformanceMetric> getAllMetrics() {
    return Map.unmodifiable(_metrics);
  }

  void _recordMetric(String endpoint, Duration duration, bool success) {
    final existing = _metrics[endpoint];
    if (existing == null) {
      _metrics[endpoint] = PerformanceMetric(
        endpoint: endpoint,
        totalRequests: 1,
        successfulRequests: success ? 1 : 0,
        averageResponseTime: duration.inMilliseconds,
        lastRequestTime: DateTime.now(),
      );
    } else {
      final newTotal = existing.totalRequests + 1;
      final newSuccess = existing.successfulRequests + (success ? 1 : 0);
      final newAverage = ((existing.averageResponseTime * existing.totalRequests) +
          duration.inMilliseconds) / newTotal;

      _metrics[endpoint] = PerformanceMetric(
        endpoint: endpoint,
        totalRequests: newTotal,
        successfulRequests: newSuccess,
        averageResponseTime: newAverage.round(),
        lastRequestTime: DateTime.now(),
      );
    }
  }

  @override
  void dispose() {
    _client.close();
    _heartbeatTimer?.cancel();
    _connectionController.close();
    _saveCacheToDisk();

    for (final timer in _cacheTimers.values) {
      timer.cancel();
    }
  }
}

// 응답 모델
class ApiResponse<T> {
  final bool success;
  final T? data;
  final ApiError? error;
  final int? statusCode;
  final bool fromCache;
  final bool isOffline;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
    this.fromCache = false,
    this.isOffline = false,
  });
}

// 에러 모델
class ApiError {
  final int code;
  final String message;
  final Map<String, dynamic>? details;

  const ApiError({
    required this.code,
    required this.message,
    this.details,
  });
}

// 예외 클래스
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (Code: $statusCode)';
}

// 캐시 응답 모델
class CachedResponse {
  final dynamic data;
  final DateTime expiry;

  const CachedResponse({
    required this.data,
    required this.expiry,
  });
}

// 연결 상태
enum ConnectionStatus {
  online,
  offline,
  reconnecting,
}

// 배치 요청 모델
class BatchRequest {
  final String endpoint;
  final String method;
  final Map<String, dynamic>? body;
  final Map<String, String>? headers;
  final bool useCache;
  final Duration? cacheTimeout;

  const BatchRequest({
    required this.endpoint,
    this.method = 'GET',
    this.body,
    this.headers,
    this.useCache = true,
    this.cacheTimeout,
  });
}

// 성능 메트릭
class PerformanceMetric {
  final String endpoint;
  final int totalRequests;
  final int successfulRequests;
  final int averageResponseTime;
  final DateTime lastRequestTime;

  const PerformanceMetric({
    required this.endpoint,
    required this.totalRequests,
    required this.successfulRequests,
    required this.averageResponseTime,
    required this.lastRequestTime,
  });

  double get successRate => totalRequests > 0 ? (successfulRequests / totalRequests) * 100 : 0;
}