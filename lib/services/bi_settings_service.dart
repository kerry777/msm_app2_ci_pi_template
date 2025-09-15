import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/preferences_manager.dart';
import 'master_filter_service.dart';
import 'slide_show_service.dart';

/// BI 설정 영구 저장/복원 서비스
/// 통합분석의 PreferencesManager 기능을 활용하여 확장
class BISettingsService extends ChangeNotifier {
  static final BISettingsService _instance = BISettingsService._internal();
  factory BISettingsService() => _instance;
  BISettingsService._internal();

  // 설정 키 상수들
  static const String _keyPivotConfigurations = 'bi_pivot_configurations';
  static const String _keyChartConfigurations = 'bi_chart_configurations';
  static const String _keyDashboardLayouts = 'bi_dashboard_layouts';
  static const String _keySlideShowSettings = 'bi_slideshow_settings';
  static const String _keyMasterFilters = 'bi_master_filters';
  static const String _keyUserPreferences = 'bi_user_preferences';
  static const String _keyRecentAnalysis = 'bi_recent_analysis';
  static const String _keyFavoriteViews = 'bi_favorite_views';

  // 캐시된 설정들
  Map<String, PivotConfiguration> _pivotConfigurations = {};
  Map<String, ChartConfiguration> _chartConfigurations = {};
  Map<String, DashboardLayout> _dashboardLayouts = {};
  Map<String, AnalysisTemplate> _recentAnalysis = {};
  Set<String> _favoriteViews = {};
  BIUserPreferences _userPreferences = BIUserPreferences.defaults();

  bool _isInitialized = false;

