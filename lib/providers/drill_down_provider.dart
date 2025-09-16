import 'package:flutter/material.dart';
import '../models/analytics_data.dart';
import '../services/api_service.dart';
import '../services/sales_service.dart';
import 'auth_provider.dart';

class DrillDownProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AuthProvider _authProvider;

  // 현재 상태
  DrillDownState _currentState = DrillDownState(
    currentLevel: DrillDownLevel.region,
    currentData: [],
    breadcrumbPath: ['전체'],
    selectedItemId: null,
  );

  // 로딩 및 에러 상태
  bool _isLoading = false;
  String? _errorMessage;

  // 원본 데이터 캐시 (API 호출 최소화)
  List<Map<String, dynamic>>? _salesData; // getAgencySalesData 결과
  List<Map<String, dynamic>>? _hospitalData; // getHospitals 결과

  DrillDownProvider(this._authProvider);

  // Getters
  DrillDownState get currentState => _currentState;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 데이터 로드 및 초기화
  Future<void> initialize() async {
    await _loadInitialData();
    await _buildRegionData();
  }

  // 통합분석 매출 데이터 로드 (summary_sales)
  Future<void> _loadInitialData() async {
    _setLoading(true);
    _clearError();

    try {
      final trCd = _authProvider.userInfo?['MEK_TR_CD']?.toString() ?? '';
      if (trCd.isEmpty) {
        throw Exception('대리점 정보를 찾을 수 없습니다.');
      }

      print('=== DrillDownProvider 통합분석 매출 데이터 API 호출 시작 ===');
      print('trCd: $trCd');

      // 최근 6개월 매출 데이터 가져오기
      final DateTime toDate = DateTime.now();
      final DateTime fromDate = DateTime(toDate.year, toDate.month - 6, toDate.day);

      // 병원 목록과 통합분석 매출 데이터를 병행으로 호출
      final futures = await Future.wait([
        _apiService.getHospitals(trCd: trCd), // 병원 목록
        SalesService.getSalesSummary( // 통합분석 매출 데이터 (summary_sales)
          fromDate: '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}',
          toDate: '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}',
          period: 'daily',
        ),
      ]);

      _hospitalData = futures[0] as List<Map<String, dynamic>>;
      final summaryData = futures[1] as Map<String, dynamic>;
      _salesData = summaryData['data'] as List<Map<String, dynamic>> ?? [];

      print('=== 매출 API 데이터 로드 완료 ===');
      print('병원 데이터: ${_hospitalData?.length}개');
      print('매출 데이터: ${_salesData?.length}개');

      // 매출 데이터 구조 확인
      if (_salesData != null && _salesData!.isNotEmpty) {
        print('매출 데이터 샘플:');
        final sample = _salesData!.first;
        print('키: ${sample.keys}');
        print('샘플 값: ${sample.values.take(5).toList()}');
      }

    } catch (e) {
      print('DrillDown 매출 데이터 로드 오류: $e');
      _setError('매출 데이터를 불러올 수 없습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 지역별 매출 데이터 구성 (Level 1)
  Future<void> _buildRegionData() async {
    if (_salesData == null || _salesData!.isEmpty || _hospitalData == null) {
      _updateState(_currentState.copyWith(currentData: []));
      return;
    }

    print('=== 지역별 매출 데이터 구성 시작 ===');

    // 병원 ID별로 병원 정보 매핑
    final Map<String, Map<String, dynamic>> hospitalMap = {};
    for (final hospital in _hospitalData!) {
      final hospitalId = hospital['id']?.toString() ?? hospital['hospitalId']?.toString() ?? '';
      if (hospitalId.isNotEmpty) {
        hospitalMap[hospitalId] = hospital;
      }
    }

    // 지역별 매출 집계
    final Map<String, double> regionSales = {};
    final Map<String, Set<String>> regionHospitals = {};

    for (final sale in _salesData!) {
      // 매출 데이터에서 병원 ID와 매출액 추출
      final hospitalId = sale['hospitalId']?.toString() ?? sale['HOSPITAL_ID']?.toString() ?? '';
      final saleAmount = _parseDouble(sale['saleAmount']) ??
                        _parseDouble(sale['SALE_AMOUNT']) ??
                        _parseDouble(sale['amount']) ??
                        _parseDouble(sale['totalAmount']) ?? 0.0;

      if (hospitalId.isNotEmpty && saleAmount > 0) {
        final hospitalInfo = hospitalMap[hospitalId];
        if (hospitalInfo != null) {
          final hospitalName = hospitalInfo['hospitalName']?.toString() ??
                              hospitalInfo['HOSPITAL_NAME']?.toString() ?? '';
          final region = _extractRegionFromHospitalName(hospitalName);

          regionSales[region] = (regionSales[region] ?? 0.0) + saleAmount;
          regionHospitals.putIfAbsent(region, () => {}).add(hospitalId);
        }
      }
    }

    print('지역별 매출 집계 결과:');
    regionSales.forEach((region, sales) {
      print('- $region: ${sales.toStringAsFixed(0)}원 (${regionHospitals[region]?.length ?? 0}개 병원)');
    });

    // DrillDownData 객체로 변환
    final regionData = regionSales.entries.map((entry) {
      return DrillDownData(
        id: 'region_${entry.key}',
        name: entry.key,
        value: entry.value,
        level: DrillDownLevel.region,
        children: null,
      );
    }).toList();

    // 매출액 기준 내림차순 정렬
    regionData.sort((a, b) => b.value.compareTo(a.value));

    print('생성된 지역 데이터: ${regionData.length}개');

    _updateState(_currentState.copyWith(
      currentLevel: DrillDownLevel.region,
      currentData: regionData,
      breadcrumbPath: ['전체'],
      selectedItemId: null,
    ));
  }

  // 병원별 매출 데이터 구성 (Level 2)
  Future<void> _buildHospitalData(String regionId) async {
    if (_salesData == null || _hospitalData == null) {
      return;
    }

    final regionName = regionId.replaceAll('region_', '');
    print('=== 병원별 매출 데이터 구성: $regionName ===');

    // 병원 ID별로 병원 정보 매핑
    final Map<String, Map<String, dynamic>> hospitalMap = {};
    for (final hospital in _hospitalData!) {
      final hospitalId = hospital['id']?.toString() ?? hospital['hospitalId']?.toString() ?? '';
      if (hospitalId.isNotEmpty) {
        hospitalMap[hospitalId] = hospital;
      }
    }

    // 해당 지역의 병원별 매출 집계
    final Map<String, double> hospitalSales = {};

    for (final sale in _salesData!) {
      final hospitalId = sale['hospitalId']?.toString() ?? sale['HOSPITAL_ID']?.toString() ?? '';
      final saleAmount = _parseDouble(sale['saleAmount']) ??
                        _parseDouble(sale['SALE_AMOUNT']) ??
                        _parseDouble(sale['amount']) ??
                        _parseDouble(sale['totalAmount']) ?? 0.0;

      if (hospitalId.isNotEmpty && saleAmount > 0) {
        final hospitalInfo = hospitalMap[hospitalId];
        if (hospitalInfo != null) {
          final hospitalName = hospitalInfo['hospitalName']?.toString() ??
                              hospitalInfo['HOSPITAL_NAME']?.toString() ?? '';
          final region = _extractRegionFromHospitalName(hospitalName);

          if (region == regionName) {
            hospitalSales[hospitalName] = (hospitalSales[hospitalName] ?? 0.0) + saleAmount;
          }
        }
      }
    }

    // DrillDownData 객체로 변환
    final hospitalData = hospitalSales.entries.map((entry) {
      return DrillDownData(
        id: 'hospital_${entry.key}',
        name: entry.key,
        value: entry.value,
        level: DrillDownLevel.hospital,
        parentId: regionId,
        children: null,
      );
    }).toList();

    // 매출액 기준 내림차순 정렬
    hospitalData.sort((a, b) => b.value.compareTo(a.value));

    print('생성된 병원 데이터: ${hospitalData.length}개');

    _updateState(_currentState.copyWith(
      currentLevel: DrillDownLevel.hospital,
      currentData: hospitalData,
      breadcrumbPath: ['전체', regionName],
      selectedItemId: regionId,
    ));
  }

  // 상품별 매출 데이터 구성 (Level 3)
  Future<void> _buildProductData(String hospitalId) async {
    if (_salesData == null || _hospitalData == null) {
      return;
    }

    final hospitalName = hospitalId.replaceAll('hospital_', '');
    print('=== 상품별 매출 데이터 구성: $hospitalName ===');

    // 해당 병원의 상품별 매출 집계
    final Map<String, double> productSales = {};

    for (final sale in _salesData!) {
      // 병원명으로 필터링 (실제로는 hospitalId로 하는 것이 좋지만, 샘플 데이터 구조에 맞춤)
      final saleHospitalName = sale['hospitalName']?.toString() ??
                              sale['HOSPITAL_NAME']?.toString() ?? '';

      if (saleHospitalName == hospitalName) {
        final itemName = sale['itemName']?.toString() ??
                        sale['ITEM_NAME']?.toString() ??
                        sale['productName']?.toString() ?? '알 수 없는 상품';

        final saleAmount = _parseDouble(sale['saleAmount']) ??
                          _parseDouble(sale['SALE_AMOUNT']) ??
                          _parseDouble(sale['amount']) ??
                          _parseDouble(sale['totalAmount']) ?? 0.0;

        if (saleAmount > 0) {
          productSales[itemName] = (productSales[itemName] ?? 0.0) + saleAmount;
        }
      }
    }

    // DrillDownData 객체로 변환
    final productData = productSales.entries.map((entry) {
      return DrillDownData(
        id: 'product_${entry.key}',
        name: entry.key,
        value: entry.value,
        level: DrillDownLevel.product,
        parentId: hospitalId,
        children: null,
      );
    }).toList();

    // 매출액 기준 내림차순 정렬
    productData.sort((a, b) => b.value.compareTo(a.value));

    print('생성된 상품 데이터: ${productData.length}개');

    // breadcrumb 경로 업데이트
    final currentBreadcrumb = List<String>.from(_currentState.breadcrumbPath);
    if (currentBreadcrumb.length >= 2) {
      currentBreadcrumb.add(hospitalName);
    }

    _updateState(_currentState.copyWith(
      currentLevel: DrillDownLevel.product,
      currentData: productData,
      breadcrumbPath: currentBreadcrumb,
      selectedItemId: hospitalId,
    ));
  }

  // 드릴다운 실행
  Future<void> drillDown(String selectedItemId) async {
    _setLoading(true);
    _clearError();

    try {
      switch (_currentState.currentLevel) {
        case DrillDownLevel.region:
          await _buildHospitalData(selectedItemId);
          break;
        case DrillDownLevel.hospital:
          await _buildProductData(selectedItemId);
          break;
        case DrillDownLevel.product:
          // 상품 레벨에서는 더 이상 드릴다운할 수 없음
          print('상품 레벨에서는 더 이상 드릴다운할 수 없습니다.');
          break;
      }
    } catch (e) {
      print('드릴다운 오류: $e');
      _setError('드릴다운 처리 중 오류가 발생했습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 드릴업 실행 (상위 레벨로 이동)
  Future<void> drillUp() async {
    final breadcrumb = _currentState.breadcrumbPath;
    if (breadcrumb.length <= 1) {
      return; // 이미 최상위 레벨
    }

    _setLoading(true);

    try {
      switch (_currentState.currentLevel) {
        case DrillDownLevel.product:
          // 상품 -> 병원
          final regionName = breadcrumb.length >= 2 ? breadcrumb[1] : '';
          if (regionName.isNotEmpty) {
            await _buildHospitalData('region_$regionName');
          }
          break;
        case DrillDownLevel.hospital:
          // 병원 -> 지역
          await _buildRegionData();
          break;
        case DrillDownLevel.region:
          // 이미 최상위 레벨
          break;
      }
    } catch (e) {
      print('드릴업 오류: $e');
      _setError('드릴업 처리 중 오류가 발생했습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 특정 레벨로 직접 이동 (브레드크럼 클릭)
  Future<void> navigateToLevel(int levelIndex) async {
    if (levelIndex >= _currentState.breadcrumbPath.length) {
      return;
    }

    _setLoading(true);

    try {
      if (levelIndex == 0) {
        // 전체 (지역 레벨)
        await _buildRegionData();
      } else if (levelIndex == 1) {
        // 지역 레벨 -> 병원 레벨
        final regionName = _currentState.breadcrumbPath[1];
        await _buildHospitalData('region_$regionName');
      }
      // levelIndex == 2는 상품 레벨이므로 현재 상태 유지
    } catch (e) {
      print('레벨 네비게이션 오류: $e');
      _setError('네비게이션 처리 중 오류가 발생했습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 최상위 레벨로 리셋
  Future<void> resetToTop() async {
    await _buildRegionData();
  }

  // 데이터 새로고침
  Future<void> refresh() async {
    await _loadInitialData();
    await _buildRegionData();
  }

  // 유틸리티 메서드들
  String _extractRegionFromHospitalName(String hospitalName) {
    // 병원명에서 지역 추출 로직
    if (hospitalName.contains('서울')) return '서울';
    if (hospitalName.contains('부산')) return '부산';
    if (hospitalName.contains('대구')) return '대구';
    if (hospitalName.contains('인천')) return '인천';
    if (hospitalName.contains('광주')) return '광주';
    if (hospitalName.contains('대전')) return '대전';
    if (hospitalName.contains('울산')) return '울산';
    if (hospitalName.contains('경기')) return '경기';
    if (hospitalName.contains('강원')) return '강원';
    if (hospitalName.contains('충북')) return '충북';
    if (hospitalName.contains('충남')) return '충남';
    if (hospitalName.contains('전북')) return '전북';
    if (hospitalName.contains('전남')) return '전남';
    if (hospitalName.contains('경북')) return '경북';
    if (hospitalName.contains('경남')) return '경남';
    if (hospitalName.contains('제주')) return '제주';

    // 기본값
    return '기타';
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', ''));
    }
    return null;
  }

  void _updateState(DrillDownState newState) {
    _currentState = newState;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Provider 해제 시 정리
}