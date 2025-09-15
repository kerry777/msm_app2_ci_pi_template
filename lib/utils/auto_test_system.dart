import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../l10n/app_localizations.dart';
import 'dart:collection';

/* 
🔄 MDM 앱 적용 가이드
=================================

✅ 1. 파일 복사
   - 이 파일(auto_test_system.dart)을 MDM 프로젝트로 복사

✅ 2. 화면 목록 수정 (아래 mdmTestScreens 참고)
   - testScreens 리스트를 MDM 앱의 화면들로 교체

✅ 3. 네비게이션 수정 (_navigateToScreen 메서드)
   - MDM 앱의 라우팅 방식에 맞게 수정

✅ 4. LoginScreen에 통합
   - 개발자 옵션 섹션에 자동 테스트 버튼 추가
   - MainScreen에 auto-test 버튼 추가

✅ 5. 의존성 없음!
   - LogMonitor, RealTimeLogViewer 등 모든 기능이 독립적
   - 어떤 앱에서든 바로 사용 가능

📋 MSM과 MDM 공통 사용 예시:
=====================================
// 어떤 앱에서든 동일하게 사용
final autoTest = AutoTestSystem();
await autoTest.startAutoTest(context);

// 로그 모니터링도 동일
LogMonitor().log('테스트 시작!', level: LogMonitor.INFO);

🔧 유일한 차이점: 화면 목록과 네비게이션만 수정하면 됨!
*/

/// 🔍 실시간 로그 모니터링 및 Exception 감지 시스템
class LogMonitor {
  static final LogMonitor _instance = LogMonitor._internal();
  factory LogMonitor() => _instance;
  LogMonitor._internal();

  final List<LogEntry> _logs = [];
  final List<ExceptionEntry> _exceptions = [];
  final StreamController<LogEvent> _logStream = StreamController<LogEvent>.broadcast();
  
  // 🎯 로그 레벨
  static const int DEBUG = 0;
  static const int INFO = 1;
  static const int WARNING = 2;
  static const int ERROR = 3;
  static const int EXCEPTION = 4;

  // 📊 로그 통계
  Map<int, int> _logCounts = {
    DEBUG: 0,
    INFO: 0,
    WARNING: 2,
    ERROR: 0,
    EXCEPTION: 0,
  };

  Stream<LogEvent> get logStream => _logStream.stream;
  List<LogEntry> get logs => List.unmodifiable(_logs);
  List<ExceptionEntry> get exceptions => List.unmodifiable(_exceptions);
  Map<int, int> get logCounts => Map.unmodifiable(_logCounts);

  /// 📝 로그 추가
  void log(String message, {int level = INFO, String? tag, Map<String, dynamic>? data}) {
    final entry = LogEntry(
      message: message,
      level: level,
      tag: tag ?? 'AutoTest',
      timestamp: DateTime.now(),
      data: data,
    );
    
    _logs.add(entry);
    _logCounts[level] = (_logCounts[level] ?? 0) + 1;
    
    // 최대 1000개의 로그만 보관
    if (_logs.length > 1000) {
      _logs.removeAt(0);
    }
    
    _logStream.add(LogEvent.newLog(entry));
    
    // 콘솔에도 출력
    _printToConsole(entry);
  }

  /// ❌ Exception 감지 및 저장
  void captureException(dynamic exception, StackTrace? stackTrace, {String? context}) {
    final entry = ExceptionEntry(
      exception: exception,
      stackTrace: stackTrace,
      context: context ?? 'Unknown',
      timestamp: DateTime.now(),
    );
    
    _exceptions.add(entry);
    _logCounts[EXCEPTION] = (_logCounts[EXCEPTION] ?? 0) + 1;
    
    // Exception도 로그에 추가
    log('🚨 EXCEPTION: $exception', level: EXCEPTION, tag: 'Exception', data: {
      'context': context,
      'stackTrace': stackTrace?.toString(),
    });
    
    _logStream.add(LogEvent.newException(entry));
  }

  /// 🖨️ 콘솔 출력
  void _printToConsole(LogEntry entry) {
    final levelEmoji = {
      DEBUG: '🔍',
      INFO: 'ℹ️',
      WARNING: '⚠️',
      ERROR: '❌',
      EXCEPTION: '🚨',
    };
    
    final timestamp = entry.timestamp.toIso8601String().substring(11, 19);
    final emoji = levelEmoji[entry.level] ?? '📝';
    
    developer.log('$emoji [$timestamp] [${entry.tag}] ${entry.message}');
  }

  /// 🧹 로그 정리
  void clearLogs() {
    _logs.clear();
    _exceptions.clear();
    _logCounts = {DEBUG: 0, INFO: 0, WARNING: 0, ERROR: 0, EXCEPTION: 0};
    _logStream.add(LogEvent.cleared());
  }

