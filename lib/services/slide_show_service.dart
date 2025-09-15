import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// PowerPoint 스타일 자동 슬라이드쇼 서비스
/// 여러 차트/분석 화면을 자동으로 전환하는 프레젠테이션 모드
class SlideShowService extends ChangeNotifier {
  static final SlideShowService _instance = SlideShowService._internal();
  factory SlideShowService() => _instance;
  SlideShowService._internal();

  // 슬라이드 상태
  List<SlideDefinition> _slides = [];
  int _currentSlideIndex = 0;
  bool _isPlaying = false;
  bool _isAutoPlay = false;
  Duration _slideDuration = const Duration(seconds: 10);

  Timer? _autoPlayTimer;
  Timer? _transitionTimer;

  // 슬라이드 전환 애니메이션
  SlideTransition _transitionType = SlideTransition.slideLeft;
  Duration _transitionDuration = const Duration(milliseconds: 800);
  bool _isTransitioning = false;

  // 슬라이드쇼 설정
  bool _showSlideCounter = true;
  bool _showProgressBar = true;
  bool _showSlideTitle = true;
  bool _enableKeyboardControl = true;
  bool _enableMouseControl = true;

  // 이벤트 스트림
  final StreamController<SlideShowEvent> _eventController =
      StreamController<SlideShowEvent>.broadcast();

  Stream<SlideShowEvent> get events => _eventController.stream;

  /// 기본 분석 슬라이드 초기화
  void initializeDefaultSlides() {
    _slides = [
      // 1. 지역별 매출 분석
      SlideDefinition(
        id: 'regional_analysis',
        title: '🌍 지역별 매출 분석',
        subtitle: '대륙별 매출 현황 및 트렌드',
        slideType: SlideType.chart,
        chartConfig: ChartConfiguration(
          id: 'regional_chart',
          name: '지역별 차트',
          chartType: 'column',
          groupBy: 'CONTINENT',
          valueField: 'SUM_SALE_AMT_WON',
          aggregation: 'sum',
          title: '대륙별 총 매출액',
          filters: {},
        ),
        duration: const Duration(seconds: 12),
        transition: SlideTransition.slideLeft,
      ),

      // 2. 국가별 Top 10
      SlideDefinition(
        id: 'country_top10',
        title: '🏆 국가별 Top 10',
        subtitle: '매출 상위 10개 국가',
        slideType: SlideType.chart,
        chartConfig: ChartConfiguration(
          id: 'top_countries_chart',
          name: '상위 국가 차트',
          chartType: 'bar',
          groupBy: 'NATION_NAME',
          valueField: 'SUM_SALE_AMT_WON',
          aggregation: 'sum',
          title: '국가별 매출액 (상위 10개)',
          filters: {},
          limit: 10,
        ),
        duration: const Duration(seconds: 15),
        transition: SlideTransition.slideUp,
      ),

      // 3. 거래처 분류별 분석
      SlideDefinition(
        id: 'customer_type_analysis',
        title: '🏥 거래처 분류별 분석',
        subtitle: '병원 규모별 매출 분포',
        slideType: SlideType.chart,
        chartConfig: ChartConfiguration(
          id: 'customer_type_chart',
          name: '거래처분류 차트',
          chartType: 'pie',
          groupBy: '거래처분류',
          valueField: 'SUM_SALE_AMT_WON',
          aggregation: 'sum',
          title: '거래처 분류별 매출 구성비',
          filters: {},
        ),
        duration: const Duration(seconds: 10),
        transition: SlideTransition.fade,
      ),

      // 4. 수량 대비 매출 분석 (산점도)
      SlideDefinition(
        id: 'quantity_vs_sales',
        title: '📊 수량 대비 매출 분석',
        subtitle: '판매 수량과 매출액의 상관관계',
        slideType: SlideType.chart,
        chartConfig: ChartConfiguration(
          id: 'correlation_chart',
          name: '상관분석 차트',
          chartType: 'scatter',
          groupBy: 'CUSTOM_NAME',
          valueField: 'SUM_SALE_AMT_WON',
          xField: 'SALE_Q',
          aggregation: 'sum',
          title: '수량 vs 매출액 상관분석',
          filters: {},
        ),
        duration: const Duration(seconds: 18),
        transition: SlideTransition.zoom,
      ),

      // 5. KPI 대시보드
      SlideDefinition(
        id: 'kpi_dashboard',
        title: '📈 핵심 성과 지표',
        subtitle: '주요 KPI 및 성과 요약',
        slideType: SlideType.dashboard,
        dashboardConfig: DashboardConfiguration(
          kpis: [
            KPIDefinition(name: '총 매출액', field: 'SUM_SALE_AMT_WON', aggregation: 'sum', format: 'currency'),
            KPIDefinition(name: '총 거래처 수', field: 'CUSTOM_NAME', aggregation: 'count', format: 'number'),
            KPIDefinition(name: '평균 주문량', field: 'SALE_Q', aggregation: 'avg', format: 'number'),
            KPIDefinition(name: '평균 단가', field: 'SALE_P', aggregation: 'avg', format: 'currency'),
          ],
          miniCharts: [
            'regional_trend',
            'monthly_growth',
          ],
        ),
        duration: const Duration(seconds: 20),
        transition: SlideTransition.slideRight,
      ),

      // 6. 트렌드 분석
      SlideDefinition(
        id: 'trend_analysis',
        title: '📈 트렌드 분석',
        subtitle: '월별/분기별 성장 추이',
        slideType: SlideType.chart,
        chartConfig: ChartConfiguration(
          id: 'trend_chart',
          name: '트렌드 차트',
          chartType: 'line',
          groupBy: 'UPDATE_DTM',
          valueField: 'SUM_SALE_AMT_WON',
          aggregation: 'sum',
          title: '월별 매출 트렌드',
          filters: {},
          timeGrouping: 'month',
        ),
        duration: const Duration(seconds: 15),
        transition: SlideTransition.slideDown,
      ),
    ];

    debugPrint('🎬 SlideShow: ${_slides.length} default slides initialized');
  }

