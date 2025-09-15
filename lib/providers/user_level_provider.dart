import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analytics_data.dart';
import '../services/sales_service.dart';
import 'auth_provider.dart';

class UserLevelProvider extends ChangeNotifier {
  final AuthProvider _authProvider;

  // 사용자 레벨 정보
  UserLevel _currentLevel = UserLevel.viewer;
  Map<String, dynamic> _permissions = {};
  List<String> _allowedHospitals = [];
  List<String> _allowedRegions = [];
  List<String> _allowedProducts = [];

  // 데이터 접근 제한
  Map<String, DataAccessRule> _dataAccessRules = {};
  Map<String, List<String>> _fieldVisibility = {};

  // 레벨별 기본 설정
  static const Map<UserLevel, Map<String, bool>> _defaultPermissions = {
    UserLevel.admin: {
      'viewAllData': true,
      'exportData': true,
      'createReports': true,
      'manageUsers': true,
      'systemSettings': true,
      'rawDataAccess': true,
      'sensitiveData': true,
      'realTimeData': true,
    },
    UserLevel.manager: {
      'viewAllData': true,
      'exportData': true,
      'createReports': true,
      'manageUsers': false,
      'systemSettings': false,
      'rawDataAccess': true,
      'sensitiveData': true,
      'realTimeData': true,
    },
    UserLevel.analyst: {
      'viewAllData': false,
      'exportData': true,
      'createReports': true,
      'manageUsers': false,
      'systemSettings': false,
      'rawDataAccess': false,
      'sensitiveData': false,
      'realTimeData': false,
    },
    UserLevel.viewer: {
      'viewAllData': false,
      'exportData': false,
      'createReports': false,
      'manageUsers': false,
      'systemSettings': false,
      'rawDataAccess': false,
      'sensitiveData': false,
      'realTimeData': false,
    },
  };

  UserLevelProvider(this._authProvider) {
    _initializeUserLevel();
  }

  // Getters
  UserLevel get currentLevel => _currentLevel;
  Map<String, dynamic> get permissions => _permissions;
  List<String> get allowedHospitals => _allowedHospitals;
  List<String> get allowedRegions => _allowedRegions;
  List<String> get allowedProducts => _allowedProducts;

  // 권한 확인
  bool hasPermission(String permission) {
    return _permissions[permission] == true;
  }

  bool canViewAllData() => hasPermission('viewAllData');
  bool canExportData() => hasPermission('exportData');
  bool canCreateReports() => hasPermission('createReports');
  bool canManageUsers() => hasPermission('manageUsers');
  bool canAccessSystemSettings() => hasPermission('systemSettings');
  bool canAccessRawData() => hasPermission('rawDataAccess');
  bool canViewSensitiveData() => hasPermission('sensitiveData');
  bool canAccessRealTimeData() => hasPermission('realTimeData');

  // 사용자 레벨 초기화
  Future<void> _initializeUserLevel() async {
    try {
      // AuthProvider에서 사용자 정보 가져오기
      final userInfo = _authProvider.userInfo;
      if (userInfo != null) {
        // 사용자 레벨 결정
        _currentLevel = _determineUserLevel(userInfo);

        // 권한 설정
        await _loadPermissions();

        // 데이터 접근 규칙 설정
        await _loadDataAccessRules();

        // 필드 가시성 설정
        _setupFieldVisibility();

        print('사용자 레벨 초기화 완료: $_currentLevel');
        print('권한: $_permissions');

        notifyListeners();
      }
    } catch (e) {
      print('사용자 레벨 초기화 오류: $e');
    }
  }

  // 사용자 레벨 결정
  UserLevel _determineUserLevel(Map<String, dynamic> userInfo) {
    // 사용자 정보에서 레벨 결정 로직
    final userRole = userInfo['role']?.toString().toLowerCase() ?? '';
    final userDepartment = userInfo['department']?.toString().toLowerCase() ?? '';
    final isManager = userInfo['isManager'] == true || userInfo['IS_MANAGER'] == true;

    // 관리자
    if (userRole.contains('admin') || userRole.contains('administrator')) {
      return UserLevel.admin;
    }

    // 매니저
    if (isManager || userRole.contains('manager') || userDepartment.contains('management')) {
      return UserLevel.manager;
    }

    // 분석가
    if (userRole.contains('analyst') || userDepartment.contains('analytics') ||
        userRole.contains('data')) {
      return UserLevel.analyst;
    }

    // 기본은 뷰어
    return UserLevel.viewer;
  }

