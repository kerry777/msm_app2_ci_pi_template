import 'package:flutter/material.dart';
import '../models/analytics_data.dart';
import '../utils/unit_converter.dart';

class AdvancedFilterProvider extends ChangeNotifier {
  // 필터 상태
  List<FilterCondition> _conditions = [];
  FilterLogic _logic = FilterLogic.and;
  Map<String, List<String>> _quickFilters = {};
  DateRange? _dateRange;

  // 활성 필터 데이터
  List<Map<String, dynamic>> _originalData = [];
  List<Map<String, dynamic>> _filteredData = [];

  // 필터 히스토리
  final List<FilterSnapshot> _filterHistory = [];
  int _historyIndex = -1;

  // Getters
  List<FilterCondition> get conditions => _conditions;
  FilterLogic get logic => _logic;
  Map<String, List<String>> get quickFilters => _quickFilters;
  DateRange? get dateRange => _dateRange;
  List<Map<String, dynamic>> get filteredData => _filteredData;
  List<FilterSnapshot> get filterHistory => _filterHistory;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _filterHistory.length - 1;

  // 원본 데이터 설정
  void setOriginalData(List<Map<String, dynamic>> data) {
    _originalData = data;
    _filteredData = data;
    _saveToHistory('초기 데이터');
    notifyListeners();
  }

  // 조건 추가
  void addCondition(FilterCondition condition) {
    _conditions.add(condition);
    _applyFilters();
    _saveToHistory('조건 추가: ${condition.field}');
    notifyListeners();
  }

  // 조건 수정
  void updateCondition(int index, FilterCondition condition) {
    if (index >= 0 && index < _conditions.length) {
      _conditions[index] = condition;
      _applyFilters();
      _saveToHistory('조건 수정: ${condition.field}');
      notifyListeners();
    }
  }

  // 조건 삭제
  void removeCondition(int index) {
    if (index >= 0 && index < _conditions.length) {
      final condition = _conditions.removeAt(index);
      _applyFilters();
      _saveToHistory('조건 삭제: ${condition.field}');
      notifyListeners();
    }
  }

  // 로직 변경 (AND/OR)
  void setLogic(FilterLogic logic) {
    _logic = logic;
    _applyFilters();
    _saveToHistory('로직 변경: ${logic.name}');
    notifyListeners();
  }

  // 날짜 범위 설정
  void setDateRange(DateRange? range) {
    _dateRange = range;
    _applyFilters();
    _saveToHistory('날짜 범위 설정');
    notifyListeners();
  }

  // 빠른 필터 설정
  void setQuickFilter(String field, List<String> values) {
    if (values.isEmpty) {
      _quickFilters.remove(field);
    } else {
      _quickFilters[field] = values;
    }
    _applyFilters();
    _saveToHistory('빠른 필터: $field');
    notifyListeners();
  }

  // 모든 필터 지우기
  void clearAllFilters() {
    _conditions.clear();
    _quickFilters.clear();
    _dateRange = null;
    _logic = FilterLogic.and;
    _filteredData = _originalData;
    _saveToHistory('모든 필터 지우기');
    notifyListeners();
  }

  // 필터 적용
  void _applyFilters() {
    List<Map<String, dynamic>> data = List.from(_originalData);

    // 1. 날짜 범위 필터
    if (_dateRange != null) {
      data = _applyDateRangeFilter(data);
    }

    // 2. 빠른 필터
    data = _applyQuickFilters(data);

    // 3. 고급 조건 필터
    if (_conditions.isNotEmpty) {
      data = _applyConditionFilters(data);
    }

    _filteredData = data;
  }