  /// 슬라이드쇼 시작
  void startSlideShow() {
    if (_slides.isEmpty) {
      initializeDefaultSlides();
    }

    _isPlaying = true;
    _currentSlideIndex = 0;

    _eventController.add(SlideShowEvent(
      type: SlideShowEventType.started,
      slideIndex: _currentSlideIndex,
      slide: _slides[_currentSlideIndex],
    ));

    if (_isAutoPlay) {
      _startAutoPlay();
    }

    notifyListeners();
    debugPrint('🎬 SlideShow: Started');
  }

  /// 슬라이드쇼 정지
  void stopSlideShow() {
    _isPlaying = false;
    _isAutoPlay = false;
    _autoPlayTimer?.cancel();
    _transitionTimer?.cancel();

    _eventController.add(SlideShowEvent(
      type: SlideShowEventType.stopped,
      slideIndex: _currentSlideIndex,
      slide: _slides.isNotEmpty ? _slides[_currentSlideIndex] : null,
    ));

    notifyListeners();
    debugPrint('🎬 SlideShow: Stopped');
  }

  /// 자동 재생 시작/중지
  void toggleAutoPlay() {
    _isAutoPlay = !_isAutoPlay;

    if (_isAutoPlay && _isPlaying) {
      _startAutoPlay();
    } else {
      _autoPlayTimer?.cancel();
    }

    _eventController.add(SlideShowEvent(
      type: _isAutoPlay ? SlideShowEventType.autoPlayStarted : SlideShowEventType.autoPlayStopped,
      slideIndex: _currentSlideIndex,
      slide: _slides.isNotEmpty ? _slides[_currentSlideIndex] : null,
    ));

    notifyListeners();
    debugPrint('🎬 SlideShow: AutoPlay ${_isAutoPlay ? "ON" : "OFF"}');
  }

  /// 다음 슬라이드로
  void nextSlide() {
    if (!_isPlaying || _slides.isEmpty || _isTransitioning) return;

    final nextIndex = (_currentSlideIndex + 1) % _slides.length;
    _transitionToSlide(nextIndex);
  }

