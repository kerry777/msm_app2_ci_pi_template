import 'dart:async';
import 'package:flutter/foundation.dart';

/// Power BI 스타일 Master Filter 서비스
/// 여러 차트/위젯 간 동기화된 필터링 시스템
class MasterFilterService extends ChangeNotifier {
  static final MasterFilterService _instance = MasterFilterService._internal();
  factory MasterFilterService() => _instance;
  MasterFilterService._internal();

  // 글로벌 필터 상태
  final Map<String, MasterFilter> _activeFilters = {};
  final Map<String, Set<String>> _chartSubscriptions = {};
  final Map<String, FilterableWidget> _registeredWidgets = {};

  // 필터 히스토리 (실행 취소/다시 실행용)
  final List<Map<String, MasterFilter>> _filterHistory = [];
  int _historyIndex = -1;
  static const int maxHistorySize = 50;

  // 필터 변경 스트림
  final StreamController<FilterChangeEvent> _filterChangeController =
      StreamController<FilterChangeEvent>.broadcast();

  Stream<FilterChangeEvent> get filterChanges => _filterChangeController.stream;

  /// 위젯을 Master Filter 시스템에 등록
  void registerWidget(String widgetId, FilterableWidget widget) {
    _registeredWidgets[widgetId] = widget;
    debugPrint('🎯 Master Filter: Widget registered - $widgetId');
  }

  /// 위젯을 Master Filter 시스템에서 제거
  void unregisterWidget(String widgetId) {
    _registeredWidgets.remove(widgetId);
    _chartSubscriptions.remove(widgetId);
    debugPrint('🎯 Master Filter: Widget unregistered - $widgetId');
  }

  /// 차트가 특정 필터 필드를 구독 설정
  void subscribeToFilter(String widgetId, String filterField) {
    _chartSubscriptions[widgetId] ??= <String>{};
    _chartSubscriptions[widgetId]!.add(filterField);
    debugPrint('🎯 Master Filter: $widgetId subscribed to $filterField');
  }

  /// 차트의 특정 필터 필드 구독 해제
  void unsubscribeFromFilter(String widgetId, String filterField) {
    _chartSubscriptions[widgetId]?.remove(filterField);
    if (_chartSubscriptions[widgetId]?.isEmpty == true) {
      _chartSubscriptions.remove(widgetId);
    }
    debugPrint('🎯 Master Filter: $widgetId unsubscribed from $filterField');
  }

  /// Master Filter 적용 (다른 모든 구독 위젯에 전파)
  void applyMasterFilter(String sourceWidgetId, String filterField, List<String> selectedValues) {
    // 히스토리 저장
    _saveCurrentStateToHistory();

    // 필터 적용
    if (selectedValues.isEmpty) {
      _activeFilters.remove(filterField);
    } else {
      _activeFilters[filterField] = MasterFilter(
        field: filterField,
        selectedValues: selectedValues,
        sourceWidgetId: sourceWidgetId,
        appliedAt: DateTime.now(),
      );
    }

    // 구독 중인 모든 위젯에 필터 전파
    final affectedWidgets = <String>[];
    for (final entry in _chartSubscriptions.entries) {
      final widgetId = entry.key;
      final subscribedFields = entry.value;

      if (widgetId != sourceWidgetId && subscribedFields.contains(filterField)) {
        final widget = _registeredWidgets[widgetId];
        if (widget != null) {
          widget.applyMasterFilter(filterField, selectedValues);
          affectedWidgets.add(widgetId);
        }
      }
    }

    // 이벤트 발생
    final event = FilterChangeEvent(
      sourceWidgetId: sourceWidgetId,
      filterField: filterField,
      selectedValues: selectedValues,
      affectedWidgets: affectedWidgets,
    );

    _filterChangeController.add(event);
    notifyListeners();

    debugPrint('🎯 Master Filter Applied: $filterField -> ${selectedValues.length} values');
    debugPrint('🎯 Affected Widgets: ${affectedWidgets.join(", ")}');
  }

  /// 모든 Master Filter 지우기
  void clearAllFilters() {
    _saveCurrentStateToHistory();

    final clearedFields = _activeFilters.keys.toList();
    _activeFilters.clear();

    // 모든 위젯에 필터 해제 전파
    for (final widget in _registeredWidgets.values) {
      for (final field in clearedFields) {
        widget.clearMasterFilter(field);
      }
    }

    _filterChangeController.add(FilterChangeEvent(
      sourceWidgetId: 'system',
      filterField: '',
      selectedValues: [],
      affectedWidgets: _registeredWidgets.keys.toList(),
      isClearing: true,
    ));

    notifyListeners();
    debugPrint('🎯 Master Filter: All filters cleared');
  }

  /// 특정 필터 제거
  void removeFilter(String filterField) {
    if (_activeFilters.containsKey(filterField)) {
      _saveCurrentStateToHistory();

      _activeFilters.remove(filterField);

      // 해당 필터를 구독하는 모든 위젯에 제거 전파
      final affectedWidgets = <String>[];
      for (final entry in _chartSubscriptions.entries) {
        final widgetId = entry.key;
        final subscribedFields = entry.value;

        if (subscribedFields.contains(filterField)) {
          final widget = _registeredWidgets[widgetId];
          if (widget != null) {
            widget.clearMasterFilter(filterField);
            affectedWidgets.add(widgetId);
          }
        }
      }

      _filterChangeController.add(FilterChangeEvent(
        sourceWidgetId: 'system',
        filterField: filterField,
        selectedValues: [],
        affectedWidgets: affectedWidgets,
        isClearing: true,
      ));

      notifyListeners();
      debugPrint('🎯 Master Filter Removed: $filterField');
    }
  }