  /// 서비스 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadAllSettings();
      _isInitialized = true;
      debugPrint('🎯 BI Settings: Initialized successfully');
    } catch (e) {
      debugPrint('🎯 BI Settings: Initialization failed - $e');
      // 기본값으로 초기화
      _initializeDefaults();
      _isInitialized = true;
    }
  }

  /// 모든 설정 로드
  Future<void> _loadAllSettings() async {
    await Future.wait([
      _loadPivotConfigurations(),
      _loadChartConfigurations(),
      _loadDashboardLayouts(),
      _loadRecentAnalysis(),
      _loadFavoriteViews(),
      _loadUserPreferences(),
    ]);
  }

  /// 기본값 초기화
  void _initializeDefaults() {
    _userPreferences = BIUserPreferences.defaults();
    _createDefaultConfigurations();
  }

  /// 기본 구성 생성
  void _createDefaultConfigurations() {
    // 기본 피벗 테이블 구성들
    _pivotConfigurations = {
      'regional_sales': PivotConfiguration(
        id: 'regional_sales',
        name: '지역별 매출 분석',
        description: '대륙 및 국가별 매출 분석',
        rowFields: ['CONTINENT', 'NATION_NAME'],
        columnFields: ['거래처분류'],
        valueFields: [
          PivotValueField('SUM_SALE_AMT_WON', 'sum', '매출액'),
          PivotValueField('SALE_Q', 'sum', '수량'),
        ],
        filters: {},
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
        useCount: 0,
        isFavorite: true,
      ),

      'customer_analysis': PivotConfiguration(
        id: 'customer_analysis',
        name: '고객별 분석',
        description: '거래처별 상세 매출 분석',
        rowFields: ['CUSTOM_NAME'],
        columnFields: ['UPDATE_DTM'],
        valueFields: [
          PivotValueField('SUM_SALE_AMT_WON', 'sum', '매출액'),
          PivotValueField('SALE_Q', 'avg', '평균수량'),
        ],
        filters: {},
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
        useCount: 0,
        isFavorite: false,
      ),
    };

    // 기본 차트 구성들
    _chartConfigurations = {
      'sales_trend': ChartConfiguration(
        id: 'sales_trend',
        name: '매출 트렌드',
        chartType: 'line',
        groupBy: 'UPDATE_DTM',
        valueField: 'SUM_SALE_AMT_WON',
        aggregation: 'sum',
        title: '월별 매출 트렌드',
        filters: {},
        timeGrouping: 'month',
      ),

      'regional_comparison': ChartConfiguration(
        id: 'regional_comparison',
        name: '지역별 비교',
        chartType: 'column',
        groupBy: 'CONTINENT',
        valueField: 'SUM_SALE_AMT_WON',
        aggregation: 'sum',
        title: '대륙별 매출 비교',
        filters: {},
      ),
    };

    // 기본 대시보드 레이아웃들
    _dashboardLayouts = {
      'executive_summary': DashboardLayout(
        id: 'executive_summary',
        name: '경영진 요약',
        description: '핵심 KPI 및 요약 정보',
        widgets: [
          DashboardWidget(
            id: 'kpi_cards',
            type: 'kpi',
            position: const DashboardPosition(0, 0, 4, 2),
            config: {'layout': 'horizontal'},
          ),
          DashboardWidget(
            id: 'sales_chart',
            type: 'chart',
            position: const DashboardPosition(0, 2, 6, 4),
            config: {'chartId': 'sales_trend'},
          ),
          DashboardWidget(
            id: 'regional_chart',
            type: 'chart',
            position: const DashboardPosition(6, 2, 6, 4),
            config: {'chartId': 'regional_comparison'},
          ),
        ],
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      ),
    };
  }

  /// 피벗 테이블 구성 저장
  Future<void> savePivotConfiguration(PivotConfiguration config) async {
    _pivotConfigurations[config.id] = config.copyWith(
      lastUsed: DateTime.now(),
      useCount: config.useCount + 1,
    );

    await _savePivotConfigurations();
    notifyListeners();
    debugPrint('🎯 BI Settings: Pivot configuration saved - ${config.name}');
  }

  /// 피벗 테이블 구성 로드
  PivotConfiguration? getPivotConfiguration(String id) {
    return _pivotConfigurations[id];
  }

  /// 피벗 테이블 구성 삭제
  Future<void> deletePivotConfiguration(String id) async {
    _pivotConfigurations.remove(id);
    await _savePivotConfigurations();
    notifyListeners();
    debugPrint('🎯 BI Settings: Pivot configuration deleted - $id');
  }

  /// 차트 구성 저장
  Future<void> saveChartConfiguration(ChartConfiguration config) async {
    _chartConfigurations[config.id] = config;
    await _saveChartConfigurations();
    notifyListeners();
    debugPrint('🎯 BI Settings: Chart configuration saved - ${config.name}');
  }

  /// 차트 구성 로드
  ChartConfiguration? getChartConfiguration(String id) {
    return _chartConfigurations[id];
  }

  /// 대시보드 레이아웃 저장
  Future<void> saveDashboardLayout(DashboardLayout layout) async {
    _dashboardLayouts[layout.id] = layout.copyWith(lastUsed: DateTime.now());
    await _saveDashboardLayouts();
    notifyListeners();
    debugPrint('🎯 BI Settings: Dashboard layout saved - ${layout.name}');
  }

  /// 대시보드 레이아웃 로드
  DashboardLayout? getDashboardLayout(String id) {
    return _dashboardLayouts[id];
  }

  /// 분석 템플릿을 최근 사용에 추가
  Future<void> addRecentAnalysis(AnalysisTemplate template) async {
    template = template.copyWith(lastUsed: DateTime.now());
    _recentAnalysis[template.id] = template;

    // 최대 20개까지만 유지
    if (_recentAnalysis.length > 20) {
      final sorted = _recentAnalysis.values.toList()
        ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));

      _recentAnalysis.clear();
      for (var i = 0; i < 20; i++) {
        _recentAnalysis[sorted[i].id] = sorted[i];
      }
    }

    await _saveRecentAnalysis();
    notifyListeners();
  }

  /// 즐겨찾기 추가/제거
  Future<void> toggleFavorite(String viewId) async {
    if (_favoriteViews.contains(viewId)) {
      _favoriteViews.remove(viewId);
    } else {
      _favoriteViews.add(viewId);
    }

    await _saveFavoriteViews();
    notifyListeners();
    debugPrint('🎯 BI Settings: Favorite toggled - $viewId');
  }

  /// 사용자 기본 설정 업데이트
  Future<void> updateUserPreferences(BIUserPreferences preferences) async {
    _userPreferences = preferences;
    await _saveUserPreferences();
    notifyListeners();
    debugPrint('🎯 BI Settings: User preferences updated');
  }

  /// 슬라이드쇼 설정 저장 (SlideShowService와 연동)
  Future<void> saveSlideShowSettings() async {
    final slideShowService = SlideShowService();
    final settings = slideShowService.exportSettings();
    await PreferencesManager.setString(_keySlideShowSettings, jsonEncode(settings));
    debugPrint('🎯 BI Settings: SlideShow settings saved');
  }

  /// 슬라이드쇼 설정 복원
  Future<void> loadSlideShowSettings() async {
    try {
      final settingsJson = await PreferencesManager.getString(_keySlideShowSettings);
      if (settingsJson != null) {
        final settings = jsonDecode(settingsJson);
        final slideShowService = SlideShowService();
        slideShowService.importSettings(settings);
        debugPrint('🎯 BI Settings: SlideShow settings loaded');
      }
    } catch (e) {
      debugPrint('🎯 BI Settings: SlideShow settings load failed - $e');
    }
  }

  /// Master Filter 설정 저장 (MasterFilterService와 연동)
  Future<void> saveMasterFilterSettings() async {
    final masterFilterService = MasterFilterService();
    final settings = masterFilterService.exportFilters();
    await PreferencesManager.setString(_keyMasterFilters, jsonEncode(settings));
    debugPrint('🎯 BI Settings: Master Filter settings saved');
  }

  /// Master Filter 설정 복원
  Future<void> loadMasterFilterSettings() async {
    try {
      final settingsJson = await PreferencesManager.getString(_keyMasterFilters);
      if (settingsJson != null) {
        final settings = jsonDecode(settingsJson);
        final masterFilterService = MasterFilterService();
        masterFilterService.importFilters(settings);
        debugPrint('🎯 BI Settings: Master Filter settings loaded');
      }
    } catch (e) {
      debugPrint('🎯 BI Settings: Master Filter settings load failed - $e');
    }
  }

  /// 전체 설정 백업
  Future<Map<String, dynamic>> exportAllSettings() async {
    await saveSlideShowSettings();
    await saveMasterFilterSettings();

    return {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'pivotConfigurations': _pivotConfigurations.map((k, v) => MapEntry(k, v.toJson())),
      'chartConfigurations': _chartConfigurations.map((k, v) => MapEntry(k, v.toJson())),
      'dashboardLayouts': _dashboardLayouts.map((k, v) => MapEntry(k, v.toJson())),
      'recentAnalysis': _recentAnalysis.map((k, v) => MapEntry(k, v.toJson())),
      'favoriteViews': _favoriteViews.toList(),
      'userPreferences': _userPreferences.toJson(),
      'slideShowSettings': PreferencesManager.getString(_keySlideShowSettings),
      'masterFilterSettings': PreferencesManager.getString(_keyMasterFilters),
    };
  }

  /// 전체 설정 복원
  Future<void> importAllSettings(Map<String, dynamic> data) async {
    try {
      // 피벗 구성 복원
      final pivotData = data['pivotConfigurations'] as Map<String, dynamic>?;
      if (pivotData != null) {
        _pivotConfigurations = pivotData.map(
          (k, v) => MapEntry(k, PivotConfiguration.fromJson(v)),
        );
      }

      // 차트 구성 복원
      final chartData = data['chartConfigurations'] as Map<String, dynamic>?;
      if (chartData != null) {
        _chartConfigurations = chartData.map(
          (k, v) => MapEntry(k, ChartConfiguration.fromJson(v)),
        );
      }

      // 대시보드 레이아웃 복원
      final dashboardData = data['dashboardLayouts'] as Map<String, dynamic>?;
      if (dashboardData != null) {
        _dashboardLayouts = dashboardData.map(
          (k, v) => MapEntry(k, DashboardLayout.fromJson(v)),
        );
      }

      // 최근 분석 복원
      final recentData = data['recentAnalysis'] as Map<String, dynamic>?;
      if (recentData != null) {
        _recentAnalysis = recentData.map(
          (k, v) => MapEntry(k, AnalysisTemplate.fromJson(v)),
        );
      }

      // 즐겨찾기 복원
      final favoritesData = data['favoriteViews'] as List<dynamic>?;
      if (favoritesData != null) {
        _favoriteViews = Set<String>.from(favoritesData);
      }

      // 사용자 기본 설정 복원
      final prefsData = data['userPreferences'] as Map<String, dynamic>?;
      if (prefsData != null) {
        _userPreferences = BIUserPreferences.fromJson(prefsData);
      }

      // 슬라이드쇼 설정 복원
      final slideShowData = data['slideShowSettings'] as String?;
      if (slideShowData != null) {
        await PreferencesManager.setString(_keySlideShowSettings, slideShowData);
        await loadSlideShowSettings();
      }

      // Master Filter 설정 복원
      final masterFilterData = data['masterFilterSettings'] as String?;
      if (masterFilterData != null) {
        await PreferencesManager.setString(_keyMasterFilters, masterFilterData);
        await loadMasterFilterSettings();
      }

      // 모든 설정 저장
      await _saveAllSettings();
      notifyListeners();

      debugPrint('🎯 BI Settings: All settings imported successfully');
    } catch (e) {
      debugPrint('🎯 BI Settings: Import failed - $e');
      throw Exception('설정 가져오기 실패: $e');
    }
  }

  /// 개별 저장 메서드들
  Future<void> _savePivotConfigurations() async {
    final json = _pivotConfigurations.map((k, v) => MapEntry(k, v.toJson()));
    await PreferencesManager.setString(_keyPivotConfigurations, jsonEncode(json));
  }

  Future<void> _loadPivotConfigurations() async {
    final json = await PreferencesManager.getString(_keyPivotConfigurations);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _pivotConfigurations = data.map((k, v) => MapEntry(k, PivotConfiguration.fromJson(v)));
    }
  }

  Future<void> _saveChartConfigurations() async {
    final json = _chartConfigurations.map((k, v) => MapEntry(k, v.toJson()));
    await PreferencesManager.setString(_keyChartConfigurations, jsonEncode(json));
  }

  Future<void> _loadChartConfigurations() async {
    final json = await PreferencesManager.getString(_keyChartConfigurations);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _chartConfigurations = data.map((k, v) => MapEntry(k, ChartConfiguration.fromJson(v)));
    }
  }

  Future<void> _saveDashboardLayouts() async {
    final json = _dashboardLayouts.map((k, v) => MapEntry(k, v.toJson()));
    await PreferencesManager.setString(_keyDashboardLayouts, jsonEncode(json));
  }

  Future<void> _loadDashboardLayouts() async {
    final json = await PreferencesManager.getString(_keyDashboardLayouts);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _dashboardLayouts = data.map((k, v) => MapEntry(k, DashboardLayout.fromJson(v)));
    }
  }

  Future<void> _saveRecentAnalysis() async {
    final json = _recentAnalysis.map((k, v) => MapEntry(k, v.toJson()));
    await PreferencesManager.setString(_keyRecentAnalysis, jsonEncode(json));
  }

  Future<void> _loadRecentAnalysis() async {
    final json = await PreferencesManager.getString(_keyRecentAnalysis);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _recentAnalysis = data.map((k, v) => MapEntry(k, AnalysisTemplate.fromJson(v)));
    }
  }

  Future<void> _saveFavoriteViews() async {
    await PreferencesManager.setStringList(_keyFavoriteViews, _favoriteViews.toList());
  }

  Future<void> _loadFavoriteViews() async {
    final favorites = await PreferencesManager.getStringList(_keyFavoriteViews);
    if (favorites != null) {
      _favoriteViews = Set<String>.from(favorites);
    }
  }

  Future<void> _saveUserPreferences() async {
    await PreferencesManager.setString(_keyUserPreferences, jsonEncode(_userPreferences.toJson()));
  }

  Future<void> _loadUserPreferences() async {
    final json = await PreferencesManager.getString(_keyUserPreferences);
    if (json != null) {
      _userPreferences = BIUserPreferences.fromJson(jsonDecode(json));
    }
  }

  Future<void> _saveAllSettings() async {
    await Future.wait([
      _savePivotConfigurations(),
      _saveChartConfigurations(),
      _saveDashboardLayouts(),
      _saveRecentAnalysis(),
      _saveFavoriteViews(),
      _saveUserPreferences(),
    ]);
  }

  // Getters
  Map<String, PivotConfiguration> get pivotConfigurations => Map.unmodifiable(_pivotConfigurations);
  Map<String, ChartConfiguration> get chartConfigurations => Map.unmodifiable(_chartConfigurations);
  Map<String, DashboardLayout> get dashboardLayouts => Map.unmodifiable(_dashboardLayouts);
  Map<String, AnalysisTemplate> get recentAnalysis => Map.unmodifiable(_recentAnalysis);
  Set<String> get favoriteViews => Set.unmodifiable(_favoriteViews);
  BIUserPreferences get userPreferences => _userPreferences;

  List<PivotConfiguration> get favoritePivotConfigurations {
    return _pivotConfigurations.values.where((config) => config.isFavorite).toList()
      ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
  }

  List<AnalysisTemplate> get recentAnalysisList {
    return _recentAnalysis.values.toList()
      ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
  }

  bool isFavorite(String viewId) => _favoriteViews.contains(viewId);
}