  // 권한 로드
  Future<void> _loadPermissions() async {
    // 기본 권한 설정
    _permissions = Map.from(_defaultPermissions[_currentLevel] ?? {});

    // 저장된 커스텀 권한이 있으면 로드
    final prefs = await SharedPreferences.getInstance();
    final customPermissionsJson = prefs.getString('user_permissions_${_authProvider.userInfo?['id']}');

    if (customPermissionsJson != null) {
      // JSON 파싱 및 권한 병합 (실제로는 json.decode 사용)
      // 현재는 간단 구현
    }

    // 서버에서 추가 권한 정보 로드 (필요시)
    await _loadServerPermissions();
  }

  // 서버 권한 로드
  Future<void> _loadServerPermissions() async {
    try {
      // 서버에서 사용자별 권한 정보를 가져오는 API 호출
      // 현재는 기본 구현
    } catch (e) {
      print('서버 권한 로드 오류: $e');
    }
  }

  // 데이터 접근 규칙 로드
  Future<void> _loadDataAccessRules() async {
    _dataAccessRules.clear();
    _allowedHospitals.clear();
    _allowedRegions.clear();
    _allowedProducts.clear();

    final userInfo = _authProvider.userInfo;
    if (userInfo == null) return;

    // 레벨별 데이터 접근 규칙 설정
    switch (_currentLevel) {
      case UserLevel.admin:
        // 관리자는 모든 데이터 접근 가능
        _dataAccessRules['hospitals'] = DataAccessRule.all();
        _dataAccessRules['regions'] = DataAccessRule.all();
        _dataAccessRules['products'] = DataAccessRule.all();
        break;

      case UserLevel.manager:
        // 매니저는 담당 지역/부서의 데이터만
        await _loadManagerDataAccess(userInfo);
        break;

      case UserLevel.analyst:
        // 분석가는 익명화된 데이터만
        await _loadAnalystDataAccess(userInfo);
        break;

      case UserLevel.viewer:
        // 뷰어는 요약 데이터만
        await _loadViewerDataAccess(userInfo);
        break;
    }
  }

  // 매니저 데이터 접근 설정
  Future<void> _loadManagerDataAccess(Map<String, dynamic> userInfo) async {
    // 담당 지역 정보
    final assignedRegion = userInfo['assignedRegion']?.toString() ?? '';
    if (assignedRegion.isNotEmpty) {
      _allowedRegions.add(assignedRegion);
      _dataAccessRules['regions'] = DataAccessRule.restricted(_allowedRegions);
    }

    // 담당 병원 정보
    final assignedHospitals = userInfo['assignedHospitals'] as List<dynamic>? ?? [];
    _allowedHospitals.addAll(assignedHospitals.map((h) => h.toString()));

    if (_allowedHospitals.isNotEmpty) {
      _dataAccessRules['hospitals'] = DataAccessRule.restricted(_allowedHospitals);
    } else {
      // 담당 병원이 없으면 지역 기반으로 병원 목록 로드
      await _loadHospitalsByRegion(assignedRegion);
    }

    // 상품은 일반적으로 모두 접근 가능
    _dataAccessRules['products'] = DataAccessRule.all();
  }

  // 지역별 병원 로드
  Future<void> _loadHospitalsByRegion(String region) async {
    if (region.isEmpty) return;

    try {
      // 실제로는 API를 통해 해당 지역의 병원 목록을 가져옴
      // 현재는 간단한 예시
      final mockHospitals = [
        '${region}대학병원',
        '${region}종합병원',
        '${region}의료원',
      ];

      _allowedHospitals.addAll(mockHospitals);
      _dataAccessRules['hospitals'] = DataAccessRule.restricted(_allowedHospitals);
    } catch (e) {
      print('지역별 병원 로드 오류: $e');
    }
  }

  // 분석가 데이터 접근 설정
  Future<void> _loadAnalystDataAccess(Map<String, dynamic> userInfo) async {
    // 분석가는 익명화된 데이터만 접근
    _dataAccessRules['hospitals'] = DataAccessRule.anonymized();
    _dataAccessRules['regions'] = DataAccessRule.all();
    _dataAccessRules['products'] = DataAccessRule.all();
  }