  // 날짜 범위 필터 적용
  List<Map<String, dynamic>> _applyDateRangeFilter(List<Map<String, dynamic>> data) {
    if (_dateRange == null) return data;

    return data.where((item) {
      final dateFields = ['salesDate', 'date', 'createdAt', 'updatedAt'];

      for (final field in dateFields) {
        if (item.containsKey(field)) {
          final dateValue = _parseDate(item[field]);
          if (dateValue != null) {
            return dateValue.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
                   dateValue.isBefore(_dateRange!.end.add(const Duration(days: 1)));
          }
        }
      }
      return true; // 날짜 필드가 없으면 통과
    }).toList();
  }

  // 빠른 필터 적용
  List<Map<String, dynamic>> _applyQuickFilters(List<Map<String, dynamic>> data) {
    List<Map<String, dynamic>> filtered = data;

    for (final entry in _quickFilters.entries) {
      final field = entry.key;
      final values = entry.value;

      filtered = filtered.where((item) {
        final itemValue = item[field]?.toString() ?? '';
        return values.contains(itemValue);
      }).toList();
    }

    return filtered;
  }

  // 조건 필터 적용
  List<Map<String, dynamic>> _applyConditionFilters(List<Map<String, dynamic>> data) {
    return data.where((item) {
      if (_logic == FilterLogic.and) {
        return _conditions.every((condition) => _evaluateCondition(item, condition));
      } else {
        return _conditions.any((condition) => _evaluateCondition(item, condition));
      }
    }).toList();
  }

  // 개별 조건 평가
  bool _evaluateCondition(Map<String, dynamic> item, FilterCondition condition) {
    final itemValue = item[condition.field];
    final conditionValue = condition.value;

    switch (condition.operator) {
      case FilterOperator.equals:
        return _compareValues(itemValue, conditionValue, (a, b) => a == b);

      case FilterOperator.notEquals:
        return _compareValues(itemValue, conditionValue, (a, b) => a != b);

      case FilterOperator.greaterThan:
        return _compareNumeric(itemValue, conditionValue, (a, b) => a > b);

      case FilterOperator.greaterThanOrEqual:
        return _compareNumeric(itemValue, conditionValue, (a, b) => a >= b);

      case FilterOperator.lessThan:
        return _compareNumeric(itemValue, conditionValue, (a, b) => a < b);

      case FilterOperator.lessThanOrEqual:
        return _compareNumeric(itemValue, conditionValue, (a, b) => a <= b);

      case FilterOperator.contains:
        return _compareString(itemValue, conditionValue, (a, b) => a.contains(b));

      case FilterOperator.startsWith:
        return _compareString(itemValue, conditionValue, (a, b) => a.startsWith(b));

      case FilterOperator.endsWith:
        return _compareString(itemValue, conditionValue, (a, b) => a.endsWith(b));

      case FilterOperator.isEmpty:
        return itemValue == null || itemValue.toString().trim().isEmpty;

      case FilterOperator.isNotEmpty:
        return itemValue != null && itemValue.toString().trim().isNotEmpty;

      case FilterOperator.inList:
        if (condition.listValues != null) {
          return condition.listValues!.contains(itemValue?.toString());
        }
        return false;

      case FilterOperator.notInList:
        if (condition.listValues != null) {
          return !condition.listValues!.contains(itemValue?.toString());
        }
        return true;

      case FilterOperator.between:
        if (condition.rangeStart != null && condition.rangeEnd != null) {
          final numValue = _parseNumber(itemValue);
          if (numValue != null) {
            return numValue >= condition.rangeStart! && numValue <= condition.rangeEnd!;
          }
        }
        return false;

      case FilterOperator.regex:
        try {
          final regex = RegExp(condition.value.toString());
          return regex.hasMatch(itemValue?.toString() ?? '');
        } catch (e) {
          return false;
        }

      case FilterOperator.dateAfter:
        return _compareDates(itemValue, conditionValue, (a, b) => a.isAfter(b));

      case FilterOperator.dateBefore:
        return _compareDates(itemValue, conditionValue, (a, b) => a.isBefore(b));

      case FilterOperator.dateOn:
        return _compareDates(itemValue, conditionValue, (a, b) =>
          a.year == b.year && a.month == b.month && a.day == b.day);
    }
  }

