import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/sales_service.dart';
import '../utils/preferences_manager.dart';
import '../utils/dialog_utils.dart';
import 'master_filter_service.dart';

/// 실시간 데이터 연동 및 자동 갱신 서비스
/// - 실시간 데이터 스트림 관리
/// - 자동 갱신 스케줄링
/// - 데이터 캐싱 및 최적화
/// - 네트워크 상태 모니터링
/// - 백그라운드 동기화
class RealtimeDataService extends ChangeNotifier {
  static final RealtimeDataService _instance = RealtimeDataService._internal();
  factory RealtimeDataService() => _instance;
  RealtimeDataService._internal();

  // 서비스 상태
  bool _isInitialized = false;
  bool _isRunning = false;
  bool _isAutoRefreshEnabled = true;

  // 갱신 설정 (통합분석의 기능 활용)
  int _refreshIntervalSeconds = 300; // 5분 기본
  String _refreshMode = 'interval'; // 'interval', 'schedule', 'manual'
  List<int> _scheduleHours = [6, 9, 12, 15, 18]; // 정시 갱신 시간

  // 타이머들
  Timer? _refreshTimer;
  Timer? _scheduleCheckTimer;
  Timer? _networkCheckTimer;
  Timer? _healthCheckTimer;

  // 데이터 스트림
  final StreamController<RealtimeDataEvent> _dataEventController =
      StreamController<RealtimeDataEvent>.broadcast();
  Stream<RealtimeDataEvent> get dataEvents => _dataEventController.stream;

  // 데이터 캐시 (통합분석의 캐싱 시스템 확장)
  final Map<String, CachedDataSet> _dataCache = {};
  final Map<String, DateTime> _lastUpdateTimes = {};
  final int _maxCachedItems = 1000;
  final Duration _cacheExpiry = const Duration(minutes: 10);

  // 구독자 관리
  final Map<String, Set<DataSubscriber>> _subscribers = {};
  final Map<String, DataQuery> _activeQueries = {};

  // 네트워크 및 성능 모니터링
  bool _isOnline = true;
  bool _isServerHealthy = true;
  double _averageResponseTime = 0.0;
  int _successfulRequests = 0;
  int _failedRequests = 0;

  // 백그라운드 동기화
  final List<PendingUpdate> _pendingUpdates = [];
  final bool _isSyncInProgress = false;

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadSettings();
      _setupTimers();
      _startHealthChecking();
      _startNetworkMonitoring();