/// 피벗 테이블 구성
class PivotConfiguration {
  final String id;
  final String name;
  final String description;
  final List<String> rowFields;
  final List<String> columnFields;
  final List<PivotValueField> valueFields;
  final Map<String, List<String>> filters;
  final DateTime createdAt;
  final DateTime lastUsed;
  final int useCount;
  final bool isFavorite;

  PivotConfiguration({
    required this.id,
    required this.name,
    required this.description,
    required this.rowFields,
    required this.columnFields,
    required this.valueFields,
    required this.filters,
    required this.createdAt,
    required this.lastUsed,
    required this.useCount,
    required this.isFavorite,
  });

  PivotConfiguration copyWith({
    String? name,
    String? description,
    List<String>? rowFields,
    List<String>? columnFields,
    List<PivotValueField>? valueFields,
    Map<String, List<String>>? filters,
    DateTime? lastUsed,
    int? useCount,
    bool? isFavorite,
  }) {
    return PivotConfiguration(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      rowFields: rowFields ?? this.rowFields,
      columnFields: columnFields ?? this.columnFields,
      valueFields: valueFields ?? this.valueFields,
      filters: filters ?? this.filters,
      createdAt: createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      useCount: useCount ?? this.useCount,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'rowFields': rowFields,
      'columnFields': columnFields,
      'valueFields': valueFields.map((v) => v.toJson()).toList(),
      'filters': filters,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed.toIso8601String(),
      'useCount': useCount,
      'isFavorite': isFavorite,
    };
  }