  // 뷰어 데이터 접근 설정
  Future<void> _loadViewerDataAccess(Map<String, dynamic> userInfo) async {
    // 뷰어는 집계된 요약 데이터만
    _dataAccessRules['hospitals'] = DataAccessRule.aggregated();
    _dataAccessRules['regions'] = DataAccessRule.aggregated();
    _dataAccessRules['products'] = DataAccessRule.aggregated();
  }

  // 필드 가시성 설정
  void _setupFieldVisibility() {
    _fieldVisibility.clear();

    // 레벨별 표시 가능한 필드 설정
    switch (_currentLevel) {
      case UserLevel.admin:
        _fieldVisibility['all'] = ['*']; // 모든 필드
        break;

      case UserLevel.manager:
        _fieldVisibility['sales'] = [
          'salesAmount', 'quantity', 'hospitalName', 'region',
          'productName', 'salesDate'
        ];
        _fieldVisibility['sensitive'] = ['unitPrice', 'profit'];
        break;

      case UserLevel.analyst:
        _fieldVisibility['sales'] = [
          'salesAmount', 'quantity', 'anonymizedHospital', 'region',
          'productCategory', 'salesPeriod'
        ];
        break;

      case UserLevel.viewer:
        _fieldVisibility['summary'] = [
          'totalSales', 'salesCount', 'region', 'productCategory', 'period'
        ];
        break;
    }
  }

  // 데이터 필터링 (권한에 따른)
  List<Map<String, dynamic>> filterDataByPermission(List<Map<String, dynamic>> data) {
    if (canViewAllData()) {
      return data;
    }

    List<Map<String, dynamic>> filtered = data;

    // 병원 필터링
    if (_dataAccessRules['hospitals']?.isRestricted == true) {
      filtered = filtered.where((item) {
        final hospitalName = item['hospitalName']?.toString() ?? '';
        return _allowedHospitals.any((allowed) => hospitalName.contains(allowed));
      }).toList();
    }

    // 지역 필터링
    if (_dataAccessRules['regions']?.isRestricted == true) {
      filtered = filtered.where((item) {
        final region = item['region']?.toString() ?? '';
        return _allowedRegions.contains(region);
      }).toList();
    }

    // 데이터 익명화 처리
    if (_dataAccessRules['hospitals']?.isAnonymized == true) {
      filtered = filtered.map((item) {
        final anonymized = Map<String, dynamic>.from(item);
        anonymized['hospitalName'] = _anonymizeHospitalName(item['hospitalName']?.toString() ?? '');
        return anonymized;
      }).toList();
    }

    // 민감한 데이터 제거
    if (!canViewSensitiveData()) {
      filtered = filtered.map((item) {
        final sanitized = Map<String, dynamic>.from(item);
        sanitized.removeWhere((key, value) =>
          ['unitPrice', 'profit', 'margin', 'cost'].contains(key));
        return sanitized;
      }).toList();
    }

    return filtered;
  }

  // 병원명 익명화
  String _anonymizeHospitalName(String hospitalName) {
    if (hospitalName.isEmpty) return hospitalName;

    // 간단한 익명화 - 실제로는 더 정교한 방법 사용
    final words = hospitalName.split(' ');
    if (words.isNotEmpty) {
      return '${words.first.substring(0, 1)}***${words.last}';
    }
    return hospitalName.substring(0, 1) + '*' * (hospitalName.length - 1);
  }

  // 필드 표시 가능 여부 확인
  bool canShowField(String fieldName) {
    if (canViewAllData()) return true;

    for (final visibleFields in _fieldVisibility.values) {
      if (visibleFields.contains('*') || visibleFields.contains(fieldName)) {
        return true;
      }
    }

    return false;
  }

  // 액션 수행 가능 여부 확인
  bool canPerformAction(UserAction action) {
    switch (action) {
      case UserAction.exportRawData:
        return canExportData() && canAccessRawData();

      case UserAction.createCustomReport:
        return canCreateReports();

      case UserAction.viewRealTimeData:
        return canAccessRealTimeData();

      case UserAction.modifyFilters:
        return _currentLevel != UserLevel.viewer;

      case UserAction.accessSystemLogs:
        return canAccessSystemSettings();

      case UserAction.manageUserAccounts:
        return canManageUsers();

      case UserAction.viewDetailedAnalytics:
        return _currentLevel != UserLevel.viewer;

      case UserAction.configureDashboard:
        return _currentLevel == UserLevel.admin || _currentLevel == UserLevel.manager;
    }
  }