  /// 이전 슬라이드로
  void previousSlide() {
    if (!_isPlaying || _slides.isEmpty || _isTransitioning) return;

    final prevIndex = (_currentSlideIndex - 1 + _slides.length) % _slides.length;
    _transitionToSlide(prevIndex);
  }

  /// 특정 슬라이드로 이동
  void goToSlide(int index) {
    if (!_isPlaying || _slides.isEmpty || index < 0 || index >= _slides.length || _isTransitioning) return;

    _transitionToSlide(index);
  }

  /// 슬라이드 전환 실행
  void _transitionToSlide(int newIndex) {
    if (_isTransitioning) return;

    _isTransitioning = true;
    final oldSlide = _slides[_currentSlideIndex];
    final newSlide = _slides[newIndex];

    // 전환 시작 이벤트
    _eventController.add(SlideShowEvent(
      type: SlideShowEventType.transitionStarted,
      slideIndex: newIndex,
      slide: newSlide,
      previousSlide: oldSlide,
    ));

    _currentSlideIndex = newIndex;

    // 전환 완료 타이머
    _transitionTimer = Timer(_transitionDuration, () {
      _isTransitioning = false;

      _eventController.add(SlideShowEvent(
        type: SlideShowEventType.slideChanged,
        slideIndex: _currentSlideIndex,
        slide: newSlide,
        previousSlide: oldSlide,
      ));

      notifyListeners();

      // 자동 재생 중이면 다음 타이머 시작
      if (_isAutoPlay && _isPlaying) {
        _startAutoPlay();
      }
    });

    debugPrint('🎬 SlideShow: Transitioning to slide $newIndex - ${newSlide.title}');
  }

  /// 자동 재생 타이머 시작
  void _startAutoPlay() {
    _autoPlayTimer?.cancel();

    if (_isPlaying && _isAutoPlay && !_isTransitioning) {
      final currentSlide = _slides[_currentSlideIndex];
      final delay = currentSlide.duration ?? _slideDuration;

      _autoPlayTimer = Timer(delay, () {
        if (_isPlaying && _isAutoPlay) {
          nextSlide();
        }
      });
    }
  }

  /// 슬라이드 추가
  void addSlide(SlideDefinition slide) {
    _slides.add(slide);
    notifyListeners();
    debugPrint('🎬 SlideShow: Slide added - ${slide.title}');
  }

  /// 슬라이드 제거
  void removeSlide(String slideId) {
    final index = _slides.indexWhere((slide) => slide.id == slideId);
    if (index != -1) {
      _slides.removeAt(index);

      // 현재 슬라이드가 제거된 경우 조정
      if (_currentSlideIndex >= _slides.length) {
        _currentSlideIndex = math.max(0, _slides.length - 1);
      }

      notifyListeners();
      debugPrint('🎬 SlideShow: Slide removed - $slideId');
    }
  }

  /// 슬라이드 순서 변경
  void reorderSlides(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _slides.length || newIndex < 0 || newIndex >= _slides.length) return;

    final slide = _slides.removeAt(oldIndex);
    _slides.insert(newIndex, slide);

    // 현재 슬라이드 인덱스 조정
    if (_currentSlideIndex == oldIndex) {
      _currentSlideIndex = newIndex;
    } else if (_currentSlideIndex > oldIndex && _currentSlideIndex <= newIndex) {
      _currentSlideIndex--;
    } else if (_currentSlideIndex < oldIndex && _currentSlideIndex >= newIndex) {
      _currentSlideIndex++;
    }