  // 값 비교 (일반)
  bool _compareValues(dynamic a, dynamic b, bool Function(dynamic, dynamic) compare) {
    if (a == null || b == null) return false;
    return compare(a.toString(), b.toString());
  }

  // 숫자 비교
  bool _compareNumeric(dynamic a, dynamic b, bool Function(double, double) compare) {
    final numA = _parseNumber(a);
    final numB = _parseNumber(b);
    if (numA == null || numB == null) return false;
    return compare(numA, numB);
  }

  // 문자열 비교
  bool _compareString(dynamic a, dynamic b, bool Function(String, String) compare) {
    final strA = a?.toString().toLowerCase() ?? '';
    final strB = b?.toString().toLowerCase() ?? '';
    return compare(strA, strB);
  }

  // 날짜 비교
  bool _compareDates(dynamic a, dynamic b, bool Function(DateTime, DateTime) compare) {
    final dateA = _parseDate(a);
    final dateB = _parseDate(b);
    if (dateA == null || dateB == null) return false;
    return compare(dateA, dateB);
  }

  // 숫자 파싱
  double? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', ''));
    }
    return null;
  }

  // 날짜 파싱
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  // 필터 프리셋
  void applyPreset(FilterPreset preset) {
    _conditions.clear();
    _quickFilters.clear();
    _dateRange = null;

    switch (preset.type) {
      case PresetType.recentSales:
        _dateRange = DateRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );
        break;

      case PresetType.highValueSales:
        addCondition(FilterCondition(
          field: 'salesAmount',
          operator: FilterOperator.greaterThan,
          value: 1000000,
        ));
        break;

      case PresetType.specificRegion:
        if (preset.parameters != null && preset.parameters!.containsKey('region')) {
          setQuickFilter('region', [preset.parameters!['region']]);
        }
        break;

      case PresetType.productCategory:
        if (preset.parameters != null && preset.parameters!.containsKey('category')) {
          setQuickFilter('productCategory', [preset.parameters!['category']]);
        }
        break;

      case PresetType.custom:
        // 커스텀 프리셋은 별도 처리
        break;
    }

    _applyFilters();
    _saveToHistory('프리셋 적용: ${preset.name}');
    notifyListeners();
  }

  // 현재 필터를 프리셋으로 저장
  FilterPreset saveAsPreset(String name) {
    return FilterPreset(
      name: name,
      type: PresetType.custom,
      conditions: List.from(_conditions),
      logic: _logic,
      quickFilters: Map.from(_quickFilters),
      dateRange: _dateRange,
    );
  }

  // 히스토리 관리
  void _saveToHistory(String description) {
    // 현재 위치 이후의 히스토리 삭제 (새로운 분기 시작)
    if (_historyIndex < _filterHistory.length - 1) {
      _filterHistory.removeRange(_historyIndex + 1, _filterHistory.length);
    }

    final snapshot = FilterSnapshot(
      description: description,
      conditions: List.from(_conditions),
      logic: _logic,
      quickFilters: Map.from(_quickFilters),
      dateRange: _dateRange,
      timestamp: DateTime.now(),
    );

    _filterHistory.add(snapshot);
    _historyIndex = _filterHistory.length - 1;

    // 히스토리 크기 제한
    if (_filterHistory.length > 50) {
      _filterHistory.removeAt(0);
      _historyIndex--;
    }
  }

  // 실행 취소
  void undo() {
    if (canUndo) {
      _historyIndex--;
      _restoreFromSnapshot(_filterHistory[_historyIndex]);
      notifyListeners();
    }
  }

  // 다시 실행
  void redo() {
    if (canRedo) {
      _historyIndex++;
      _restoreFromSnapshot(_filterHistory[_historyIndex]);
      notifyListeners();
    }
  }

  // 스냅샷에서 복원
  void _restoreFromSnapshot(FilterSnapshot snapshot) {
    _conditions = List.from(snapshot.conditions);
    _logic = snapshot.logic;
    _quickFilters = Map.from(snapshot.quickFilters);
    _dateRange = snapshot.dateRange;
    _applyFilters();
  }

  // 필터 통계
  FilterStatistics getStatistics() {
    final originalCount = _originalData.length;
    final filteredCount = _filteredData.length;
    final filteredPercentage = originalCount > 0 ? (filteredCount / originalCount) * 100 : 0.0;

    return FilterStatistics(
      originalCount: originalCount,
      filteredCount: filteredCount,
      filteredPercentage: filteredPercentage,
      activeConditions: _conditions.length,
      activeQuickFilters: _quickFilters.length,
      hasDateRange: _dateRange != null,
    );
  }

  // 필터 검증
  List<FilterValidationError> validateFilters() {
    List<FilterValidationError> errors = [];

    for (int i = 0; i < _conditions.length; i++) {
      final condition = _conditions[i];

      // 필수 값 검증
      if (condition.operator.needsValue && condition.value == null) {
        errors.add(FilterValidationError(
          conditionIndex: i,
          field: condition.field,
          message: '값이 필요합니다.',
        ));
      }

      // 숫자 타입 검증
      if (condition.operator.isNumeric) {
        if (_parseNumber(condition.value) == null) {
          errors.add(FilterValidationError(
            conditionIndex: i,
            field: condition.field,
            message: '숫자 값이 필요합니다.',
          ));
        }
      }

      // 날짜 타입 검증
      if (condition.operator.isDate) {
        if (_parseDate(condition.value) == null) {
          errors.add(FilterValidationError(
            conditionIndex: i,
            field: condition.field,
            message: '올바른 날짜 형식이 필요합니다.',
          ));
        }
      }

      // 범위 검증
      if (condition.operator == FilterOperator.between) {
        if (condition.rangeStart == null || condition.rangeEnd == null) {
          errors.add(FilterValidationError(
            conditionIndex: i,
            field: condition.field,
            message: '시작값과 끝값이 모두 필요합니다.',
          ));
        } else if (condition.rangeStart! > condition.rangeEnd!) {
          errors.add(FilterValidationError(
            conditionIndex: i,
            field: condition.field,
            message: '시작값이 끝값보다 작아야 합니다.',
          ));
        }
      }

      // 정규식 검증
      if (condition.operator == FilterOperator.regex) {
        try {
          RegExp(condition.value.toString());
        } catch (e) {
          errors.add(FilterValidationError(
            conditionIndex: i,
            field: condition.field,
            message: '올바른 정규식이 아닙니다.',
          ));
        }
      }
    }

    return errors;
  }
}

