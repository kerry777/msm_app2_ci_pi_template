import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/item_return.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static String? _token;
  static String get baseUrl => AppConfig.serverUrl;

  // 초기화: 저장된 토큰 로드
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  // 토큰 설정
  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // 토큰 삭제
  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // 토큰 가져오기
  static Future<String?> getToken() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
    }
    return _token;
  }

  static Future<bool> validateToken(String token) async {
    // 실제 토큰 검증 로직을 구현하거나, 임시로 항상 true 반환
    // 예시:
    return token.isNotEmpty;
  }

  // 공통 API 호출 메서드 (단일 Map 데이터용)
  static Future<dynamic> _request(
    String method,
    String endpoint,
    dynamic body,
    Map<String, String>? queryParams,
    {bool isFormData = false, int maxRetries = 2}
  ) async {
    int retryCount = 0;
    
    while (retryCount <= maxRetries) {
    try {
      debugPrint('=== API 요청 시작 ===');
      debugPrint('메서드: $method');
      debugPrint('엔드포인트: $endpoint');
      debugPrint('요청 본문: $body');
      debugPrint('쿼리 파라미터: $queryParams');
      
      final token = await _getToken();
      debugPrint('토큰: ${token != null ? "존재 (길이: ${token.length})" : "없음"}');
      
      final url = Uri.parse(AppConfig.getApiEndpoint(endpoint)).replace(
        queryParameters: queryParams,
      );
      debugPrint('최종 URL: $url');

      final headers = {
        'Content-Type': isFormData ? 'multipart/form-data' : 'application/json',
        if (token != null && !endpoint.contains('/auth/')) 'Authorization': 'Bearer $token',
      };

      http.Response response;
      final client = http.Client();
      
      try {
        switch (method.toUpperCase()) {
          case 'GET':
            debugPrint('GET 요청 전송...');
            response = await client.get(url, headers: headers).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timeout after 30 seconds');
              },
            );
            break;
          case 'POST':
            debugPrint('POST 요청 전송...');
            final requestBody = body != null ? jsonEncode(body) : null;
            debugPrint('POST 요청 본문: $requestBody');
            response = await client.post(url, headers: headers, body: requestBody).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timeout after 30 seconds');
              },
            );
            break;
          case 'PUT':
            response = await client.put(url, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timeout after 30 seconds');
              },
            );
            break;
          case 'DELETE':
            response = await client.delete(url, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timeout after 30 seconds');
              },
            );
            break;
          default:
            throw Exception('Unsupported HTTP method: $method');
        }
      } finally {
        client.close();
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return null;
        }
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if ((e.toString().contains('timeout') || 
             e.toString().contains('SocketException') ||
             e.toString().contains('Connection refused')) && 
            retryCount < maxRetries) {
          retryCount++;
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        }
        
      rethrow;
    }
    }
    
    throw Exception('Max retries exceeded');
  }

  static Future<String?> _getToken() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
    }
    return _token;
  }

  static Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) {
    return _request(
      'GET',
      endpoint,
      null,
      queryParams,
    );
  }

  // 대리점 셀(창고) 목록 조회
  Future<List<Map<String, dynamic>>> getAgencyCells({required String trCd}) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/agency-cells',
        null,
        {'trCd': trCd},
      );
      // dynamic을 List<Map<String, dynamic>>으로 안전하게 변환
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error getting agency cells: $e');
      return [];
    }
  }

  // 대리점 기초재고 조회
  Future<List<Map<String, dynamic>>> getAgencyBaseStocks({
    required String trCd,
    required String year,
    required String month,
    required String cellId,
  }) async {
    try {
      print('===== 기초재고 조회 API 호출 시작 =====');
      print('요청 파라미터: trCd=$trCd, year=$year, month=$month, cellId=$cellId');
      
      final response = await _request(
        'GET',
        '/api/v1/base-stock',
        null,
        {
          'trCd': trCd,
          'year': year,
          'month': month,
          'cellId': cellId,
        },
      );
      
      if (response['data'] != null) {
        final List<dynamic> data = response['data'];
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e, stackTrace) {
      print('===== 기초재고 조회 API 호출 실패 =====');
      print('에러 메시지: $e');
      print('스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  // 대리점 기초재고 저장
  Future<Map<String, dynamic>> saveAgencyBaseStocks({
    required List<Map<String, dynamic>> baseStocks,
  }) async {
    try {
      print('기초재고 저장 API 호출');
      final response = await _request(
        'POST',
        '/api/v1/base-stock',
        baseStocks, // 배열 자체를 body로 전송
        null,
      );
      return response;
    } catch (e) {
      print('기초재고 저장 API 호출 실패: $e');
      rethrow;
    }
  }

  // 소모품 목록 조회
  Future<List<Map<String, dynamic>>> getConsumables() async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/consumables',
        null,
        null,
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      print('Error getting consumables: $e');
      return [];
    }
  }

  // 소모품 검색
  Future<List<Map<String, dynamic>>> searchConsumableItems(String keyword) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/items/consumable/search',
        null,
        {'keyword': keyword},
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      print('Error searching consumable items: $e');
      return [];
    }
  }

  // 기초재고 엑셀 다운로드
  Future<void> downloadBaseStockExcel({
    required String trCd,
    required String year,
    required String month,
    required String cellId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/base-stock/excel').replace(
          queryParameters: {
            'trCd': trCd,
            'year': year,
            'month': month,
            'cellId': cellId,
          },
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('엑셀 다운로드 실패: [38;5;9m${response.statusCode}[0m');
      }

      final contentDisposition = response.headers['content-disposition'];
      String fileName = 'base_stock.xlsx';
      if (contentDisposition != null) {
        final regExp = RegExp(r'filename="?([^";]+)"?');
        final match = regExp.firstMatch(contentDisposition);
        if (match != null) {
          fileName = match.group(1) ?? fileName;
        }
      }

      // 모바일/데스크탑: 파일 시스템을 사용하여 다운로드
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: fileName);
    } catch (e) {
      print('엑셀 다운로드 실패: $e');
      rethrow;
    }
  }

  // 사용자 접근 타입 조회
  Future<String?> getUserAccessType() async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/user/access-type',
        null,
        null,
      );
      return response['MEK_ACCESS_TYPE'];
    } catch (e) {
      print('Error getting user access type: $e');
      return null;
    }
  }

  // 로그인
  Future<Map<String, dynamic>> login(String empCd, String password) async {
    try {
      debugPrint('=== Login API 호출 시작 ===');
      debugPrint('서버 URL: ${AppConfig.serverUrl}');
      debugPrint('API 엔드포인트: ${AppConfig.getApiEndpoint("/api/v1/auth/login")}');
      debugPrint('로그인 정보: empCd=$empCd, password=${password.isNotEmpty ? "***" : "empty"}');
      
      final requestData = {'empCd': empCd, 'password': password};
      debugPrint('요청 데이터: $requestData');
      
      final response = await _request(
        'POST',
        '/api/v1/auth/login',
        requestData,
        null,
      );
      
      debugPrint('=== Login API 응답 ===');
      debugPrint('응답 타입: ${response.runtimeType}');
      debugPrint('응답 전체: $response');
      if (response is Map) {
        debugPrint('응답 키들: ${response.keys.toList()}');
        if (response.containsKey('userInfo')) {
          debugPrint('userInfo 내용: ${response['userInfo']}');
        }
        if (response.containsKey('accessToken')) {
          debugPrint('accessToken 존재: ${response['accessToken'] != null}');
        }
        if (response.containsKey('token')) {
          debugPrint('token 존재: ${response['token'] != null}');
        }
      }
      
      return response;
    } catch (e) {
      debugPrint('=== Login API 오류 ===');
      debugPrint('오류 타입: ${e.runtimeType}');
      debugPrint('오류 메시지: $e');
      print('Login error: $e');
      rethrow;
    }
  }

  // 출고 목록 조회
  Future<List<dynamic>> getItemReleases() async {
    final response = await _request('GET', '/item-releases', null, null);
    return response['data'] ?? [];
  }

  // 출고 수정
  Future<Map<String, dynamic>> updateItemRelease(Map<String, dynamic> item) async {
    return await _request('PUT', '/item-releases/${item['id']}', item, null);
  }

  // 출고 삭제
  Future<void> deleteItemRelease(dynamic id) async {
    await _request('DELETE', '/item-releases/$id', null, null);
  }

  // 반품 목록 조회
  Future<List<dynamic>> getItemReturns() async {
    final response = await _request('GET', '/item-returns', null, null);
    return response['data'] ?? [];
  }

  // 반품 생성
  Future<Map<String, dynamic>> createItemReturn(dynamic item) async {
    return await _request('POST', '/item-returns', item, null);
  }

  // 반품 수정
  Future<Map<String, dynamic>> updateItemReturn(Map<String, dynamic> item) async {
    return await _request('PUT', '/item-returns/${item['id']}', item, null);
  }

  // 반품 삭제
  Future<void> deleteItemReturn(dynamic id) async {
    await _request('DELETE', '/item-returns/$id', null, null);
  }

  // 대리점 안전재고 조회 (hospital-safe-stock API 사용)
  Future<List<Map<String, dynamic>>> getAgencySafeStocks({
    required String trCd,
    required String cellId,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/items',
        null,
        {
          'trCd': trCd,
          'cellId': cellId,
          'type': 'agency-safe-stock', // 명확하게 지정
        },
      );
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error getting agency safe stocks: $e');
      return [];
    }
  }

  // 대리점 안전재고 저장
  Future<void> saveAgencySafetyStocks({
    required List<Map<String, dynamic>> safeStocks,
  }) async {
    try {
      await _request(
        'POST',
        '/api/v1/safe-stock',
        safeStocks,
        null,
      );
    } catch (e) {
      print('Error saving agency safe stocks: $e');
      rethrow;
    }
  }

  // 대리점 품목별 재고 조회
  Future<List<Map<String, dynamic>>> getAgencyStockByItem({
    required String trCd,
    required String cellId,
    required String itemCd,
  }) async {
    try {
      // 품목 반출 목록 조회
      final exports = await _request(
        'GET',
        '/api/v1/item-export/list',
        null,
        {'trCd': trCd, 'cellId': cellId, 'itemCd': itemCd},
      );

      // 품목 반납 목록 조회
      final returns = await _request(
        'GET',
        '/api/v1/item-return/list',
        null,
        {'trCd': trCd, 'cellId': cellId, 'itemCd': itemCd},
      );

      if (exports != null && exports['data'] is List && returns != null && returns['data'] is List) {
        final exportsData = List<Map<String, dynamic>>.from(exports['data']);
        final returnsData = List<Map<String, dynamic>>.from(returns['data']);

        final stockMap = <String, Map<String, dynamic>>{};

        // 반출 데이터 처리
        for (final export in exportsData) {
          final itemCd = export['ITEM_CODE'] ?? export['ITEM_CD'];
          final itemName = export['ITEM_NAME'];
          final qty = export['IO_QT'] ?? export['EXPORT_QTY'] ?? 0;
          
          stockMap[itemCd] = {
            'ITEM_CD': itemCd,
            'ITEM_NAME': itemName,
            'FROM_AGENCY_QTY': qty,
            'TO_AGENCY_QTY': 0,
            'CURRENT_STOCK_QTY': qty,
          };
        }

        // 반납 데이터 처리
        for (final returnItem in returnsData) {
          final itemCd = returnItem['ITEM_CODE'] ?? returnItem['ITEM_CD'];
          final itemName = returnItem['ITEM_NAME'];
          final qty = returnItem['IO_QT'] ?? returnItem['RETURN_QTY'] ?? 0;
          
          final map = stockMap[itemCd];
          if (map != null) {
            map['TO_AGENCY_QTY'] = qty;
            map['CURRENT_STOCK_QTY'] = (map['CURRENT_STOCK_QTY'] ?? 0) - qty;
          } else {
            // 반납만 있고 반출이 없는 경우 (이상 케이스)
            stockMap[itemCd] = {
              'ITEM_CD': itemCd,
              'ITEM_NAME': itemName,
              'FROM_AGENCY_QTY': 0,
              'TO_AGENCY_QTY': qty,
              'CURRENT_STOCK_QTY': -qty, // 음수 재고
            };
          }
        }

        return stockMap.values.toList();
      }
      return [];
    } catch (e) {
      print('대리점 품목별 재고 조회 실패: $e');
      throw Exception('Failed to load agency stock by item: $e');
    }
  }

  // 대리점 납품용 품목 반출 목록 조회
  Future<List<Map<String, dynamic>>> getAgencyDeliveryItemExports({
    required String trCd,
    String? cellId,
    String? exportDate,
    String? empCd,
  }) async {
    try {
      final queryParams = {
        'trCd': trCd,
        if (cellId != null) 'cellId': cellId,
        if (exportDate != null) 'exportDate': exportDate,
        if (empCd != null) 'empCd': empCd,
      };
      final response = await _request(
        'GET',
        '/api/v1/agency/delivery-item-export/list',
        null,
        queryParams,
      );
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('납품용품목반출 목록 조회 실패: $e');
      throw Exception('Failed to load agency delivery item exports: $e');
    }
  }

  // 대리점 납품용 품목 반납 목록 조회
  Future<List<Map<String, dynamic>>> getAgencyDeliveryItemReturns({
    required String trCd,
    String? cellId,
    String? returnDate,
    String? empCd,
  }) async {
    try {
      final queryParams = {
        'trCd': trCd,
        if (cellId != null) 'cellId': cellId,
        if (returnDate != null) 'returnDate': returnDate,
        if (empCd != null) 'empCd': empCd,
      };
      final response = await _request(
        'GET',
        '/api/v1/agency/delivery-item-return/list',
        null,
        queryParams,
      );
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('납품용품목반납 목록 조회 실패: $e');
      throw Exception('Failed to load agency delivery item returns: $e');
    }
  }

  // 대리점 안전재고 엑셀 다운로드
  Future<void> downloadAgencySafeStockExcel({
    required String trCd,
    required String cellId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/safe-stock/excel').replace(
          queryParameters: {
          'trCd': trCd,
          'cellId': cellId,
          },
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('엑셀 다운로드 실패: ${response.statusCode}');
    }

      final contentDisposition = response.headers['content-disposition'];
      String fileName = 'agency_safe_stock.xlsx';
      if (contentDisposition != null) {
        final regExp = RegExp(r'filename="?([^";]+)"?');
        final match = regExp.firstMatch(contentDisposition);
        if (match != null) {
          fileName = match.group(1) ?? fileName;
        }
      }

      // 모바일에서는 파일 시스템을 사용하여 다운로드
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: fileName);
    } catch (e) {
      print('엑셀 다운로드 실패: $e');
      rethrow;
    }
  }

  // 대리점 재고현황 엑셀 다운로드
  Future<void> downloadAgencyStockStatusExcel({
    required String trCd,
    required String cellId,
    required String itemCd,
    required String baseDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stock-status/excel').replace(
          queryParameters: {
            'trCd': trCd,
            'cellId': cellId,
            'itemCd': itemCd,
            'baseDate': baseDate,
          },
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('엑셀 다운로드 실패: ${response.statusCode}');
      }

      final contentDisposition = response.headers['content-disposition'];
      String fileName = 'agency_stock_status.xlsx';
      if (contentDisposition != null) {
        final regExp = RegExp(r'filename="?([^";]+)"?');
        final match = regExp.firstMatch(contentDisposition);
        if (match != null) {
          fileName = Uri.decodeComponent(match.group(1)!) ?? fileName;
        }
      }

      // 모바일에서는 파일 시스템을 사용하여 다운로드
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: fileName);
    } catch (e) {
      print('엑셀 다운로드 실패: $e');
      rethrow;
    }
  }

  // 품목 입고 목록 조회
  Future<List<Map<String, dynamic>>> getItemIOList({
    required String trCd,
    required String cellId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/item-io/list',
        null,
        {
          'trCd': trCd,
          'cellId': cellId,
          'startDate': _formatDate(startDate),
          'endDate': _formatDate(endDate),
        },
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      print('Error getting item IO list: $e');
      return [];
    }
  }

  // 품목 입고 등록
  Future<void> saveItemIO({
    required List<Map<String, dynamic>> ioData,
  }) async {
    try {
      await _request(
        'POST',
        '/api/v1/item-io',
        ioData,
        null,
      );
    } catch (e) {
      print('Error saving item IO: $e');
      rethrow;
    }
  }

  // 품목 입고 수정
  Future<void> updateItemIO({
    required String ioId,
    required int ioQt,
    String? remark,
  }) async {
    try {
      await _request(
        'PUT',
        '/api/v1/item-io/$ioId',
        {
          'ioQt': ioQt,
          'remark': remark,
        },
        null,
      );
    } catch (e) {
      print('Error updating item IO: $e');
      rethrow;
    }
  }

  static Future<void> downloadItemIOExcel({
    required String trCd,
    required String? cellId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/item-io/excel').replace(
          queryParameters: {
            'trCd': trCd,
            'cellId': cellId ?? '',
            'startDate': DateFormat('yyyy-MM-dd').format(startDate),
            'endDate': DateFormat('yyyy-MM-dd').format(endDate),
          },
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('엑셀 다운로드 실패: ${response.statusCode}');
      }

      final contentDisposition = response.headers['content-disposition'];
      String fileName = 'item_io.xlsx';
      if (contentDisposition != null) {
        final regExp = RegExp(r'filename="?([^";]+)"?');
        final match = regExp.firstMatch(contentDisposition);
        if (match != null) {
          fileName = match.group(1) ?? fileName;
        }
      }

      // 모바일에서는 파일 시스템을 사용하여 다운로드
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: fileName);
    } catch (e) {
      print('엑셀 다운로드 실패: $e');
      rethrow;
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getConsumableItems() async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/consumables',
        null,
        null,
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      print('Error getting consumable items: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getItems({
    required String trCd,
    String? type,
    String? hospitalId,
    String? cellId,
  }) async {
    try {
      final queryParams = <String, String>{
        'trCd': trCd,
      };
      if (type != null) {
        queryParams['type'] = type;
      }
      if (hospitalId != null) {
        queryParams['hospitalId'] = hospitalId;
      }
      if (cellId != null) {
        queryParams['cellId'] = cellId;
      }

      final response = await _request(
        'GET',
        '/api/v1/items',
        null,
        queryParams,
      );

      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error getting items: $e');
      rethrow;
    }
  }

  // 품목반납 엑셀 다운로드
  static Future<void> downloadItemReturnExcel({
    required String trCd,
    required String cellId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/item-return/excel',
        null,
        {
          'trCd': trCd,
          'cellId': cellId,
          'startDate': DateFormat('yyyy-MM-dd').format(startDate),
          'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        },
      );

      if (response['data'] != null) {
        final base64Data = response['data'];
        final bytes = base64Decode(base64Data);
        
        // 모바일 환경
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/품목반납_${DateFormat('yyyyMMdd').format(startDate)}.xlsx');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (e) {
      print('엑셀 다운로드 실패: $e');
      rethrow;
    }
  }

  // 품목반납 내역 조회
  Future<List<Map<String, dynamic>>> getItemReturnHistory({
    required String trCd,
    required String cellId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('===== 반납내역 조회 API 호출 시작 =====');
      print('요청 파라미터: trCd=$trCd, cellId=$cellId, startDate=$startDate, endDate=$endDate');
      
      final response = await _request(
        'GET',
        '/api/v1/item-return/history',
        null,
        {
          'trCd': trCd,
          'cellId': cellId,
          'startDate': DateFormat('yyyy-MM-dd').format(startDate),
          'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        },
      );
      
      print('API 응답 전체: $response');
      
      if (response['data'] != null) {
        final List<dynamic> data = response['data'];
        return data.map((item) {
          final Map<String, dynamic> convertedItem = Map<String, dynamic>.from(item);
          
          // null 값 안전 처리
          if (convertedItem['TOTAL_ORDER_QTY'] == null) {
            convertedItem['totalOrderQty'] = null;
          } else {
            convertedItem['totalOrderQty'] = convertedItem['TOTAL_ORDER_QTY'];
          }
          
          if (convertedItem['TOTAL_ORDER_AMOUNT'] == null) {
            convertedItem['totalOrderAmount'] = null;
          } else {
            convertedItem['totalOrderAmount'] = convertedItem['TOTAL_ORDER_AMOUNT'];
          }
          
          // 다른 필드들도 안전하게 변환
          convertedItem['closeDate'] = convertedItem['close_date']?.toString() ?? convertedItem['CLOSE_DATE']?.toString() ?? '';
          convertedItem['status'] = convertedItem['status']?.toString() ?? convertedItem['STATUS']?.toString() ?? '';
          convertedItem['totalItems'] = convertedItem['total_items'] ?? convertedItem['TOTAL_ITEMS'] ?? 0;
          convertedItem['shortageItems'] = convertedItem['shortage_items'] ?? convertedItem['SHORTAGE_ITEMS'] ?? 0;
          convertedItem['createdBy'] = convertedItem['emp_cd']?.toString() ?? convertedItem['CREATED_BY']?.toString() ?? '';
          convertedItem['createdAt'] = convertedItem['created_at']?.toString() ?? convertedItem['CREATED_AT']?.toString() ?? '';
          convertedItem['completedAt'] = convertedItem['completed_at']?.toString() ?? convertedItem['COMPLETED_AT']?.toString();
          convertedItem['remark'] = convertedItem['remark']?.toString() ?? convertedItem['REMARK']?.toString() ?? '';
          convertedItem['orderId'] = convertedItem['order_id']?.toString() ?? convertedItem['ORDER_ID']?.toString() ?? '';
          convertedItem['orderStatus'] = convertedItem['order_status']?.toString() ?? convertedItem['ORDER_STATUS']?.toString() ?? '';
          convertedItem['deliveredAt'] = convertedItem['delivered_at']?.toString() ?? convertedItem['DELIVERED_AT']?.toString();
          
          return convertedItem;
        }).toList();
      }
      print('응답에 data 필드가 없음');
      return [];
    } catch (e, stackTrace) {
      print('===== 반납내역 조회 API 호출 실패 =====');
      print('에러 메시지: $e');
      print('스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getHospitalStock({
    required String stockSurveyId,
    required String hospitalId,
    required String cellId,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/stock',
        null,
        {
          'inventoryId': stockSurveyId,
          'hospitalId': hospitalId,
          'cellId': cellId,
        },
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      print('재고 조회 실패: $e');
      rethrow;
    }
  }

  Future<void> updateHospitalStock({
    required List<Map<String, dynamic>> stockData,
  }) async {
    try {
      await _request(
        'PUT',
        '/api/stock/update',
        stockData,
        null,
      );
    } catch (e) {
      print('재고 업데이트 실패: $e');
      rethrow;
    }
  }

  Future<void> deleteHospitalStock({
    required String checkDt,
    required int checkDtSeq,
    required String hospitalId,
    required String cellId,
    required String itemCd,
  }) async {
    try {
      await _request(
        'DELETE',
        '/api/stock/delete',
        {
          'checkDt': checkDt,
          'checkDtSeq': checkDtSeq,
          'hospitalId': hospitalId,
          'cellId': cellId,
          'itemCd': itemCd,
        },
        null,
      );
    } catch (e) {
      print('재고 삭제 실패: $e');
      rethrow;
    }
  }

  // ===== 새로운 병원재고조사 API (v2) =====
  
  /// 병원재고조사 현황 대시보드 조회
  Future<List<Map<String, dynamic>>> getHospitalStockSurveyDashboard({
    required String trCd,
  }) async {
    try {
      print('=== getHospitalStockSurveyDashboard 호출 ===');
      print('요청 파라미터: trCd=$trCd');
      
      // 서버의 라우터 설정에 맞게 수정 (/api/v1/stock-survey/dashboard)
      final url = Uri.parse('${AppConfig.serverUrl}/api/v1/stock-survey/dashboard').replace(
        queryParameters: {'trCd': trCd},
      );
      
      final token = await _getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      
      print('=== API Request Details ===');
      print('Method: GET');
      print('URL: $url');
      print('Token: ${token != null ? "Present" : "Missing"}');
      print('Headers: $headers');
      
      final response = await http.get(url, headers: headers);
      
      print('=== API Response Details ===');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        print('API 응답: $data');
        
        if (data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        return [];
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('재고조사 현황 조회 실패: $e');
      rethrow;
    }
  }

  /// 병원재고조사 마스터 조회
  Future<List<Map<String, dynamic>>> getHospitalStockSurveyMasters({
    required String trCd,
    String? hospitalId,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'trCd': trCd,
        if (hospitalId != null && hospitalId.isNotEmpty) 'hospitalId': hospitalId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      };
      
      print('=== getHospitalStockSurveyMasters 쿼리 파라미터 ===');
      print('queryParams: $queryParams');
      
      // 서버 라우터에 맞게 수정 (/api/v1/stock-survey/masters)
      final response = await _request(
        'GET',
        '/api/v1/stock-survey/masters',
        null,
        queryParams,
      );
      
      if (response['data'] != null) {
        final rawData = List<Map<String, dynamic>>.from(response['data']);
        
        // 서버 응답에서 누락된 필드에 기본값 설정
        return rawData.map((item) {
          return {
            ...item,
            'SURVEY_CYCLE': item['SURVEY_CYCLE'] ?? '정기', // 기본값 설정
          };
        }).toList();
      }
      return [];
    } catch (e) {
      print('재고조사 마스터 조회 실패: $e');
      rethrow;
    }
  }

  /// 병원재고조사 상세 조회
  /// 재고조사 수정용: stockSurveyId에 단일 ID만 전달
  /// 통계/분석용: stockSurveyId에 콤마구분 다수 ID 또는 null(전체) 전달
  Future<List<Map<String, dynamic>>> getHospitalStockSurveyDetails({
    String? stockSurveyId, // 단일값: 특정서베이, 콤마구분: 다수서베이, null: 전체
    required String hospitalId,
    required String cellId,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'hospitalId': hospitalId,
        'cellId': cellId,
      };
      
      // stockSurveyId 처리
      if (stockSurveyId != null && stockSurveyId.isNotEmpty) {
        // 콤마가 포함되어 있으면 다수 서베이, 아니면 단일 서베이
        if (stockSurveyId.contains(',')) {
          // 다수 서베이 ID를 콤마로 구분하여 전달 (통계/분석용)
          queryParams['stockSurveyIds'] = stockSurveyId;
        } else {
          // 단일 서베이 ID (재고조사 수정용)
          queryParams['stockSurveyId'] = stockSurveyId;
        }
      }
      // stockSurveyId가 null이면 모든 서베이 조회 (통계/분석용)
      
      print('=== getHospitalStockSurveyDetails 쿼리 파라미터 ===');
      print('queryParams: $queryParams');
      
      // 서버 라우터에 맞게 수정 (/api/v1/stock-survey/details)
      final response = await _request(
        'GET',
        '/api/v1/stock-survey/details',
        null,
        queryParams,
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      print('재고조사 상세 조회 실패: $e');
      rethrow;
    }
  }

  static Future<dynamic> _requestForList(
      String method, String endpoint, dynamic body,
      [Map<String, String>? queryParams]) async {
    final token = await _getToken();
    final url = Uri.parse(AppConfig.getApiEndpoint(endpoint))
        .replace(queryParameters: queryParams);
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final client = http.Client();
    try {
      final response = await client
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception(
            'API Error: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> saveHospitalStockSurveyDetails({
    required List<Map<String, dynamic>> detailData,
  }) async {
    try {
      // 서버 라우터에 맞게 수정 (/api/v1/stock-survey/details)
      final responseBody = await _request(
        'POST',
        '/api/v1/stock-survey/details',
        detailData,
        null,
      );
      if (responseBody is List && responseBody.isNotEmpty) {
        return Map<String, dynamic>.from(responseBody.first);
      } else if (responseBody is Map) {
        return Map<String, dynamic>.from(responseBody);
      } else {
        return {'status': 'success', 'message': '상세 데이터가 성공적으로 처리되었습니다.'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// 병원재고조사 마스터 저장
  Future<Map<String, dynamic>> saveHospitalStockSurveyMaster({
    required Map<String, dynamic> masterData,
  }) async {
    try {
      // 서버 라우터에 맞게 수정 (/api/v1/stock-survey/masters)
      final response = await _request(
        'POST',
        '/api/v1/stock-survey/masters',
        masterData,
        null,
      );
      return response;
    } catch (e) {
      print('재고조사 마스터 저장 실패: $e');
      rethrow;
    }
  }

  /// 병원재고조사 마스터 논리적 삭제/복구
  Future<void> toggleHospitalStockSurveyMaster({
    required String stockSurveyId,
    required bool isDeleted, // true: 삭제, false: 복구
  }) async {
    try {
      // 서버 라우터에 맞게 수정 (/api/v1/stock-survey/masters/toggle)
      await _request(
        'PUT',
        '/api/v1/stock-survey/masters/toggle',
        {
          'stockSurveyId': stockSurveyId,
          'isDeleted': isDeleted,
        },
        null,
      );
    } catch (e) {
      print('재고조사 마스터 삭제/복구 실패: $e');
      rethrow;
    }
  }

  /// 병원재고조사 엑셀 다운로드
  Future<String> downloadHospitalStockSurveyExcel({
    required String trCd,
    String? hospitalId,
    String? cellId,
    String? startDate,
    String? endDate,
    String? surveyPurpose,
  }) async {
    try {
      final Map<String, String> params = {'trCd': trCd};
      if (hospitalId != null) params['hospitalId'] = hospitalId;
      if (cellId != null) params['cellId'] = cellId;
      if (startDate != null) params['startDate'] = startDate;
      if (endDate != null) params['endDate'] = endDate;
      if (surveyPurpose != null) params['surveyPurpose'] = surveyPurpose;
      
      // 서버 라우터에 맞게 수정 (/api/v1/stock-survey/excel-download)
      final response = await _request(
        'GET',
        '/api/v1/stock-survey/excel-download',
        null,
        params,
      );
      return response['downloadUrl'] ?? '';
    } catch (e) {
      print('재고조사 엑셀 다운로드 실패: $e');
      rethrow;
    }
  }

  // 제품납품 품목 목록 조회 (임시 더미 데이터)
  Future<List<Map<String, dynamic>>> getHospitalDeliveryItems({
    required String hospitalId,
    required String cellId,
    required String deliveryDate,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/hospital-delivery-items',
        null,
        {
          'hospitalId': hospitalId,
          'cellId': cellId,
          'deliveryDate': deliveryDate,
        },
      );
      
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('제품납품 품목 목록 조회 실패: $e');
      rethrow;
    }
  }

  // 제품납품 저장 (임시 성공 처리)
  Future<void> saveHospitalDeliveryItems({
    required List<Map<String, dynamic>> deliveryItems,
    required String userId,
  }) async {
    try {
      await _request(
        'POST',
        '/api/v1/hospital-delivery-items',
        {'deliveryItems': deliveryItems, 'userId': userId},
        null,
      );
    } catch (e) {
      print('제품납품 저장 실패: $e');
      rethrow;
    }
  }

  // 반출/반납 목록 조회
  Future<List<ItemReturn>> fetchItemReturns({
    required String warehouseCode,
    String? status,
    String? returnType,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = {
        'warehouseCode': warehouseCode,
        if (status != null) 'status': status,
        if (returnType != null) 'returnType': returnType,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };

      final response = await _request(
        'GET',
        '/api/v1/item-returns',
        null,
        queryParams,
      );

      final List<dynamic> data = response['data'];
      return data.map((item) => ItemReturn.fromJson(item)).toList();
    } catch (e) {
      print('Error getting item returns: $e');
      rethrow;
    }
  }

  // 반출/반납 신청
  Future<ItemReturn> submitItemReturn({
    required String itemCode,
    required String itemName,
    required int quantity,
    required String returnType,
    required String warehouseCode,
    String? reason,
  }) async {
    try {
      final body = {
        'itemCode': itemCode,
        'itemName': itemName,
        'quantity': quantity,
        'returnType': returnType,
        'warehouseCode': warehouseCode,
        if (reason != null) 'reason': reason,
      };

      final response = await _request(
        'POST',
        '/api/v1/item-returns',
        body,
        null,
      );

      return ItemReturn.fromJson(response['data']);
    } catch (e) {
      print('Error creating item return: $e');
      rethrow;
    }
  }

  // 반출/반납 승인/거절
  Future<ItemReturn> processItemReturnStatus({
    required int returnId,
    required String status,
    String? approverComment,
  }) async {
    try {
      final body = {
        'status': status,
        if (approverComment != null) 'approverComment': approverComment,
      };

      final response = await _request(
        'PUT',
        '/api/v1/item-returns/$returnId/status',
        body,
        null,
      );

      return ItemReturn.fromJson(response['data']);
    } catch (e) {
      print('Error updating item return status: $e');
      rethrow;
    }
  }

  // 반출/반납 상세 조회
  Future<ItemReturn> fetchItemReturnDetails(int returnId) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/item-returns/$returnId',
        null,
        null,
      );

      return ItemReturn.fromJson(response['data']);
    } catch (e) {
      print('Error getting item return details: $e');
      rethrow;
    }
  }

  // 품목반출 목록 조회
  Future<List<Map<String, dynamic>>> getItemExportList({
    required String trCd,
    required String cellId,
    required String exportDate,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/item-export/list',
        null,
        {
          'trCd': trCd,
          'cellId': cellId,
          'exportDate': exportDate,
        },
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      print('품목반출 목록 조회 실패: $e');
      rethrow;
    }
  }

  // 품목반출 저장
  Future<void> saveItemExportList({
    required List<Map<String, dynamic>> exports,
  }) async {
    try {
      await _request(
        'POST',
        '/api/v1/item-export/save',
        exports,
        null,
      );
    } catch (e) {
      print('품목반출 저장 실패: $e');
      rethrow;
    }
  }

  // 품목반납 목록 조회
  Future<List<Map<String, dynamic>>> getItemReturnList({
    required String trCd,
    required String cellId,
    required String returnDate,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/item-return/list',
        null,
        {
          'trCd': trCd,
          'cellId': cellId,
          'returnDate': returnDate,
        },
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      print('품목반납 목록 조회 실패: $e');
      rethrow;
    }
  }

  // 품목반납 저장
  Future<void> saveItemReturnList({
    required List<Map<String, dynamic>> returns,
  }) async {
    try {
      await _request(
        'POST',
        '/api/v1/item-return/save',
        returns,
        null,
      );
    } catch (e) {
      print('품목반납 저장 실패: $e');
      rethrow;
    }
  }

  // 대리점 직원 목록 조회
  Future<List<Map<String, dynamic>>> getAgencyEmployees({
    required String trCd,
  }) async {
    try {
      print('=== 대리점 직원 목록 조회 시작 ===');
      print('요청 엔드포인트: /api/v1/employees');
      print('trCd: $trCd');
      
      final response = await _request(
        'GET',
        '/api/v1/employees',
        null,
        {'trCd': trCd},
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      print('대리점 직원 목록 조회 실패: $e');
      rethrow;
    }
  }

  // 대리점 재고 조회
  Future<List<Map<String, dynamic>>> getAgencyStocks({required String trCd}) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/stocks/agent-stock-status',
        null,
        {'trCd': trCd},
      );
      if (response != null && response['data'] != null && response['data']['master'] is List) {
        return List<Map<String, dynamic>>.from(response['data']['master']);
      }
      return [];
    } catch (e) {
      print('Error getting agency stocks: $e');
      return [];
    }
  }

  // 병원 현재고 조회 (추가 필요)
  Future<List<Map<String, dynamic>>> getHospitalCurrentStocks({
    required String hospitalId,
    required String cellId,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/hospital-current-stock',
        null,
        {
          'hospitalId': hospitalId,
          'cellId': cellId,
        },
      );
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error getting hospital current stocks: $e');
      return [];
    }
  }

  // 병원 목록 조회
  Future<List<Map<String, dynamic>>> getHospitals({String? trCd, Set<String>? trCds}) async {
    try {
      print('=== getHospitals API 호출 시작 ===');
      print('TR_CD: $trCd');
      print('TR_CDs: $trCds');
      
      Map<String, String>? queryParams;
      if (trCds != null && trCds.isNotEmpty) {
        // 여러 대리점 코드를 콤마로 구분하여 전송
        queryParams = {'trCds': trCds.join(',')};
      } else if (trCd != null) {
        queryParams = {'trCd': trCd};
      }
      
      final response = await _request(
        'GET',
        '/api/v1/hospitals/simple',
        null,
        queryParams,
      );
      
      print('=== getHospitals API 응답 ===');
      print('Response: $response');
      print('Response type: ${response.runtimeType}');
      
      if (response != null && response['data'] is List) {
        final hospitals = List<Map<String, dynamic>>.from(response['data']);
        print('=== 병원 데이터 변환 완료 ===');
        print('병원 개수: ${hospitals.length}');
        for (int i = 0; i < hospitals.length; i++) {
          final hospital = hospitals[i];
          print('병원 $i: $hospital');
          print('  - hospitalId: ${hospital['hospitalId']}');
          print('  - name: ${hospital['name']}');
          print('  - 기타 키들: ${hospital.keys.toList()}');
        }
        return hospitals;
      } else {
        print('=== 병원 데이터 변환 실패 ===');
        print('Response가 null이거나 data가 List가 아님');
        print('Response: $response');
        return [];
      }
    } catch (e) {
      print('Error getting hospitals: $e');
      return [];
    }
  }

  // 병원 창고 조회
  Future<List<Map<String, dynamic>>> getHospitalCells({
    required String hospitalId,
    required String trCd,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/cells',
        null,
        {
          'hospitalId': hospitalId,
          'trCd': trCd,
        },
      );
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error getting hospital cells: $e');
      return [];
    }
  }

  // 전체 창고 목록 조회 (독립적인 창고 리스트)
  Future<List<Map<String, dynamic>>> getHospitalCellsAll({
    required String trCd,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/hospital_cells/all',
        null,
        {
          'trCd': trCd,
        },
      );
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error getting all hospital cells: $e');
      return [];
    }
  }

  // 병원 안전재고 조회
  Future<List<Map<String, dynamic>>> getHospitalSafeStocks({
    required String hospitalId,
    required String cellId,
    required String trCd,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/items',
        null,
        {
          'hospitalId': hospitalId,
          'cellId': cellId,
          'trCd': trCd,
          'type': 'hospital-safe-stock', // 명확하게 지정
        },
      );
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error getting hospital safe stocks: $e');
      return [];
    }
  }

  // 병원 안전재고 저장
  Future<void> saveHospitalSafeStocks({
    required List<Map<String, dynamic>> safeStocks,
  }) async {
    try {
      await _request(
        'POST',
        '/api/v1/hospital-safe-stock',
        safeStocks,
        null,
      );
    } catch (e) {
      print('Error saving hospital safe stocks: $e');
      rethrow;
    }
  }

  // 병원 안전재고 엑셀 다운로드
  Future<void> downloadHospitalSafeStockExcel(String hospitalId, String cellId) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/hospital-safe-stock/excel',
        null,
        {
          'hospitalId': hospitalId,
          'cellId': cellId,
        },
      );
      // 엑셀 다운로드 처리 로직
      print('Excel download response: $response');
    } catch (e) {
      print('Error downloading hospital safe stock excel: $e');
      rethrow;
    }
  }

  // 대리점 재고현황 조회
  Future<Map<String, dynamic>> getAgencyStockStatus({
    String? trCd,
    String? cellId,
    String? itemCd,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (trCd != null) queryParams['trCd'] = trCd;
      if (cellId != null) queryParams['cellId'] = cellId;
      if (itemCd != null) queryParams['itemCd'] = itemCd;

      final response = await _request(
        'GET',
        '/api/v1/agency-stock-status',
        null,
        queryParams,
      );
      
      if (response != null && response['data'] is Map) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {'master': [], 'detail': []};
    } catch (e) {
      print('Error getting agency stock status: $e');
      return {'master': [], 'detail': []};
    }
  }

  // 병원별 재고현황 조회 (독립적인 API)
  Future<Map<String, dynamic>> getHospitalStockStatus({
    required String trCd,
    required String hospitalId,
    required String cellId,
  }) async {
    try {
      final queryParams = {
        'trCd': trCd,
        'hospitalId': hospitalId,
        'cellId': cellId,
      };
      
      final response = await _request(
        'GET',
        '/api/v1/hospital-stock-status',
        null,
        queryParams,
      );

      if (response != null && response['data'] is Map) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {'master': [], 'detail': [], 'surveyInfo': null};
    } catch (e) {
      print('Error getting hospital stock status: $e');
      return {'master': [], 'detail': [], 'surveyInfo': null};
    }
  }

  // 병원별 재고현황 데이터 새로고침 (독립적인 API)
  Future<Map<String, dynamic>> refreshHospitalStockStatus({
    required String trCd,
    required String hospitalId,
    required String cellId,
  }) async {
    try {
      final body = {
        'trCd': trCd,
        'hospitalId': hospitalId,
        'cellId': cellId,
      };
      
      final response = await _request(
        'POST',
        '/api/v1/hospital-stock-status/refresh',
        body,
        null,
      );

      if (response != null && response['data'] is Map) {
        return Map<String, dynamic>.from(response['data']);
      }
      return {'master': [], 'detail': [], 'surveyInfo': null};
    } catch (e) {
      print('Error refreshing hospital stock status: $e');
      return {'master': [], 'detail': [], 'surveyInfo': null};
    }
  }

  // 담당자 재고 현황 조회 (내 재고)
  Future<Map<String, dynamic>> getAgentStockStatus({
    required String trCd,
    required String empCd,
    required String baseDate,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/agent-stock-status',
        null,
        {'trCd': trCd, 'empCd': empCd, 'baseDate': baseDate},
      );
      if (response != null && response['data'] != null) {
        final data = response['data'];
        return {
          'master': List<Map<String, dynamic>>.from(data['master'] ?? []),
          'detail': List<Map<String, dynamic>>.from(data['detail'] ?? []),
        };
      }
      return {'master': [], 'detail': []};
    } catch (e) {
      print('Error getting agent stock status: $e');
      rethrow;
    }
  }

  // 담당자 재고 엑셀 다운로드
  Future<void> downloadAgentStockStatusExcel({
    required String trCd,
    required String empCd,
    required String baseDate,
  }) async {
    await _downloadExcel(
      '/api/v1/agent-stock-status/excel',
      'agent_stock_status_$baseDate.xlsx',
      queryParameters: {'trCd': trCd, 'empCd': empCd, 'baseDate': baseDate},
    );
  }

  Future<void> _downloadExcel(String endpoint, String fileName, {Map<String, String>? queryParameters}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint').replace(
          queryParameters: queryParameters,
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('엑셀 다운로드 실패: ${response.statusCode}');
      }

      final contentDisposition = response.headers['content-disposition'];
      if (contentDisposition != null) {
        final regExp = RegExp(r'filename="?([^";]+)"?');
        final match = regExp.firstMatch(contentDisposition);
        if (match != null) {
          fileName = Uri.decodeComponent(match.group(1)!) ?? fileName;
        }
      }

      // 모바일에서는 파일 시스템을 사용하여 다운로드
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: fileName);
    } catch (e) {
      print('엑셀 다운로드 실패: $e');
      rethrow;
    }
  }

  // 대리점 전체 병원 안전재고 일괄 입력
  Future<void> saveAllHospitalSafeStocks({
    required String trCd,
    required int safeQt,
  }) async {
    try {
      await _request(
        'POST',
        '/api/v1/hospital-safe-stock/bulk-all',
        {
          'trCd': trCd,
          'safeQt': safeQt,
        },
        null,
      );
    } catch (e) {
      print('Error saving all hospital safe stocks: $e');
      rethrow;
    }
  }

  // 특정 병원 안전재고 일괄 입력
  Future<void> saveHospitalSafeStocksByHospital({
    required String trCd,
    required String hospitalId,
    required int safeQt,
  }) async {
    try {
      await _request(
        'POST',
        '/api/v1/hospital-safe-stock/bulk-hospital',
        {
          'trCd': trCd,
          'hospitalId': hospitalId,
          'safeQt': safeQt,
        },
        null,
      );
    } catch (e) {
      print('Error saving hospital safe stocks by hospital: $e');
      rethrow;
    }
  }

  // ===== 재고마감 관련 API =====

  /// 재고마감 실행
  Future<Map<String, dynamic>> executeStockClose({
    required String trCd,
    required String closeDate,
    required String empCd,
    String? closeDesc, // 추가
    String? remark,
    List<Map<String, dynamic>>? items, // 상세 데이터 추가
  }) async {
    try {
      print('===== 재고마감 실행 API 호출 시작 =====');
      print('요청 파라미터: trCd=$trCd, closeDate=$closeDate, empCd=$empCd, closeDesc=$closeDesc');
      print('상세 데이터 개수: \\${items?.length ?? 0}');
      final response = await _request(
        'POST',
        '/api/v1/stock-close/execute',
        {
          'trCd': trCd,
          'closeDate': closeDate,
          'empCd': empCd,
          'closeDesc': closeDesc ?? '', // 추가
          'remark': remark ?? '',
          'items': items, // 상세 데이터 포함
        },
        null,
      );
      print('재고마감 실행 API 응답: $response');
      return response;
    } catch (e) {
      print('재고마감 실행 API 호출 실패: $e');
      rethrow;
    }
  }

  /// 재고마감 이력 조회
  Future<List<Map<String, dynamic>>> getStockCloseHistory({
    required String trCd,
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    try {
      print('===== 재고마감 이력 조회 API 호출 시작 =====');
      
      final queryParams = <String, String>{
        'trCd': trCd, // 서버/DB와 100% 일치
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (status != null && status.isNotEmpty && status != '전체') 'status': status,
      };
      
      print('요청 파라미터: $queryParams');
      
      final response = await _request(
        'GET',
        '/api/v1/stock-close/history',
        null,
        queryParams,
      );
      
      print('재고마감 이력 조회 API 응답: $response');
      
      if (response['data'] != null) {
        final List<dynamic> data = response['data'];
        return data.map((item) {
          final Map<String, dynamic> convertedItem = Map<String, dynamic>.from(item);
          
          // null 값 안전 처리
          if (convertedItem['TOTAL_ORDER_QTY'] == null) {
            convertedItem['totalOrderQty'] = null;
          } else {
            convertedItem['totalOrderQty'] = convertedItem['TOTAL_ORDER_QTY'];
          }
          
          if (convertedItem['TOTAL_ORDER_AMOUNT'] == null) {
            convertedItem['totalOrderAmount'] = null;
          } else {
            convertedItem['totalOrderAmount'] = convertedItem['TOTAL_ORDER_AMOUNT'];
          }
          
          // 다른 필드들도 안전하게 변환
          convertedItem['closeDate'] = convertedItem['close_date']?.toString() ?? convertedItem['CLOSE_DATE']?.toString() ?? '';
          convertedItem['status'] = convertedItem['status']?.toString() ?? convertedItem['STATUS']?.toString() ?? '';
          convertedItem['totalItems'] = convertedItem['total_items'] ?? convertedItem['TOTAL_ITEMS'] ?? 0;
          convertedItem['shortageItems'] = convertedItem['shortage_items'] ?? convertedItem['SHORTAGE_ITEMS'] ?? 0;
          convertedItem['createdBy'] = convertedItem['emp_cd']?.toString() ?? convertedItem['CREATED_BY']?.toString() ?? '';
          convertedItem['createdAt'] = convertedItem['created_at']?.toString() ?? convertedItem['CREATED_AT']?.toString() ?? '';
          convertedItem['completedAt'] = convertedItem['completed_at']?.toString() ?? convertedItem['COMPLETED_AT']?.toString();
          convertedItem['remark'] = convertedItem['remark']?.toString() ?? convertedItem['REMARK']?.toString() ?? '';
          convertedItem['orderId'] = convertedItem['order_id']?.toString() ?? convertedItem['ORDER_ID']?.toString() ?? '';
          convertedItem['orderStatus'] = convertedItem['order_status']?.toString() ?? convertedItem['ORDER_STATUS']?.toString() ?? '';
          convertedItem['deliveredAt'] = convertedItem['delivered_at']?.toString() ?? convertedItem['DELIVERED_AT']?.toString();
          
          return convertedItem;
        }).toList();
      }
      return [];
    } catch (e) {
      print('재고마감 이력 조회 API 호출 실패: $e');
      rethrow;
    }
  }

  /// 재고마감 번복 요청 목록 조회
  Future<List<Map<String, dynamic>>> getStockCloseRevertRequests({
    required String trCd,
    String? status,
  }) async {
    try {
      print('===== 재고마감 번복 요청 조회 API 호출 시작 =====');
      
      final queryParams = <String, String>{
        'trCd': trCd,
        if (status != null && status.isNotEmpty && status != '전체') 'status': status,
      };
      
      print('요청 파라미터: $queryParams');
      
      final response = await _request(
        'GET',
        '/api/v1/stock-close/revert-requests',
        null,
        queryParams,
      );
      
      print('재고마감 번복 요청 조회 API 응답: $response');
      
      if (response['data'] != null) {
        final List<dynamic> data = response['data'];
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      print('재고마감 번복 요청 조회 API 호출 실패: $e');
      rethrow;
    }
  }

  /// 재고마감 번복 요청 등록
  Future<Map<String, dynamic>> createStockCloseRevertRequest({
    required String trCd,
    required String closeDate,
    required String requestReason,
    required String requestDetail,
    required String requestBy,
  }) async {
    try {
      print('===== 재고마감 번복 요청 등록 API 호출 시작 =====');
      
      final response = await _request(
        'POST',
        '/api/v1/stock-close/revert-request',
        {
          'trCd': trCd,
          'closeDate': closeDate,
          'requestReason': requestReason,
          'requestDetail': requestDetail,
          'requestBy': requestBy,
        },
        null,
      );
      
      print('재고마감 번복 요청 등록 API 응답: $response');
      return response;
    } catch (e) {
      print('재고마감 번복 요청 등록 API 호출 실패: $e');
      rethrow;
    }
  }

  /// 재고마감 분석 데이터 조회
  Future<List<Map<String, dynamic>>> getStockCloseAnalytics({
    required String trCd,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('===== 재고마감 분석 데이터 조회 API 호출 시작 =====');
      
      final response = await _request(
        'GET',
        '/api/v1/stock-close/analytics',
        null,
        {
          'trCd': trCd, // 서버/DB와 100% 일치
          'startDate': DateFormat('yyyy-MM-dd').format(startDate),
          'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        },
      );
      
      print('재고마감 분석 데이터 조회 API 응답: $response');
      
      if (response['data'] != null) {
        final List<dynamic> data = response['data'];
        return data.map((item) {
          final Map<String, dynamic> convertedItem = Map<String, dynamic>.from(item);
          
          // null 값 안전 처리
          convertedItem['month'] = convertedItem['month']?.toString() ?? '';
          convertedItem['totalCloses'] = convertedItem['totalCloses'] ?? 0;
          convertedItem['totalItems'] = convertedItem['totalItems'] ?? 0;
          convertedItem['totalOrderQty'] = convertedItem['totalOrderQty'];
          convertedItem['totalOrderAmount'] = convertedItem['totalOrderAmount'];
          convertedItem['shortageRate'] = convertedItem['shortageRate'];
          convertedItem['status'] = convertedItem['STATUS']?.toString() ?? '';
          convertedItem['avgProcessingTime'] = convertedItem['avgProcessingTime'] ?? 0;
          
          return convertedItem;
        }).toList();
      }
      return [];
    } catch (e) {
      print('재고마감 분석 데이터 조회 API 호출 실패: $e');
      rethrow;
    }
  }

  /// 재고마감 상세 정보 조회
  Future<List<Map<String, dynamic>>> getStockCloseDetail({
    required int stockCloseId,
  }) async {
    try {
      print('===== 재고마감 상세 정보 조회 API 호출 시작 =====');
      final response = await _request(
        'GET',
        '/api/v1/stock-close/detail',
        null,
        {
          'stockCloseId': stockCloseId.toString(), // 서버/DB와 100% 일치
        },
      );
      print('재고마감 상세 정보 조회 API 응답: $response');
      if (response['data'] != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('재고마감 상세 정보 조회 API 호출 실패: $e');
      rethrow;
    }
  }

  /// 재고마감 엑셀 다운로드
  Future<void> downloadStockCloseExcel({
    required String trCd,
    required String closeDate,
  }) async {
    try {
      await _downloadExcel(
        '/api/v1/stock-close/excel',
        'stock_close_$closeDate.xlsx',
        queryParameters: {
          'trCd': trCd,
          'closeDate': closeDate,
        },
      );
    } catch (e) {
      print('재고마감 엑셀 다운로드 실패: $e');
      rethrow;
    }
  }

  /// 재고마감 분석 엑셀 다운로드
  Future<void> downloadStockCloseAnalyticsExcel({
    required String trCd,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      await _downloadExcel(
        '/api/v1/stock-close/analytics/excel',
        'stock_close_analytics_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.xlsx',
        queryParameters: {
          'trCd': trCd,
          'startDate': DateFormat('yyyy-MM-dd').format(startDate),
          'endDate': DateFormat('yyyy-MM-dd').format(endDate),
        },
      );
    } catch (e) {
      print('재고마감 분석 엑셀 다운로드 실패: $e');
      rethrow;
    }
  }

  // 병원 셀(창고)의 품목 목록 조회
  Future<List<Map<String, dynamic>>> getHospitalCellItems({
    required String trCd,
    required String hospitalId,
    required String cellId,
    String? itemName,
    String? itemCode,
    bool? showOnlySafetyStock,
    bool? showOnlyActiveItems,
  }) async {
    try {
      final response = await _request(
        'POST',
        '/api/v1/hospital-cell-items',
        {
          'trCd': trCd,
          'hospitalId': hospitalId,
          'cellId': cellId,
          'itemName': itemName ?? '',
          'itemCode': itemCode ?? '',
          'showOnlySafetyStock': showOnlySafetyStock ?? false,
          'showOnlyActiveItems': showOnlyActiveItems ?? true,
        },
        null,
      );
      if (response != null && response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      print('Error getting hospital cell items: $e');
      rethrow;
    }
  }
  
  // 병원 안전재고 등록/수정
  Future<void> saveHospitalSafetyStock(List<Map<String, dynamic>> updatedItems) async {
    try {
      await _request(
        'POST',
        '/api/v1/hospital-safe-stock',
        updatedItems,
        null,
      );
    } catch (e) {
      print('Error saving hospital safe stocks: $e');
      rethrow;
    }
  }

  /// 병원별 재고조사 주기 설정 저장
  /// 선택된 병원 리스트와 창고 리스트를 서버로 전송하여 일괄 저장합니다.
  /// @param trCd 대리점 코드
  /// @param hospitalIds 선택된 병원 ID 배열
  /// @param cellIds 선택된 창고 ID 배열
  /// @param cycleType 주기 타입 (DAYS 또는 SPECIFIC_DAY)
  /// @param cycleValue 주기 값
  /// @param updatedBy 수정자
  Future<void> saveHospitalSurveyCycle({
    required String trCd,
    required List<String> hospitalIds,
    required List<String> cellIds,
    required String cycleType,
    required String cycleValue,
    required String updatedBy,
  }) async {
    try {
      // 디버깅을 위한 로그 추가
      print('=== saveHospitalSurveyCycle Debug ===');
      print('trCd: $trCd');
      print('hospitalIds: $hospitalIds');
      print('cellIds: $cellIds');
      print('cycleType: $cycleType');
      print('cycleValue: $cycleValue');
      print('updatedBy: $updatedBy');
      
      final requestBody = {
        'trCd': trCd,
        'hospitalIds': hospitalIds,
        'cellIds': cellIds,
        'cycleType': cycleType,
        'cycleValue': cycleValue,
        'updatedBy': updatedBy,
      };

      print('requestBody: $requestBody');

      await _request('POST', '/api/v1/stock-survey-cycle/hospital-cells/survey-cycle', requestBody, null);
    } catch (e) {
      throw Exception('병원별 재고조사 주기 설정 저장 실패: $e');
    }
  }

  /// 병원별 재고조사 주기 설정 조회
  /// 현재 설정된 모든 병원별 재고조사 주기 설정을 조회합니다.
  /// @param trCd 대리점 코드
  Future<List<Map<String, dynamic>>> getHospitalSurveyCycleSettings({required String trCd}) async {
    try {
      final response = await _request('GET', '/api/v1/stock-survey-cycle/hospital-cells/survey-cycle', null, {
        'trCd': trCd,
      });
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      throw Exception('병원별 재고조사 주기 설정 조회 실패: $e');
    }
  }

  /// 병원별 재고조사 주기 설정 삭제
  /// 특정 병원/창고의 재고조사 주기 설정을 삭제합니다.
  /// @param trCd 대리점 코드
  /// @param hospitalId 병원 코드 (선택사항, null이면 전체 삭제)
  /// @param warehouseId 창고 코드 (선택사항, null이면 해당 병원 전체 삭제)
  Future<void> deleteHospitalSurveyCycle({
    required String trCd,
    String? hospitalId,
    String? warehouseId,
  }) async {
    try {
      final queryParams = <String, String>{
        'trCd': trCd,
        if (hospitalId != null) 'hospitalId': hospitalId,
        if (warehouseId != null) 'warehouseId': warehouseId,
      };
      
      await _request('DELETE', '/api/v1/stock-survey-cycle/hospital-cells/survey-cycle', null, queryParams);
    } catch (e) {
      throw Exception('병원별 재고조사 주기 설정 삭제 실패: $e');
    }
  }

  /// 지능형 재고조사 관리 - 조사가 필요한 병원 조회
  /// 재고조사가 필요한 병원들을 우선순위별로 조회합니다.
  /// @param trCd 대리점 코드
  Future<List<Map<String, dynamic>>> getSurveyNeededHospitals({required String trCd}) async {
    try {
      final response = await _request('GET', '/api/v1/stock-survey-cycle/hospital-cells/survey-needed', null, {
        'trCd': trCd,
      });
      
      // 안전한 데이터 처리
      if (response != null && 
          response['data'] != null && 
          response['data'] is Map<String, dynamic> &&
          response['data']['all'] != null &&
          response['data']['all'] is List) {
        return List<Map<String, dynamic>>.from(response['data']['all']);
      }
      
      // 데이터가 없거나 잘못된 형식인 경우 빈 리스트 반환
      print('재고조사 필요현황 데이터가 없거나 형식이 올바르지 않습니다.');
      return [];
      
    } catch (e) {
      print('조사가 필요한 병원 조회 실패: $e');
      // 오류가 발생해도 빈 리스트 반환 (앱이 크래시되지 않도록)
      return [];
    }
  }

  /// 병원별 재고조사 주기 설정 엑셀 다운로드
  Future<void> downloadHospitalSurveyCycleExcel({required String trCd}) async {
    try {
      await _downloadExcel(
        '/api/v1/stock-survey-cycle/excel',
        'hospital_survey_cycle_${trCd}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
        queryParameters: {
          'trCd': trCd,
        },
      );
    } catch (e) {
      throw Exception('병원별 재고조사 주기 설정 엑셀 다운로드 실패: $e');
    }
  }

  /// 비밀번호 변경 API
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String empCd,
  }) async {
    try {
      debugPrint('=== 비밀번호 변경 API 호출 시작 ===');
      debugPrint('직원코드: $empCd');

      final response = await _request(
        'PUT',
        '/api/v1/auth/user/change-password',
        {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'empCd': empCd,
        },
        null,
      );

      debugPrint('=== 비밀번호 변경 API 응답 ===');
      debugPrint('응답: $response');

      return response ?? {};
    } catch (e) {
      debugPrint('=== 비밀번호 변경 API 오류 ===');
      debugPrint('오류: $e');
      print('비밀번호 변경 오류: $e');
      rethrow;
    }
  }

  // 제품납품 품목 목록 조회
  Future<List<Map<String, dynamic>>> fetchHospitalDeliveryItems({
    required String hospitalId,
    required String cellId,
    required String deliveryDate,
  }) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/hospital-delivery-items',
        null,
        {
          'hospitalId': hospitalId,
          'cellId': cellId,
          'deliveryDate': deliveryDate,
        },
      );
      
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('제품납품 품목 목록 조회 실패: $e');
      rethrow;
    }
  }

  /// 재고마감 이력 마스터 조회
  Future<List<Map<String, dynamic>>> getStockCloseHistoryMaster({
    required String trCd,
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'trCd': trCd,
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (status != null && status.isNotEmpty) 'status': status,
      };
      
      final response = await _request(
        'GET',
        '/api/v1/stock-close/history-master',
        null,
        queryParams,
      );
      
      if (response['data'] != null) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('재고마감 이력 마스터 조회 실패: $e');
      rethrow;
    }
  }

  /// 자동주문 재실행
  Future<Map<String, dynamic>> executeAutoOrder({
    required String trCd,
    required String empCd,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      print('===== 자동주문 재실행 API 호출 시작 =====');
      print('요청 파라미터: trCd=$trCd, empCd=$empCd');
      print('주문 품목 개수: ${items.length}');
      
      final response = await _request(
        'POST',
        '/api/v1/auto-orders/execute',
        {
          'trCd': trCd,
          'empCd': empCd,
          'items': items,
        },
        null,
      );
      
      print('자동주문 재실행 API 응답: $response');
      return response;
    } catch (e) {
      print('자동주문 재실행 API 호출 실패: $e');
      rethrow;
    }
  }

  /// 자동주문 조회
  Future<List<Map<String, dynamic>>> getAutoOrders({
    required String trCd,
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'trCd': trCd,
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (status != null && status.isNotEmpty) 'status': status,
      };
      
      final response = await _request(
        'GET',
        '/api/v1/auto-orders',
        null,
        queryParams,
      );
      
      if (response != null && response['data'] != null && response['data']['orders'] is List) {
        final List<dynamic> data = response['data']['orders'];
        return data.map((item) {
          final Map<String, dynamic> converted = Map<String, dynamic>.from(item);
          // 서버 필드명 → 클라이언트 필드명 매핑
          converted['id'] = item['AUTO_ORDER_ID'] ?? item['id'] ?? '';
          converted['order_date'] = item['ORDER_DATE'] ?? item['order_date'] ?? '';
          converted['agency_id'] = item['TR_CD'] ?? item['agency_id'] ?? '';
          converted['status'] = item['STATUS'] ?? item['status'] ?? '';
          converted['created_at'] = item['CREATED_AT'] ?? item['created_at'] ?? '';
          converted['closeId'] = item['STOCK_CLOSE_ID'] ?? item['closeId'] ?? '';
          converted['totalItems'] = item['TOTAL_ITEMS'] ?? item['totalItems'] ?? 0;
          converted['shortageItems'] = item['SHORTAGE_ITEMS'] ?? item['shortageItems'] ?? 0;
          converted['totalOrderQty'] = item['TOTAL_ORDER_QTY'] ?? item['totalOrderQty'] ?? 0;
          converted['totalOrderAmount'] = item['TOTAL_VALUE'] ?? item['totalOrderAmount'] ?? 0;
          converted['remark'] = item['REMARK'] ?? item['remark'] ?? '';
          // items 내부 품목별 상세도 매핑
          if (item['items'] is List) {
            converted['items'] = (item['items'] as List).map((i) => {
              'item_id': i['ITEM_ID'] ?? i['item_id'] ?? '',
              'item_name': i['ITEM_NAME'] ?? i['item_name'] ?? '',
              'close_qty': i['CLOSE_QTY'] ?? i['close_qty'] ?? 0,
              'safe_qty': i['SAFE_QTY'] ?? i['safe_qty'] ?? 0,
              'short_qty': i['SHORT_QTY'] ?? i['short_qty'] ?? 0,
              'order_qty': i['ORDER_QTY'] ?? i['order_qty'] ?? 0,
              // 기타 필요한 필드 추가
            }).toList();
          } else {
            converted['items'] = [];
          }
          // 기타 필요한 필드 모두 매핑
          return converted;
        }).toList();
      }
      return [];
    } catch (e) {
      print('자동주문 조회 실패: $e');
      rethrow;
    }
  }

  /// 병원별 제품납품 목록 조회
  Future<List<Map<String, dynamic>>> getHospitalDeliveryList({
    required String hospitalId,
    required String cellId,
    required String deliveryDate,
  }) async {
    try {
      final queryParams = {
        'hospitalId': hospitalId,
        'cellId': cellId,
        'deliveryDate': deliveryDate,
      };
      final response = await _request(
        'GET',
        '/api/v1/hospital-delivery-items',
        null,
        queryParams,
      );
      if (response != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('제품납품 조회 실패: $e');
      rethrow;
    }
  }

  /// 무한 스크롤/페이지네이션용 주기 설정 조회
  Future<Map<String, dynamic>> getHospitalSurveyCycleSettingsPaged({required String trCd, required int page, required int size}) async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/stock-survey-cycle/hospital-cells/survey-cycle',
        null,
        {
          'trCd': trCd,
          'page': page.toString(),
          'size': size.toString(),
        },
      );
      return response;
    } catch (e) {
      throw Exception('주기 설정 페이지네이션 조회 실패: $e');
    }
  }

  // 대리점 목록 조회
  Future<List<Map<String, dynamic>>> getAgencies() async {
    try {
      print('=== getAgencies API 호출 시작 ===');
      
      final response = await _request(
        'GET',
        '/api/v1/agencies',
        null,
        null,
      );
      
      print('=== getAgencies API 응답 ===');
      print('Response: $response');
      
      if (response != null && response['data'] is List) {
        final agencies = List<Map<String, dynamic>>.from(response['data']);
        print('=== 대리점 데이터 변환 완료 ===');
        print('대리점 개수: ${agencies.length}');
        return agencies;
      } else {
        print('=== 대리점 데이터 변환 실패 ===');
        print('Response: $response');
        return [];
      }
    } catch (e) {
      print('Error getting agencies: $e');
      return [];
    }
  }

  // 병원매출 데이터 조회
  Future<List<Map<String, dynamic>>> getAgencySalesData({
    required DateTime fromDate,
    required DateTime toDate,
    required List<String> hospitalIds,
    required List<String> warehouseIds,
    required List<String> itemIds,
    required List<String> agencyIds,
    required String trCd,
  }) async {
    try {
      print('=== getAgencySalesData API 호출 시작 ===');
      print('FromDate: $fromDate');
      print('ToDate: $toDate');
      print('HospitalIds: $hospitalIds');
      print('WarehouseIds: $warehouseIds');
      print('ItemIds: $itemIds');
      print('AgencyIds: $agencyIds');
      print('TrCd: $trCd');
      
      final queryParams = <String, String>{
        'userTrCd': trCd,
        'startDate': DateFormat('yyyy-MM-dd').format(fromDate),
        'endDate': DateFormat('yyyy-MM-dd').format(toDate),
      };
      if (hospitalIds.isNotEmpty) {
        queryParams['hospitalIds'] = hospitalIds.join(',');
      }
      if (warehouseIds.isNotEmpty) {
        queryParams['cellIds'] = warehouseIds.join(',');
      }
      if (itemIds.isNotEmpty) {
        queryParams['itemCds'] = itemIds.join(',');
      }
      final response = await _request(
        'GET',
        '/api/v1/agency-sales/data',
        null,
        queryParams,
      );
      print('=== getAgencySalesData API 응답 ===');
      print('Response: $response');
      if (response != null && response['success'] == true && response['data'] is List) {
        final salesData = List<Map<String, dynamic>>.from(response['data']);
        print('=== 매출 데이터 변환 완료 ===');
        print('매출 데이터 개수: \\${salesData.length}');
        return salesData;
      } else {
        print('=== 매출 데이터 변환 실패 ===');
        print('Response: $response');
        // 에러 메시지 반환
        throw Exception(response?['message'] ?? '매출 데이터 응답 오류');
      }
    } catch (e) {
      print('Error getting hospital sales data: $e');
      // 크래시 방지: 빈 리스트 반환
      return [];
    }
  }
}
