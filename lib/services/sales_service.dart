import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class SalesService {
  static String get baseUrl => AppConfig.serverUrl;

  // 인증 토큰 가져오기
  static Future<String?> _getAuthToken() async {
    // SharedPreferences에서 토큰 가져오기 (AuthProvider와 ApiService와 동일한 방식)
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 매출요약 데이터 조회
  static Future<Map<String, dynamic>> getSalesSummary({
    required String fromDate,
    required String toDate,
    String period = 'monthly',
    String? trCd,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final uri = Uri.parse('$baseUrl/api/v1/sales/summary').replace(
        queryParameters: {
          'startDate': fromDate,
          'endDate': toDate,
          'period': period,
        },
      );

      print('매출요약 API 호출: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('응답 상태코드: ${response.statusCode}');
      print('응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? '데이터 조회에 실패했습니다.');
        }
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('매출요약 데이터 조회 오류: $e');
      rethrow;
    }
  }

  // 기간별 매출 분석
  static Future<Map<String, dynamic>> getPeriodAnalysis({
    required String fromDate,
    required String toDate,
    String periodType = 'monthly',
    String compareType = 'previous',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final uri = Uri.parse('$baseUrl/api/v1/sales/period-analysis').replace(
        queryParameters: {
          'startDate': fromDate,
          'endDate': toDate,
          'periodType': periodType,
          'compareType': compareType,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? '데이터 조회에 실패했습니다.');
        }
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('기간별 분석 데이터 조회 오류: $e');
      rethrow;
    }
  }

  // 상품별 매출 분석
  static Future<Map<String, dynamic>> getProductAnalysis({
    required String fromDate,
    required String toDate,
    int topN = 10,
    String? categoryFilter,
    String sortBy = 'amount',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final queryParams = {
        'startDate': fromDate,
        'endDate': toDate,
        'topN': topN.toString(),
        'sortBy': sortBy,
      };

      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        queryParams['categoryFilter'] = categoryFilter;
      }

      final uri = Uri.parse('$baseUrl/api/v1/sales/product-analysis').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? '데이터 조회에 실패했습니다.');
        }
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('상품별 분석 데이터 조회 오류: $e');
      rethrow;
    }
  }

  // 병원별 매출 분석
  static Future<Map<String, dynamic>> getHospitalAnalysis({
    required String fromDate,
    required String toDate,
    int topN = 10,
    String? regionFilter,
    String? hospitalTypeFilter,
    String sortBy = 'amount',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final queryParams = {
        'startDate': fromDate,
        'endDate': toDate,
        'topN': topN.toString(),
        'sortBy': sortBy,
      };

      if (regionFilter != null && regionFilter.isNotEmpty) {
        queryParams['regionFilter'] = regionFilter;
      }
      if (hospitalTypeFilter != null && hospitalTypeFilter.isNotEmpty) {
        queryParams['hospitalTypeFilter'] = hospitalTypeFilter;
      }

      final uri = Uri.parse('$baseUrl/api/v1/sales/hospital-analysis').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? '데이터 조회에 실패했습니다.');
        }
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('병원별 분석 데이터 조회 오류: $e');
      rethrow;
    }
  }

  // 차트 데이터 조회
  static Future<Map<String, dynamic>> getChartData({
    required String fromDate,
    required String toDate,
    String chartType = 'line',
    String dataType = 'amount',
    String groupBy = 'month',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final uri = Uri.parse('$baseUrl/api/v1/sales/chart-data').replace(
        queryParameters: {
          'startDate': fromDate,
          'endDate': toDate,
          'chartType': chartType,
          'dataType': dataType,
          'groupBy': groupBy,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? '데이터 조회에 실패했습니다.');
        }
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('차트 데이터 조회 오류: $e');
      rethrow;
    }
  }

  // 엑셀 다운로드
  static Future<Map<String, dynamic>> exportSalesData({
    required String fromDate,
    required String toDate,
    String exportType = 'summary',
    String? analysisType,
    String format = 'xlsx',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final requestBody = {
        'startDate': fromDate,
        'endDate': toDate,
        'exportType': exportType,
        'format': format,
      };

      if (analysisType != null && analysisType.isNotEmpty) {
        requestBody['analysisType'] = analysisType;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/sales/export'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? '엑셀 다운로드에 실패했습니다.');
        }
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('엑셀 다운로드 오류: $e');
      rethrow;
    }
  }

  // 테스트 엔드포인트
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/sales/test'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('서버 연결 테스트 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('서버 연결 테스트 오류: $e');
      rethrow;
    }
  }
} 