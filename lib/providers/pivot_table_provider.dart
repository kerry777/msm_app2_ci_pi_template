import 'package:flutter/material.dart';
import '../models/analytics_data.dart';
import '../services/sales_service.dart';
import '../utils/unit_converter.dart';
import 'auth_provider.dart';

class PivotTableProvider extends ChangeNotifier {
  final AuthProvider _authProvider;

  // 피벗 테이블 상태
  PivotTableConfiguration _config = PivotTableConfiguration();
  List<Map<String, dynamic>> _rawData = [];
  List<List<dynamic>> _pivotData = [];
  bool _isLoading = false;
  String? _errorMessage;

  // 사용 가능한 필드 정보
  List<PivotField> _availableFields = [];
  Map<String, List<String>> _fieldValues = {};

  // 계산된 필드들
  final List<CalculatedField> _calculatedFields = [];

  PivotTableProvider(this._authProvider) {
    _initializeFields();
  }

  // Getters
  PivotTableConfiguration get config => _config;
  List<Map<String, dynamic>> get rawData => _rawData;
  List<List<dynamic>> get pivotData => _pivotData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<PivotField> get availableFields => _availableFields;
  Map<String, List<String>> get fieldValues => _fieldValues;
  List<CalculatedField> get calculatedFields => _calculatedFields;

  // 피벗 테이블 초기화
  Future<void> initialize() async {
    await _loadData();
    _buildPivotTable();
  }

  // 기본 필드 초기화
  void _initializeFields() {
    _availableFields = [
      PivotField(
        name: 'region',
        displayName: '지역',
        type: FieldType.dimension,
        category: 'location',
      ),
      PivotField(
        name: 'hospitalName',
        displayName: '병원명',
        type: FieldType.dimension,
        category: 'hospital',
      ),
      PivotField(
        name: 'hospitalType',
        displayName: '병원종류',
        type: FieldType.dimension,
        category: 'hospital',
      ),
      PivotField(
        name: 'productName',
        displayName: '제품명',
        type: FieldType.dimension,
        category: 'product',
      ),
      PivotField(
        name: 'productCategory',
        displayName: '제품분류',
        type: FieldType.dimension,
        category: 'product',
      ),
      PivotField(
        name: 'salesDate',
        displayName: '매출일자',
        type: FieldType.date,
        category: 'time',
      ),
      PivotField(
        name: 'salesAmount',
        displayName: '매출액',
        type: FieldType.measure,
        category: 'sales',
        aggregationType: AggregationType.sum,
      ),
      PivotField(
        name: 'quantity',
        displayName: '수량',
        type: FieldType.measure,
        category: 'sales',
        aggregationType: AggregationType.sum,
      ),
      PivotField(
        name: 'unitPrice',
        displayName: '단가',
        type: FieldType.measure,
        category: 'sales',
        aggregationType: AggregationType.average,
      ),
    ];
  }

