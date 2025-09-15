import 'package:flutter/foundation.dart';
import '../services/agency_sales_service.dart';

class AgencySalesProvider with ChangeNotifier {
  final AgencySalesService _agencySalesService = AgencySalesService();
  
  // 상태 변수들
  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _summaryData = [];
  List<Map<String, dynamic>> _analysisData = [];
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _historyData = [];
  List<Map<String, dynamic>> _mapData = [];
  List<Map<String, dynamic>> _regionalStatsData = [];
  
  bool _isLoading = false;
  String? _error;
  
  // 필터 변수들 (업그레이드)
  String? _selectedUserTrCd;
  String? _selectedStartDate;
  String? _selectedEndDate;
  List<String> _selectedHospitalIds = [];
  List<String> _selectedCellIds = [];
  List<String> _selectedItemCds = [];
  String? _selectedRegion;
  String? _selectedHospitalType;
  String? _selectedHospitalScale;
  String? _selectedSido;
  String? _selectedSigungu;
  String? _selectedEupmyeondong;
  String _selectedGroupBy = 'HOSPITAL';
  String _selectedAnalysisType = 'TREND';
  String _selectedChartType = 'DAILY';
  String _selectedExportType = 'DETAIL';
  int _selectedTopN = 10;
  
  // Getter들
  List<Map<String, dynamic>> get salesData => _salesData;
  List<Map<String, dynamic>> get summaryData => _summaryData;
  List<Map<String, dynamic>> get analysisData => _analysisData;
  List<Map<String, dynamic>> get chartData => _chartData;
  List<Map<String, dynamic>> get historyData => _historyData;
  List<Map<String, dynamic>> get mapData => _mapData;
  List<Map<String, dynamic>> get regionalStatsData => _regionalStatsData;
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  String? get selectedUserTrCd => _selectedUserTrCd;
  String? get selectedStartDate => _selectedStartDate;
  String? get selectedEndDate => _selectedEndDate;
  List<String> get selectedHospitalIds => _selectedHospitalIds;
  List<String> get selectedCellIds => _selectedCellIds;
  List<String> get selectedItemCds => _selectedItemCds;
  String? get selectedRegion => _selectedRegion;
  String? get selectedHospitalType => _selectedHospitalType;
  String? get selectedHospitalScale => _selectedHospitalScale;
  String? get selectedSido => _selectedSido;
  String? get selectedSigungu => _selectedSigungu;
  String? get selectedEupmyeondong => _selectedEupmyeondong;
  String get selectedGroupBy => _selectedGroupBy;
  String get selectedAnalysisType => _selectedAnalysisType;
  String get selectedChartType => _selectedChartType;
  String get selectedExportType => _selectedExportType;
  int get selectedTopN => _selectedTopN;
  
  // Setter들 (업그레이드)
  void setSelectedUserTrCd(String? value) {
    _selectedUserTrCd = value;
    notifyListeners();
  }
  
  void setSelectedStartDate(String? value) {
    _selectedStartDate = value;
    notifyListeners();
  }
  
  void setSelectedEndDate(String? value) {
    _selectedEndDate = value;
    notifyListeners();
  }
  
  void setSelectedHospitalIds(List<String> value) {
    _selectedHospitalIds = value;
    notifyListeners();
  }
  
  void setSelectedCellIds(List<String> value) {
    _selectedCellIds = value;
    notifyListeners();
  }
  
  void setSelectedItemCds(List<String> value) {
    _selectedItemCds = value;
    notifyListeners();
  }
  
  void setSelectedRegion(String? value) {
    _selectedRegion = value;
    notifyListeners();
  }
  
  void setSelectedHospitalType(String? value) {
    _selectedHospitalType = value;
    notifyListeners();
  }
  
  void setSelectedHospitalScale(String? value) {
    _selectedHospitalScale = value;
    notifyListeners();
  }
  
  void setSelectedSido(String? value) {
    _selectedSido = value;
    notifyListeners();
  }
  
  void setSelectedSigungu(String? value) {
    _selectedSigungu = value;
    notifyListeners();
  }
  
  void setSelectedEupmyeondong(String? value) {
    _selectedEupmyeondong = value;
    notifyListeners();
  }
  
  void setSelectedGroupBy(String value) {
    _selectedGroupBy = value;
    notifyListeners();
  }
  
  void setSelectedAnalysisType(String value) {
    _selectedAnalysisType = value;
    notifyListeners();
  }
  
  void setSelectedChartType(String value) {
    _selectedChartType = value;
    notifyListeners();
  }
  