  // 사용자 레벨 업그레이드 요청
  Future<bool> requestLevelUpgrade(UserLevel requestedLevel, String reason) async {
    try {
      // 실제로는 서버에 승인 요청을 보내는 로직
      print('레벨 업그레이드 요청: ${_currentLevel.displayName} -> ${requestedLevel.displayName}');
      print('사유: $reason');

      // 임시로 항상 false 반환 (실제로는 서버 응답에 따라)
      return false;
    } catch (e) {
      print('레벨 업그레이드 요청 오류: $e');
      return false;
    }
  }

  // 임시 권한 부여 (시간 제한)
  Future<void> grantTemporaryPermission(String permission, Duration duration) async {
    if (!canManageUsers()) return;

    _permissions[permission] = true;
    notifyListeners();

    // 시간 후 권한 해제
    Future.delayed(duration, () {
      _permissions[permission] = false;
      notifyListeners();
    });
  }

  // 사용자 활동 로깅
  void logUserActivity(String activity, Map<String, dynamic>? metadata) {
    final logEntry = {
      'userId': _authProvider.userInfo?['id'],
      'userLevel': _currentLevel.name,
      'activity': activity,
      'metadata': metadata,
      'timestamp': DateTime.now().toIso8601String(),
    };

    print('사용자 활동 로그: $logEntry');

    // 실제로는 서버에 로그 전송 또는 로컬 저장
  }

  // 권한 변경 감지
  void checkPermissionChanges() {
    // 주기적으로 서버에서 권한 변경 사항을 확인
    // 실시간 권한 업데이트가 필요한 경우 사용
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// 사용자 레벨
enum UserLevel {
  admin,      // 관리자 - 모든 권한
  manager,    // 매니저 - 부분적 관리 권한
  analyst,    // 분석가 - 분석 전용
  viewer,     // 뷰어 - 읽기 전용
}

extension UserLevelExtension on UserLevel {
  String get displayName {
    switch (this) {
      case UserLevel.admin: return '관리자';
      case UserLevel.manager: return '매니저';
      case UserLevel.analyst: return '분석가';
      case UserLevel.viewer: return '뷰어';
    }
  }

  String get description {
    switch (this) {
      case UserLevel.admin: return '시스템 전체에 대한 완전한 접근 권한';
      case UserLevel.manager: return '담당 영역의 데이터 관리 및 분석';
      case UserLevel.analyst: return '익명화된 데이터의 분석 및 리포트 작성';
      case UserLevel.viewer: return '요약 데이터의 조회만 가능';
    }
  }

  Color get color {
    switch (this) {
      case UserLevel.admin: return Colors.red;
      case UserLevel.manager: return Colors.orange;
      case UserLevel.analyst: return Colors.blue;
      case UserLevel.viewer: return Colors.green;
    }
  }

  IconData get icon {
    switch (this) {
      case UserLevel.admin: return Icons.admin_panel_settings;
      case UserLevel.manager: return Icons.manage_accounts;
      case UserLevel.analyst: return Icons.analytics;
      case UserLevel.viewer: return Icons.visibility;
    }
  }
}

// 데이터 접근 규칙
class DataAccessRule {
  final bool isRestricted;
  final bool isAnonymized;
  final bool isAggregated;
  final List<String>? allowedValues;

  const DataAccessRule({
    required this.isRestricted,
    required this.isAnonymized,
    required this.isAggregated,
    this.allowedValues,
  });

  factory DataAccessRule.all() {
    return const DataAccessRule(
      isRestricted: false,
      isAnonymized: false,
      isAggregated: false,
    );
  }

  factory DataAccessRule.restricted(List<String> allowedValues) {
    return DataAccessRule(
      isRestricted: true,
      isAnonymized: false,
      isAggregated: false,
      allowedValues: allowedValues,
    );
  }

  factory DataAccessRule.anonymized() {
    return const DataAccessRule(
      isRestricted: false,
      isAnonymized: true,
      isAggregated: false,
    );
  }

  factory DataAccessRule.aggregated() {
    return const DataAccessRule(
      isRestricted: false,
      isAnonymized: false,
      isAggregated: true,
    );
  }
}

// 사용자 액션
enum UserAction {
  exportRawData,
  createCustomReport,
  viewRealTimeData,
  modifyFilters,
  accessSystemLogs,
  manageUserAccounts,
  viewDetailedAnalytics,
  configureDashboard,
}