  /// 실행 취소
  void undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _restoreFromHistory(_filterHistory[_historyIndex]);
      debugPrint('🎯 Master Filter: Undo to history index $_historyIndex');
    }
  }

  /// 다시 실행
  void redo() {
    if (_historyIndex < _filterHistory.length - 1) {
      _historyIndex++;
      _restoreFromHistory(_filterHistory[_historyIndex]);
      debugPrint('🎯 Master Filter: Redo to history index $_historyIndex');
    }
  }

  /// 현재 상태를 히스토리에 저장
  void _saveCurrentStateToHistory() {
    // 현재 히스토리 인덱스 이후의 모든 항목 제거 (새로운 분기 시작)
    if (_historyIndex < _filterHistory.length - 1) {
      _filterHistory.removeRange(_historyIndex + 1, _filterHistory.length);
    }

    // 현재 상태 저장
    _filterHistory.add(Map<String, MasterFilter>.from(_activeFilters));
    _historyIndex = _filterHistory.length - 1;

    // 히스토리 크기 제한
    if (_filterHistory.length > maxHistorySize) {
      _filterHistory.removeAt(0);
      _historyIndex--;
    }
  }

  /// 히스토리에서 상태 복원
  void _restoreFromHistory(Map<String, MasterFilter> historyState) {
    _activeFilters.clear();
    _activeFilters.addAll(Map<String, MasterFilter>.from(historyState));

    // 모든 위젯에 복원된 필터 상태 적용
    for (final entry in _chartSubscriptions.entries) {
      final widgetId = entry.key;
      final subscribedFields = entry.value;
      final widget = _registeredWidgets[widgetId];

      if (widget != null) {
        for (final field in subscribedFields) {
          if (_activeFilters.containsKey(field)) {
            widget.applyMasterFilter(field, _activeFilters[field]!.selectedValues);
          } else {
            widget.clearMasterFilter(field);
          }
        }
      }
    }

    notifyListeners();
  }

  // Getters
  Map<String, MasterFilter> get activeFilters => Map.unmodifiable(_activeFilters);
  bool get hasActiveFilters => _activeFilters.isNotEmpty;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _filterHistory.length - 1;

  List<String> getFilterValues(String filterField) {
    return _activeFilters[filterField]?.selectedValues ?? [];
  }

  bool isFilterActive(String filterField) {
    return _activeFilters.containsKey(filterField);
  }

  /// 필터 정보 내보내기 (설정 저장용)
  Map<String, dynamic> exportFilters() {
    return {
      'filters': _activeFilters.map((key, filter) => MapEntry(key, filter.toJson())),
      'subscriptions': _chartSubscriptions.map((key, value) => MapEntry(key, value.toList())),
    };
  }

  /// 필터 정보 가져오기 (설정 복원용)
  void importFilters(Map<String, dynamic> data) {
    try {
      _activeFilters.clear();
      _chartSubscriptions.clear();

      final filtersData = data['filters'] as Map<String, dynamic>?;
      if (filtersData != null) {
        for (final entry in filtersData.entries) {
          _activeFilters[entry.key] = MasterFilter.fromJson(entry.value);
        }
      }

      final subscriptionsData = data['subscriptions'] as Map<String, dynamic>?;
      if (subscriptionsData != null) {
        for (final entry in subscriptionsData.entries) {
          _chartSubscriptions[entry.key] = Set<String>.from(entry.value);
        }
      }

      notifyListeners();
      debugPrint('🎯 Master Filter: Settings imported successfully');
    } catch (e) {
      debugPrint('🎯 Master Filter: Import failed - $e');
    }
  }

  @override
  void dispose() {
    _filterChangeController.close();
    super.dispose();
  }
}

/// Master Filter 데이터 클래스
class MasterFilter {
  final String field;
  final List<String> selectedValues;
  final String sourceWidgetId;
  final DateTime appliedAt;

  MasterFilter({
    required this.field,
    required this.selectedValues,
    required this.sourceWidgetId,
    required this.appliedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'selectedValues': selectedValues,
      'sourceWidgetId': sourceWidgetId,
      'appliedAt': appliedAt.toIso8601String(),
    };
  }

  factory MasterFilter.fromJson(Map<String, dynamic> json) {
    return MasterFilter(
      field: json['field'],
      selectedValues: List<String>.from(json['selectedValues']),
      sourceWidgetId: json['sourceWidgetId'],
      appliedAt: DateTime.parse(json['appliedAt']),
    );
  }
}

/// 필터 변경 이벤트
class FilterChangeEvent {
  final String sourceWidgetId;
  final String filterField;
  final List<String> selectedValues;
  final List<String> affectedWidgets;
  final bool isClearing;

  FilterChangeEvent({
    required this.sourceWidgetId,
    required this.filterField,
    required this.selectedValues,
    required this.affectedWidgets,
    this.isClearing = false,
  });
}

/// Master Filter를 지원하는 위젯이 구현해야 하는 인터페이스
abstract class FilterableWidget {
  void applyMasterFilter(String filterField, List<String> selectedValues);
  void clearMasterFilter(String filterField);
}