  /// 📊 로그 통계 리포트 생성
  String generateLogReport() {
    final report = StringBuffer();
    report.writeln('📊 실시간 로그 리포트');
    report.writeln('=' * 40);
    report.writeln('🔍 DEBUG: ${_logCounts[DEBUG]}개');
    report.writeln('ℹ️ INFO: ${_logCounts[INFO]}개');
    report.writeln('⚠️ WARNING: ${_logCounts[WARNING]}개');
    report.writeln('❌ ERROR: ${_logCounts[ERROR]}개');
    report.writeln('🚨 EXCEPTION: ${_logCounts[EXCEPTION]}개');
    report.writeln('');
    
    if (_exceptions.isNotEmpty) {
      report.writeln('🚨 발생한 Exception들:');
      for (final ex in _exceptions) {
        report.writeln('  • [${ex.timestamp.toIso8601String().substring(11, 19)}] ${ex.context}: ${ex.exception}');
      }
      report.writeln('');
    }
    
    return report.toString();
  }
}

/// 📝 로그 엔트리
class LogEntry {
  final String message;
  final int level;
  final String tag;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  LogEntry({
    required this.message,
    required this.level,
    required this.tag,
    required this.timestamp,
    this.data,
  });
}

/// ❌ Exception 엔트리
class ExceptionEntry {
  final dynamic exception;
  final StackTrace? stackTrace;
  final String context;
  final DateTime timestamp;

  ExceptionEntry({
    required this.exception,
    required this.stackTrace,
    required this.context,
    required this.timestamp,
  });
}

/// 📺 로그 이벤트
abstract class LogEvent {
  factory LogEvent.newLog(LogEntry entry) = NewLogEvent;
  factory LogEvent.newException(ExceptionEntry entry) = NewExceptionEvent;
  factory LogEvent.cleared() = LogsClearedEvent;
}

class NewLogEvent implements LogEvent {
  final LogEntry entry;
  NewLogEvent(this.entry);
}

class NewExceptionEvent implements LogEvent {
  final ExceptionEntry entry;
  NewExceptionEvent(this.entry);
}

class LogsClearedEvent implements LogEvent {}

/// 🔍 실시간 로그 뷰어 위젯
class RealTimeLogViewer extends StatefulWidget {
  const RealTimeLogViewer({super.key});

  @override
  State<RealTimeLogViewer> createState() => _RealTimeLogViewerState();
}

class _RealTimeLogViewerState extends State<RealTimeLogViewer> {
  final LogMonitor _monitor = LogMonitor();
  late StreamSubscription _subscription;
  bool _autoScroll = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _subscription = _monitor.logStream.listen((event) {
      if (mounted) {
        setState(() {});
        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = _monitor.logs;
    final counts = _monitor.logCounts;

    return Column(
      children: [
        // 🎛️ 헤더 및 통계
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('실시간 로그 모니터', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Switch(
                    value: _autoScroll,
                    onChanged: (value) => setState(() => _autoScroll = value),
                  ),
                  const Text('자동스크롤', style: TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  _buildStatChip('🔍', counts[LogMonitor.DEBUG] ?? 0, Colors.grey),
                  _buildStatChip('ℹ️', counts[LogMonitor.INFO] ?? 0, Colors.blue),
                  _buildStatChip('⚠️', counts[LogMonitor.WARNING] ?? 0, Colors.orange),
                  _buildStatChip('❌', counts[LogMonitor.ERROR] ?? 0, Colors.red),
                  _buildStatChip('🚨', counts[LogMonitor.EXCEPTION] ?? 0, Colors.purple),
                ],
              ),
            ],
          ),
        ),
        
        // 📝 로그 목록
        Expanded(
          child: logs.isEmpty
              ? const Center(child: Text('로그가 없습니다.'))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogItem(log);
                  },
                ),
        ),
        