      _isInitialized = true;
      debugPrint('📡 Realtime Data Service: Initialized successfully');
    } catch (e) {
      debugPrint('📡 Realtime Data Service: Initialization failed - $e');
      rethrow;
    }
  }

  /// 실시간 데이터 서비스 시작
  Future<void> startService() async {
    if (!_isInitialized) await initialize();
    if (_isRunning) return;

    _isRunning = true;

    if (_isAutoRefreshEnabled) {
      _startAutoRefresh();
    }

    _dataEventController.add(RealtimeDataEvent(
      type: DataEventType.serviceStarted,
      timestamp: DateTime.now(),
    ));

    notifyListeners();
    debugPrint('📡 Realtime Data Service: Started');
  }

  /// 실시간 데이터 서비스 중지
  void stopService() {
    _isRunning = false;

    _refreshTimer?.cancel();
    _scheduleCheckTimer?.cancel();

    _dataEventController.add(RealtimeDataEvent(
      type: DataEventType.serviceStopped,
      timestamp: DateTime.now(),
    ));

    notifyListeners();
    debugPrint('📡 Realtime Data Service: Stopped');
  }

  /// 데이터 구독 (위젯이나 서비스가 특정 데이터를 구독)
  void subscribe(String subscriberId, DataQuery query, DataSubscriber subscriber) {
    _subscribers[subscriberId] ??= <DataSubscriber>{};
    _subscribers[subscriberId]!.add(subscriber);
    _activeQueries[subscriberId] = query;

    // 즉시 캐시된 데이터 제공
    _provideCachedDataIfAvailable(subscriberId, query);

    debugPrint('📡 Realtime: $subscriberId subscribed to ${query.dataType}');
  }

  /// 데이터 구독 해제
  void unsubscribe(String subscriberId, DataSubscriber subscriber) {
    _subscribers[subscriberId]?.remove(subscriber);
    if (_subscribers[subscriberId]?.isEmpty == true) {
      _subscribers.remove(subscriberId);
      _activeQueries.remove(subscriberId);
    }

    debugPrint('📡 Realtime: $subscriberId unsubscribed');
  }

  /// 수동 데이터 새로고침
  Future<void> refreshData({String? specificDataType}) async {
    if (!_isRunning) return;

    final startTime = DateTime.now();

    try {
      List<String> dataTypesToRefresh;
      if (specificDataType != null) {
        dataTypesToRefresh = [specificDataType];
      } else {
        dataTypesToRefresh = _activeQueries.values.map((q) => q.dataType).toSet().toList();
      }

      for (final dataType in dataTypesToRefresh) {
        await _fetchAndCacheData(dataType);
      }

      final duration = DateTime.now().difference(startTime);
      _updatePerformanceMetrics(true, duration.inMilliseconds);

      _dataEventController.add(RealtimeDataEvent(
        type: DataEventType.manualRefresh,
        timestamp: DateTime.now(),
        dataType: specificDataType,
      ));

      debugPrint('📡 Realtime: Manual refresh completed in ${duration.inMilliseconds}ms');
    } catch (e) {
      _updatePerformanceMetrics(false, 0);
      _handleDataError(e);
    }
  }

  /// 캐시된 데이터 즉시 제공
  void _provideCachedDataIfAvailable(String subscriberId, DataQuery query) {
    final cachedData = _dataCache[query.dataType];
    if (cachedData != null && !_isCacheExpired(query.dataType)) {
      final filteredData = _applyQueryFilters(cachedData.data, query);
      _notifySubscribers(subscriberId, filteredData, isFromCache: true);
    }
  }

  /// 자동 갱신 시작
  void _startAutoRefresh() {
    _refreshTimer?.cancel();

    if (_refreshMode == 'interval') {
      _refreshTimer = Timer.periodic(
        Duration(seconds: _refreshIntervalSeconds),
        (timer) => _performScheduledRefresh(),
      );
    } else if (_refreshMode == 'schedule') {
      _scheduleCheckTimer = Timer.periodic(
        const Duration(minutes: 1),
        (timer) => _checkScheduledRefresh(),
      );
    }

    debugPrint('📡 Realtime: Auto refresh started - $_refreshMode mode');
  }

  /// 예약된 갱신 수행
  void _performScheduledRefresh() async {
    if (!_isRunning || !_isAutoRefreshEnabled) return;

    try {
      await refreshData();

      _dataEventController.add(RealtimeDataEvent(
        type: DataEventType.scheduledRefresh,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      _handleDataError(e);
    }
  }

  /// 정시 갱신 체크
  void _checkScheduledRefresh() {
    final now = DateTime.now();
    if (_scheduleHours.contains(now.hour) && now.minute == 0) {
      _performScheduledRefresh();
    }
  }

  /// 데이터 가져오기 및 캐싱
  Future<void> _fetchAndCacheData(String dataType) async {
    final salesService = SalesService();

    try {
      final result = await salesService.getSalesSummary(
        fromDate: DateTime(DateTime.now().year, 1, 1),
        toDate: DateTime(DateTime.now().year, 12, 31),
        period: 'ALL',
        trCd: '',
      );

      if (result['success'] == true && result['data'] != null) {
        final data = List<Map<String, dynamic>>.from(result['data']);

        // 캐시에 저장
        _dataCache[dataType] = CachedDataSet(
          data: data,
          timestamp: DateTime.now(),
          source: 'api',
        );

        _lastUpdateTimes[dataType] = DateTime.now();

        // 구독자들에게 알림
        _notifyAllSubscribers(dataType, data);

        _cleanupCache();

      } else {
        throw Exception(result['message'] ?? '데이터 로드 실패');
      }
    } catch (e) {
      debugPrint('📡 Realtime: Data fetch failed for $dataType - $e');
      rethrow;
    }
  }

  /// 쿼리 필터 적용
  List<Map<String, dynamic>> _applyQueryFilters(
    List<Map<String, dynamic>> data,
    DataQuery query,
  ) {
    var filteredData = data;

    // 날짜 범위 필터
    if (query.dateRange != null) {
      filteredData = filteredData.where((item) {
        final dateStr = item['UPDATE_DTM']?.toString();
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            return date.isAfter(query.dateRange!.start) &&
                   date.isBefore(query.dateRange!.end);
          }
        }
        return false;
      }).toList();
    }

    // 필드 필터
    for (final entry in query.filters.entries) {
      final field = entry.key;
      final values = entry.value;
      if (values.isNotEmpty) {
        filteredData = filteredData.where((item) {
          final itemValue = item[field]?.toString() ?? '';
          return values.contains(itemValue);
        }).toList();
      }
    }

    // 정렬
    if (query.sortBy != null) {
      filteredData.sort((a, b) {
        final aValue = a[query.sortBy!] ?? '';
        final bValue = b[query.sortBy!] ?? '';

        if (aValue is num && bValue is num) {
          return query.sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
        } else {
          return query.sortAscending ?
            aValue.toString().compareTo(bValue.toString()) :
            bValue.toString().compareTo(aValue.toString());
        }
      });
    }

    // 제한
    if (query.limit != null && query.limit! > 0) {
      filteredData = filteredData.take(query.limit!).toList();
    }

    return filteredData;
  }

  /// 모든 구독자에게 알림
  void _notifyAllSubscribers(String dataType, List<Map<String, dynamic>> data) {
    for (final entry in _activeQueries.entries) {
      final subscriberId = entry.key;
      final query = entry.value;

      if (query.dataType == dataType) {
        final filteredData = _applyQueryFilters(data, query);
        _notifySubscribers(subscriberId, filteredData, isFromCache: false);
      }
    }
  }

  /// 특정 구독자에게 알림
  void _notifySubscribers(
    String subscriberId,
    List<Map<String, dynamic>> data, {
    bool isFromCache = false,
  }) {
    final subscribers = _subscribers[subscriberId];
    if (subscribers != null) {
      final event = DataUpdateEvent(
        subscriberId: subscriberId,
        data: data,
        timestamp: DateTime.now(),
        isFromCache: isFromCache,
      );

      for (final subscriber in subscribers) {
        try {
          subscriber.onDataUpdate(event);
        } catch (e) {
          debugPrint('📡 Realtime: Subscriber notification failed - $e');
        }
      }
    }
  }

  /// 캐시 만료 확인
  bool _isCacheExpired(String dataType) {
    final cachedData = _dataCache[dataType];
    if (cachedData == null) return true;

    return DateTime.now().difference(cachedData.timestamp) > _cacheExpiry;
  }

  /// 캐시 정리
  void _cleanupCache() {
    if (_dataCache.length <= _maxCachedItems) return;

    final sortedEntries = _dataCache.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

    final itemsToRemove = _dataCache.length - _maxCachedItems;
    for (int i = 0; i < itemsToRemove; i++) {
      _dataCache.remove(sortedEntries[i].key);
    }

    debugPrint('📡 Realtime: Cache cleaned up - removed $itemsToRemove items');
  }

  /// 네트워크 모니터링 시작
  void _startNetworkMonitoring() {
    _networkCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) => _checkNetworkStatus(),
    );
  }

  /// 네트워크 상태 확인
  void _checkNetworkStatus() async {
    try {
      // 간단한 네트워크 체크 (실제 구현에서는 더 정교한 방법 사용)
      final salesService = SalesService();
      final startTime = DateTime.now();

      // 빠른 상태 체크용 요청
      await salesService.getSalesSummary(
        fromDate: DateTime.now().subtract(const Duration(days: 1)),
        toDate: DateTime.now(),
        period: 'DAILY',
        trCd: '',
      );

      final responseTime = DateTime.now().difference(startTime).inMilliseconds;

      if (!_isOnline) {
        _isOnline = true;
        _dataEventController.add(RealtimeDataEvent(
          type: DataEventType.networkRestored,
          timestamp: DateTime.now(),
        ));
      }

      _averageResponseTime = (_averageResponseTime + responseTime) / 2;

    } catch (e) {
      if (_isOnline) {
        _isOnline = false;
        _dataEventController.add(RealtimeDataEvent(
          type: DataEventType.networkLost,
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  /// 서버 상태 모니터링 시작
  void _startHealthChecking() {
    _healthCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) => _checkServerHealth(),
    );
  }

  /// 서버 상태 확인
  void _checkServerHealth() async {
    try {
      // 서버 상태 확인 로직
      final isHealthy = _averageResponseTime < 5000 && _isOnline;

      if (_isServerHealthy != isHealthy) {
        _isServerHealthy = isHealthy;

        _dataEventController.add(RealtimeDataEvent(
          type: isHealthy ? DataEventType.serverHealthy : DataEventType.serverUnhealthy,
          timestamp: DateTime.now(),
        ));
      }
    } catch (e) {
      debugPrint('📡 Realtime: Health check failed - $e');
    }
  }

  /// 성능 지표 업데이트
  void _updatePerformanceMetrics(bool success, int responseTime) {
    if (success) {
      _successfulRequests++;
      _averageResponseTime = (_averageResponseTime + responseTime) / 2;
    } else {
      _failedRequests++;
    }
  }

  /// 데이터 에러 처리
  void _handleDataError(dynamic error) {
    _dataEventController.add(RealtimeDataEvent(
      type: DataEventType.error,
      timestamp: DateTime.now(),
      error: error.toString(),
    ));

    debugPrint('📡 Realtime: Data error - $error');
  }

  /// 타이머 설정
  void _setupTimers() {
    // 통합분석의 타이머 기능 활용
    if (_isAutoRefreshEnabled) {
      _startAutoRefresh();
    }
  }

  /// 설정 로드 (통합분석의 PreferencesManager 활용)
  Future<void> _loadSettings() async {
    _refreshIntervalSeconds = PreferencesManager.getInt('realtime_refresh_interval') ?? 300;
    _refreshMode = PreferencesManager.getString('realtime_refresh_mode') ?? 'interval';
    _isAutoRefreshEnabled = PreferencesManager.getBool('realtime_auto_refresh') ?? true;

    final scheduleHoursStr = PreferencesManager.getString('realtime_schedule_hours');
    try {
      final List<dynamic> decoded = jsonDecode(scheduleHoursStr);
      _scheduleHours = decoded.cast<int>();
    } catch (e) {
      _scheduleHours = [6, 9, 12, 15, 18];
    }
  
    debugPrint('📡 Realtime: Settings loaded');
  }

  /// 설정 저장
  Future<void> _saveSettings() async {
    await PreferencesManager.setInt('realtime_refresh_interval', _refreshIntervalSeconds);
    await PreferencesManager.setString('realtime_refresh_mode', _refreshMode);
    await PreferencesManager.setBool('realtime_auto_refresh', _isAutoRefreshEnabled);
    await PreferencesManager.setString('realtime_schedule_hours', jsonEncode(_scheduleHours));
  }

  // 설정 메서드들
  void setRefreshInterval(int seconds) {
    _refreshIntervalSeconds = seconds;
    _saveSettings();
    if (_isRunning && _refreshMode == 'interval') {
      _startAutoRefresh(); // 재시작
    }
    notifyListeners();
  }

  void setRefreshMode(String mode) {
    _refreshMode = mode;
    _saveSettings();
    if (_isRunning) {
      _startAutoRefresh(); // 재시작
    }
    notifyListeners();
  }

  void setScheduleHours(List<int> hours) {
    _scheduleHours = hours;
    _saveSettings();
    notifyListeners();
  }

  void toggleAutoRefresh() {
    _isAutoRefreshEnabled = !_isAutoRefreshEnabled;
    _saveSettings();

    if (_isRunning) {
      if (_isAutoRefreshEnabled) {
        _startAutoRefresh();
      } else {
        _refreshTimer?.cancel();
        _scheduleCheckTimer?.cancel();
      }
    }

    notifyListeners();
  }

  // Getters
  bool get isRunning => _isRunning;
  bool get isAutoRefreshEnabled => _isAutoRefreshEnabled;
  bool get isOnline => _isOnline;
  bool get isServerHealthy => _isServerHealthy;
  int get refreshIntervalSeconds => _refreshIntervalSeconds;
  String get refreshMode => _refreshMode;
  List<int> get scheduleHours => List.unmodifiable(_scheduleHours);
  double get averageResponseTime => _averageResponseTime;
  int get successfulRequests => _successfulRequests;
  int get failedRequests => _failedRequests;
  double get successRate =>
    (_successfulRequests + _failedRequests) > 0 ?
    _successfulRequests / (_successfulRequests + _failedRequests) :
    0.0;

  Map<String, DateTime> get lastUpdateTimes => Map.unmodifiable(_lastUpdateTimes);

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scheduleCheckTimer?.cancel();
    _networkCheckTimer?.cancel();
    _healthCheckTimer?.cancel();
    _dataEventController.close();
    super.dispose();
  }
}

/// 데이터 쿼리 정의
class DataQuery {
  final String dataType;
  final DateTimeRange? dateRange;
  final Map<String, List<String>> filters;
  final String? sortBy;
  final bool sortAscending;
  final int? limit;

  DataQuery({
    required this.dataType,
    this.dateRange,
    this.filters = const {},
    this.sortBy,
    this.sortAscending = true,
    this.limit,
  });
}

/// 캐시된 데이터셋
class CachedDataSet {
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;
  final String source;

  CachedDataSet({
    required this.data,
    required this.timestamp,
    required this.source,
  });
}

/// 실시간 데이터 이벤트
class RealtimeDataEvent {
  final DataEventType type;
  final DateTime timestamp;
  final String? dataType;
  final String? error;
  final Map<String, dynamic>? metadata;

  RealtimeDataEvent({
    required this.type,
    required this.timestamp,
    this.dataType,
    this.error,
    this.metadata,
  });
}

/// 데이터 업데이트 이벤트
class DataUpdateEvent {
  final String subscriberId;
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;
  final bool isFromCache;

  DataUpdateEvent({
    required this.subscriberId,
    required this.data,
    required this.timestamp,
    required this.isFromCache,
  });
}

/// 데이터 구독자 인터페이스
abstract class DataSubscriber {
  void onDataUpdate(DataUpdateEvent event);
}

/// 보류 중인 업데이트
class PendingUpdate {
  final String dataType;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;

  PendingUpdate({
    required this.dataType,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });
}

/// 데이터 이벤트 타입
enum DataEventType {
  serviceStarted,
  serviceStopped,
  manualRefresh,
  scheduledRefresh,
  networkLost,
  networkRestored,
  serverHealthy,
  serverUnhealthy,
  error,
  dataUpdated,
}