    notifyListeners();
    debugPrint('🎬 SlideShow: Slide reordered from $oldIndex to $newIndex');
  }

  // 설정 메서드들
  void setSlideDuration(Duration duration) {
    _slideDuration = duration;
    debugPrint('🎬 SlideShow: Duration set to ${duration.inSeconds}s');
  }

  void setTransitionType(SlideTransition transition) {
    _transitionType = transition;
    debugPrint('🎬 SlideShow: Transition set to $transition');
  }

  void setTransitionDuration(Duration duration) {
    _transitionDuration = duration;
    debugPrint('🎬 SlideShow: Transition duration set to ${duration.inMilliseconds}ms');
  }

  // Getters
  List<SlideDefinition> get slides => List.unmodifiable(_slides);
  SlideDefinition? get currentSlide => _slides.isNotEmpty ? _slides[_currentSlideIndex] : null;
  int get currentSlideIndex => _currentSlideIndex;
  bool get isPlaying => _isPlaying;
  bool get isAutoPlay => _isAutoPlay;
  bool get isTransitioning => _isTransitioning;
  Duration get slideDuration => _slideDuration;
  SlideTransition get transitionType => _transitionType;
  Duration get transitionDuration => _transitionDuration;
  int get slideCount => _slides.length;
  double get progress => _slides.isEmpty ? 0.0 : (_currentSlideIndex + 1) / _slides.length;

  bool get showSlideCounter => _showSlideCounter;
  bool get showProgressBar => _showProgressBar;
  bool get showSlideTitle => _showSlideTitle;

  /// 설정 내보내기
  Map<String, dynamic> exportSettings() {
    return {
      'slides': _slides.map((slide) => slide.toJson()).toList(),
      'slideDuration': _slideDuration.inSeconds,
      'transitionType': _transitionType.toString(),
      'transitionDuration': _transitionDuration.inMilliseconds,
      'showSlideCounter': _showSlideCounter,
      'showProgressBar': _showProgressBar,
      'showSlideTitle': _showSlideTitle,
      'enableKeyboardControl': _enableKeyboardControl,
      'enableMouseControl': _enableMouseControl,
    };
  }

  /// 설정 가져오기
  void importSettings(Map<String, dynamic> data) {
    try {
      final slidesData = data['slides'] as List<dynamic>?;
      if (slidesData != null) {
        _slides = slidesData.map((json) => SlideDefinition.fromJson(json)).toList();
      }

      _slideDuration = Duration(seconds: data['slideDuration'] ?? 10);
      _transitionDuration = Duration(milliseconds: data['transitionDuration'] ?? 800);
      _showSlideCounter = data['showSlideCounter'] ?? true;
      _showProgressBar = data['showProgressBar'] ?? true;
      _showSlideTitle = data['showSlideTitle'] ?? true;
      _enableKeyboardControl = data['enableKeyboardControl'] ?? true;
      _enableMouseControl = data['enableMouseControl'] ?? true;

      // 전환 타입 파싱
      final transitionStr = data['transitionType'] as String?;
      if (transitionStr != null) {
        _transitionType = SlideTransition.values.firstWhere(
          (t) => t.toString() == transitionStr,
          orElse: () => SlideTransition.slideLeft,
        );
      }

      notifyListeners();
      debugPrint('🎬 SlideShow: Settings imported successfully');
    } catch (e) {
      debugPrint('🎬 SlideShow: Import failed - $e');
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _transitionTimer?.cancel();
    _eventController.close();
    super.dispose();
  }
}

/// 슬라이드 정의
class SlideDefinition {
  final String id;
  final String title;
  final String subtitle;
  final SlideType slideType;
  final Duration? duration;
  final SlideTransition transition;

  // 차트 슬라이드용
  final ChartConfiguration? chartConfig;

  // 대시보드 슬라이드용
  final DashboardConfiguration? dashboardConfig;

  // 커스텀 슬라이드용
  final Map<String, dynamic>? customData;

  SlideDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.slideType,
    this.duration,
    this.transition = SlideTransition.slideLeft,
    this.chartConfig,
    this.dashboardConfig,
    this.customData,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'slideType': slideType.toString(),
      'duration': duration?.inSeconds,
      'transition': transition.toString(),
      'chartConfig': chartConfig?.toJson(),
      'dashboardConfig': dashboardConfig?.toJson(),
      'customData': customData,
    };
  }

  factory SlideDefinition.fromJson(Map<String, dynamic> json) {
    return SlideDefinition(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      slideType: SlideType.values.firstWhere((t) => t.toString() == json['slideType']),
      duration: json['duration'] != null ? Duration(seconds: json['duration']) : null,
      transition: SlideTransition.values.firstWhere(
        (t) => t.toString() == json['transition'],
        orElse: () => SlideTransition.slideLeft,
      ),
      chartConfig: json['chartConfig'] != null ? ChartConfiguration.fromJson(json['chartConfig']) : null,
      dashboardConfig: json['dashboardConfig'] != null ? DashboardConfiguration.fromJson(json['dashboardConfig']) : null,
      customData: json['customData'],
    );
  }
}

/// 차트 설정
class ChartConfiguration {
  final String id;
  final String name;
  final String chartType;
  final String groupBy;
  final String valueField;
  final String? xField; // 산점도용
  final String aggregation;
  final String title;
  final Map<String, List<String>> filters;
  final int? limit;
  final String? timeGrouping; // 시간 그룹핑 (month, quarter, year)

  ChartConfiguration({
    required this.id,
    required this.name,
    required this.chartType,
    required this.groupBy,
    required this.valueField,
    this.xField,
    required this.aggregation,
    required this.title,
    required this.filters,
    this.limit,
    this.timeGrouping,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'chartType': chartType,
      'groupBy': groupBy,
      'valueField': valueField,
      'xField': xField,
      'aggregation': aggregation,
      'title': title,
      'filters': filters,
      'limit': limit,
      'timeGrouping': timeGrouping,
    };
  }

  factory ChartConfiguration.fromJson(Map<String, dynamic> json) {
    return ChartConfiguration(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      chartType: json['chartType'],
      groupBy: json['groupBy'],
      valueField: json['valueField'],
      xField: json['xField'],
      aggregation: json['aggregation'],
      title: json['title'],
      filters: Map<String, List<String>>.from(
        (json['filters'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      ),
      limit: json['limit'],
      timeGrouping: json['timeGrouping'],
    );
  }
}

/// 대시보드 설정
class DashboardConfiguration {
  final List<KPIDefinition> kpis;
  final List<String> miniCharts;

  DashboardConfiguration({
    required this.kpis,
    required this.miniCharts,
  });

  Map<String, dynamic> toJson() {
    return {
      'kpis': kpis.map((kpi) => kpi.toJson()).toList(),
      'miniCharts': miniCharts,
    };
  }

  factory DashboardConfiguration.fromJson(Map<String, dynamic> json) {
    return DashboardConfiguration(
      kpis: (json['kpis'] as List<dynamic>).map((kpi) => KPIDefinition.fromJson(kpi)).toList(),
      miniCharts: List<String>.from(json['miniCharts']),
    );
  }
}

/// KPI 정의
class KPIDefinition {
  final String name;
  final String field;
  final String aggregation;
  final String format;

  KPIDefinition({
    required this.name,
    required this.field,
    required this.aggregation,
    required this.format,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'field': field,
      'aggregation': aggregation,
      'format': format,
    };
  }

  factory KPIDefinition.fromJson(Map<String, dynamic> json) {
    return KPIDefinition(
      name: json['name'],
      field: json['field'],
      aggregation: json['aggregation'],
      format: json['format'],
    );
  }
}

/// 슬라이드 타입
enum SlideType {
  chart,
  dashboard,
  pivot,
  custom,
}

/// 슬라이드 전환 효과
enum SlideTransition {
  slideLeft,
  slideRight,
  slideUp,
  slideDown,
  fade,
  zoom,
  flip,
  rotate,
}

/// 슬라이드쇼 이벤트 타입
enum SlideShowEventType {
  started,
  stopped,
  slideChanged,
  autoPlayStarted,
  autoPlayStopped,
  transitionStarted,
}

/// 슬라이드쇼 이벤트
class SlideShowEvent {
  final SlideShowEventType type;
  final int slideIndex;
  final SlideDefinition? slide;
  final SlideDefinition? previousSlide;

  SlideShowEvent({
    required this.type,
    required this.slideIndex,
    this.slide,
    this.previousSlide,
  });
}