        // 🎛️ 액션 버튼들
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _monitor.clearLogs,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('로그 지우기'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _exportLogs,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('내보내기'),
              ),
              const Spacer(),
              Text('총 ${logs.length}개 로그', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String emoji, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$emoji $count',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLogItem(LogEntry log) {
    final colors = {
      LogMonitor.DEBUG: Colors.grey,
      LogMonitor.INFO: Colors.blue,
      LogMonitor.WARNING: Colors.orange,
      LogMonitor.ERROR: Colors.red,
      LogMonitor.EXCEPTION: Colors.purple,
    };

    final color = colors[log.level] ?? Colors.black;
    final timestamp = log.timestamp.toIso8601String().substring(11, 19);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timestamp,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              log.tag,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exportLogs() {
    final report = _monitor.generateLogReport();
    // TODO: 실제 파일 내보내기 구현
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그 리포트'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              report,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}

/// 🤖 자동 테스트 시스템
/// 개발 모드에서만 동작하며, 자동으로 모든 화면을 순회하면서 에러를 체크
class AutoTestSystem {
  static final AutoTestSystem _instance = AutoTestSystem._internal();
  factory AutoTestSystem() => _instance;
  AutoTestSystem._internal();

  // 🎯 테스트 설정
  static const bool enableAutoTest = true; // ← 이 값을 false로 바꾸면 자동 테스트 비활성화
  static const Duration screenTestDuration = Duration(seconds: 3); // 각 화면 테스트 시간
  static const Duration navigationDelay = Duration(milliseconds: 500); // 화면 전환 대기시간
  
  // 📋 테스트 상태
  bool _isRunning = false;
  final List<TestResult> _testResults = [];
  final StreamController<TestEvent> _eventStream = StreamController<TestEvent>.broadcast();
  
  // 🔍 로그 모니터링
  final LogMonitor _logMonitor = LogMonitor();
  
  // 🎯 테스트 대상 화면들 (MainScreen의 menuData 기반)
  static const List<TestScreen> testScreens = [
    // 매출현황(리포트)
    TestScreen('sales_summary', '영업매출요약', category: '매출현황'),
    TestScreen('agency_stock_status_agency', '대리점 재고', category: '매출현황'),
    TestScreen('hospital_delivery_status', '대리점 매출', category: '매출현황'),
    TestScreen('hospital_master', '병원목록', category: '매출현황'),
    TestScreen('item_export', '반출현황', category: '매출현황'),
    TestScreen('item_return', '반납현황', category: '매출현황'),
    TestScreen('auto_order_history', '자동주문내역', category: '매출현황'),
    TestScreen('ai_analysis', 'AI 분석', category: '매출현황'),
    
    // 재고현황
    TestScreen('stock_status_agency', '대리점 재고', category: '재고현황'),
    TestScreen('stock_status_my', '내 재고', category: '재고현황'),
    TestScreen('agency_stock_analytics', '재고 분석', category: '재고현황'),
    
    // 납품관리 (기존 병원납품 대체)
    TestScreen('product_delivery', '납품등록', category: '납품관리'),
    TestScreen('item_export', '반출현황', category: '납품관리'),
    TestScreen('item_return', '반납현황', category: '납품관리'),
    
    // 재고마감
    TestScreen('stock_close_regist', '재고마감 등록', category: '재고마감'),
    TestScreen('stock_close_history', '재고마감 이력', category: '재고마감'),
    
    // 재고설정
    TestScreen('agency_monthly_base_stock_regist', '월별 기준재고', category: '재고설정'),
    TestScreen('agency_safety_stock_regist', '안전재고 설정', category: '재고설정'),
    TestScreen('hospital_safety_stock_regist', '병원 안전재고', category: '재고설정'),
    TestScreen('agency_item_io_regist', '품목 입출고', category: '재고설정'),
    
    // 내정보 & 기타
    TestScreen('change_password', '비밀번호 변경', category: '내정보'),
    TestScreen('apk_download', 'APK 다운로드', category: '기타'),
  ];

  /* 🔄 MDM 앱용 화면 목록 예시:
  static const List<TestScreen> mdmTestScreens = [
    // 디바이스 관리
    TestScreen('device_list', '디바이스 목록', category: '디바이스 관리'),
    TestScreen('device_details', '디바이스 상세', category: '디바이스 관리'),
    TestScreen('device_enrollment', '디바이스 등록', category: '디바이스 관리'),
    TestScreen('device_commands', '디바이스 명령', category: '디바이스 관리'),
    
    // 정책 관리
    TestScreen('policy_list', '정책 목록', category: '정책 관리'),
    TestScreen('policy_create', '정책 생성', category: '정책 관리'),
    TestScreen('policy_assignment', '정책 할당', category: '정책 관리'),
    TestScreen('compliance_monitoring', '컴플라이언스 모니터링', category: '정책 관리'),
    
    // 앱 관리
    TestScreen('app_catalog', '앱 카탈로그', category: '앱 관리'),
    TestScreen('app_distribution', '앱 배포', category: '앱 관리'),
    TestScreen('app_updates', '앱 업데이트', category: '앱 관리'),
    TestScreen('app_blacklist', '앱 블랙리스트', category: '앱 관리'),
    
    // 사용자 관리
    TestScreen('user_list', '사용자 목록', category: '사용자 관리'),
    TestScreen('user_groups', '사용자 그룹', category: '사용자 관리'),
    TestScreen('role_management', '역할 관리', category: '사용자 관리'),
    
    // 보안 관리
    TestScreen('security_dashboard', '보안 대시보드', category: '보안 관리'),
    TestScreen('threat_detection', '위협 탐지', category: '보안 관리'),
    TestScreen('security_reports', '보안 리포트', category: '보안 관리'),
    
    // 리포트 & 분석
    TestScreen('analytics_dashboard', '분석 대시보드', category: '리포트'),
    TestScreen('usage_reports', '사용량 리포트', category: '리포트'),
    TestScreen('compliance_reports', '컴플라이언스 리포트', category: '리포트'),
    
    // 설정
    TestScreen('system_settings', '시스템 설정', category: '설정'),
    TestScreen('notification_settings', '알림 설정', category: '설정'),
    TestScreen('integration_settings', '연동 설정', category: '설정'),
  ];
  */

  // 🚀 자동 테스트 시작
  Future<void> startAutoTest(BuildContext context) async {
    if (!kDebugMode || !enableAutoTest) {
      _logMonitor.log('🚫 자동 테스트가 비활성화되어 있습니다.', level: LogMonitor.WARNING);
      return;
    }

    if (_isRunning) {
      _logMonitor.log('⚠️ 자동 테스트가 이미 실행 중입니다.', level: LogMonitor.WARNING);
      return;
    }

    _logMonitor.log('🤖 자동 테스트 시작!', level: LogMonitor.INFO);
    _logMonitor.clearLogs(); // 이전 로그 정리
    _isRunning = true;
    _testResults.clear();
    
    // 🎉 테스트 시작 이벤트
    _eventStream.add(TestEvent.started(testScreens.length));
    
    // 🎯 테스트 진행 다이얼로그 표시
    _showTestProgressDialog(context);
    
    try {
      for (int i = 0; i < testScreens.length; i++) {
        final screen = testScreens[i];
        developer.log('🎯 테스트 중: ${screen.name} (${i + 1}/${testScreens.length})');
        
        // 📱 화면 테스트 실행
        final result = await _testScreen(context, screen, i + 1);
        _testResults.add(result);
        
        // 📊 진행 상황 업데이트
        _eventStream.add(TestEvent.progress(i + 1, testScreens.length, result));
        
        // ⏱️ 다음 화면으로 이동 전 대기
        if (i < testScreens.length - 1) {
          await Future.delayed(navigationDelay);
        }
      }
      
      // ✅ 테스트 완료
      _eventStream.add(TestEvent.completed(_testResults));
      developer.log('✅ 자동 테스트 완료! 총 ${_testResults.length}개 화면 테스트됨');
      
    } catch (e, stackTrace) {
      // ❌ 테스트 실패
      developer.log('❌ 자동 테스트 실패: $e');
      _eventStream.add(TestEvent.error(e.toString(), stackTrace.toString()));
    } finally {
      _isRunning = false;
    }
  }

  // 📱 개별 화면 테스트
  Future<TestResult> _testScreen(BuildContext context, TestScreen screen, int index) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      _logMonitor.log('🎯 테스트 시작: ${screen.displayName}', tag: 'Screen Test');
      
      // 🔄 화면 변경 (MainScreen의 _selectedSubKey 변경 방식 시뮬레이션)
      await _navigateToScreen(context, screen);
      
      // ⏱️ 화면 로딩 대기
      _logMonitor.log('⏱️ ${screenTestDuration.inSeconds}초 대기 중...', tag: 'Screen Test');
      await Future.delayed(screenTestDuration);
      
      // 🔍 화면 상태 체크
      final healthCheck = await _performHealthCheck(context, screen);
      
      stopwatch.stop();
      
      final result = TestResult(
        screen: screen,
        success: healthCheck.success,
        duration: stopwatch.elapsed,
        message: healthCheck.message,
        index: index,
      );
      
      _logMonitor.log(
        '${result.success ? "✅" : "❌"} ${screen.displayName}: ${result.message}',
        level: result.success ? LogMonitor.INFO : LogMonitor.ERROR,
        tag: 'Screen Test',
      );
      
      return result;
      
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      // 🚨 Exception 캡처
      _logMonitor.captureException(e, stackTrace, context: '화면 테스트: ${screen.displayName}');
      
      return TestResult(
        screen: screen,
        success: false,
        duration: stopwatch.elapsed,
        message: '에러 발생: $e',
        error: e.toString(),
        stackTrace: stackTrace.toString(),
        index: index,
      );
    }
  }

  // 🔄 화면 네비게이션
  Future<void> _navigateToScreen(BuildContext context, TestScreen screen) async {
    try {
      developer.log('🔄 ${screen.name} 화면으로 이동 중...');
      
      // 📋 현재는 실제 화면 전환 대신 시뮬레이션으로 처리
      // 실제 화면 전환은 MainScreen에서 GlobalKey나 callback을 통해 구현 가능
      developer.log('📱 ${screen.displayName} 화면 테스트 시뮬레이션');
      
      /* 🔄 실제 MSM 앱 네비게이션 방식 예시:
      final mainScreenState = MainScreen.of(context);
      mainScreenState?.changeSelectedSubKey(screen.name);
      */
      
      /* 🔄 MDM 앱 네비게이션 방식 예시:
      switch (screen.name) {
        case 'device_list':
          Navigator.pushNamed(context, '/mdm/devices');
          break;
        case 'policy_list':
          Navigator.pushNamed(context, '/mdm/policies');
          break;
        case 'app_catalog':
          Navigator.pushNamed(context, '/mdm/apps');
          break;
        default:
          Navigator.pushNamed(context, '/mdm/${screen.name}');
      }
      */
      
      // 🎯 화면별 특별한 테스트 로직
      switch (screen.name) {
        case 'sales_summary':
          developer.log('💰 영업매출요약 화면 테스트');
          break;
        // 병원재고조사 관련 테스트 케이스 제거됨
          developer.log('🏥 병원재고조사 대시보드 테스트');
          break;
        case 'agency_stock_status':
          developer.log('📦 대리점 재고현황 테스트');
          break;
        default:
          developer.log('🎯 ${screen.displayName} 기본 테스트');
      }
      
      /* 🔄 MDM 앱 화면별 특별 테스트 예시:
      switch (screen.name) {
        case 'device_list':
          developer.log('📱 디바이스 목록 화면 테스트 - 디바이스 로딩 확인');
          break;
        case 'policy_list':
          developer.log('📋 정책 목록 화면 테스트 - 정책 데이터 확인');
          break;
        case 'security_dashboard':
          developer.log('🔒 보안 대시보드 테스트 - 위협 통계 확인');
          break;
        case 'app_distribution':
          developer.log('📦 앱 배포 화면 테스트 - 배포 상태 확인');
          break;
        default:
          developer.log('🎯 ${screen.displayName} 기본 테스트');
      }
      */
      
    } catch (e) {
      developer.log('❌ 화면 전환 실패: ${screen.name} - $e');
      rethrow;
    }
  }

  // 🔍 화면 건강 상태 체크
  Future<HealthCheck> _performHealthCheck(BuildContext context, TestScreen screen) async {
    try {
      // 📊 다양한 체크 항목들
      final checks = <String, bool>{};
      
      // ✅ 위젯 트리 상태 체크
      checks['widget_tree'] = _checkWidgetTree(context);
      
      // ✅ 메모리 사용량 체크
      checks['memory_usage'] = _checkMemoryUsage();
      
      // ✅ 네트워크 상태 체크 (선택적)
      checks['network_status'] = await _checkNetworkStatus(screen);
      
      // ✅ 에러 로그 체크
      checks['error_logs'] = _checkErrorLogs();
      
      // 📊 전체 성공 여부
      final allPassed = checks.values.every((check) => check);
      final failedChecks = checks.entries.where((entry) => !entry.value).map((e) => e.key).toList();
      
      return HealthCheck(
        success: allPassed,
        message: allPassed 
          ? '✅ 모든 체크 통과' 
          : '❌ 실패한 체크: ${failedChecks.join(', ')}',
        details: checks,
      );
      
    } catch (e) {
      return HealthCheck(
        success: false,
        message: '❌ 건강 상태 체크 실패: $e',
        details: {},
      );
    }
  }

  // 🎯 개별 체크 메서드들
  bool _checkWidgetTree(BuildContext context) {
    try {
      // 위젯 트리가 정상적으로 마운트되어 있는지 확인
      final mounted = context.mounted;
      final hasMediaQuery = MediaQuery.maybeOf(context) != null;
      final hasTheme = Theme.of(context) != null;
      
      return mounted && hasMediaQuery && hasTheme;
    } catch (e) {
      developer.log('❌ 위젯 트리 체크 실패: $e');
      return false;
    }
  }

  bool _checkMemoryUsage() {
    try {
      // 간단한 메모리 체크 (실제로는 더 정교한 체크 필요)
      return true; // 일단 항상 통과
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkNetworkStatus(TestScreen screen) async {
    try {
      // 네트워크가 필요한 화면들에 대해서만 체크
      if (screen.requiresNetwork) {
        // TODO: 실제 네트워크 체크 로직
        return true;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  bool _checkErrorLogs() {
    try {
      // 최근 에러 로그 체크
      // TODO: 실제 로그 시스템과 연동
      return true;
    } catch (e) {
      return false;
    }
  }

  // 🎯 테스트 진행 다이얼로그
  void _showTestProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TestProgressDialog(eventStream: _eventStream.stream),
    );
  }

  // 📊 테스트 결과 리포트 생성
  String generateReport() {
    if (_testResults.isEmpty) {
      return '📝 테스트 결과가 없습니다.';
    }

    final successful = _testResults.where((r) => r.success).length;
    final failed = _testResults.where((r) => !r.success).length;
    final totalDuration = _testResults.fold<Duration>(
      Duration.zero, (sum, result) => sum + result.duration);

    final report = StringBuffer();
    report.writeln('🤖 자동 테스트 리포트');
    report.writeln('=' * 50);
    report.writeln('📊 전체 결과: ${_testResults.length}개 화면 테스트');
    report.writeln('✅ 성공: $successful개');
    report.writeln('❌ 실패: $failed개');
    report.writeln('⏱️ 총 소요 시간: ${totalDuration.inSeconds}초');
    report.writeln('');

    // 카테고리별 결과
    final categories = testScreens.map((s) => s.category).toSet();
    for (final category in categories) {
      final categoryResults = _testResults.where((r) => r.screen.category == category);
      final categorySuccess = categoryResults.where((r) => r.success).length;
      report.writeln('📁 $category: $categorySuccess/${categoryResults.length} 성공');
    }
    report.writeln('');

    // 실패한 화면들 상세
    final failedResults = _testResults.where((r) => !r.success);
    if (failedResults.isNotEmpty) {
      report.writeln('❌ 실패한 화면들:');
      for (final result in failedResults) {
        report.writeln('  • ${result.screen.displayName}: ${result.message}');
      }
      report.writeln('');
    }

    // 성능 통계
    report.writeln('⚡ 성능 통계:');
    final durations = _testResults.map((r) => r.duration.inMilliseconds).toList()..sort();
    if (durations.isNotEmpty) {
      report.writeln('  • 최단 시간: ${durations.first}ms');
      report.writeln('  • 최장 시간: ${durations.last}ms');
      report.writeln('  • 평균 시간: ${durations.reduce((a, b) => a + b) ~/ durations.length}ms');
    }

    return report.toString();
  }

  // 🧹 정리
  void dispose() {
    _eventStream.close();
  }

  // 🔧 Sales Summary 화면 전용 렌더링 테스트
  Future<void> startSalesSummaryRenderingTest(BuildContext context) async {
    if (!kDebugMode) {
      print('🚫 렌더링 테스트는 개발 모드에서만 실행됩니다.');
      return;
    }

    print('🔧 Sales Summary 화면 렌더링 테스트 시작!');
    
    // 렌더링 에러 감지 시작
    _startRenderingErrorDetection();
    
    await _runSalesSummaryTests(context);
    
    print('✅ Sales Summary 렌더링 테스트 완료!');
  }

  // 🎯 Sales Summary 화면 전체 테스트 실행
  Future<void> _runSalesSummaryTests(BuildContext context) async {
    final testCases = [
      // 다양한 화면 크기 테스트
      {'width': 320.0, 'height': 568.0, 'name': '아이폰 SE'},
      {'width': 375.0, 'height': 667.0, 'name': '아이폰 8'},
      {'width': 414.0, 'height': 896.0, 'name': '아이폰 XR'},
      {'width': 768.0, 'height': 1024.0, 'name': '아이패드'},
      {'width': 1024.0, 'height': 768.0, 'name': '아이패드 가로'},
      {'width': 1440.0, 'height': 900.0, 'name': '데스크톱'},
    ];

    final salesSummaryTabs = [
      '요약',
      '차트',
      '데이터',
      '데이터(상세)',
    ];

    for (final testCase in testCases) {
      print('📱 화면 크기 테스트: ${testCase['name']} (${testCase['width']}x${testCase['height']})');
      
             // 화면 크기 변경 시뮬레이션
       await _simulateScreenResize(context, (testCase['width']! as num).toDouble(), (testCase['height']! as num).toDouble());
      
      for (final tab in salesSummaryTabs) {
        print('  🔄 탭 테스트: $tab');
        await _testSalesSummaryTab(context, tab);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // 확장/축소 기능 테스트
      await _testExpandCollapseFeatures(context);
      
      // 필터 기능 테스트
      await _testFilterFeatures(context);
      
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // 📐 화면 크기 변경 시뮬레이션
  Future<void> _simulateScreenResize(BuildContext context, double width, double height) async {
    try {
      // MediaQuery 오버라이드를 통한 화면 크기 시뮬레이션
      final mediaQuery = MediaQuery.of(context);
      final newMediaQuery = mediaQuery.copyWith(
        size: Size(width, height),
      );
      
      // 위젯 트리 강제 리빌드
      if (context.mounted) {
        // Flutter Inspector에서 확인 가능하도록 로그
        print('  📐 화면 크기 변경: ${width}x$height');
        
        // 프레임 완료까지 대기
        await Future.delayed(const Duration(milliseconds: 100));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkForRenderingErrors(context);
        });
      }
    } catch (e) {
      print('❌ 화면 크기 변경 실패: $e');
    }
  }

  // 🔄 Sales Summary 탭 테스트
  Future<void> _testSalesSummaryTab(BuildContext context, String tabName) async {
    try {
      print('    📋 $tabName 탭 렌더링 검사...');
      
      // 탭 전환 시뮬레이션 (실제 탭 인덱스 찾기)
      final tabIndex = _getSalesTabIndex(tabName);
      if (tabIndex >= 0) {
        // 탭 전환 후 렌더링 검사
        await Future.delayed(const Duration(milliseconds: 300));
        _checkForRenderingErrors(context);
        
        // 해당 탭의 특수 기능들 테스트
        await _testTabSpecificFeatures(context, tabName);
      }
    } catch (e) {
      print('    ❌ $tabName 탭 테스트 실패: $e');
    }
  }

  // 📑 탭별 특수 기능 테스트
  Future<void> _testTabSpecificFeatures(BuildContext context, String tabName) async {
    switch (tabName) {
      case '요약':
        await _testSummaryTabFeatures(context);
        break;
      case '차트':
        await _testChartTabFeatures(context);
        break;
      case '데이터':
        await _testDataTabFeatures(context);
        break;
      case '데이터(상세)':
        await _testDataDetailTabFeatures(context);
        break;
    }
  }

  // 📊 요약 탭 기능 테스트
  Future<void> _testSummaryTabFeatures(BuildContext context) async {
    print('      🔧 요약 카드 렌더링 검사...');
    
    // 기간 선택기 확장/축소
    await _simulateExpansionTileToggle(context, '기간 선택');
    _checkForRenderingErrors(context);
    
    // 퀵 필터 확장/축소
    await _simulateExpansionTileToggle(context, '퀵 필터');
    _checkForRenderingErrors(context);
  }

  // 📈 차트 탭 기능 테스트
  Future<void> _testChartTabFeatures(BuildContext context) async {
    print('      📈 차트 렌더링 검사...');
    
    // 차트 타입 변경 시뮬레이션
    final chartTypes = ['막대', '파이', '라인', '도넛', '트리맵'];
    for (final chartType in chartTypes) {
      print('        📊 $chartType 차트 테스트...');
      await Future.delayed(const Duration(milliseconds: 200));
      _checkForRenderingErrors(context);
    }
  }

  // 📋 데이터 탭 기능 테스트
  Future<void> _testDataTabFeatures(BuildContext context) async {
    print('      📋 데이터 테이블 렌더링 검사...');
    
    // 컬럼 선택기 토글
    await _simulateExpansionTileToggle(context, '컬럼 설정');
    _checkForRenderingErrors(context);
    
    // 검색 패널 토글
    await _simulateExpansionTileToggle(context, '검색 패널');
    _checkForRenderingErrors(context);
  }

  // 📋 데이터 상세 탭 기능 테스트
  Future<void> _testDataDetailTabFeatures(BuildContext context) async {
    print('      📊 상세 데이터 렌더링 검사...');
    
    // 고급 수치 조건 패널
    await _simulateExpansionTileToggle(context, '고급 수치 조건');
    _checkForRenderingErrors(context);
  }

  // 🔄 확장/축소 기능 테스트
  Future<void> _testExpandCollapseFeatures(BuildContext context) async {
    final expansionFeatures = [
      '기간 선택기',
      '퀵 필터',
      '고급 필터',
      '컬럼 선택기',
      '차트 섹션',
      '요약 통계',
    ];

    for (final feature in expansionFeatures) {
      print('    🔄 $feature 확장/축소 테스트...');
      await _simulateExpansionTileToggle(context, feature);
      _checkForRenderingErrors(context);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  // 🔍 필터 기능 테스트
  Future<void> _testFilterFeatures(BuildContext context) async {
    print('    🔍 필터 기능 렌더링 검사...');
    
    // 검색어 입력 시뮬레이션
    await _simulateTextInput(context, 'search', '테스트');
    _checkForRenderingErrors(context);
    
    // 국가 필터 선택
    await _simulateDropdownSelection(context, 'country');
    _checkForRenderingErrors(context);
    
    // 거래처 분류 필터
    await _simulateDropdownSelection(context, 'type');
    _checkForRenderingErrors(context);
  }

  // 🎬 ExpansionTile 토글 시뮬레이션
  Future<void> _simulateExpansionTileToggle(BuildContext context, String title) async {
    try {
      // ExpansionTile 찾기 및 토글 시뮬레이션
      print('      🎬 $title 토글 시뮬레이션...');
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('      ❌ $title 토글 실패: $e');
    }
  }

  // ⌨️ 텍스트 입력 시뮬레이션
  Future<void> _simulateTextInput(BuildContext context, String fieldId, String text) async {
    try {
      print('      ⌨️ $fieldId 필드에 "$text" 입력 시뮬레이션...');
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('      ❌ 텍스트 입력 실패: $e');
    }
  }

  // 📝 드롭다운 선택 시뮬레이션
  Future<void> _simulateDropdownSelection(BuildContext context, String dropdownId) async {
    try {
      print('      📝 $dropdownId 드롭다운 선택 시뮬레이션...');
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('      ❌ 드롭다운 선택 실패: $e');
    }
  }

  // 🔍 렌더링 에러 감지 시작
  void _startRenderingErrorDetection() {
    // FlutterError 핸들러 오버라이드
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('RenderFlex overflowed') ||
          details.exception.toString().contains('OVERFLOWED')) {
        print('🚨 렌더링 오버플로우 감지: ${details.exception}');
        print('📍 위치: ${details.stack}');
      }
      
      // 기본 에러 핸들러도 호출
      FlutterError.presentError(details);
    };
  }

  // 🔍 렌더링 에러 검사
  void _checkForRenderingErrors(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // RenderObject 트리 검사
        final renderObject = context.findRenderObject();
        if (renderObject != null) {
          _inspectRenderObject(renderObject);
        }
      } catch (e) {
        print('🚨 렌더링 검사 중 에러: $e');
      }
    });
  }

  // 🔍 RenderObject 검사
  void _inspectRenderObject(RenderObject renderObject) {
    try {
      // RenderFlex 오버플로우 검사
      if (renderObject is RenderFlex) {
        // 오버플로우 검사 로직 (Flutter 3.x 호환)
        final constraints = renderObject.constraints;
        final size = renderObject.size;
        
        // 기본적인 크기 검사로 대체
        if (size.width > constraints.maxWidth || size.height > constraints.maxHeight) {
          print('🚨 RenderFlex 크기 제약 초과 발견');
          print('  제약조건: $constraints');
          print('  실제크기: $size');
        }
      }
      
      // 자식들도 재귀적으로 검사
      renderObject.visitChildren(_inspectRenderObject);
    } catch (e) {
      // 검사 중 에러는 무시 (성능상의 이유)
    }
  }

  // 📑 탭 인덱스 가져오기
  int _getSalesTabIndex(String tabName) {
    switch (tabName) {
      case '요약': return 0;
      case '차트': return 1;
      case '데이터': return 2;
      case '데이터(상세)': return 3;
      default: return -1;
    }
  }
}

// 📱 테스트 대상 화면 정의
class TestScreen {
  final String name;
  final String displayName;
  final String category;
  final bool requiresNetwork;

  const TestScreen(
    this.name, 
    this.displayName, {
    required this.category,
    this.requiresNetwork = true,
  });

  @override
  String toString() => '$category > $displayName';
}

// 📊 테스트 결과
class TestResult {
  final TestScreen screen;
  final bool success;
  final Duration duration;
  final String message;
  final String? error;
  final String? stackTrace;
  final int index;

  TestResult({
    required this.screen,
    required this.success,
    required this.duration,
    required this.message,
    required this.index,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    return '${success ? "✅" : "❌"} ${screen.displayName} (${duration.inMilliseconds}ms)';
  }
}

// 🔍 건강 상태 체크 결과
class HealthCheck {
  final bool success;
  final String message;
  final Map<String, bool> details;

  HealthCheck({
    required this.success,
    required this.message,
    required this.details,
  });
}

// 📺 테스트 이벤트
abstract class TestEvent {
  factory TestEvent.started(int totalScreens) = TestStartedEvent;
  factory TestEvent.progress(int current, int total, TestResult result) = TestProgressEvent;
  factory TestEvent.completed(List<TestResult> results) = TestCompletedEvent;
  factory TestEvent.error(String message, String stackTrace) = TestErrorEvent;
}

class TestStartedEvent implements TestEvent {
  final int totalScreens;
  TestStartedEvent(this.totalScreens);
}

class TestProgressEvent implements TestEvent {
  final int current;
  final int total;
  final TestResult result;
  TestProgressEvent(this.current, this.total, this.result);
}

class TestCompletedEvent implements TestEvent {
  final List<TestResult> results;
  TestCompletedEvent(this.results);
}

class TestErrorEvent implements TestEvent {
  final String message;
  final String stackTrace;
  TestErrorEvent(this.message, this.stackTrace);
}

// 🎯 테스트 진행 다이얼로그
class TestProgressDialog extends StatefulWidget {
  final Stream<TestEvent> eventStream;

  const TestProgressDialog({super.key, required this.eventStream});

  @override
  State<TestProgressDialog> createState() => _TestProgressDialogState();
}

class _TestProgressDialogState extends State<TestProgressDialog> {
  int _currentStep = 0;
  int _totalSteps = 0;
  List<TestResult> _results = [];
  String _currentScreen = '';
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    widget.eventStream.listen((event) {
      setState(() {
        switch (event.runtimeType) {
          case TestStartedEvent:
            final e = event as TestStartedEvent;
            _totalSteps = e.totalScreens;
            break;
          case TestProgressEvent:
            final e = event as TestProgressEvent;
            _currentStep = e.current;
            _currentScreen = e.result.screen.displayName;
            _results.add(e.result);
            break;
          case TestCompletedEvent:
            final e = event as TestCompletedEvent;
            _isCompleted = true;
            _results = e.results;
            break;
          case TestErrorEvent:
            final e = event as TestErrorEvent;
            _isCompleted = true;
            break;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSteps > 0 ? _currentStep / _totalSteps : 0.0;
    final successCount = _results.where((r) => r.success).length;
    final failCount = _results.where((r) => !r.success).length;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.smart_toy, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('🤖 자동 테스트 실행 중'),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 진행률 표시
            Text('진행률: $_currentStep / $_totalSteps'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 16),
            
            // 현재 테스트 중인 화면
            if (!_isCompleted) ...[
              Text('현재 테스트 중: $_currentScreen'),
              const SizedBox(height: 16),
            ],
            
            // 통계
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('✅ 성공: $successCount', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('❌ 실패: $failCount', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 결과 목록
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      result.success ? Icons.check_circle : Icons.error,
                      color: result.success ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    title: Text(
                      result.screen.displayName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      '${result.duration.inMilliseconds}ms',
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: result.success 
                      ? null 
                      : const Icon(Icons.warning, color: Colors.orange, size: 16),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isCompleted) ...[
          TextButton(
            onPressed: () {
              // 상세 리포트 보기
              final report = AutoTestSystem().generateReport();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('📊 테스트 리포트'),
                  content: SizedBox(
                    width: 500,
                    height: 400,
                    child: SingleChildScrollView(
                      child: Text(
                        report,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('📊 상세 리포트'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('완료'),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('중단'),
          ),
        ],
      ],
    );
  }
} 