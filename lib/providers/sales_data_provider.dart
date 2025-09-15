import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../services/sales_service.dart';

class SalesDataProvider with ChangeNotifier {
  // 통합매출분석 데이터
  List<Map<String, dynamic>> _salesSummaryData = [];
  List<Map<String, dynamic>> _salesRawData = [];
  
  bool _isLoading = false;
  String _errorMessage = '';
  
  // 기본 기간: 당해년도 전체
  DateTime _fromDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _toDate = DateTime(DateTime.now().year, 12, 31);
  
  // 마지막 업데이트 시간
  DateTime? _lastUpdated;
  
  // Getters
  List<Map<String, dynamic>> get salesSummaryData => _salesSummaryData;
  List<Map<String, dynamic>> get salesRawData => _salesRawData;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  DateTime get fromDate => _fromDate;
  DateTime get toDate => _toDate;
  DateTime? get lastUpdated => _lastUpdated;
  
  // 데이터가 있는지 확인
  bool get hasData => _salesSummaryData.isNotEmpty;
  
  // 캐시 유효성 확인 (1시간)
  bool get isCacheValid {
    if (_lastUpdated == null) return false;
    final now = DateTime.now();
    final difference = now.difference(_lastUpdated!);
    return difference.inHours < 1 && hasData;
  }
  
  // 통합매출분석 데이터 로드
  Future<void> loadSalesData({bool forceRefresh = false}) async {
    // 캐시가 유효하고 강제 새로고침이 아닌 경우 스킵
    if (isCacheValid && !forceRefresh) {
      print('[매출데이터] 캐시된 데이터 사용');
      return;
    }
    
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      print('[매출데이터] API 호출 시작: ${DateFormat('yyyy-MM-dd').format(_fromDate)} ~ ${DateFormat('yyyy-MM-dd').format(_toDate)}');
      
      // 매출요약 데이터 로드
      final summaryResult = await SalesService.getSalesSummary(
        fromDate: DateFormat('yyyy-MM-dd').format(_fromDate),
        toDate: DateFormat('yyyy-MM-dd').format(_toDate),
        period: 'monthly',
      );
      
      _salesSummaryData = List<Map<String, dynamic>>.from(summaryResult['data'] ?? []);
      
      // Raw 데이터도 로드 (필요한 경우) - 임시 주석 처리
      // final rawResult = await SalesService.getSalesRawData(
      //   fromDate: DateFormat('yyyy-MM-dd').format(_fromDate),
      //   toDate: DateFormat('yyyy-MM-dd').format(_toDate),
      // );
      
      // _salesRawData = List<Map<String, dynamic>>.from(rawResult['data'] ?? []);
      _salesRawData = []; // 임시로 빈 배열 설정
      
      _lastUpdated = DateTime.now();
      _errorMessage = '';
      
      print('[매출데이터] 로드 완료: 요약 ${_salesSummaryData.length}건');
      
    } catch (e) {
      _errorMessage = '매출 데이터 로드 실패: $e';
      _salesSummaryData = [];
      _salesRawData = [];
      print('[매출데이터] 로드 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 기간 변경 (필요한 경우)
  void updatePeriod(DateTime fromDate, DateTime toDate) {
    if (_fromDate != fromDate || _toDate != toDate) {
      _fromDate = fromDate;
      _toDate = toDate;
      // 기간이 변경되면 데이터 새로고침
      loadSalesData(forceRefresh: true);
    }
  }
  
  // 캐시 초기화
  void clearCache() {
    _salesSummaryData = [];
    _salesRawData = [];
    _lastUpdated = null;
    _errorMessage = '';
    notifyListeners();
  }
  
  // 특정 조건으로 데이터 필터링
  List<Map<String, dynamic>> getFilteredSummaryData({
    String? searchQuery,
    String? sortColumn,
    bool sortAscending = true,
  }) {
    var filtered = List<Map<String, dynamic>>.from(_salesSummaryData);
    
    // 검색 필터
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.values.any((value) => 
          value.toString().toLowerCase().contains(searchQuery.toLowerCase()));
      }).toList();
    }
    
    // 정렬
    if (sortColumn != null && sortColumn.isNotEmpty) {
      filtered.sort((a, b) {
        var aValue = a[sortColumn];
        var bValue = b[sortColumn];
        
        // null 처리
        if (aValue == null && bValue == null) return 0;
        if (aValue == null) return sortAscending ? -1 : 1;
        if (bValue == null) return sortAscending ? 1 : -1;
        
        // 숫자 비교
        if (aValue is num && bValue is num) {
          return sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
        }
        
        // 문자열 비교
        final result = aValue.toString().compareTo(bValue.toString());
        return sortAscending ? result : -result;
      });
    }
    
    return filtered;
  }
  
  // 통계 정보 계산
  Map<String, dynamic> getSummaryStats() {
    if (_salesSummaryData.isEmpty) {
      return {
        'totalSales': 0.0,
        'averageSales': 0.0,
        'topProduct': '',
        'totalOrders': 0,
      };
    }
    
    double totalSales = 0;
    int totalOrders = 0;
    
    for (var item in _salesSummaryData) {
      totalSales += (item['SUM_SALE_AMT_WON'] as num? ?? 0).toDouble();
      totalOrders += (item['ORDER_COUNT'] as num? ?? 0).toInt();
    }
    
    return {
      'totalSales': totalSales,
      'averageSales': _salesSummaryData.isNotEmpty ? totalSales / _salesSummaryData.length : 0.0,
      'totalOrders': totalOrders,
      'dataCount': _salesSummaryData.length,
    };
  }
}