// 필터 조건
class FilterCondition {
  final String field;
  final FilterOperator operator;
  final dynamic value;
  final List<String>? listValues;
  final double? rangeStart;
  final double? rangeEnd;

  const FilterCondition({
    required this.field,
    required this.operator,
    this.value,
    this.listValues,
    this.rangeStart,
    this.rangeEnd,
  });

  FilterCondition copyWith({
    String? field,
    FilterOperator? operator,
    dynamic value,
    List<String>? listValues,
    double? rangeStart,
    double? rangeEnd,
  }) {
    return FilterCondition(
      field: field ?? this.field,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      listValues: listValues ?? this.listValues,
      rangeStart: rangeStart ?? this.rangeStart,
      rangeEnd: rangeEnd ?? this.rangeEnd,
    );
  }
}

// 필터 연산자
enum FilterOperator {
  equals,
  notEquals,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  contains,
  startsWith,
  endsWith,
  isEmpty,
  isNotEmpty,
  inList,
  notInList,
  between,
  regex,
  dateAfter,
  dateBefore,
  dateOn,
}

extension FilterOperatorExtension on FilterOperator {
  String get displayName {
    switch (this) {
      case FilterOperator.equals: return '같음';
      case FilterOperator.notEquals: return '같지 않음';
      case FilterOperator.greaterThan: return '보다 큰';
      case FilterOperator.greaterThanOrEqual: return '보다 크거나 같음';
      case FilterOperator.lessThan: return '보다 작은';
      case FilterOperator.lessThanOrEqual: return '보다 작거나 같음';
      case FilterOperator.contains: return '포함';
      case FilterOperator.startsWith: return '시작';
      case FilterOperator.endsWith: return '끝';
      case FilterOperator.isEmpty: return '비어있음';
      case FilterOperator.isNotEmpty: return '비어있지 않음';
      case FilterOperator.inList: return '목록에 있음';
      case FilterOperator.notInList: return '목록에 없음';
      case FilterOperator.between: return '사이';
      case FilterOperator.regex: return '정규식';
      case FilterOperator.dateAfter: return '이후';
      case FilterOperator.dateBefore: return '이전';
      case FilterOperator.dateOn: return '당일';
    }
  }