  void setSelectedExportType(String value) {
    _selectedExportType = value;
    notifyListeners();
  }
  
  void setSelectedTopN(int value) {
    _selectedTopN = value;
    notifyListeners();
  }
  
  // 1. 대리점매출현황 기본 데이터 조회 (업그레이드)
  Future<void> loadSalesData() async {
    if (_selectedUserTrCd == null || _selectedStartDate == null || _selectedEndDate == null) {
      _error = '필수 파라미터가 누락되었습니다.';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[대리점매출현황] 기본 데이터 조회 시작');
      final response = await _agencySalesService.getAgencySalesData(
        userTrCd: _selectedUserTrCd!,
        startDate: _selectedStartDate!,
        endDate: _selectedEndDate!,
        hospitalIds: _selectedHospitalIds.isNotEmpty ? _selectedHospitalIds : null,
        cellIds: _selectedCellIds.isNotEmpty ? _selectedCellIds : null,
        itemCds: _selectedItemCds.isNotEmpty ? _selectedItemCds : null,
        region: _selectedRegion,
        hospitalType: _selectedHospitalType,
        hospitalScale: _selectedHospitalScale,
        sido: _selectedSido,
        sigungu: _selectedSigungu,
        eupmyeondong: _selectedEupmyeondong,
      );
      
      if (response['success'] == true) {
        _salesData = List<Map<String, dynamic>>.from(response['data'] ?? []);
        print('[대리점매출현황] 기본 데이터 조회 성공: ${_salesData.length}건');
      } else {
        _error = response['message'] ?? '데이터 조회에 실패했습니다.';
      }
    } catch (e) {
      print('[대리점매출현황] 기본 데이터 조회 실패: $e');
      _error = '데이터 조회 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 2. 대리점매출현황 고급 통계 조회 (업그레이드)
  Future<void> loadSummaryData() async {
    if (_selectedUserTrCd == null || _selectedStartDate == null || _selectedEndDate == null) {
      _error = '필수 파라미터가 누락되었습니다.';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[대리점매출현황] 고급 통계 조회 시작');
      final response = await _agencySalesService.getAgencySalesSummary(
        userTrCd: _selectedUserTrCd!,
        startDate: _selectedStartDate!,
        endDate: _selectedEndDate!,
        hospitalIds: _selectedHospitalIds.isNotEmpty ? _selectedHospitalIds : null,
        cellIds: _selectedCellIds.isNotEmpty ? _selectedCellIds : null,
        itemCds: _selectedItemCds.isNotEmpty ? _selectedItemCds : null,
        groupBy: _selectedGroupBy,
        topN: _selectedTopN,
        region: _selectedRegion,
        hospitalType: _selectedHospitalType,
        hospitalScale: _selectedHospitalScale,
        sido: _selectedSido,
        sigungu: _selectedSigungu,
        eupmyeondong: _selectedEupmyeondong,
      );
      
      if (response['success'] == true) {
        _summaryData = List<Map<String, dynamic>>.from(response['data'] ?? []);
        print('[대리점매출현황] 고급 통계 조회 성공: ${_summaryData.length}건');
      } else {
        _error = response['message'] ?? '통계 조회에 실패했습니다.';
      }
    } catch (e) {
      print('[대리점매출현황] 고급 통계 조회 실패: $e');
      _error = '통계 조회 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 3. 대리점매출현황 AI 분석 조회 (업그레이드)
  Future<void> loadAnalysisData() async {
    if (_selectedUserTrCd == null || _selectedStartDate == null || _selectedEndDate == null) {
      _error = '필수 파라미터가 누락되었습니다.';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[대리점매출현황] AI 분석 조회 시작');
      final response = await _agencySalesService.getAgencySalesAnalysis(
        userTrCd: _selectedUserTrCd!,
        startDate: _selectedStartDate!,
        endDate: _selectedEndDate!,
        hospitalIds: _selectedHospitalIds.isNotEmpty ? _selectedHospitalIds : null,
        cellIds: _selectedCellIds.isNotEmpty ? _selectedCellIds : null,
        itemCds: _selectedItemCds.isNotEmpty ? _selectedItemCds : null,
        analysisType: _selectedAnalysisType,
        topN: _selectedTopN,
        region: _selectedRegion,
        hospitalType: _selectedHospitalType,
        hospitalScale: _selectedHospitalScale,
        sido: _selectedSido,
        sigungu: _selectedSigungu,
        eupmyeondong: _selectedEupmyeondong,
      );
      
      if (response['success'] == true) {
        _analysisData = List<Map<String, dynamic>>.from(response['data'] ?? []);
        print('[대리점매출현황] AI 분석 조회 성공: ${_analysisData.length}건');
      } else {
        _error = response['message'] ?? '분석 조회에 실패했습니다.';
      }
    } catch (e) {
      print('[대리점매출현황] AI 분석 조회 실패: $e');
      _error = '분석 조회 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 4. 대리점매출현황 지도 데이터 조회 (새로 추가)
  Future<void> loadMapData() async {
    if (_selectedUserTrCd == null || _selectedStartDate == null || _selectedEndDate == null) {
      _error = '필수 파라미터가 누락되었습니다.';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[대리점매출현황] 지도 데이터 조회 시작');
      final response = await _agencySalesService.getAgencySalesMapData(
        userTrCd: _selectedUserTrCd!,
        startDate: _selectedStartDate!,
        endDate: _selectedEndDate!,
        hospitalIds: _selectedHospitalIds.isNotEmpty ? _selectedHospitalIds : null,
        cellIds: _selectedCellIds.isNotEmpty ? _selectedCellIds : null,
        itemCds: _selectedItemCds.isNotEmpty ? _selectedItemCds : null,
        region: _selectedRegion,
        hospitalType: _selectedHospitalType,
        hospitalScale: _selectedHospitalScale,
        sido: _selectedSido,
        sigungu: _selectedSigungu,
        eupmyeondong: _selectedEupmyeondong,
      );
      
      if (response['success'] == true) {
        _mapData = List<Map<String, dynamic>>.from(response['data'] ?? []);
        print('[대리점매출현황] 지도 데이터 조회 성공: ${_mapData.length}건');
      } else {
        _error = response['message'] ?? '지도 데이터 조회에 실패했습니다.';
      }
    } catch (e) {
      print('[대리점매출현황] 지도 데이터 조회 실패: $e');
      _error = '지도 데이터 조회 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 5. 대리점매출현황 지역별 통계 조회 (새로 추가)
  Future<void> loadRegionalStatsData() async {
    if (_selectedUserTrCd == null || _selectedStartDate == null || _selectedEndDate == null) {
      _error = '필수 파라미터가 누락되었습니다.';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[대리점매출현황] 지역별 통계 조회 시작');
      final response = await _agencySalesService.getAgencySalesRegionalStats(
        userTrCd: _selectedUserTrCd!,
        startDate: _selectedStartDate!,
        endDate: _selectedEndDate!,
        hospitalIds: _selectedHospitalIds.isNotEmpty ? _selectedHospitalIds : null,
        cellIds: _selectedCellIds.isNotEmpty ? _selectedCellIds : null,
        itemCds: _selectedItemCds.isNotEmpty ? _selectedItemCds : null,
        region: _selectedRegion,
        hospitalType: _selectedHospitalType,
        hospitalScale: _selectedHospitalScale,
        sido: _selectedSido,
        sigungu: _selectedSigungu,
        eupmyeondong: _selectedEupmyeondong,
      );
      
      if (response['success'] == true) {
        _regionalStatsData = List<Map<String, dynamic>>.from(response['data'] ?? []);
        print('[대리점매출현황] 지역별 통계 조회 성공: ${_regionalStatsData.length}건');
      } else {
        _error = response['message'] ?? '지역별 통계 조회에 실패했습니다.';
      }
    } catch (e) {
      print('[대리점매출현황] 지역별 통계 조회 실패: $e');
      _error = '지역별 통계 조회 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 6. 대리점매출현황 차트 데이터 조회 (업그레이드)
  Future<void> loadChartData() async {
    if (_selectedUserTrCd == null || _selectedStartDate == null || _selectedEndDate == null) {
      _error = '필수 파라미터가 누락되었습니다.';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[대리점매출현황] 차트 데이터 조회 시작');
      final response = await _agencySalesService.getAgencySalesChart(
        userTrCd: _selectedUserTrCd!,
        startDate: _selectedStartDate!,
        endDate: _selectedEndDate!,
        chartType: _selectedChartType,
        hospitalIds: _selectedHospitalIds.isNotEmpty ? _selectedHospitalIds : null,
        cellIds: _selectedCellIds.isNotEmpty ? _selectedCellIds : null,
        itemCds: _selectedItemCds.isNotEmpty ? _selectedItemCds : null,
        region: _selectedRegion,
        hospitalType: _selectedHospitalType,
        hospitalScale: _selectedHospitalScale,
        sido: _selectedSido,
        sigungu: _selectedSigungu,
        eupmyeondong: _selectedEupmyeondong,
      );
      
      if (response['success'] == true) {
        _chartData = List<Map<String, dynamic>>.from(response['data'] ?? []);
        print('[대리점매출현황] 차트 데이터 조회 성공: ${_chartData.length}건');
      } else {
        _error = response['message'] ?? '차트 데이터 조회에 실패했습니다.';
      }
    } catch (e) {
      print('[대리점매출현황] 차트 데이터 조회 실패: $e');
      _error = '차트 데이터 조회 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 7. 대리점매출현황 이력 조회 (업그레이드)
  Future<void> loadHistoryData({String? hospitalId, String? itemCd, int limit = 100}) async {
    if (_selectedUserTrCd == null) {
      _error = '필수 파라미터가 누락되었습니다.';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[대리점매출현황] 이력 데이터 조회 시작');
      final response = await _agencySalesService.getAgencySalesHistory(
        userTrCd: _selectedUserTrCd!,
        hospitalId: hospitalId,
        itemCd: itemCd,
        limit: limit,
      );
      
      if (response['success'] == true) {
        _historyData = List<Map<String, dynamic>>.from(response['data'] ?? []);
        print('[대리점매출현황] 이력 데이터 조회 성공: ${_historyData.length}건');
      } else {
        _error = response['message'] ?? '이력 데이터 조회에 실패했습니다.';
      }
    } catch (e) {
      print('[대리점매출현황] 이력 데이터 조회 실패: $e');
      _error = '이력 데이터 조회 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 8. 대리점매출현황 엑셀 다운로드 (업그레이드)
  Future<Map<String, dynamic>> exportData() async {
    if (_selectedUserTrCd == null || _selectedStartDate == null || _selectedEndDate == null) {
      _error = '필수 파라미터가 누락되었습니다.';
      notifyListeners();
      return {};
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[대리점매출현황] 엑셀 다운로드 시작');
      final response = await _agencySalesService.exportAgencySales(
        userTrCd: _selectedUserTrCd!,
        startDate: _selectedStartDate!,
        endDate: _selectedEndDate!,
        hospitalIds: _selectedHospitalIds.isNotEmpty ? _selectedHospitalIds : null,
        cellIds: _selectedCellIds.isNotEmpty ? _selectedCellIds : null,
        itemCds: _selectedItemCds.isNotEmpty ? _selectedItemCds : null,
        exportType: _selectedExportType,
        region: _selectedRegion,
        hospitalType: _selectedHospitalType,
        hospitalScale: _selectedHospitalScale,
        sido: _selectedSido,
        sigungu: _selectedSigungu,
        eupmyeondong: _selectedEupmyeondong,
      );
      
      if (response['status'] == 'success') {
        print('[대리점매출현황] 엑셀 다운로드 성공');
        return response;
      } else {
        _error = response['message'] ?? '엑셀 다운로드에 실패했습니다.';
        return {};
      }
    } catch (e) {
      print('[대리점매출현황] 엑셀 다운로드 실패: $e');
      _error = '엑셀 다운로드 중 오류가 발생했습니다: $e';
      return {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 9. 모든 데이터 초기화
  void clearAllData() {
    _salesData = [];
    _summaryData = [];
    _analysisData = [];
    _chartData = [];
    _historyData = [];
    _mapData = [];
    _regionalStatsData = [];
    _error = null;
    notifyListeners();
  }
  
  // 10. 필터 초기화
  void clearFilters() {
    _selectedHospitalIds = [];
    _selectedCellIds = [];
    _selectedItemCds = [];
    _selectedRegion = null;
    _selectedHospitalType = null;
    _selectedHospitalScale = null;
    _selectedSido = null;
    _selectedSigungu = null;
    _selectedEupmyeondong = null;
    _selectedGroupBy = 'HOSPITAL';
    _selectedAnalysisType = 'TREND';
    _selectedChartType = 'DAILY';
    _selectedExportType = 'DETAIL';
    _selectedTopN = 10;
    notifyListeners();
  }
  
  // 11. 테스트 API 호출
  Future<void> testApi() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('[대리점매출현황] 테스트 API 호출 시작');
      final response = await _agencySalesService.testAgencySales();
      
      if (response['status'] == 'success') {
        print('[대리점매출현황] 테스트 API 성공');
      } else {
        _error = response['message'] ?? '테스트 API 호출에 실패했습니다.';
      }
    } catch (e) {
      print('[대리점매출현황] 테스트 API 실패: $e');
      _error = '테스트 API 호출 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 