  factory PivotConfiguration.fromJson(Map<String, dynamic> json) {
    return PivotConfiguration(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      rowFields: List<String>.from(json['rowFields']),
      columnFields: List<String>.from(json['columnFields']),
      valueFields: (json['valueFields'] as List).map((v) => PivotValueField.fromJson(v)).toList(),
      filters: Map<String, List<String>>.from(
        (json['filters'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, List<String>.from(v)),
        ),
      ),
      createdAt: DateTime.parse(json['createdAt']),
      lastUsed: DateTime.parse(json['lastUsed']),
      useCount: json['useCount'],
      isFavorite: json['isFavorite'],
    );
  }
}

/// 피벗 값 필드
class PivotValueField {
  final String field;
  final String aggregation;
  final String displayName;

  PivotValueField(this.field, this.aggregation, this.displayName);

  Map<String, dynamic> toJson() => {
    'field': field,
    'aggregation': aggregation,
    'displayName': displayName,
  };

  factory PivotValueField.fromJson(Map<String, dynamic> json) {
    return PivotValueField(
      json['field'],
      json['aggregation'],
      json['displayName'],
    );
  }
}

/// 대시보드 레이아웃
class DashboardLayout {
  final String id;
  final String name;
  final String description;
  final List<DashboardWidget> widgets;
  final DateTime createdAt;
  final DateTime lastUsed;