  bool get needsValue {
    return ![FilterOperator.isEmpty, FilterOperator.isNotEmpty].contains(this);
  }

  bool get isNumeric {
    return [
      FilterOperator.greaterThan,
      FilterOperator.greaterThanOrEqual,
      FilterOperator.lessThan,
      FilterOperator.lessThanOrEqual,
      FilterOperator.between,
    ].contains(this);
  }

  bool get isDate {
    return [
      FilterOperator.dateAfter,
      FilterOperator.dateBefore,
      FilterOperator.dateOn,
    ].contains(this);
  }
}

// 필터 로직
enum FilterLogic {
  and,
  or,
}

extension FilterLogicExtension on FilterLogic {
  String get displayName {
    switch (this) {
      case FilterLogic.and: return 'AND (모든 조건)';
      case FilterLogic.or: return 'OR (임의 조건)';
    }
  }
}

// 날짜 범위
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({
    required this.start,
    required this.end,
  });

  DateRange copyWith({
    DateTime? start,
    DateTime? end,
  }) {
    return DateRange(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}

// 필터 프리셋
class FilterPreset {
  final String name;
  final PresetType type;
  final List<FilterCondition> conditions;
  final FilterLogic logic;
  final Map<String, List<String>> quickFilters;
  final DateRange? dateRange;
  final Map<String, dynamic>? parameters;

  const FilterPreset({
    required this.name,
    required this.type,
    this.conditions = const [],
    this.logic = FilterLogic.and,
    this.quickFilters = const {},
    this.dateRange,
    this.parameters,
  });
}

// 프리셋 타입
enum PresetType {
  recentSales,
  highValueSales,
  specificRegion,
  productCategory,
  custom,
}

// 필터 스냅샷 (히스토리용)
class FilterSnapshot {
  final String description;
  final List<FilterCondition> conditions;
  final FilterLogic logic;
  final Map<String, List<String>> quickFilters;
  final DateRange? dateRange;
  final DateTime timestamp;

  const FilterSnapshot({
    required this.description,
    required this.conditions,
    required this.logic,
    required this.quickFilters,
    this.dateRange,
    required this.timestamp,
  });
}

// 필터 통계
class FilterStatistics {
  final int originalCount;
  final int filteredCount;
  final double filteredPercentage;
  final int activeConditions;
  final int activeQuickFilters;
  final bool hasDateRange;

  const FilterStatistics({
    required this.originalCount,
    required this.filteredCount,
    required this.filteredPercentage,
    required this.activeConditions,
    required this.activeQuickFilters,
    required this.hasDateRange,
  });
}

// 필터 검증 오류
class FilterValidationError {
  final int conditionIndex;
  final String field;
  final String message;

  const FilterValidationError({
    required this.conditionIndex,
    required this.field,
    required this.message,
  });
}