import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgencySalesService {
  static final AgencySalesService _instance = AgencySalesService._internal();
  factory AgencySalesService() => _instance;
  AgencySalesService._internal();

  static String get baseUrl => AppConfig.serverUrl;

  // 공통 API 호출 메서드
  static Future<dynamic> _request(
    String method,
    String endpoint,
    dynamic body,
    Map<String, String>? queryParams,
  ) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParams,
      );

      final headers = {
        'Content-Type': 'application/json',
      };
      // 토큰 헤더 추가
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      http.Response response;
      final client = http.Client();
      
      try {
        switch (method.toUpperCase()) {
          case 'GET':
            response = await client.get(url, headers: headers).timeout(
              const Duration(seconds: 30),
            );
            break;
          case 'POST':
            response = await client.post(
              url, 
              headers: headers, 
              body: body != null ? jsonEncode(body) : null
            ).timeout(
              const Duration(seconds: 30),
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
      print('AgencySalesService Error: $e');
      rethrow;
    }
  }

  // 1. 대리점매출현황 기본 데이터 조회 (업그레이드)
  Future<Map<String, dynamic>> getAgencySalesData({
    required String userTrCd,
    required String startDate,
    required String endDate,
    List<String>? hospitalIds,
    List<String>? cellIds,
    List<String>? itemCds,
    String? region,
    String? hospitalType,
    String? hospitalScale,
    String? sido,
    String? sigungu,
    String? eupmyeondong,
  }) async {
    try {
      final queryParams = <String, String>{
        'userTrCd': userTrCd,
        'startDate': startDate,
        'endDate': endDate,
      };

      if (hospitalIds != null && hospitalIds.isNotEmpty) {
        queryParams['hospitalIds'] = hospitalIds.join(',');
      }
      if (cellIds != null && cellIds.isNotEmpty) {
        queryParams['cellIds'] = cellIds.join(',');
      }
      if (itemCds != null && itemCds.isNotEmpty) {
        queryParams['itemCds'] = itemCds.join(',');
      }
      if (region != null && region.isNotEmpty) {
        queryParams['region'] = region;
      }
      if (hospitalType != null && hospitalType.isNotEmpty) {
        queryParams['hospitalType'] = hospitalType;
      }
      if (hospitalScale != null && hospitalScale.isNotEmpty) {
        queryParams['hospitalScale'] = hospitalScale;
      }
      if (sido != null && sido.isNotEmpty) {
        queryParams['sido'] = sido;
      }
      if (sigungu != null && sigungu.isNotEmpty) {
        queryParams['sigungu'] = sigungu;
      }
      if (eupmyeondong != null && eupmyeondong.isNotEmpty) {
        queryParams['eupmyeondong'] = eupmyeondong;
      }

      final response = await _request(
        'GET',
        '/api/v1/agency-sales/data',
        null,
        queryParams,
      );

      return response ?? {};
    } catch (e) {
      print('Error getting agency sales data: $e');
      rethrow;
    }
  }

  // 2. 대리점매출현황 고급 통계 조회 (업그레이드)
  Future<Map<String, dynamic>> getAgencySalesSummary({
    required String userTrCd,
    required String startDate,
    required String endDate,
    List<String>? hospitalIds,
    List<String>? cellIds,
    List<String>? itemCds,
    String groupBy = 'HOSPITAL',
    int topN = 10,
    String? region,
    String? hospitalType,
    String? hospitalScale,
    String? sido,
    String? sigungu,
    String? eupmyeondong,
  }) async {
    try {
      final queryParams = <String, String>{
        'userTrCd': userTrCd,
        'startDate': startDate,
        'endDate': endDate,
        'groupBy': groupBy,
        'topN': topN.toString(),
      };

      if (hospitalIds != null && hospitalIds.isNotEmpty) {
        queryParams['hospitalIds'] = hospitalIds.join(',');
      }
      if (cellIds != null && cellIds.isNotEmpty) {
        queryParams['cellIds'] = cellIds.join(',');
      }
      if (itemCds != null && itemCds.isNotEmpty) {
        queryParams['itemCds'] = itemCds.join(',');
      }
      if (region != null && region.isNotEmpty) {
        queryParams['region'] = region;
      }
      if (hospitalType != null && hospitalType.isNotEmpty) {
        queryParams['hospitalType'] = hospitalType;
      }
      if (hospitalScale != null && hospitalScale.isNotEmpty) {
        queryParams['hospitalScale'] = hospitalScale;
      }
      if (sido != null && sido.isNotEmpty) {
        queryParams['sido'] = sido;
      }
      if (sigungu != null && sigungu.isNotEmpty) {
        queryParams['sigungu'] = sigungu;
      }
      if (eupmyeondong != null && eupmyeondong.isNotEmpty) {
        queryParams['eupmyeondong'] = eupmyeondong;
      }

      final response = await _request(
        'GET',
        '/api/v1/agency-sales/summary',
        null,
        queryParams,
      );

      return response ?? {};
    } catch (e) {
      print('Error getting agency sales summary: $e');
      rethrow;
    }
  }

  // 3. 대리점매출현황 AI 분석 조회 (업그레이드)
  Future<Map<String, dynamic>> getAgencySalesAnalysis({
    required String userTrCd,
    required String startDate,
    required String endDate,
    List<String>? hospitalIds,
    List<String>? cellIds,
    List<String>? itemCds,
    String analysisType = 'TREND',
    int topN = 10,
    String? region,
    String? hospitalType,
    String? hospitalScale,
    String? sido,
    String? sigungu,
    String? eupmyeondong,
  }) async {
    try {
      final queryParams = <String, String>{
        'userTrCd': userTrCd,
        'startDate': startDate,
        'endDate': endDate,
        'analysisType': analysisType,
        'topN': topN.toString(),
      };

      if (hospitalIds != null && hospitalIds.isNotEmpty) {
        queryParams['hospitalIds'] = hospitalIds.join(',');
      }
      if (cellIds != null && cellIds.isNotEmpty) {
        queryParams['cellIds'] = cellIds.join(',');
      }
      if (itemCds != null && itemCds.isNotEmpty) {
        queryParams['itemCds'] = itemCds.join(',');
      }
      if (region != null && region.isNotEmpty) {
        queryParams['region'] = region;
      }
      if (hospitalType != null && hospitalType.isNotEmpty) {
        queryParams['hospitalType'] = hospitalType;
      }
      if (hospitalScale != null && hospitalScale.isNotEmpty) {
        queryParams['hospitalScale'] = hospitalScale;
      }
      if (sido != null && sido.isNotEmpty) {
        queryParams['sido'] = sido;
      }
      if (sigungu != null && sigungu.isNotEmpty) {
        queryParams['sigungu'] = sigungu;
      }
      if (eupmyeondong != null && eupmyeondong.isNotEmpty) {
        queryParams['eupmyeondong'] = eupmyeondong;
      }

      final response = await _request(
        'GET',
        '/api/v1/agency-sales/analysis',
        null,
        queryParams,
      );

      return response ?? {};
    } catch (e) {
      print('Error getting agency sales analysis: $e');
      rethrow;
    }
  }

  // 4. 대리점매출현황 지도 데이터 조회 (새로 추가)
  Future<Map<String, dynamic>> getAgencySalesMapData({
    required String userTrCd,
    required String startDate,
    required String endDate,
    List<String>? hospitalIds,
    List<String>? cellIds,
    List<String>? itemCds,
    String? region,
    String? hospitalType,
    String? hospitalScale,
    String? sido,
    String? sigungu,
    String? eupmyeondong,
  }) async {
    try {
      final queryParams = <String, String>{
        'userTrCd': userTrCd,
        'startDate': startDate,
        'endDate': endDate,
      };

      if (hospitalIds != null && hospitalIds.isNotEmpty) {
        queryParams['hospitalIds'] = hospitalIds.join(',');
      }
      if (cellIds != null && cellIds.isNotEmpty) {
        queryParams['cellIds'] = cellIds.join(',');
      }
      if (itemCds != null && itemCds.isNotEmpty) {
        queryParams['itemCds'] = itemCds.join(',');
      }
      if (region != null && region.isNotEmpty) {
        queryParams['region'] = region;
      }
      if (hospitalType != null && hospitalType.isNotEmpty) {
        queryParams['hospitalType'] = hospitalType;
      }
      if (hospitalScale != null && hospitalScale.isNotEmpty) {
        queryParams['hospitalScale'] = hospitalScale;
      }
      if (sido != null && sido.isNotEmpty) {
        queryParams['sido'] = sido;
      }
      if (sigungu != null && sigungu.isNotEmpty) {
        queryParams['sigungu'] = sigungu;
      }
      if (eupmyeondong != null && eupmyeondong.isNotEmpty) {
        queryParams['eupmyeondong'] = eupmyeondong;
      }

      final response = await _request(
        'GET',
        '/api/v1/agency-sales/map',
        null,
        queryParams,
      );

      return response ?? {};
    } catch (e) {
      print('Error getting agency sales map data: $e');
      rethrow;
    }
  }

  // 5. 대리점매출현황 지역별 통계 조회 (새로 추가)
  Future<Map<String, dynamic>> getAgencySalesRegionalStats({
    required String userTrCd,
    required String startDate,
    required String endDate,
    List<String>? hospitalIds,
    List<String>? cellIds,
    List<String>? itemCds,
    String? region,
    String? hospitalType,
    String? hospitalScale,
    String? sido,
    String? sigungu,
    String? eupmyeondong,
  }) async {
    try {
      final queryParams = <String, String>{
        'userTrCd': userTrCd,
        'startDate': startDate,
        'endDate': endDate,
      };

      if (hospitalIds != null && hospitalIds.isNotEmpty) {
        queryParams['hospitalIds'] = hospitalIds.join(',');
      }
      if (cellIds != null && cellIds.isNotEmpty) {
        queryParams['cellIds'] = cellIds.join(',');
      }
      if (itemCds != null && itemCds.isNotEmpty) {
        queryParams['itemCds'] = itemCds.join(',');
      }
      if (region != null && region.isNotEmpty) {
        queryParams['region'] = region;
      }
      if (hospitalType != null && hospitalType.isNotEmpty) {
        queryParams['hospitalType'] = hospitalType;
      }
      if (hospitalScale != null && hospitalScale.isNotEmpty) {
        queryParams['hospitalScale'] = hospitalScale;
      }
      if (sido != null && sido.isNotEmpty) {
        queryParams['sido'] = sido;
      }
      if (sigungu != null && sigungu.isNotEmpty) {
        queryParams['sigungu'] = sigungu;
      }
      if (eupmyeondong != null && eupmyeondong.isNotEmpty) {
        queryParams['eupmyeondong'] = eupmyeondong;
      }

      final response = await _request(
        'GET',
        '/api/v1/agency-sales/regional-stats',
        null,
        queryParams,
      );

      return response ?? {};
    } catch (e) {
      print('Error getting agency sales regional stats: $e');
      rethrow;
    }
  }

  // 6. 대리점매출현황 차트 데이터 조회 (업그레이드)
  Future<Map<String, dynamic>> getAgencySalesChart({
    required String userTrCd,
    required String startDate,
    required String endDate,
    String chartType = 'DAILY',
    List<String>? hospitalIds,
    List<String>? cellIds,
    List<String>? itemCds,
    String? region,
    String? hospitalType,
    String? hospitalScale,
    String? sido,
    String? sigungu,
    String? eupmyeondong,
  }) async {
    try {
      final queryParams = <String, String>{
        'userTrCd': userTrCd,
        'startDate': startDate,
        'endDate': endDate,
        'chartType': chartType,
      };

      if (hospitalIds != null && hospitalIds.isNotEmpty) {
        queryParams['hospitalIds'] = hospitalIds.join(',');
      }
      if (cellIds != null && cellIds.isNotEmpty) {
        queryParams['cellIds'] = cellIds.join(',');
      }
      if (itemCds != null && itemCds.isNotEmpty) {
        queryParams['itemCds'] = itemCds.join(',');
      }
      if (region != null && region.isNotEmpty) {
        queryParams['region'] = region;
      }
      if (hospitalType != null && hospitalType.isNotEmpty) {
        queryParams['hospitalType'] = hospitalType;
      }
      if (hospitalScale != null && hospitalScale.isNotEmpty) {
        queryParams['hospitalScale'] = hospitalScale;
      }
      if (sido != null && sido.isNotEmpty) {
        queryParams['sido'] = sido;
      }
      if (sigungu != null && sigungu.isNotEmpty) {
        queryParams['sigungu'] = sigungu;
      }
      if (eupmyeondong != null && eupmyeondong.isNotEmpty) {
        queryParams['eupmyeondong'] = eupmyeondong;
      }

      final response = await _request(
        'GET',
        '/api/v1/agency-sales/chart',
        null,
        queryParams,
      );

      return response ?? {};
    } catch (e) {
      print('Error getting agency sales chart: $e');
      rethrow;
    }
  }

  // 7. 대리점매출현황 이력 조회 (업그레이드)
  Future<Map<String, dynamic>> getAgencySalesHistory({
    required String userTrCd,
    String? hospitalId,
    String? itemCd,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, String>{
        'userTrCd': userTrCd,
        'limit': limit.toString(),
      };

      if (hospitalId != null && hospitalId.isNotEmpty) {
        queryParams['hospitalId'] = hospitalId;
      }
      if (itemCd != null && itemCd.isNotEmpty) {
        queryParams['itemCd'] = itemCd;
      }

      final response = await _request(
        'GET',
        '/api/v1/agency-sales/history',
        null,
        queryParams,
      );

      return response ?? {};
    } catch (e) {
      print('Error getting agency sales history: $e');
      rethrow;
    }
  }

  // 8. 대리점매출현황 엑셀 다운로드 (업그레이드)
  Future<Map<String, dynamic>> exportAgencySales({
    required String userTrCd,
    required String startDate,
    required String endDate,
    List<String>? hospitalIds,
    List<String>? cellIds,
    List<String>? itemCds,
    String exportType = 'DETAIL',
    String? region,
    String? hospitalType,
    String? hospitalScale,
    String? sido,
    String? sigungu,
    String? eupmyeondong,
  }) async {
    try {
      final body = <String, dynamic>{
        'userTrCd': userTrCd,
        'startDate': startDate,
        'endDate': endDate,
        'exportType': exportType,
      };

      if (hospitalIds != null && hospitalIds.isNotEmpty) {
        body['hospitalIds'] = hospitalIds;
      }
      if (cellIds != null && cellIds.isNotEmpty) {
        body['cellIds'] = cellIds;
      }
      if (itemCds != null && itemCds.isNotEmpty) {
        body['itemCds'] = itemCds;
      }
      if (region != null && region.isNotEmpty) {
        body['region'] = region;
      }
      if (hospitalType != null && hospitalType.isNotEmpty) {
        body['hospitalType'] = hospitalType;
      }
      if (hospitalScale != null && hospitalScale.isNotEmpty) {
        body['hospitalScale'] = hospitalScale;
      }
      if (sido != null && sido.isNotEmpty) {
        body['sido'] = sido;
      }
      if (sigungu != null && sigungu.isNotEmpty) {
        body['sigungu'] = sigungu;
      }
      if (eupmyeondong != null && eupmyeondong.isNotEmpty) {
        body['eupmyeondong'] = eupmyeondong;
      }

      final response = await _request(
        'POST',
        '/api/v1/agency-sales/export',
        body,
        null,
      );

      return response ?? {};
    } catch (e) {
      print('Error exporting agency sales: $e');
      rethrow;
    }
  }

  // 9. 테스트 API
  Future<Map<String, dynamic>> testAgencySales() async {
    try {
      final response = await _request(
        'GET',
        '/api/v1/agency-sales/test',
        null,
        null,
      );

      return response ?? {};
    } catch (e) {
      print('Error testing agency sales API: $e');
      rethrow;
    }
  }
} 