  DashboardLayout({
    required this.id,
    required this.name,
    required this.description,
    required this.widgets,
    required this.createdAt,
    required this.lastUsed,
  });

  DashboardLayout copyWith({
    String? name,
    String? description,
    List<DashboardWidget>? widgets,
    DateTime? lastUsed,
  }) {
    return DashboardLayout(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      widgets: widgets ?? this.widgets,
      createdAt: createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'widgets': widgets.map((w) => w.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  factory DashboardLayout.fromJson(Map<String, dynamic> json) {
    return DashboardLayout(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      widgets: (json['widgets'] as List).map((w) => DashboardWidget.fromJson(w)).toList(),
      createdAt: DateTime.parse(json['createdAt']),
      lastUsed: DateTime.parse(json['lastUsed']),
    );
  }
}

/// 대시보드 위젯
class DashboardWidget {
  final String id;
  final String type;
  final DashboardPosition position;
  final Map<String, dynamic> config;

  DashboardWidget({
    required this.id,
    required this.type,
    required this.position,
    required this.config,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'position': position.toJson(),
      'config': config,
    };
  }

  factory DashboardWidget.fromJson(Map<String, dynamic> json) {
    return DashboardWidget(
      id: json['id'],
      type: json['type'],
      position: DashboardPosition.fromJson(json['position']),
      config: json['config'],
    );
  }
}

/// 대시보드 위젯 위치
class DashboardPosition {
  final int x;
  final int y;
  final int width;
  final int height;

  const DashboardPosition(this.x, this.y, this.width, this.height);

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  factory DashboardPosition.fromJson(Map<String, dynamic> json) {
    return DashboardPosition(
      json['x'],
      json['y'],
      json['width'],
      json['height'],
    );
  }
}

/// 분석 템플릿
class AnalysisTemplate {
  final String id;
  final String name;
  final String type; // 'pivot', 'chart', 'dashboard'
  final String description;
  final DateTime lastUsed;
  final Map<String, dynamic> config;

  AnalysisTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.lastUsed,
    required this.config,
  });

  AnalysisTemplate copyWith({
    String? name,
    String? description,
    DateTime? lastUsed,
    Map<String, dynamic>? config,
  }) {
    return AnalysisTemplate(
      id: id,
      name: name ?? this.name,
      type: type,
      description: description ?? this.description,
      lastUsed: lastUsed ?? this.lastUsed,
      config: config ?? this.config,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'lastUsed': lastUsed.toIso8601String(),
      'config': config,
    };
  }

  factory AnalysisTemplate.fromJson(Map<String, dynamic> json) {
    return AnalysisTemplate(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      description: json['description'],
      lastUsed: DateTime.parse(json['lastUsed']),
      config: json['config'],
    );
  }
}

/// BI 사용자 기본 설정
class BIUserPreferences {
  final String theme; // 'light', 'dark', 'auto'
  final String language; // 'ko', 'en'
  final bool enableAnimations;
  final bool enableNotifications;
  final bool autoSaveEnabled;
  final int autoSaveInterval; // 분 단위
  final String dateFormat;
  final String numberFormat;
  final Map<String, dynamic> customSettings;