  // 통합분석 데이터 로드
  Future<void> _loadData() async {
    _setLoading(true);
    _clearError();

    try {
      // 최근 6개월 데이터 가져오기
      final DateTime toDate = DateTime.now();
      final DateTime fromDate = DateTime(toDate.year, toDate.month - 6, toDate.day);

      print('=== PivotTableProvider 통합분석 데이터 로드 시작 ===');

      // 여러 분석 데이터를 병렬로 로드
      final futures = await Future.wait([
        SalesService.getSalesSummary(
          fromDate: '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}',
          toDate: '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}',
          period: 'daily',
        ),
        SalesService.getHospitalAnalysis(
          fromDate: '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}',
          toDate: '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}',
          topN: 100,
        ),
        SalesService.getProductAnalysis(
          fromDate: '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}',
          toDate: '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}',
          topN: 100,
        ),
      ]);

      // 데이터 통합 및 정규화
      _rawData = _combineDataSources(futures);

      // 필드값 추출
      _extractFieldValues();

      print('피벗 테이블 데이터 로드 완료: ${_rawData.length}개');

    } catch (e) {
      print('피벗 테이블 데이터 로드 오류: $e');
      _setError('피벗 테이블 데이터를 불러올 수 없습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 여러 데이터 소스 통합
  List<Map<String, dynamic>> _combineDataSources(List<Map<String, dynamic>> sources) {
    List<Map<String, dynamic>> combined = [];

    for (var source in sources) {
      if (source['data'] is List) {
        combined.addAll((source['data'] as List).cast<Map<String, dynamic>>());
      }
    }

    // 데이터 정규화 및 표준화
    return combined.map((item) => _normalizeDataItem(item)).toList();
  }

  // 데이터 아이템 정규화
  Map<String, dynamic> _normalizeDataItem(Map<String, dynamic> item) {
    return {
      'region': _extractRegion(item['hospitalName']?.toString() ?? ''),
      'hospitalName': item['hospitalName']?.toString() ?? '',
      'hospitalType': item['hospitalType']?.toString() ?? '종합병원',
      'productName': item['productName']?.toString() ?? item['itemName']?.toString() ?? '',
      'productCategory': _extractProductCategory(item['productName']?.toString() ?? item['itemName']?.toString() ?? ''),
      'salesDate': item['salesDate']?.toString() ?? item['date']?.toString() ?? DateTime.now().toIso8601String(),
      'salesAmount': _parseDouble(item['salesAmount'] ?? item['amount'] ?? 0),
      'quantity': _parseDouble(item['quantity'] ?? item['qty'] ?? 0),
      'unitPrice': _parseDouble(item['unitPrice'] ?? item['price'] ?? 0),
    };
  }

  // 지역 추출
  String _extractRegion(String hospitalName) {
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
    return '기타';
  }

  // 제품 카테고리 추출
  String _extractProductCategory(String productName) {
    if (productName.contains('주사') || productName.contains('바늘') || productName.contains('링거')) {
      return '주사용품';
    } else if (productName.contains('수술') || productName.contains('메스') || productName.contains('가위')) {
      return '수술용품';
    } else if (productName.contains('검사') || productName.contains('시약') || productName.contains('키트')) {
      return '검사용품';
    } else if (productName.contains('드레싱') || productName.contains('거즈') || productName.contains('붕대')) {
      return '드레싱용품';
    } else if (productName.contains('카테터') || productName.contains('튜브')) {
      return '튜브류';
    } else {
      return '기타';
    }
  }

  // 필드값 추출
  void _extractFieldValues() {
    _fieldValues = {};

    if (_rawData.isEmpty) return;

    for (var field in _availableFields) {
      if (field.type == FieldType.dimension || field.type == FieldType.date) {
        Set<String> uniqueValues = {};

        for (var item in _rawData) {
          final value = item[field.name]?.toString() ?? '';
          if (value.isNotEmpty) {
            uniqueValues.add(value);
          }
        }

        _fieldValues[field.name] = uniqueValues.toList()..sort();
      }
    }
  }

  // 피벗 테이블 구성 업데이트
  void updateConfiguration(PivotTableConfiguration newConfig) {
    _config = newConfig;
    _buildPivotTable();
    notifyListeners();
  }

  // 행 필드 추가
  void addRowField(String fieldName) {
    if (!_config.rowFields.contains(fieldName)) {
      _config = _config.copyWith(
        rowFields: [..._config.rowFields, fieldName],
      );
      _buildPivotTable();
      notifyListeners();
    }
  }

  // 열 필드 추가
  void addColumnField(String fieldName) {
    if (!_config.columnFields.contains(fieldName)) {
      _config = _config.copyWith(
        columnFields: [..._config.columnFields, fieldName],
      );
      _buildPivotTable();
      notifyListeners();
    }
  }

  // 값 필드 추가
  void addValueField(String fieldName, AggregationType aggregation) {
    final valueField = ValueField(fieldName: fieldName, aggregation: aggregation);
    if (!_config.valueFields.any((vf) => vf.fieldName == fieldName && vf.aggregation == aggregation)) {
      _config = _config.copyWith(
        valueFields: [..._config.valueFields, valueField],
      );
      _buildPivotTable();
      notifyListeners();
    }
  }

  // 필터 추가
  void addFilter(String fieldName, List<String> values) {
    final newFilters = Map<String, List<String>>.from(_config.filters);
    newFilters[fieldName] = values;

    _config = _config.copyWith(filters: newFilters);
    _buildPivotTable();
    notifyListeners();
  }

  // 피벗 테이블 구축
  void _buildPivotTable() {
    if (_rawData.isEmpty) {
      _pivotData = [];
      return;
    }

    try {
      // 1. 필터 적용
      final filteredData = _applyFilters(_rawData);

      // 2. 그룹핑
      final groupedData = _groupData(filteredData);

      // 3. 집계
      final aggregatedData = _aggregateData(groupedData);

      // 4. 피벗 테이블 생성
      _pivotData = _createPivotMatrix(aggregatedData);

    } catch (e) {
      print('피벗 테이블 구축 오류: $e');
      _setError('피벗 테이블을 구축할 수 없습니다: $e');
    }
  }

  // 필터 적용
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> data) {
    List<Map<String, dynamic>> filtered = data;

    for (var entry in _config.filters.entries) {
      final fieldName = entry.key;
      final filterValues = entry.value;

      if (filterValues.isNotEmpty) {
        filtered = filtered.where((item) {
          final value = item[fieldName]?.toString() ?? '';
          return filterValues.contains(value);
        }).toList();
      }
    }

    return filtered;
  }

  // 데이터 그룹핑
  Map<String, List<Map<String, dynamic>>> _groupData(List<Map<String, dynamic>> data) {
    Map<String, List<Map<String, dynamic>>> groups = {};

    for (var item in data) {
      final groupKey = _createGroupKey(item);
      groups.putIfAbsent(groupKey, () => []).add(item);
    }

    return groups;
  }

  // 그룹 키 생성
  String _createGroupKey(Map<String, dynamic> item) {
    List<String> keyParts = [];

    // 행 필드
    for (var fieldName in _config.rowFields) {
      keyParts.add('${item[fieldName] ?? ''}');
    }

    // 열 필드
    for (var fieldName in _config.columnFields) {
      keyParts.add('${item[fieldName] ?? ''}');
    }

    return keyParts.join('|');
  }

  // 데이터 집계
  Map<String, Map<String, dynamic>> _aggregateData(Map<String, List<Map<String, dynamic>>> groupedData) {
    Map<String, Map<String, dynamic>> aggregated = {};

    for (var entry in groupedData.entries) {
      final groupKey = entry.key;
      final groupItems = entry.value;

      Map<String, dynamic> aggregatedValues = {};

      for (var valueField in _config.valueFields) {
        final fieldName = valueField.fieldName;
        final aggregation = valueField.aggregation;

        final values = groupItems
            .map((item) => _parseDouble(item[fieldName] ?? 0))
            .where((value) => value != 0)
            .toList();

        if (values.isNotEmpty) {
          switch (aggregation) {
            case AggregationType.sum:
              aggregatedValues['${fieldName}_sum'] = values.fold(0.0, (a, b) => a + b);
              break;
            case AggregationType.average:
              aggregatedValues['${fieldName}_avg'] = values.fold(0.0, (a, b) => a + b) / values.length;
              break;
            case AggregationType.count:
              aggregatedValues['${fieldName}_count'] = values.length;
              break;
            case AggregationType.min:
              aggregatedValues['${fieldName}_min'] = values.reduce((a, b) => a < b ? a : b);
              break;
            case AggregationType.max:
              aggregatedValues['${fieldName}_max'] = values.reduce((a, b) => a > b ? a : b);
              break;
          }
        }
      }

      aggregated[groupKey] = aggregatedValues;
    }

    return aggregated;
  }

  // 피벗 매트릭스 생성
  List<List<dynamic>> _createPivotMatrix(Map<String, Map<String, dynamic>> aggregatedData) {
    if (aggregatedData.isEmpty) return [];

    // 행과 열 헤더 생성
    final rowHeaders = _generateRowHeaders();
    final columnHeaders = _generateColumnHeaders();

    // 매트릭스 초기화
    List<List<dynamic>> matrix = [];

    // 헤더 행 추가
    List<dynamic> headerRow = [''];
    headerRow.addAll(columnHeaders);
    matrix.add(headerRow);

    // 데이터 행 추가
    for (var rowHeader in rowHeaders) {
      List<dynamic> row = [rowHeader];

      for (var columnHeader in columnHeaders) {
        final key = '$rowHeader|$columnHeader';
        final data = aggregatedData[key];

        if (data != null && _config.valueFields.isNotEmpty) {
          final valueField = _config.valueFields.first;
          final aggregationKey = '${valueField.fieldName}_${_getAggregationSuffix(valueField.aggregation)}';
          row.add(data[aggregationKey] ?? 0);
        } else {
          row.add(0);
        }
      }

      matrix.add(row);
    }

    return matrix;
  }

  // 행 헤더 생성
  List<String> _generateRowHeaders() {
    if (_config.rowFields.isEmpty) return ['Total'];

    Set<String> headers = {};

    for (var item in _rawData) {
      List<String> headerParts = [];
      for (var fieldName in _config.rowFields) {
        headerParts.add(item[fieldName]?.toString() ?? '');
      }
      headers.add(headerParts.join(' / '));
    }

    return headers.toList()..sort();
  }

  // 열 헤더 생성
  List<String> _generateColumnHeaders() {
    if (_config.columnFields.isEmpty) {
      if (_config.valueFields.isNotEmpty) {
        return _config.valueFields
            .map((vf) => '${vf.fieldName} (${_getAggregationName(vf.aggregation)})')
            .toList();
      }
      return ['Total'];
    }

    Set<String> headers = {};

    for (var item in _rawData) {
      List<String> headerParts = [];
      for (var fieldName in _config.columnFields) {
        headerParts.add(item[fieldName]?.toString() ?? '');
      }
      headers.add(headerParts.join(' / '));
    }

    return headers.toList()..sort();
  }

  // 집계 타입 접미사
  String _getAggregationSuffix(AggregationType type) {
    switch (type) {
      case AggregationType.sum: return 'sum';
      case AggregationType.average: return 'avg';
      case AggregationType.count: return 'count';
      case AggregationType.min: return 'min';
      case AggregationType.max: return 'max';
    }
  }

  // 집계 타입 이름
  String _getAggregationName(AggregationType type) {
    switch (type) {
      case AggregationType.sum: return '합계';
      case AggregationType.average: return '평균';
      case AggregationType.count: return '개수';
      case AggregationType.min: return '최소';
      case AggregationType.max: return '최대';
    }
  }

  // 계산된 필드 추가
  void addCalculatedField(CalculatedField field) {
    _calculatedFields.add(field);
    _availableFields.add(PivotField(
      name: field.name,
      displayName: field.displayName,
      type: FieldType.measure,
      category: 'calculated',
      aggregationType: AggregationType.sum,
    ));

    // 계산된 값을 데이터에 추가
    _applyCalculatedField(field);
    notifyListeners();
  }

  // 계산된 필드 적용
  void _applyCalculatedField(CalculatedField field) {
    for (var item in _rawData) {
      try {
        final result = _evaluateExpression(field.formula, item);
        item[field.name] = result;
      } catch (e) {
        item[field.name] = 0;
        print('계산된 필드 오류 (${field.name}): $e');
      }
    }
  }

  // 수식 평가 (간단한 사칙연산)
  double _evaluateExpression(String formula, Map<String, dynamic> item) {
    String expression = formula;

    // 필드명을 실제 값으로 치환
    for (var fieldName in ['salesAmount', 'quantity', 'unitPrice']) {
      final value = _parseDouble(item[fieldName] ?? 0);
      expression = expression.replaceAll(fieldName, value.toString());
    }

    // 간단한 사칙연산 평가 (실제로는 더 복잡한 파서가 필요)
    return _simpleCalculate(expression);
  }

  // 간단한 계산기
  double _simpleCalculate(String expression) {
    // 매우 기본적인 구현 - 실제로는 expression_parser 같은 패키지 사용 권장
    try {
      expression = expression.replaceAll(' ', '');

      // 곱셈과 나눗셈 먼저 처리
      while (expression.contains('*') || expression.contains('/')) {
        final multiplyMatch = RegExp(r'(\d+(?:\.\d+)?)\*(\d+(?:\.\d+)?)').firstMatch(expression);
        if (multiplyMatch != null) {
          final result = double.parse(multiplyMatch.group(1)!) * double.parse(multiplyMatch.group(2)!);
          expression = expression.replaceFirst(multiplyMatch.group(0)!, result.toString());
          continue;
        }

        final divideMatch = RegExp(r'(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)').firstMatch(expression);
        if (divideMatch != null) {
          final divisor = double.parse(divideMatch.group(2)!);
          if (divisor != 0) {
            final result = double.parse(divideMatch.group(1)!) / divisor;
            expression = expression.replaceFirst(divideMatch.group(0)!, result.toString());
          }
          continue;
        }
        break;
      }

      // 덧셈과 뺄셈 처리
      while (expression.contains('+') || expression.contains('-')) {
        final addMatch = RegExp(r'(\d+(?:\.\d+)?)\+(\d+(?:\.\d+)?)').firstMatch(expression);
        if (addMatch != null) {
          final result = double.parse(addMatch.group(1)!) + double.parse(addMatch.group(2)!);
          expression = expression.replaceFirst(addMatch.group(0)!, result.toString());
          continue;
        }

        final subtractMatch = RegExp(r'(\d+(?:\.\d+)?)-(\d+(?:\.\d+)?)').firstMatch(expression);
        if (subtractMatch != null) {
          final result = double.parse(subtractMatch.group(1)!) - double.parse(subtractMatch.group(2)!);
          expression = expression.replaceFirst(subtractMatch.group(0)!, result.toString());
          continue;
        }
        break;
      }

      return double.tryParse(expression) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // 엑셀 내보내기
  Future<String?> exportToExcel() async {
    try {
      // ExcelService나 다른 엑셀 처리 서비스를 사용하여 내보내기
      // 현재는 기본 구현
      return null;
    } catch (e) {
      _setError('엑셀 내보내기 실패: $e');
      return null;
    }
  }

  // 유틸리티 메서드들
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
    }
    return 0.0;
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

}

// 피벗 테이블 설정 클래스
class PivotTableConfiguration {
  final List<String> rowFields;
  final List<String> columnFields;
  final List<ValueField> valueFields;
  final Map<String, List<String>> filters;
  final bool showSubtotals;
  final bool showGrandTotal;

  const PivotTableConfiguration({
    this.rowFields = const [],
    this.columnFields = const [],
    this.valueFields = const [],
    this.filters = const {},
    this.showSubtotals = true,
    this.showGrandTotal = true,
  });

  PivotTableConfiguration copyWith({
    List<String>? rowFields,
    List<String>? columnFields,
    List<ValueField>? valueFields,
    Map<String, List<String>>? filters,
    bool? showSubtotals,
    bool? showGrandTotal,
  }) {
    return PivotTableConfiguration(
      rowFields: rowFields ?? this.rowFields,
      columnFields: columnFields ?? this.columnFields,
      valueFields: valueFields ?? this.valueFields,
      filters: filters ?? this.filters,
      showSubtotals: showSubtotals ?? this.showSubtotals,
      showGrandTotal: showGrandTotal ?? this.showGrandTotal,
    );
  }
}

// 피벗 필드 정보
class PivotField {
  final String name;
  final String displayName;
  final FieldType type;
  final String category;
  final AggregationType? aggregationType;

  const PivotField({
    required this.name,
    required this.displayName,
    required this.type,
    required this.category,
    this.aggregationType,
  });
}

// 값 필드
class ValueField {
  final String fieldName;
  final AggregationType aggregation;

  const ValueField({
    required this.fieldName,
    required this.aggregation,
  });
}

// 계산된 필드
class CalculatedField {
  final String name;
  final String displayName;
  final String formula;
  final FieldType resultType;

  const CalculatedField({
    required this.name,
    required this.displayName,
    required this.formula,
    this.resultType = FieldType.measure,
  });
}

// 필드 타입
enum FieldType {
  dimension,  // 차원 (카테고리 데이터)
  measure,    // 측정값 (수치 데이터)
  date,       // 날짜
  calculated, // 계산된 필드
}

// 집계 타입
enum AggregationType {
  sum,        // 합계
  average,    // 평균
  count,      // 개수
  min,        // 최소값
  max,        // 최대값
}