  BIUserPreferences({
    required this.theme,
    required this.language,
    required this.enableAnimations,
    required this.enableNotifications,
    required this.autoSaveEnabled,
    required this.autoSaveInterval,
    required this.dateFormat,
    required this.numberFormat,
    required this.customSettings,
  });

  factory BIUserPreferences.defaults() {
    return BIUserPreferences(
      theme: 'auto',
      language: 'ko',
      enableAnimations: true,
      enableNotifications: true,
      autoSaveEnabled: true,
      autoSaveInterval: 5,
      dateFormat: 'yyyy-MM-dd',
      numberFormat: '#,###',
      customSettings: {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'language': language,
      'enableAnimations': enableAnimations,
      'enableNotifications': enableNotifications,
      'autoSaveEnabled': autoSaveEnabled,
      'autoSaveInterval': autoSaveInterval,
      'dateFormat': dateFormat,
      'numberFormat': numberFormat,
      'customSettings': customSettings,
    };
  }

  factory BIUserPreferences.fromJson(Map<String, dynamic> json) {
    return BIUserPreferences(
      theme: json['theme'],
      language: json['language'],
      enableAnimations: json['enableAnimations'],
      enableNotifications: json['enableNotifications'],
      autoSaveEnabled: json['autoSaveEnabled'],
      autoSaveInterval: json['autoSaveInterval'],
      dateFormat: json['dateFormat'],
      numberFormat: json['numberFormat'],
      customSettings: json['customSettings'],
    );
  }
}