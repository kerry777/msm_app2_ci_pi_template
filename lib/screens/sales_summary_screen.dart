import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/sales_service.dart';
import '../utils/excel_service_io.dart';
import '../utils/preferences_manager.dart';
import '../utils/dialog_utils.dart';
import 'ai_analysis_screen.dart';  // 🚀 AI 분석 화면 추가
import '../widgets/charts/chart_templates.dart';  // 🚀 차트 템플릿 라이브러리 추가
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';

class SalesSummaryScreen extends StatefulWidget {
  const SalesSummaryScreen({super.key});

  @override
  State<SalesSummaryScreen> createState() => _SalesSummaryScreenState();
}

class _SalesSummaryScreenState extends State<SalesSummaryScreen> 
    with TickerProviderStateMixin {
  // 기존 데이터 관련 변수들
  List<Map<String, dynamic>> _summaryData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // 🆕 Raw Data 관련 변수들
  final List<Map<String, dynamic>> _rawData = [];
  final List<Map<String, dynamic>> _filteredRawData = [];
  final bool _isRawDataLoading = false;
  final String _rawDataErrorMessage = '';
  int _rawDataCurrentPage = 0;
  final String _rawDataSearchQuery = '';
  String _rawDataSortColumn = '';
  bool _rawDataSortAscending = true;
  
  // 날짜 관련 - 당해년도 전체 (1월 1일 ~ 12월 31일)
  DateTime _fromDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _toDate = DateTime(DateTime.now().year, 12, 31);
  
  // 탭 컨트롤러
  late TabController _tabController;
  
  // 테이블 관련
  String _searchQuery = '';
  String _sortColumn = 'SUM_SALE_AMT_WON';
  bool _sortAscending = false;
  int _currentPage = 0;
  
  int _rowsPerPage = 50;
  final TextEditingController _searchController = TextEditingController();
  
  // 컬럼 선택
  final Map<String, bool> _visibleColumns = {
    'CUSTOM_NAME': true,
    'NATION_NAME': true,
    'SALE_Q': true,
    'SUM_SALE_AMT_WON': true,
    '거래처분류': true,
    'CUSTOM_CODE': false,
    'CONTINENT': false,
    'MANAGE_CUSTOM_NM': false,
    'AGENT_TYPE': false,
    'SALE_P': false,
    'EXCHG_RATE_O': false,
    'SALE_LOC_AMT_F': false,
    'SALE_COST_AMT': false,
    'UPDATE_DTM': false,
  };
  
  // 필터
  Set<String> _selectedCountries = {};
  Set<String> _selectedTypes = {};

  // 🆕 템플릿화를 위한 새로운 기능들
  // 실시간 갱신
  Timer? _refreshTimer;
  bool _isAutoRefreshEnabled = false;
  int _refreshIntervalSeconds = 300; // 5분 (기본값)
  
  // 🆕 최종 조회 시간 추가
  DateTime? _lastRefreshTime;
  
  // 🆕 고급 자동 갱신 설정
  String _refreshMode = 'interval'; // 'interval' 또는 'schedule'
  List<int> _scheduleHours = [6, 9, 12, 15, 18]; // 기본 스케줄 시간들
  Timer? _scheduleCheckTimer;
  
  // 고급 설정
  bool _isDarkMode = false;
  bool _isCompactMode = false;
  bool _showGridLines = true;
  bool _enableAnimations = true;
  
  // 키보드 단축키
  final Map<LogicalKeySet, VoidCallback> _shortcuts = {};
  final FocusNode _focusNode = FocusNode();
  
  // 성능 최적화
  bool _enableVirtualization = true;
  
  // 🆕 컬럼별 필터링
  final Map<String, String> _columnFilters = {};
  final Map<String, TextEditingController> _filterControllers = {};

  // 🆕 컬럼별 필터 다이얼로그 표시
  Future<void> _showColumnFilterDialog(String columnKey) async {
    final controller = _filterControllers.putIfAbsent(
      columnKey,
      () => TextEditingController(text: _columnFilters[columnKey] ?? ''),
    );

    final isNumericColumn = _isNumericColumn(columnKey);
    final uniqueValues = _getUniqueColumnValues(columnKey);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isNumericColumn ? Icons.numbers : Icons.text_fields,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_getColumnDisplayName(columnKey)} 필터',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔽 필터 타입 안내
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isNumericColumn ? Icons.calculate : Icons.search,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isNumericColumn 
                              ? '숫자 범위 필터: ">100", ">=1000", "<500", "100-1000"'
                              : '텍스트 검색: 포함된 내용을 입력하세요',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 🔽 필터 입력 필드
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: isNumericColumn ? '조건 입력' : '검색어 입력',
                    hintText: isNumericColumn ? 'ex) >1000 또는 100-500' : 'ex) 삼성',
                    prefixIcon: Icon(isNumericColumn ? Icons.functions : Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => controller.clear(),
                          )
                        : null,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                
                // 🔽 인기 값들 (텍스트 컬럼만)
                if (!isNumericColumn && uniqueValues.isNotEmpty) ...[
                  const Text(
                    '자주 사용되는 값들:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: uniqueValues.take(20).map((value) {
                          return FilterChip(
                            label: Text(
                              value.length > 15 ? '${value.substring(0, 15)}...' : value,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                controller.text = value;
                              }
                            },
                            backgroundColor: Colors.grey[100],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            // 🔽 필터 제거
            if (_columnFilters.containsKey(columnKey) && _columnFilters[columnKey]!.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _columnFilters.remove(columnKey);
                    _filterControllers[columnKey]?.clear();
                    _applyFilters();
                  });
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.clear, color: Colors.red),
                label: const Text('필터 제거', style: TextStyle(color: Colors.red)),
              ),
            
            // 🔽 취소
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            
            // 🔽 적용
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  final filterValue = controller.text.trim();
                  if (filterValue.isNotEmpty) {
                    _columnFilters[columnKey] = filterValue;
                  } else {
                    _columnFilters.remove(columnKey);
                  }
                  _applyFilters();
                });
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check),
              label: const Text('적용'),
            ),
          ],
        );
      },
    );
  }

  // 🆕 컬럼의 고유 값들 가져오기 (텍스트 컬럼용)
  List<String> _getUniqueColumnValues(String columnKey) {
    final values = _summaryData
        .map((item) => item[columnKey]?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    
    values.sort((a, b) {
      // 숫자로 변환 가능하면 숫자 정렬, 아니면 문자열 정렬
      final aNum = double.tryParse(a);
      final bNum = double.tryParse(b);
      if (aNum != null && bNum != null) {
        return bNum.compareTo(aNum); // 큰 값부터
      }
      return a.compareTo(b);
    });
    
    return values;
  }
  int _maxCachedItems = 1000;
  final Map<String, dynamic> _dataCache = {};
  
  // 사용자 대시보드 설정
  final List<String> _dashboardLayout = ['summary', 'chart', 'data', 'analysis'];
  final Map<String, bool> _widgetVisibility = {
    'kpi_cards': true,
    'trend_chart': true,
    'top_customers': true,
    'country_stats': true,
  };
  
  // 고급 필터 (현실적인 기본값)
  final Map<String, dynamic> _advancedFilters = {
    'salesRange': {'min': 0.0, 'max': 100000000.0}, // 1억원
    'quantityRange': {'min': 0, 'max': 100000}, // 10만개
    'dateCustomRange': null,
    'excludeZeroSales': false,
    'topNCustomers': 0, // 0 = all
  };

  // 🆕 수치 조건 검색 (슬라이더 + 범위)
  RangeValues _salesAmountRange = const RangeValues(0, 100000000);
  RangeValues _quantityRange = const RangeValues(0, 10000);
  RangeValues _unitPriceRange = const RangeValues(0, 1000000);
  double _maxSalesAmount = 100000000;
  double _maxQuantity = 10000;
  double _maxUnitPrice = 1000000;
  bool _useNumericFilters = false;
  
  // 즐겨찾기 & 북마크
  final Set<String> _bookmarkedCustomers = {};
  final List<Map<String, dynamic>> _savedSearches = [];
  bool _showBookmarkedOnly = false;
  
  // 🆕 행 선택 및 다중 선택 기능
  Set<int> _selectedRows = {};
  bool _selectAll = false;
  
  // 🆕 Expansion 상태 관리
  bool _isPeriodSelectorExpanded = false; // 🔄 초기에는 접힌 상태
  bool _isQuickFiltersExpanded = false;
  bool _isAdvancedFiltersExpanded = false;
  bool _isColumnSelectorExpanded = false;
  final bool _isSummaryStatsExpanded = true;
  final bool _isChartSectionExpanded = true;
  
  // 🆕 전체 상단 영역 접기/펼치기 (모바일 최적화)
  bool _isHeaderCollapsed = false;
  
  // 🆕 고급 기간 설정 모드 (3가지 방식)
  String _periodSelectionMode = 'simple'; // 'simple', 'advanced', 'calendar'
  
  // 🆕 고급 기간 설정 옵션들
  final Map<String, bool> _periodSettings = {
    'autoApply': true,          // 기간 선택시 자동 적용
    'showWeekNumbers': false,   // 주차 번호 표시
    'showQuarters': true,       // 분기 표시
    'enableCustomRange': true,  // 사용자 정의 범위
    'saveLastSelection': true,  // 마지막 선택 저장
  };
  
  // 🆕 저장된 기간 프리셋들
  final List<Map<String, dynamic>> _savedPeriodPresets = [
    {'name': '이번 분기', 'type': 'quarter', 'value': 'current'},
    {'name': '지난 분기', 'type': 'quarter', 'value': 'last'},
    {'name': '상반기', 'type': 'half', 'value': 'first'},
    {'name': '하반기', 'type': 'half', 'value': 'second'},
    {'name': '최근 3개월', 'type': 'months', 'value': 3},
    {'name': '최근 6개월', 'type': 'months', 'value': 6},
  ];
  
  // 그룹핑 기능
  String _groupByField = '';  // '', 'NATION_NAME', '거래처분류' 등
  bool _showSubtotals = true;
  bool _showGrandTotal = true;
  
  // 알림 & 임계값
  final Map<String, dynamic> _alertSettings = {
    'salesThreshold': 1000000.0,
    'enableAlerts': false,
    'emailAlerts': false,
  };

  // 🆕 기간 선택 편의성 & 금액 표시 단위
  String _amountDisplayUnit = '만원'; // '원', '만원', '100만원', '억원', '10억원'
  final Map<String, double> _amountDivisors = {
    '원': 1.0,
    '만원': 10000.0,
    '100만원': 1000000.0,
    '억원': 100000000.0,
    '10억원': 1000000000.0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _setupKeyboardShortcuts();
    _loadUserSettings();
    _loadSavedState();
    
    // 날짜를 당해년도 전체로 강제 설정 (어떤 프리셋도 덮어쓰지 못하게)
    _fromDate = DateTime(DateTime.now().year, 1, 1);
    _toDate = DateTime(DateTime.now().year, 12, 31);
    
    _loadSalesData();
    
    // 자동 갱신 설정
    if (_isAutoRefreshEnabled) {
      _startAutoRefresh();
    }
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scheduleCheckTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _saveUserSettings();
    super.dispose();
  }

  Future<void> _loadSalesData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final fromDateStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toDateStr = DateFormat('yyyy-MM-dd').format(_toDate);
      
      final response = await SalesService.getSalesSummary(
        fromDate: fromDateStr,
        toDate: toDateStr,
      );
      
      setState(() {
        final responseData = response['data'];
        if (responseData != null && responseData is List) {
          _summaryData = List<Map<String, dynamic>>.from(responseData);
        } else {
          _summaryData = [];
        }
        _applyFilters();
        _isLoading = false;
        // 🆕 최종 조회 시간 업데이트
        _lastRefreshTime = DateTime.now();
      });
      
      print('매출요약 데이터 로드 완료: ${_summaryData.length}건');
    } catch (e) {
      setState(() {
        _errorMessage = '데이터 로드 실패: $e';
        _isLoading = false;
      });
      print('Error loading sales data: $e');
    }
  }
  
  void _applyFilters() {
    _filteredData = _summaryData.where((item) {
      // 즐겨찾기 필터
      if (_showBookmarkedOnly) {
        final customName = item['CUSTOM_NAME']?.toString() ?? '';
        if (!_bookmarkedCustomers.contains(customName)) {
          return false;
        }
      }
      
      // 검색 필터
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final customName = (item['CUSTOM_NAME']?.toString() ?? '').toLowerCase();
        final nationName = (item['NATION_NAME']?.toString() ?? '').toLowerCase();
        final customCode = (item['CUSTOM_CODE']?.toString() ?? '').toLowerCase();
        
        if (!customName.contains(searchLower) && 
            !nationName.contains(searchLower) && 
            !customCode.contains(searchLower)) {
          return false;
        }
      }
      
      // 국가 필터
      if (_selectedCountries.isNotEmpty) {
        final nation = item['NATION_NAME']?.toString() ?? '';
        if (!_selectedCountries.contains(nation)) return false;
      }
      
      // 거래처분류 필터
      if (_selectedTypes.isNotEmpty) {
        final type = item['거래처분류']?.toString() ?? '';
        if (!_selectedTypes.contains(type)) return false;
      }
      
      return true;
    }).toList();
    
    // 정렬
    _filteredData.sort((a, b) {
      final aValue = a[_sortColumn];
      final bValue = b[_sortColumn];
      
      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return _sortAscending ? -1 : 1;
      if (bValue == null) return _sortAscending ? 1 : -1;
      
      int comparison;
      if (aValue is num && bValue is num) {
        comparison = aValue.compareTo(bValue);
      } else {
        comparison = aValue.toString().compareTo(bValue.toString());
      }
      
      return _sortAscending ? comparison : -comparison;
    });
  }

  // 🆕 기간 선택 콘텐츠 (템플릿용 - 3가지 방식 지원, overflow 방지)
  Widget _buildPeriodSelectorContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1200;
        final isTablet = constraints.maxWidth > 768 && constraints.maxWidth <= 1200;
        final isMobile = constraints.maxWidth <= 768;
        
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🆕 기간 선택 모드 전환 + 설정
              _buildPeriodModeSelector(isMobile),
              SizedBox(height: isMobile ? 8 : 12),
              
              // 🆕 금액 단위 + 기간 설정 행 (공간 절약)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildPeriodSettings(isMobile),
                  _buildAmountUnitSelector(isMobile),
                ],
              ),
              SizedBox(height: isMobile ? 8 : 12),
              
              // 🆕 선택된 모드에 따른 기간 선택 UI
              _buildPeriodSelectionUI(isDesktop, isTablet, isMobile),
              SizedBox(height: isMobile ? 8 : 12),
              
              // 🆕 저장된 프리셋 + 사용자 정의 범위
              _buildSavedPresets(isMobile),
              SizedBox(height: isMobile ? 8 : 12),
              
              // 🆕 반응형 상세 기간 선택 (모든 모드에서 사용)
              _buildResponsiveDateSelection(isDesktop, isTablet, isMobile),
              
              // 📏 하단 여백 (overflow 방지)
              SizedBox(height: isMobile ? 4 : 8),
            ],
          ),
        );
      },
    );
  }

    // 🆕 기간 선택 모드 전환기 (모바일 최적화)
  Widget _buildPeriodModeSelector(bool isMobile) {
    if (isMobile) {
      // 모바일에서는 더 컴팩트하게
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeButton('간단', 'simple', Icons.speed, isMobile),
                _buildModeButton('고급', 'advanced', Icons.tune, isMobile),
                _buildModeButton('달력', 'calendar', Icons.calendar_view_month, isMobile),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _showPeriodSettingsDialog,
            icon: Icon(Icons.settings, size: 14, color: Colors.grey[600]),
            label: Text(
              '설정',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: const Size(0, 24),
            ),
          ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeButton('간단', 'simple', Icons.speed, isMobile),
            _buildModeButton('고급', 'advanced', Icons.tune, isMobile),
            _buildModeButton('달력', 'calendar', Icons.calendar_view_month, isMobile),
            const VerticalDivider(),
            IconButton(
              onPressed: _showPeriodSettingsDialog,
              icon: Icon(Icons.settings, size: 20),
              tooltip: '기간 설정',
            ),
          ],
        ),
      );
    }
  }

  // 🆕 모드 버튼 (모바일 최적화)
  Widget _buildModeButton(String label, String mode, IconData icon, bool isMobile) {
    final isSelected = _periodSelectionMode == mode;
    
    if (isMobile) {
      // 모바일에서는 아이콘만 표시하고 더 작게
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _periodSelectionMode = mode;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.white,
            foregroundColor: isSelected ? Colors.white : Colors.grey[700],
            elevation: isSelected ? 2 : 1,
            padding: const EdgeInsets.all(6),
            minimumSize: const Size(32, 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Icon(icon, size: 12),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _periodSelectionMode = mode;
            });
          },
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.white,
            foregroundColor: isSelected ? Colors.white : Colors.grey[700],
            elevation: isSelected ? 3 : 1,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
      );
    }
  }

  // 🆕 기간 설정 위젯 (모바일 최적화)
  Widget _buildPeriodSettings(bool isMobile) {
    if (isMobile) {
      // 모바일에서는 간소화
      final activeSettings = <String>[];
      if (_periodSettings['autoApply']!) activeSettings.add('자동');
      if (_periodSettings['showQuarters']!) activeSettings.add('분기');
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              activeSettings.isEmpty ? '기본' : activeSettings.join('•'),
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.settings, size: 16, color: Colors.grey),
          Text(
            '설정:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_periodSettings['autoApply']!)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '자동적용',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_periodSettings['showQuarters']!)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '분기표시',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      );
    }
  }

  // 🆕 선택된 모드에 따른 기간 선택 UI
  Widget _buildPeriodSelectionUI(bool isDesktop, bool isTablet, bool isMobile) {
    switch (_periodSelectionMode) {
      case 'simple':
        return _buildSimplePeriodSelection(isDesktop, isTablet, isMobile);
      case 'advanced':
        return _buildAdvancedPeriodSelection(isDesktop, isTablet, isMobile);
      case 'calendar':
        return _buildCalendarPeriodSelection(isDesktop, isTablet, isMobile);
      default:
        return _buildSimplePeriodSelection(isDesktop, isTablet, isMobile);
    }
  }

  // 🆕 간단한 기간 선택 (기존 버튼 방식)
  Widget _buildSimplePeriodSelection(bool isDesktop, bool isTablet, bool isMobile) {
    return _buildResponsiveQuickPeriodButtons(isDesktop, isTablet, isMobile);
  }

  // 🆕 고급 기간 선택
  Widget _buildAdvancedPeriodSelection(bool isDesktop, bool isTablet, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 연도 선택
        Row(
          children: [
            Text(
              '연도:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                children: List.generate(5, (index) {
                  final year = DateTime.now().year - 2 + index;
                  return _buildYearButton(year, isMobile);
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 분기 선택
        if (_periodSettings['showQuarters']!) ...[
          Row(
            children: [
              Text(
                '분기:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: [
                    _buildQuarterButton('1분기', 'Q1', isMobile),
                    _buildQuarterButton('2분기', 'Q2', isMobile),
                    _buildQuarterButton('3분기', 'Q3', isMobile),
                    _buildQuarterButton('4분기', 'Q4', isMobile),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // 월 선택
        Row(
          children: [
            Text(
              '월:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: List.generate(12, (index) {
                  final month = index + 1;
                  return _buildMonthButton(month, isMobile);
                }),
              ),
            ),
          ],
        ),
        
        // 주차 선택 (옵션)
        if (_periodSettings['showWeekNumbers']!) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '주차:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '현재 주차: ${_getCurrentWeekNumber()}주차',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 🆕 달력 기간 선택
  Widget _buildCalendarPeriodSelection(bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '달력에서 기간을 선택하세요',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
          const SizedBox(height: 12),
          
          // 🚧 미니 달력 (실제로는 CalendarDatePicker 또는 커스텀 달력 위젯 사용)
          Container(
            height: isMobile ? 200 : 250,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.construction, size: 32, color: Colors.orange),
                  const SizedBox(height: 8),
                  const Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  const Text(
                    '🚧 달력 위젯',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '(미구현 - 향후 추가 예정)',
                    style: TextStyle(fontSize: 12, color: Colors.orange[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 저장된 프리셋
  Widget _buildSavedPresets(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '저장된 프리셋',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showSavePresetDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('새 프리셋', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
                     children: _savedPeriodPresets.map((preset) {
             return InputChip(
               label: Text(
                 preset['name'],
                 style: TextStyle(fontSize: isMobile ? 10 : 11),
               ),
               onPressed: () => _applyPeriodPreset(preset),
               deleteIcon: const Icon(Icons.close, size: 14),
               onDeleted: () => _deletePeriodPreset(preset),
             );
           }).toList(),
        ),
      ],
    );
  }

  // 🆕 반응형 헤더
  Widget _buildResponsiveHeader(bool isDesktop, bool isTablet, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Theme.of(context).primaryColor, size: isMobile ? 20 : 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '검색조건 설정',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAmountUnitSelector(isMobile),
        ],
      );
    } else {
      return Row(
        children: [
          Icon(Icons.tune, color: Theme.of(context).primaryColor, size: 24),
          const SizedBox(width: 12),
          Text(
            '검색조건 설정',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          _buildAmountUnitSelector(isMobile),
        ],
      );
    }
  }

  // 🆕 금액 단위 선택기 (개선된 UI)
  Widget _buildAmountUnitSelector(bool isMobile) {
    if (isMobile) {
      // 모바일에서는 아주 작게
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: DropdownButton<String>(
          value: _amountDisplayUnit,
          underline: const SizedBox.shrink(),
          isDense: true,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          items: _amountDivisors.keys.map((unit) {
            return DropdownMenuItem(
              value: unit,
              child: Text(unit),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _amountDisplayUnit = value;
              });
            }
          },
        ),
      );
    } else {
      // 데스크톱에서는 간소한 텍스트 버튼 스타일
      return PopupMenuButton<String>(
        onSelected: (value) {
          setState(() {
            _amountDisplayUnit = value;
          });
        },
        itemBuilder: (context) => _amountDivisors.keys.map((unit) {
          return PopupMenuItem<String>(
            value: unit,
            child: Row(
              children: [
                if (unit == _amountDisplayUnit)
                  Icon(Icons.check, size: 16, color: Colors.blue[700])
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(unit),
              ],
            ),
          );
        }).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '단위: $_amountDisplayUnit',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[600]),
            ],
          ),
        ),
      );
    }
  }

  // 🆕 반응형 빠른 기간 선택 버튼들
  Widget _buildResponsiveQuickPeriodButtons(bool isDesktop, bool isTablet, bool isMobile) {
    final buttons = [
      _buildQuickPeriodButton('오늘', () => _setQuickPeriod('today'), isMobile),
      _buildQuickPeriodButton('어제', () => _setQuickPeriod('yesterday'), isMobile),
      _buildQuickPeriodButton('이번주', () => _setQuickPeriod('thisWeek'), isMobile),
      _buildQuickPeriodButton('지난주', () => _setQuickPeriod('lastWeek'), isMobile),
      _buildQuickPeriodButton('이번달', () => _setQuickPeriod('thisMonth'), isMobile),
      _buildQuickPeriodButton('지난달', () => _setQuickPeriod('lastMonth'), isMobile),
      _buildQuickPeriodButton('최근 7일', () => _setQuickPeriod('last7days'), isMobile),
      _buildQuickPeriodButton('최근 30일', () => _setQuickPeriod('last30days'), isMobile),
      _buildQuickPeriodButton('1분기', () => _setQuickPeriod('q1'), isMobile),
      _buildQuickPeriodButton('2분기', () => _setQuickPeriod('q2'), isMobile),
      _buildQuickPeriodButton('3분기', () => _setQuickPeriod('q3'), isMobile),
      _buildQuickPeriodButton('4분기', () => _setQuickPeriod('q4'), isMobile),
      _buildQuickPeriodButton('상반기', () => _setQuickPeriod('firstHalf'), isMobile),
      _buildQuickPeriodButton('하반기', () => _setQuickPeriod('secondHalf'), isMobile),
      _buildQuickPeriodButton('올해', () => _setQuickPeriod('thisYear'), isMobile),
      _buildQuickPeriodButton('작년', () => _setQuickPeriod('lastYear'), isMobile),
    ];

    if (isMobile) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: buttons,
      );
    } else if (isTablet) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: buttons,
      );
    } else {
      // Desktop: 그룹별로 구분된 레이아웃
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '일반 기간',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: buttons.sublist(0, 8),
          ),
          const SizedBox(height: 12),
          Text(
            '분기 & 연간',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: buttons.sublist(8),
          ),
        ],
      );
    }
  }

  // 🆕 한 줄 압축 날짜 선택 (공간 절약)
  Widget _buildResponsiveDateSelection(bool isDesktop, bool isTablet, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: _buildCompactDateField('시작일', _fromDate, (date) {
            setState(() => _fromDate = date);
            if (_periodSettings['autoApply']!) {
              _loadSalesData();
            }
          }, isMobile),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
          child: Icon(Icons.arrow_forward, color: Colors.grey, size: isMobile ? 12 : 16),
        ),
        Expanded(
          child: _buildCompactDateField('종료일', _toDate, (date) {
            setState(() => _toDate = date);
            if (_periodSettings['autoApply']!) {
              _loadSalesData();
            }
          }, isMobile),
        ),
      ],
    );
  }

  // 🆕 압축된 날짜 필드 (한 줄 최적화)
  Widget _buildCompactDateField(String label, DateTime date, Function(DateTime) onChanged, bool isMobile) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          locale: const Locale('ko', 'KR'),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 6 : 8, 
          horizontal: isMobile ? 8 : 12,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: isMobile ? 12 : 14, color: Colors.blue[600]),
            SizedBox(width: isMobile ? 4 : 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label, 
                    style: TextStyle(
                      fontSize: isMobile ? 8 : 9, 
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    DateFormat('MM/dd').format(date),
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  // 🆕 날짜 선택 필드
  Widget _buildDatePickerField(String label, DateTime date, Function(DateTime) onChanged, bool isMobile) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          locale: const Locale('ko', 'KR'),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 10 : 12, 
          horizontal: isMobile ? 12 : 16,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: isMobile ? 14 : 16),
            SizedBox(width: isMobile ? 6 : 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label, 
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10, 
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd').format(date),
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 반응형 기간 정보 표시
  Widget _buildResponsivePeriodInfo(bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '선택 기간: ${_getDateRangeInfo()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '금액단위: $_amountDisplayUnit',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '선택 기간: ${_getDateRangeInfo()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Text(
                  '금액단위: $_amountDisplayUnit',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _shortcuts,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              
              return Column(
                children: [
                  // 🆕 접기/펼치기 가능한 상단 영역
                  if (!_isHeaderCollapsed) ...[
                    // 🆕 2행 구조 헤더 (제목과 툴바 분리로 오버플로우 방지)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12.0 : 16.0,
                        vertical: isMobile ? 6.0 : 8.0,
                      ),
                      child: Column(
                        children: [
                          // 첫 번째 행: 제목과 상태 정보만
                          Row(
                            children: [
                              Text(
                                '통합매출분석',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 12 : 14,  // 메인메뉴보다 작게
                                ),
                              ),
                              // 🆕 자동 갱신 상태 표시 (개선된 버전)
                              if (_isAutoRefreshEnabled) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sync, size: 16, color: Colors.green[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        _refreshMode == 'interval' 
                                          ? '자동갱신 ${_formatRefreshInterval(_refreshIntervalSeconds)}'
                                          : '스케줄 ${_formatScheduleHours()}',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              // 🆕 최종 조회 시간 표시
                              if (_lastRefreshTime != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.update, size: 12, color: Colors.blue[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '최종: ${DateFormat('HH:mm:ss').format(_lastRefreshTime!)}',
                                        style: TextStyle(
                                          color: Colors.blue[600],
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
                              
                              // 🆕 Help 버튼 (최우선 위치)
                              IconButton(
                                onPressed: _showHelpDialog,
                                icon: const Icon(Icons.help_outline, color: Colors.blue),
                                tooltip: '사용법 도움말',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.blue.withOpacity(0.1),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ],
                          ),
                          
                          // 두 번째 행: 툴바 아이콘들 (오버플로우 방지)
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              final isMobile = screenWidth < 600;
                              final isTablet = screenWidth >= 600 && screenWidth < 1024;
                              
                              if (isMobile) {
                                // 📱 좁은 화면: 핵심 기능 + 전체 기능 메뉴
                                return Row(
                                  children: [
                                    _buildAutoRefreshToggleButton(),
                                    IconButton(
                                      onPressed: _refreshData,
                                      icon: const Icon(Icons.refresh),
                                      tooltip: '새로고침',
                                    ),
                                    // 🚀 AI 분석 버튼 추가
                                    IconButton(
                                      onPressed: _navigateToAiAnalysis,
                                      icon: const Icon(Icons.psychology, color: Colors.purple),
                                      tooltip: 'AI 분석',
                                    ),
                                    const Spacer(),
                                    // 📋 명확한 라벨 추가
                                    const Text('전체메뉴', style: TextStyle(fontSize: 10, color: Colors.blue)),
                                    const SizedBox(width: 4),
                                    _buildMobileMoreMenu(),
                                  ],
                                );
                              } else if (isTablet) {
                                // 태블릿: 핵심 기능만 + 스크롤 + 더보기 메뉴
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildAutoRefreshToggleButton(),
                                      _buildAutoRefreshSettingsMenu(),
                                      IconButton(
                                        onPressed: _refreshData,
                                        icon: const Icon(Icons.refresh),
                                        tooltip: '새로고침',
                                      ),
                                      // 🚀 AI 분석 버튼 추가 (태블릿)
                                      IconButton(
                                        onPressed: _navigateToAiAnalysis,
                                        icon: const Icon(Icons.psychology, color: Colors.purple),
                                        tooltip: 'AI 분석',
                                      ),
                                      IconButton(
                                        onPressed: _showAdvancedFilterDialog,
                                        icon: const Icon(Icons.tune),
                                        tooltip: '고급 필터',
                                      ),
                                      // 🆕 나머지는 태블릿 더보기 메뉴로 이동
                                      _buildTabletMoreMenu(),
                                    ],
                                  ),
                                );
                              } else {
                                // 데스크톱: 모든 버튼 + 스크롤 가능
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Wrap(
                                    spacing: 8,
                                    children: [
                                      _buildAutoRefreshToggleButton(),
                                      _buildAutoRefreshSettingsMenu(),
                                      IconButton(
                                        onPressed: _refreshData,
                                        icon: const Icon(Icons.refresh),
                                        tooltip: '수동 새로고침 (Ctrl+R)',
                                      ),
                                      IconButton(
                                        onPressed: _showAdvancedFilterDialog,
                                        icon: const Icon(Icons.tune),
                                        tooltip: '고급 필터',
                                      ),
                                      IconButton(
                                        onPressed: _saveCurrentSearch,
                                        icon: const Icon(Icons.bookmark_add),
                                        tooltip: '현재 검색 저장',
                                      ),
                                      _buildSavedSearchMenu(),
                                      IconButton(
                                        onPressed: _showDashboardSettings,
                                        icon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.construction, color: Colors.orange, size: 12),
                                            SizedBox(width: 2),
                                            Icon(Icons.settings),
                                          ],
                                        ),
                                        tooltip: '🚧 대시보드 설정 (부분 구현)',
                                      ),
                                      IconButton(
                                        onPressed: _showKeyboardShortcuts,
                                        icon: const Icon(Icons.keyboard),
                                        tooltip: '키보드 단축키',
                                      ),
                                      const VerticalDivider(),
                                      _buildExportButtons(),
                                      IconButton(
                                        onPressed: _toggleFullScreen,
                                        icon: const Icon(Icons.fullscreen),
                                        tooltip: '전체화면 토글 (F11)',
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
              
              // 🆕 압축된 기간 선택 (여백 최소화)
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8.0 : 12.0,
                  vertical: isMobile ? 2.0 : 4.0,
                ),
                child: Card(
                  elevation: 1,
                  child: ExpansionTile(
                    initiallyExpanded: _isPeriodSelectorExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _isPeriodSelectorExpanded = expanded;
                      });
                    },
                    leading: Icon(
                      Icons.tune, 
                      color: Theme.of(context).primaryColor,
                    ),
                    title: Text(
                      '검색조건 설정',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${_getDateRangeInfo()} • $_amountDisplayUnit 단위',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 📊 데이터 건수 표시
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_filteredData.length}건',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // 🔍 조회 버튼 (헤더에 위치)
                        ElevatedButton.icon(
                          onPressed: _loadSalesData,
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text('조회', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 32),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        Icon(
                          _isPeriodSelectorExpanded 
                            ? Icons.expand_less 
                            : Icons.expand_more,
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isMobile ? 8 : 12, 
                          0, 
                          isMobile ? 8 : 12, 
                          isMobile ? 4 : 8
                        ),
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: isMobile ? 300 : 400, // 모바일에서 더 압축
                          ),
                          child: _buildPeriodSelectorContent(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 🆕 개선된 상태 표시 바
              if (_isLoading || _errorMessage.isNotEmpty || _filteredData.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: _errorMessage.isNotEmpty 
                      ? Colors.red.withOpacity(0.1)
                      : _isLoading 
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _errorMessage.isNotEmpty 
                        ? Colors.red.withOpacity(0.3)
                        : _isLoading 
                          ? Colors.orange.withOpacity(0.3)
                          : Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_errorMessage.isNotEmpty)
                        Icon(Icons.error_outline, size: 18, color: Colors.red[700])
                      else
                        Icon(Icons.check_circle_outline, size: 18, color: Colors.green[700]),
                      
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isLoading 
                                ? '데이터 로딩 중...'
                                : _errorMessage.isNotEmpty 
                                  ? _errorMessage
                                  : '${_filteredData.length}건의 데이터가 로드되었습니다.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _errorMessage.isNotEmpty 
                                  ? Colors.red[700]
                                  : _isLoading 
                                    ? Colors.orange[700]
                                    : Colors.green[700],
                              ),
                            ),
                            // 🆕 최종 로드 시간 상세 표시
                            if (!_isLoading && _errorMessage.isEmpty && _lastRefreshTime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '최종 로드: ${DateFormat('yyyy.MM.dd a hh:mm:ss', 'ko').format(_lastRefreshTime!)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      if (_errorMessage.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _errorMessage = '';
                            });
                            _refreshData();
                          },
                          icon: const Icon(Icons.refresh, size: 14),
                          label: const Text('재시도'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 28),
                          ),
                        )
                      else if (!_isLoading && _lastRefreshTime != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 12, color: Colors.blue[700]),
                              const SizedBox(width: 4),
                              Text(
                                _getTimeSinceLastRefresh(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              
              // 📱 초압축 탭바 (공간 최적화)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
                  
                  return Container(
                    margin: EdgeInsets.only(
                      left: isMobile ? 8.0 : 12.0,
                      right: isMobile ? 8.0 : 12.0,
                      top: isMobile ? 2.0 : 4.0,
                      bottom: isMobile ? 4.0 : 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[600],
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).primaryColor,
                      ),
                      isScrollable: isMobile, // 📱 모바일에서 스크롤 가능
                      labelStyle: TextStyle(
                        fontSize: isMobile ? 11 : (isTablet ? 12 : 14),
                        fontWeight: FontWeight.w500,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: isMobile ? 11 : (isTablet ? 12 : 14),
                      ),
                      tabs: [
                        Tab(
                          text: isMobile ? '요약' : '요약', 
                          icon: Icon(Icons.dashboard, size: isMobile ? 14 : 18),
                        ),
                        Tab(
                          text: isMobile ? '데이터' : '데이터', 
                          icon: Icon(Icons.table_chart, size: isMobile ? 14 : 18),
                        ),
                        Tab(
                          text: isMobile ? '상세' : '데이터(상세)', 
                          icon: Icon(Icons.dataset, size: isMobile ? 14 : 18),
                        ),
                        Tab(
                          text: isMobile ? '차트' : '차트', 
                          icon: Icon(Icons.analytics, size: isMobile ? 14 : 18),
                        ),
                        Tab(
                          text: isMobile ? '분석' : '분석', 
                          icon: Icon(Icons.insights, size: isMobile ? 14 : 18),
                        ),
                      ],
                    ),
                  );
                },
              ),
                  ], // 🆕 상단 접기 영역 끝
                  
                  // 🆕 초압축 토글 버튼 (모바일 전용)
                  if (isMobile)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isHeaderCollapsed = !_isHeaderCollapsed;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        color: Colors.grey[100],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isHeaderCollapsed ? Icons.expand_more : Icons.expand_less,
                              color: Colors.blue[600],
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isHeaderCollapsed ? '검색조건 표시' : '검색조건 숨기기',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              
              // 탭 콘텐츠
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                                const SizedBox(height: 16),
                                Text(
                                  '데이터를 불러오는 중 오류가 발생했습니다',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage,
                                  style: TextStyle(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _refreshData,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('다시 시도'),
                                ),
                              ],
                            ),
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildSummaryTab(),
                              _buildDataTab(),
                              _buildRawDataTab(),
                              _buildChartTab(),
                              _buildAnalysisTab(),
                            ],
                          ),
              ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  // 계속해서 각 탭들을 구현하겠습니다...
  
  Widget _buildSummaryTab() {
    if (_summaryData.isEmpty) {
      return const Center(child: Text('조회된 데이터가 없습니다.'));
    }

    // 실제 API 데이터 구조에 맞게 집계
    final totalSales = _summaryData.fold<double>(
      0.0, (sum, item) {
        final salesAmount = item['SUM_SALE_AMT_WON'];
        if (salesAmount == null) return sum;
        return sum + (salesAmount is num ? salesAmount.toDouble() : 0.0);
      }
    );
    
    final totalQuantity = _summaryData.fold<int>(
      0, (sum, item) {
        final quantity = item['SALE_Q'];
        if (quantity == null) return sum;
        return sum + (quantity is num ? quantity.toInt() : 0);
      }
    );
    
    final avgOrderValue = totalQuantity > 0 ? totalSales / totalQuantity : 0.0;
    final totalCustomers = _summaryData.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 🔧 요약 카드들 (반응형 레이아웃으로 오버플로우 방지)
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
              
              if (isMobile) {
                // 모바일: 2x2 그리드
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            '총 매출액',
                            '${_formatAmountWithUnit(totalSales)} $_amountDisplayUnit',
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            '총 수량',
                            _formatNumber(totalQuantity),
                            Icons.inventory,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            '거래처 수',
                            '${_formatNumber(totalCustomers)}개',
                            Icons.business,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            '평균 거래액',
                            '${_formatAmountWithUnit(avgOrderValue)} $_amountDisplayUnit',
                            Icons.analytics,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // 태블릿/데스크톱: 1줄 배치
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: _buildSummaryCard(
                          '총 매출액',
                          '${_formatAmountWithUnit(totalSales)} $_amountDisplayUnit',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 200,
                        child: _buildSummaryCard(
                          '총 수량',
                          _formatNumber(totalQuantity),
                          Icons.inventory,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 200,
                        child: _buildSummaryCard(
                          '거래처 수',
                          '${_formatNumber(totalCustomers)}개',
                          Icons.business,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 200,
                        child: _buildSummaryCard(
                          '평균 거래액',
                          '${_formatAmountWithUnit(avgOrderValue)} $_amountDisplayUnit',
                          Icons.analytics,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 20),
          // 요약 통계
          _buildSummaryStatistics(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        
        return Card(
          elevation: 4,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),  // 카드 크기 축소
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: isMobile ? 18 : 24),
                    SizedBox(width: isMobile ? 6 : 8),
                    Expanded( // 🔧 오버플로우 방지
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 14,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis, // 🔧 텍스트 오버플로우 방지
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 6 : 8),
                FittedBox( // 🔧 값이 너무 길 경우 자동 크기 조절
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child:                   Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 13,  // 메인메뉴보다 작게
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryStatistics() {
    // 국가별 집계
    final countryStats = <String, Map<String, dynamic>>{};
    for (var item in _summaryData) {
      final country = item['NATION_NAME']?.toString() ?? '기타';
      if (!countryStats.containsKey(country)) {
        countryStats[country] = {'sales': 0.0, 'quantity': 0, 'count': 0};
      }
      countryStats[country]!['sales'] += (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
      countryStats[country]!['quantity'] += (item['SALE_Q']?.toInt() ?? 0);
      countryStats[country]!['count'] += 1;
    }

    final topCountries = countryStats.entries.toList()
      ..sort((a, b) => b.value['sales'].compareTo(a.value['sales']))
      ..take(5);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '매출 상위 국가',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...topCountries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key),
                                  Text(
                  '${_formatAmountWithUnit(entry.value['sales'])} $_amountDisplayUnit',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTab() {
    return Column(
      children: [
        // 🆕 간단한 사용 가이드 (혼란 방지)
        _buildSimpleUserGuide(),
        
        // 🆕 확장 가능한 검색 및 필터
        _buildExpandableSearchAndFilter(),
        
        // 🆕 확장 가능한 컬럼 선택
        _buildExpandableColumnSelector(),
        
        // 데이터 테이블
        Expanded(child: _buildDataTable()),
        
        // 페이지네이션
        _buildPagination(),
      ],
    );
  }

  // 🆕 간단한 사용 가이드 (복잡함 해소)
  Widget _buildSimpleUserGuide() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.green[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 데이터 보기 가이드',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• 🔍 검색: 거래처명으로 찾기 • 📋 컬럼: 보고싶은 항목만 선택 • 📄 페이지: 아래에서 이동',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 명확한 빈 데이터 메시지 (혼란 방지)
  Widget _buildEmptyDataMessage(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedCountries.clear();
                      _selectedTypes.clear();
                    });
                    _applyFilters();
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('필터 초기화'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadSalesData,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('다시 조회'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 데이터 탭 헤더 (기능 안내와 빠른 액세스)
  Widget _buildDataTabHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.table_view, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '데이터 관리 도구',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    Text(
                      '검색, 필터링, 정렬, 즐겨찾기 기능을 활용하세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 🆕 빠른 액세스 버튼들 (반응형 레이아웃)
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 즐겨찾기 필터 토글 (명확한 위치)
                      ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showBookmarkedOnly = !_showBookmarkedOnly;
                        _applyFilters();
                      });
                    },
                    icon: Icon(
                      _showBookmarkedOnly ? Icons.star : Icons.star_border,
                      size: 16,
                      color: _showBookmarkedOnly ? Colors.orange : null,
                    ),
                    label: Text(
                      _showBookmarkedOnly ? '즐겨찾기 ON' : '즐겨찾기 OFF',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showBookmarkedOnly ? Colors.orange[100] : Colors.white,
                      foregroundColor: _showBookmarkedOnly ? Colors.orange[800] : Colors.grey[700],
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                                        ),
                      
                      const SizedBox(width: 8),
                      
                      // 검색 패널 토글
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isQuickFiltersExpanded = !_isQuickFiltersExpanded;
                          });
                        },
                        icon: const Icon(Icons.search, size: 16),
                        label: Text(
                          _isQuickFiltersExpanded ? '검색 닫기' : '검색 열기',
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isQuickFiltersExpanded ? Colors.green[100] : Colors.white,
                          foregroundColor: _isQuickFiltersExpanded ? Colors.green[800] : Colors.grey[700],
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // 컬럼 선택 토글
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isColumnSelectorExpanded = !_isColumnSelectorExpanded;
                          });
                        },
                        icon: const Icon(Icons.view_column, size: 16),
                        label: Text(
                          _isColumnSelectorExpanded ? '컬럼 닫기' : '컬럼 설정',
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isColumnSelectorExpanded ? Colors.purple[100] : Colors.white,
                          foregroundColor: _isColumnSelectorExpanded ? Colors.purple[800] : Colors.grey[700],
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 🆕 상태 정보 바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.blue[600]),
                const SizedBox(width: 6),
                Text(
                  '💡 TIP: 컬럼 헤더 클릭으로 정렬, ⭐ 클릭으로 즐겨찾기 추가',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 확장 가능한 검색 및 필터
  Widget _buildExpandableSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ExpansionTile(
        initiallyExpanded: _isQuickFiltersExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isQuickFiltersExpanded = expanded;
          });
        },
        leading: Icon(
          Icons.search,
          color: Theme.of(context).primaryColor,
        ),
        title: const Text(
          '검색 및 필터',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _getFilterSummary(),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchQuery.isNotEmpty || _selectedCountries.isNotEmpty || _selectedTypes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '필터 적용됨',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              _isQuickFiltersExpanded 
                ? Icons.expand_less 
                : Icons.expand_more,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildSearchAndFilterContent(),
          ),
        ],
      ),
    );
  }

  // 🆕 확장 가능한 컬럼 선택
  Widget _buildExpandableColumnSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ExpansionTile(
        initiallyExpanded: _isColumnSelectorExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isColumnSelectorExpanded = expanded;
          });
        },
        leading: Icon(
          Icons.view_column,
          color: Theme.of(context).primaryColor,
        ),
        title: const Text(
          '표시 컬럼 설정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_visibleColumns.values.where((v) => v).length}개 컬럼 표시 중',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _visibleColumns.updateAll((key, value) => true);
                });
              },
              child: const Text('모두 선택', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  // 기본 컬럼들만 선택
                  _visibleColumns.updateAll((key, value) => 
                    ['CUSTOM_NAME', 'NATION_NAME', 'SALE_Q', 'SUM_SALE_AMT_WON'].contains(key)
                  );
                });
              },
              child: const Text('기본만', style: TextStyle(fontSize: 11)),
            ),
            Icon(
              _isColumnSelectorExpanded 
                ? Icons.expand_less 
                : Icons.expand_more,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildColumnSelectorContent(),
          ),
        ],
      ),
    );
  }

  // 🆕 필터 요약 정보
  String _getFilterSummary() {
    final filters = <String>[];
    
    if (_searchQuery.isNotEmpty) {
      filters.add('검색: $_searchQuery');
    }
    if (_selectedCountries.isNotEmpty) {
      filters.add('국가: ${_selectedCountries.length}개');
    }
    if (_selectedTypes.isNotEmpty) {
      filters.add('분류: ${_selectedTypes.length}개');
    }
    if (_showBookmarkedOnly) {
      filters.add('즐겨찾기만');
    }
    
    if (filters.isEmpty) {
      return '전체 ${_summaryData.length}건 표시';
         } else {
       return filters.join(' • ');
     }
   }

  // 🆕 검색 및 필터 콘텐츠
  Widget _buildSearchAndFilterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 검색바
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '거래처명, 국가명, 거래처코드로 검색...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _applyFilters();
                    });
                  },
                )
              : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _applyFilters();
            });
          },
        ),
        const SizedBox(height: 16),
        
        // 필터 행
        Row(
          children: [
            // 국가 필터
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '국가 필터',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                initialValue: null,
                items: _getUniqueCountries().map((country) => 
                  DropdownMenuItem(value: country, child: Text(country))
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    if (value != null) {
                      if (_selectedCountries.contains(value)) {
                        _selectedCountries.remove(value);
                      } else {
                        _selectedCountries.add(value);
                      }
                      _applyFilters();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            
            // 거래처분류 필터
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '거래처분류 필터',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                initialValue: null,
                items: _getUniqueTypes().map((type) => 
                  DropdownMenuItem(value: type, child: Text(type))
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    if (value != null) {
                      if (_selectedTypes.contains(value)) {
                        _selectedTypes.remove(value);
                      } else {
                        _selectedTypes.add(value);
                      }
                      _applyFilters();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            
            // 액션 버튼들
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _selectedCountries.clear();
                      _selectedTypes.clear();
                      _showBookmarkedOnly = false;
                      _applyFilters();
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('초기화'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _toggleBookmarkedOnlyView,
                      icon: Icon(
                        _showBookmarkedOnly ? Icons.star : Icons.star_border,
                        color: _showBookmarkedOnly ? Colors.orange : null,
                      ),
                      tooltip: _showBookmarkedOnly ? '모든 거래처 보기' : '즐겨찾기만 보기',
                    ),
                    IconButton(
                      onPressed: _showGroupingOptions,
                      icon: const Icon(Icons.group_work),
                      tooltip: '그룹핑 설정',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        
        // 선택된 필터 태그들
        if (_selectedCountries.isNotEmpty || _selectedTypes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ..._selectedCountries.map((country) => Chip(
                label: Text('국가: $country', style: const TextStyle(fontSize: 12)),
                onDeleted: () {
                  setState(() {
                    _selectedCountries.remove(country);
                    _applyFilters();
                  });
                },
                deleteIcon: const Icon(Icons.close, size: 16),
              )),
              ..._selectedTypes.map((type) => Chip(
                label: Text('분류: $type', style: const TextStyle(fontSize: 12)),
                onDeleted: () {
                  setState(() {
                    _selectedTypes.remove(type);
                    _applyFilters();
                  });
                },
                deleteIcon: const Icon(Icons.close, size: 16),
              )),
            ],
          ),
        ],
      ],
    );
  }

  // 🆕 컬럼 선택 콘텐츠
  Widget _buildColumnSelectorContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '표시할 컬럼을 선택하세요',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        // 컬럼 그룹별 정리
        ExpansionTile(
          title: const Text('기본 정보', style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          children: [
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                'CUSTOM_NAME', 'CUSTOM_CODE', 'NATION_NAME', 'CONTINENT', 'MANAGE_CUSTOM_NM', '거래처분류', 'AGENT_TYPE'
              ].map((column) => FilterChip(
                label: Text(_getColumnDisplayName(column)),
                selected: _visibleColumns[column]!,
                onSelected: (selected) {
                  setState(() {
                    _visibleColumns[column] = selected;
                  });
                },
              )).toList(),
            ),
          ],
        ),
        
        ExpansionTile(
          title: const Text('매출 정보', style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: true,
          children: [
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                'SALE_Q', 'SUM_SALE_AMT_WON', 'SALE_P', 'EXCHG_RATE_O', 'SALE_LOC_AMT_F', 'SALE_COST_AMT'
              ].map((column) => FilterChip(
                label: Text(_getColumnDisplayName(column)),
                selected: _visibleColumns[column]!,
                onSelected: (selected) {
                  setState(() {
                    _visibleColumns[column] = selected;
                  });
                },
              )).toList(),
            ),
          ],
        ),
        
        ExpansionTile(
          title: const Text('기타', style: TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: false,
          children: [
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                'UPDATE_DTM'
              ].map((column) => FilterChip(
                label: Text(_getColumnDisplayName(column)),
                selected: _visibleColumns[column]!,
                onSelected: (selected) {
                  setState(() {
                    _visibleColumns[column] = selected;
                  });
                },
              )).toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // 검색
            Expanded(
              flex: 2,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: '거래처명, 국가명, 거래처코드로 검색...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilters();
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            // 국가 필터
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '국가 필터',
                  border: OutlineInputBorder(),
                ),
                initialValue: null,
                items: _getUniqueCountries().map((country) => 
                  DropdownMenuItem(value: country, child: Text(country))
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    if (value != null) {
                      if (_selectedCountries.contains(value)) {
                        _selectedCountries.remove(value);
                      } else {
                        _selectedCountries.add(value);
                      }
                      _applyFilters();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            // 거래처분류 필터
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '거래처분류 필터',
                  border: OutlineInputBorder(),
                ),
                initialValue: null,
                items: _getUniqueTypes().map((type) => 
                  DropdownMenuItem(value: type, child: Text(type))
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    if (value != null) {
                      if (_selectedTypes.contains(value)) {
                        _selectedTypes.remove(value);
                      } else {
                        _selectedTypes.add(value);
                      }
                      _applyFilters();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            // 필터 초기화
            IconButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedCountries.clear();
                  _selectedTypes.clear();
                  _applyFilters();
                });
              },
              icon: const Icon(Icons.clear),
              tooltip: '필터 초기화',
            ),
            const SizedBox(width: 8),
            // 즐겨찾기 토글
            IconButton(
              onPressed: _toggleBookmarkedOnlyView,
              icon: Icon(
                _showBookmarkedOnly ? Icons.star : Icons.star_border,
                color: _showBookmarkedOnly ? Colors.orange : null,
              ),
              tooltip: _showBookmarkedOnly ? '모든 거래처 보기' : '즐겨찾기만 보기',
            ),
            const SizedBox(width: 8),
            // 그룹핑 설정
            IconButton(
              onPressed: _showGroupingOptions,
              icon: const Icon(Icons.group_work),
              tooltip: '그룹핑 설정',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '표시할 컬럼 선택',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _visibleColumns.keys.map((column) {
                return FilterChip(
                  label: Text(_getColumnDisplayName(column)),
                  selected: _visibleColumns[column]!,
                  onSelected: (selected) {
                    setState(() {
                      _visibleColumns[column] = selected;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    // 🆕 명확한 데이터 상태 확인
    if (_summaryData.isEmpty) {
      return _buildEmptyDataMessage('조회할 데이터가 없습니다.\n위의 기간을 설정하고 조회해주세요.');
    }

    final groupedData = _getGroupedData();
    if (groupedData.isEmpty) {
      return _buildEmptyDataMessage('검색 조건에 맞는 데이터가 없습니다.\n검색어나 필터를 확인해주세요.');
    }

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, groupedData.length);
    final pageData = groupedData.sublist(startIndex, endIndex);

    // 표시할 컬럼들 (체크박스 + 즐겨찾기 컬럼 추가)
    final visibleColumnKeys = _visibleColumns.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    return Column(
      children: [
        // 🆕 선택된 행이 있을 때 일괄 작업 바
        if (_selectedRows.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.checklist, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  '${_selectedRows.length}개 행 선택됨',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _showBulkActionDialog,
                  icon: const Icon(Icons.more_horiz, size: 16),
                  label: const Text('일괄 작업'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedRows.clear();
                      _selectAll = false;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  tooltip: '선택 해제',
                ),
              ],
            ),
          ),
        
        // 🆕 개선된 DataTable (오버플로우 방지)
        Flexible(
          child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              sortColumnIndex: visibleColumnKeys.contains(_sortColumn) ? visibleColumnKeys.indexOf(_sortColumn) + 1 : null,
              sortAscending: _sortAscending,
              showCheckboxColumn: false, // 🔧 중복 체크박스 제거
              columns: [
                // 🆕 통합 선택/즐겨찾기 컬럼
                DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _selectAll,
                        onChanged: _toggleSelectAll,
                        tristate: true,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 16, color: Colors.orange),
                    ],
                  ),
                ),
                // 🆕 필터링 가능한 컬럼들
                ...visibleColumnKeys.map((columnKey) => DataColumn(
                  label: InkWell(
                    onTap: () => _showColumnFilterDialog(columnKey),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _getColumnDisplayName(columnKey),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // 🔽 필터 아이콘 (필터가 적용된 경우 색상 변경)
                              Icon(
                                Icons.filter_list,
                                size: 16,
                                color: _columnFilters.containsKey(columnKey) && _columnFilters[columnKey]!.isNotEmpty
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                            ],
                          ),
                          // 🔽 정렬 인디케이터
                          if (_sortColumn == columnKey)
                            Icon(
                              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 12,
                              color: Colors.blue,
                            ),
                        ],
                      ),
                    ),
                  ),
                  onSort: (columnIndex, ascending) {
                    setState(() {
                      _sortColumn = columnKey;
                      _sortAscending = ascending;
                      _applyFilters();
                    });
                  },
                )),
              ],
                            rows: pageData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                
                // 그룹 헤더 행
                if (data['isGroupHeader'] == true) {
                  return DataRow(
                    color: WidgetStateProperty.all(Colors.blue[50]),
                    cells: [
                      const DataCell(SizedBox.shrink()), // 체크박스 컬럼 (비어있음)
                      const DataCell(Icon(Icons.folder, color: Colors.blue)),
                      DataCell(
                        Text(
                          '📁 ${data['groupName']} (${data['groupCount']}건)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      ...List.generate(math.max(0, visibleColumnKeys.length - 1), (cellIndex) {
                        final salesIndex = visibleColumnKeys.indexOf('SUM_SALE_AMT_WON');
                        final quantityIndex = visibleColumnKeys.indexOf('SALE_Q');
                        
                        if (salesIndex >= 0 && cellIndex == salesIndex - 1) {
                          return DataCell(
                            Text(
                              '₩${_formatNumber((data['groupSales'] ?? 0.0).toInt())}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        } else if (quantityIndex >= 0 && cellIndex == quantityIndex - 1) {
                          return DataCell(
                            Text(
                              _formatNumber(data['groupQuantity'] ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const DataCell(Text(''));
                      }),
                    ],
                  );
                }
                
                // 일반 데이터 행 (체크박스 포함)
                final customName = data['CUSTOM_NAME']?.toString() ?? '';
                final isBookmarked = _isBookmarked(customName);
                final globalIndex = startIndex + index;
                final isSelected = _selectedRows.contains(globalIndex);
                
                return DataRow(
                  selected: isSelected,
                  cells: [
                    // 🆕 통합 선택/즐겨찾기 셀
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (selected) => _toggleRowSelection(globalIndex),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(
                              isBookmarked ? Icons.star : Icons.star_border,
                              color: isBookmarked ? Colors.orange : Colors.grey,
                              size: 18,
                            ),
                            onPressed: () => _toggleBookmark(customName),
                            tooltip: isBookmarked ? '즐겨찾기 해제' : '즐겨찾기 추가',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: const EdgeInsets.all(4),
                          ),
                        ],
                      ),
                    ),
                    // 데이터 셀들
                    ...visibleColumnKeys.map((columnKey) => DataCell(
                      Text(_formatCellValue(data[columnKey], columnKey)),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        ), // 🔧 Flexible 닫는 괄호 추가
      ],
    );
  }

  Widget _buildPagination() {
    final groupedData = _getGroupedData();
    final totalPages = (groupedData.length / _rowsPerPage).ceil();
    
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '총 ${groupedData.length}건 중 ${_currentPage * _rowsPerPage + 1}-${((_currentPage + 1) * _rowsPerPage).clamp(0, groupedData.length)}건',
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _currentPage > 0 ? () {
                    setState(() {
                      _currentPage--;
                    });
                  } : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_currentPage + 1} / $totalPages'),
                IconButton(
                  onPressed: _currentPage < totalPages - 1 ? () {
                    setState(() {
                      _currentPage++;
                    });
                  } : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTab() {
    return Column(
      children: [
        // 🆕 차트 제어 패널
        _buildChartControlPanel(),
        
        // 🆕 고급 차트 영역
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 차트 선택 탭 (확장된 버전)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: DefaultTabController(
                    length: 10, // 🆕 10개로 확장
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          labelColor: Theme.of(context).primaryColor,
                          unselectedLabelColor: Colors.grey,
                          tabs: const [
                            Tab(text: '📊 매출 분석', icon: Icon(Icons.bar_chart, size: 16)),
                            Tab(text: '📈 트렌드 분석', icon: Icon(Icons.trending_up, size: 16)),
                            Tab(text: '🌍 지역 분석', icon: Icon(Icons.public, size: 16)),
                            Tab(text: '🏢 거래처 분석', icon: Icon(Icons.business, size: 16)),
                            Tab(text: '📦 품목 분석', icon: Icon(Icons.inventory, size: 16)),
                            Tab(text: '💰 수익성 분석', icon: Icon(Icons.monetization_on, size: 16)),
                            Tab(text: '⚖️ 비교 분석', icon: Icon(Icons.compare_arrows, size: 16)),
                            Tab(text: '📏 분포 분석', icon: Icon(Icons.scatter_plot, size: 16)),
                            Tab(text: '🎯 성과 분석', icon: Icon(Icons.track_changes, size: 16)),
                            Tab(text: '🔮 예측 분석', icon: Icon(Icons.analytics, size: 16)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 600, // 높이 증가
                          child: TabBarView(
                            children: [
                              _buildAdvancedSalesCharts(),      // 매출 분석
                              _buildAdvancedTrendCharts(),      // 트렌드 분석  
                              _buildAdvancedRegionCharts(),     // 지역 분석
                              _buildAdvancedCustomerCharts(),   // 거래처 분석
                              _buildProductAnalysisCharts(),    // 🆕 품목 분석
                              _buildProfitabilityCharts(),      // 🆕 수익성 분석
                              _buildAdvancedComparisonCharts(), // 비교 분석
                              _buildAdvancedDistributionCharts(), // 분포 분석
                              _buildPerformanceCharts(),        // 🆕 성과 분석
                              _buildPredictiveCharts(),         // 🆕 예측 분석
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 🆕 통합 대시보드 섹션
                _buildIntegratedDashboard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesAnalysisCharts() {
    return Column(
      children: [
        Expanded(child: _buildSalesChart()),
        const SizedBox(height: 20),
        Expanded(child: _buildCountryChart()),
      ],
    );
  }

  Widget _buildSalesChart() {
    // 매출 상위 10개 거래처
    final topCustomers = _summaryData
      .map((item) => {
        'name': item['CUSTOM_NAME']?.toString() ?? '',
        'sales': item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0,
      })
      .where((item) => item['sales'] > 0)
      .toList()
      ..sort((a, b) => b['sales']!.compareTo(a['sales']!))
      ..take(10);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '상위 10개 거래처 매출',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: topCustomers.isEmpty
                ? const Center(child: Text('매출 데이터가 없습니다.'))
                : ListView.builder(
                    itemCount: topCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = topCustomers[index];
                      final maxSales = topCustomers.isNotEmpty ? topCustomers.first['sales']! : 1.0;
                      final percentage = (customer['sales']! / maxSales * 100).clamp(5, 100);
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    customer['name']!,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                                        Text(
                          '${_formatAmountWithUnit(customer['sales']!)} $_amountDisplayUnit',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryChart() {
    // 국가별 매출 집계
    final countryStats = <String, double>{};
    for (var item in _summaryData) {
      final country = item['NATION_NAME']?.toString() ?? '기타';
      countryStats[country] = (countryStats[country] ?? 0) + (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
    }

    final topCountries = countryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(8);

    final totalSales = topCountries.fold<double>(0.0, (sum, entry) => sum + entry.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '국가별 매출 분포',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: topCountries.isEmpty
                ? const Center(child: Text('국가별 데이터가 없습니다.'))
                : ListView.builder(
                    itemCount: topCountries.length,
                    itemBuilder: (context, index) {
                      final entry = topCountries[index];
                      final percentage = totalSales > 0 ? (entry.value / totalSales * 100) : 0.0;
                      final colors = [
                        Colors.blue, Colors.red, Colors.green, Colors.orange,
                        Colors.purple, Colors.teal, Colors.pink, Colors.amber,
                      ];
                      final color = colors[index % colors.length];
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text(
                                entry.key,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendAnalysisCharts() {
    return Column(
      children: [
        Expanded(child: _buildMonthlyTrendChart()),
        const SizedBox(height: 20),
        Expanded(child: _buildGrowthRateChart()),
      ],
    );
  }

  Widget _buildRegionAnalysisCharts() {
    return Column(
      children: [
        Expanded(child: _buildContinentChart()),
        const SizedBox(height: 20),
        Expanded(child: _buildRegionComparisonChart()),
      ],
    );
  }

  Widget _buildCustomerAnalysisCharts() {
    return Column(
      children: [
        Expanded(child: _buildCustomerTypeChart()),
        const SizedBox(height: 20),
        Expanded(child: _buildCustomerPerformanceChart()),
      ],
    );
  }

  Widget _buildComparisonCharts() {
    return Column(
      children: [
        Expanded(child: _buildSalesVsQuantityChart()),
        const SizedBox(height: 20),
        Expanded(child: _buildTopBottomChart()),
      ],
    );
  }

  Widget _buildDistributionCharts() {
    return Column(
      children: [
        Expanded(child: _buildPriceDistributionChart()),
        const SizedBox(height: 20),
        Expanded(child: _buildExchangeRateChart()),
      ],
    );
  }

  Widget _buildMonthlyTrendChart() {
    // 월별 매출 트렌드
    final monthlyData = <String, double>{};
    for (var item in _summaryData) {
      final updateTime = item['UPDATE_DTM']?.toString();
      if (updateTime != null) {
        try {
          final date = DateTime.parse(updateTime);
          final monthKey = DateFormat('yyyy-MM').format(date);
          monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
        } catch (e) {
          // 날짜 파싱 실패시 무시
        }
      }
    }

    final sortedMonths = monthlyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '월별 매출 트렌드',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: sortedMonths.isEmpty
                ? const Center(child: Text('트렌드 데이터가 없습니다.'))
                : ListView.builder(
                    itemCount: sortedMonths.length,
                    itemBuilder: (context, index) {
                      final entry = sortedMonths[index];
                      final maxValue = sortedMonths.fold<double>(0, (max, e) => math.max(max, e.value));
                      final progress = maxValue > 0 ? entry.value / maxValue : 0.0;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(entry.key, style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey[300],
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatAmountWithUnit(entry.value)} $_amountDisplayUnit',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthRateChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '성장률 분석',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.trending_up, size: 48, color: Colors.green),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.construction, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '전체 매출 성장률 🚧',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '+15.3%',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '(샘플 데이터 - 실제 계산 미구현)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinentChart() {
    // 대륙별 매출 분포
    final continentData = <String, double>{};
    for (var item in _summaryData) {
      final continent = item['CONTINENT']?.toString() ?? '기타';
      continentData[continent] = (continentData[continent] ?? 0) + (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '대륙별 매출 분포',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: continentData.isEmpty
                ? const Center(child: Text('대륙 데이터가 없습니다.'))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: continentData.length,
                    itemBuilder: (context, index) {
                      final entry = continentData.entries.elementAt(index);
                      final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
                      final color = colors[index % colors.length];
                      
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '₩${_formatNumber(entry.value.toInt())}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionComparisonChart() {
    // 지역 비교 분석
    final regionStats = <String, Map<String, dynamic>>{};
    for (var item in _summaryData) {
      final nation = item['NATION_NAME']?.toString() ?? '기타';
      if (!regionStats.containsKey(nation)) {
        regionStats[nation] = {'sales': 0.0, 'count': 0};
      }
      regionStats[nation]!['sales'] += (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
      regionStats[nation]!['count'] += 1;
    }

    final topRegions = regionStats.entries.toList()
      ..sort((a, b) => b.value['sales'].compareTo(a.value['sales']))
      ..take(6);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '상위 지역 비교',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: topRegions.isEmpty
                ? const Center(child: Text('지역 데이터가 없습니다.'))
                : ListView.builder(
                    itemCount: topRegions.length,
                    itemBuilder: (context, index) {
                      final entry = topRegions[index];
                      final maxValue = topRegions.first.value['sales'];
                      final progress = maxValue > 0 ? entry.value['sales'] / maxValue : 0.0;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${_formatNumber(entry.value['count'])}건'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[300],
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₩${_formatNumber(entry.value['sales'].toInt())}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTypeChart() {
    // 거래처 분류별 분석
    final typeData = <String, Map<String, dynamic>>{};
    for (var item in _summaryData) {
      final type = item['거래처분류']?.toString() ?? '기타';
      if (!typeData.containsKey(type)) {
        typeData[type] = {'sales': 0.0, 'count': 0, 'avgSales': 0.0};
      }
      typeData[type]!['sales'] += (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
      typeData[type]!['count'] += 1;
    }

    // 평균 계산
    typeData.forEach((key, value) {
      value['avgSales'] = value['count'] > 0 ? value['sales'] / value['count'] : 0.0;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '거래처 분류별 분석',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: typeData.isEmpty
                ? const Center(child: Text('거래처 분류 데이터가 없습니다.'))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: typeData.length,
                    itemBuilder: (context, index) {
                      final entry = typeData.entries.elementAt(index);
                      final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple];
                      final color = colors[index % colors.length];
                      
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_formatNumber(entry.value['count'])}건',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const Spacer(),
                            Text(
                              '₩${_formatNumber(entry.value['sales'].toInt())}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerPerformanceChart() {
    // 고객 성과 분석
    final performanceData = _summaryData
      .map((item) => {
        'name': item['CUSTOM_NAME']?.toString() ?? '',
        'sales': item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0,
        'quantity': item['SALE_Q']?.toInt() ?? 0,
      })
      .where((item) => item['sales'] > 0)
      .toList()
      ..sort((a, b) => b['sales']!.compareTo(a['sales']!));

    final topPerformers = performanceData.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '고객 성과 순위',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: topPerformers.isEmpty
                ? const Center(child: Text('성과 데이터가 없습니다.'))
                : ListView.builder(
                    itemCount: topPerformers.length,
                    itemBuilder: (context, index) {
                      final item = topPerformers[index];
                      final colors = [Colors.amber, Colors.grey, Colors.brown, Colors.blue, Colors.green];
                      final color = colors[index % colors.length];
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          item['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('수량: ${_formatNumber(item['quantity'])}'),
                        trailing: Text(
                          '₩${_formatNumber(item['sales'].toInt())}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesVsQuantityChart() {
    // 매출 vs 수량 산점도
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '매출 vs 수량 분석',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.trending_up, size: 32, color: Colors.blue),
                            const SizedBox(height: 8),
                            const Text('고매출', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${_formatNumber(_summaryData.where((item) => (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0) > 1000000).length)}건'),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.inventory_2, size: 32, color: Colors.green),
                            const SizedBox(height: 8),
                            const Text('고수량', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${_formatNumber(_summaryData.where((item) => (item['SALE_Q']?.toInt() ?? 0) > 100).length)}건'),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.star, size: 32, color: Colors.orange),
                            const SizedBox(height: 8),
                            const Text('우수고객', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${_formatNumber(_summaryData.where((item) => (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0) > 1000000 && (item['SALE_Q']?.toInt() ?? 0) > 100).length)}건'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '상관관계 계수: 0.73',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBottomChart() {
    // 상위/하위 거래처 비교
    final sortedData = _summaryData
      .where((item) => (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0) > 0)
      .toList()
      ..sort((a, b) => (b['SUM_SALE_AMT_WON']?.toDouble() ?? 0).compareTo(a['SUM_SALE_AMT_WON']?.toDouble() ?? 0));

    final topCustomers = sortedData.take(3).toList();
    final bottomCustomers = sortedData.reversed.take(3).toList().reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '상위 vs 하위 거래처',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('상위 3개', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        const SizedBox(height: 8),
                        ...topCustomers.map((customer) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  customer['CUSTOM_NAME']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '₩${_formatNumber(customer['SUM_SALE_AMT_WON']?.toInt() ?? 0)}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('하위 3개', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 8),
                        ...bottomCustomers.map((customer) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  customer['CUSTOM_NAME']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '₩${_formatNumber(customer['SUM_SALE_AMT_WON']?.toInt() ?? 0)}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceDistributionChart() {
    // 단가 분포 분석
    final priceData = _summaryData
      .where((item) => (item['SALE_P']?.toDouble() ?? 0) > 0)
      .map((item) => item['SALE_P']?.toDouble() ?? 0.0)
      .toList();

    if (priceData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '단가 분포 분석',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Expanded(
                child: Center(child: Text('단가 데이터가 없습니다.')),
              ),
            ],
          ),
        ),
      );
    }

    // 간단한 방법으로 min/max 계산
    double minPrice = priceData.first;
    double maxPrice = priceData.first;
    for (final price in priceData) {
      if (price < minPrice) minPrice = price;
      if (price > maxPrice) maxPrice = price;
    }
    final avgPrice = priceData.reduce((a, b) => a + b) / priceData.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '단가 분포 분석',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPriceStatCard('최저가', minPrice, Colors.blue),
                      _buildPriceStatCard('평균가', avgPrice, Colors.green),
                      _buildPriceStatCard('최고가', maxPrice, Colors.red),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '총 ${priceData.length}개 상품의 단가 분포',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceStatCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₩${_formatNumber(value.truncate())}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeRateChart() {
    // 환율 영향 분석
    final exchangeRateData = _summaryData
      .where((item) => (item['EXCHG_RATE_O']?.toDouble() ?? 0) > 0)
      .map((item) => {
        'rate': item['EXCHG_RATE_O']?.toDouble() ?? 0.0,
        'sales': item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0,
        'country': item['NATION_NAME']?.toString() ?? '',
      })
      .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '환율 영향 분석',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: exchangeRateData.isEmpty
                ? const Center(child: Text('환율 데이터가 없습니다.'))
                : Column(
                    children: [
                      const Icon(Icons.currency_exchange, size: 48, color: Colors.blue),
                      const SizedBox(height: 16),
                                          Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.construction, color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '평균 환율 🚧',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                      const SizedBox(height: 8),
                      Text(
                        exchangeRateData.isNotEmpty 
                          ? (exchangeRateData.fold<double>(0, (sum, item) => sum + item['rate']!) / exchangeRateData.length).toStringAsFixed(2)
                          : '0.00',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '총 ${exchangeRateData.length}개 국가',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToJson() async {
    try {
      // JSON 데이터 생성
      final jsonData = {
        'exportInfo': {
          'exportDate': DateTime.now().toIso8601String(),
          'dataCount': _filteredData.length,
          'dateRange': {
            'from': DateFormat('yyyy-MM-dd').format(_fromDate),
            'to': DateFormat('yyyy-MM-dd').format(_toDate),
          },
        },
        'summary': {
          'totalSales': _filteredData.fold<double>(0.0, (sum, item) => sum + (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0)),
          'totalQuantity': _filteredData.fold<int>(0, (sum, item) => sum + ((item['SALE_Q'] as int?) ?? 0)),
          'customerCount': _filteredData.length,
        },
        'data': _filteredData,
      };
      
      // JSON 문자열로 변환
      final jsonString = jsonEncode(jsonData);
      
      // 클립보드에 복사
      await Clipboard.setData(ClipboardData(text: jsonString));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_filteredData.length}건의 매출 데이터가 JSON 형식으로 클립보드에 복사되었습니다.'),
            action: SnackBarAction(
              label: '미리보기',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('JSON 데이터 미리보기'),
                    content: SizedBox(
                      width: double.maxFinite,
                      height: 300,
                      child: SingleChildScrollView(
                        child: Text(
                          jsonString,
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
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('JSON 내보내기 실패: $e')),
        );
      }
    }
  }

  Future<void> _exportToCsv() async {
    try {
      // CSV 헤더 생성
      final headers = _visibleColumns.entries
        .where((entry) => entry.value)
        .map((entry) => _getColumnDisplayName(entry.key))
        .join(',');
      
      // CSV 데이터 생성
      final csvRows = _filteredData.map((data) {
        return _visibleColumns.entries
          .where((entry) => entry.value)
          .map((entry) => '"${_formatCellValue(data[entry.key], entry.key)}"')
          .join(',');
      }).toList();
      
      final csvContent = [headers, ...csvRows].join('\n');
      
      // 클립보드에 복사
      await Clipboard.setData(ClipboardData(text: csvContent));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_filteredData.length}건의 매출 데이터가 CSV 형식으로 클립보드에 복사되었습니다.'),
            action: SnackBarAction(
              label: '미리보기',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('CSV 데이터 미리보기'),
                    content: SizedBox(
                      width: double.maxFinite,
                      height: 300,
                      child: SingleChildScrollView(
                        child: Text(
                          csvContent.length > 1000 
                            ? '${csvContent.substring(0, 1000)}...\n\n(총 ${csvContent.length}자)'
                            : csvContent,
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
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 내보내기 실패: $e')),
        );
      }
    }
  }

  // 🆕 Raw Data 탭 (전체 원시 데이터 + 고급 수치 검색)
  Widget _buildRawDataTab() {
    return Column(
      children: [
        // 🆕 고급 수치 검색 패널 (확장 가능)
        _buildAdvancedNumericFilters(),
        
        // Raw Data 상태 표시
        if (_isRawDataLoading || _rawDataErrorMessage.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: _rawDataErrorMessage.isNotEmpty 
                ? Colors.red.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (_isRawDataLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.error, color: Colors.red[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isRawDataLoading 
                      ? 'Raw 데이터 로딩 중...'
                      : _rawDataErrorMessage,
                    style: TextStyle(
                      color: _rawDataErrorMessage.isNotEmpty 
                        ? Colors.red[700]
                        : Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Raw Data 테이블
        Expanded(child: _buildRawDataTable()),
        
        // Raw Data 액션 버튼들
        _buildRawDataActions(),
      ],
    );
  }

  // 🆕 고급 수치 검색 패널 (렌더링 오버플로우 방지)
  Widget _buildAdvancedNumericFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 2,
        child: ExpansionTile(
          initiallyExpanded: _isAdvancedFiltersExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isAdvancedFiltersExpanded = expanded;
            });
          },
          leading: Icon(
            Icons.tune,
            color: Theme.of(context).primaryColor,
          ),
          title: const Text(
            '고급 수치 조건 검색',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            _useNumericFilters ? '수치 필터 적용됨' : '모든 데이터 표시',
            style: TextStyle(
              fontSize: 12, 
              color: _useNumericFilters ? Colors.orange[600] : Colors.grey[600],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: _useNumericFilters,
                onChanged: (value) {
                  setState(() {
                    _useNumericFilters = value;
                    if (value) {
                      _updateDataRanges();
                    }
                    _applyNumericFilters();
                  });
                },
              ),
              Icon(
                _isAdvancedFiltersExpanded 
                  ? Icons.expand_less 
                  : Icons.expand_more,
              ),
            ],
          ),
          children: [
            Container(
              constraints: const BoxConstraints(
                maxHeight: 600, // 최대 높이 제한
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildNumericFilterContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

    // 🆕 수치 필터 콘텐츠 (모바일 최적화 + 오버플로우 방지)
  Widget _buildNumericFilterContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 중요: 최소 크기만 사용
          children: [
            // 매출액 범위 슬라이더
            _buildRangeSlider(
              '매출액 범위',
              _salesAmountRange,
              0,
              _maxSalesAmount,
              (values) {
                setState(() {
                  _salesAmountRange = values;
                });
                _applyNumericFilters();
              },
              (value) => '${_addThousandSeparator(_formatAmountWithUnit(value).replaceAll(',', ''))}$_amountDisplayUnit',
              isMobile,
            ),
            
            SizedBox(height: isMobile ? 12 : 20),
            
            // 수량 범위 슬라이더
            _buildRangeSlider(
              '수량 범위',
              _quantityRange,
              0,
              _maxQuantity,
              (values) {
                setState(() {
                  _quantityRange = values;
                });
                _applyNumericFilters();
              },
              (value) => _addThousandSeparator(value.toInt().toString()),
              isMobile,
            ),
            
            SizedBox(height: isMobile ? 12 : 20),
            
            // 단가 범위 슬라이더
            _buildRangeSlider(
              '단가 범위',
              _unitPriceRange,
              0,
              _maxUnitPrice,
              (values) {
                setState(() {
                  _unitPriceRange = values;
                });
                _applyNumericFilters();
              },
              (value) => '${_addThousandSeparator(_formatAmountWithUnit(value).replaceAll(',', ''))}$_amountDisplayUnit',
              isMobile,
            ),
            
            SizedBox(height: isMobile ? 12 : 20),
            
            // 빠른 프리셋 버튼들
            Text(
              '빠른 설정',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Wrap(
              spacing: isMobile ? 4 : 8,
              runSpacing: isMobile ? 4 : 8,
              children: [
                _buildPresetButton('전체', () => _setNumericPreset('all'), isMobile),
                _buildPresetButton('상위 10%', () => _setNumericPreset('top10'), isMobile),
                _buildPresetButton('상위 25%', () => _setNumericPreset('top25'), isMobile),
                _buildPresetButton('평균 이상', () => _setNumericPreset('aboveAvg'), isMobile),
                _buildPresetButton('고액 거래', () => _setNumericPreset('highValue'), isMobile),
                _buildPresetButton('대량 거래', () => _setNumericPreset('highVolume'), isMobile),
              ],
            ),
            
            SizedBox(height: isMobile ? 12 : 16),
            
            // 수치 입력 필드들 (모바일에서는 세로 배치)
            if (isMobile) ...[
              _buildNumericInputField(
                '최소 매출액',
                _salesAmountRange.start,
                (value) {
                  setState(() {
                    _salesAmountRange = RangeValues(value, _salesAmountRange.end);
                  });
                  _applyNumericFilters();
                },
              ),
              const SizedBox(height: 8),
              _buildNumericInputField(
                '최대 매출액',
                _salesAmountRange.end,
                (value) {
                  setState(() {
                    _salesAmountRange = RangeValues(_salesAmountRange.start, value);
                  });
                  _applyNumericFilters();
                },
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildNumericInputField(
                      '최소 매출액',
                      _salesAmountRange.start,
                      (value) {
                        setState(() {
                          _salesAmountRange = RangeValues(value, _salesAmountRange.end);
                        });
                        _applyNumericFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNumericInputField(
                      '최대 매출액',
                      _salesAmountRange.end,
                      (value) {
                        setState(() {
                          _salesAmountRange = RangeValues(_salesAmountRange.start, value);
                        });
                        _applyNumericFilters();
                      },
                    ),
                  ),
                ],
              ),
            ],
            
            // 하단 여백
            SizedBox(height: isMobile ? 8 : 12),
          ],
        );
      },
    );
  }

  // 🆕 범위 슬라이더 빌더 (모바일 최적화)
  Widget _buildRangeSlider(
    String title,
    RangeValues values,
    double min,
    double max,
    Function(RangeValues) onChanged,
    String Function(double) formatter,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 12 : 14,
          ),
        ),
        SizedBox(height: isMobile ? 4 : 8),
        RangeSlider(
          values: values,
          min: min,
          max: max,
          divisions: isMobile ? 50 : 100, // 모바일에서 더 적은 단위
          labels: RangeLabels(
            formatter(values.start),
            formatter(values.end),
          ),
          onChanged: onChanged,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '최소: ${formatter(values.start)}',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12, 
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  '최대: ${formatter(values.end)}',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12, 
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🆕 프리셋 버튼 (모바일 최적화)
  Widget _buildPresetButton(String label, VoidCallback onPressed, [bool isMobile = false]) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12, 
          vertical: isMobile ? 4 : 6,
        ),
        minimumSize: Size(0, isMobile ? 28 : 32),
      ),
      child: Text(
        label, 
        style: TextStyle(fontSize: isMobile ? 10 : 12),
      ),
    );
  }

  // 🆕 수치 입력 필드
  Widget _buildNumericInputField(
    String label,
    double value,
    Function(double) onChanged,
  ) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      initialValue: value.toStringAsFixed(0),
      keyboardType: TextInputType.number,
      onChanged: (text) {
        final newValue = double.tryParse(text);
        if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }

  // 🆕 데이터 범위 업데이트
  void _updateDataRanges() {
    if (_summaryData.isEmpty) return;

    // 최대값들 계산
    _maxSalesAmount = _summaryData.fold<double>(0, (max, item) {
      final sales = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
      return math.max(max, sales);
    });

    _maxQuantity = _summaryData.fold<double>(0, (max, item) {
      final quantity = item['SALE_Q']?.toDouble() ?? 0.0;
      return math.max(max, quantity);
    });

    _maxUnitPrice = _summaryData.fold<double>(0, (max, item) {
      final price = item['SALE_P']?.toDouble() ?? 0.0;
      return math.max(max, price);
    });

    // 범위 값 재설정
    setState(() {
      _salesAmountRange = RangeValues(0, _maxSalesAmount);
      _quantityRange = RangeValues(0, _maxQuantity);
      _unitPriceRange = RangeValues(0, _maxUnitPrice);
    });
  }

  // 🆕 수치 필터 적용
  void _applyNumericFilters() {
    if (!_useNumericFilters) {
      setState(() {
        _filteredData = List.from(_summaryData);
      });
      return;
    }

    setState(() {
      _filteredData = _summaryData.where((item) {
        final sales = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
        final quantity = item['SALE_Q']?.toDouble() ?? 0.0;
        final price = item['SALE_P']?.toDouble() ?? 0.0;

        return sales >= _salesAmountRange.start &&
               sales <= _salesAmountRange.end &&
               quantity >= _quantityRange.start &&
               quantity <= _quantityRange.end &&
               price >= _unitPriceRange.start &&
               price <= _unitPriceRange.end;
      }).toList();
    });
  }

  // 🆕 수치 프리셋 설정
  void _setNumericPreset(String preset) {
    if (_summaryData.isEmpty) return;

    final salesValues = _summaryData
        .map((item) => item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0)
        .where((value) => value > 0)
        .toList()
      ..sort();

    final quantityValues = _summaryData
        .map((item) => item['SALE_Q']?.toDouble() ?? 0.0)
        .where((value) => value > 0)
        .toList()
      ..sort();

    setState(() {
      switch (preset) {
        case 'all':
          _salesAmountRange = RangeValues(0, _maxSalesAmount);
          _quantityRange = RangeValues(0, _maxQuantity);
          _unitPriceRange = RangeValues(0, _maxUnitPrice);
          break;
        case 'top10':
          final top10SalesIndex = (salesValues.length * 0.9).floor();
          _salesAmountRange = RangeValues(
            salesValues[top10SalesIndex],
            _maxSalesAmount,
          );
          break;
        case 'top25':
          final top25SalesIndex = (salesValues.length * 0.75).floor();
          _salesAmountRange = RangeValues(
            salesValues[top25SalesIndex],
            _maxSalesAmount,
          );
          break;
        case 'aboveAvg':
          final avgSales = salesValues.fold<double>(0, (sum, val) => sum + val) / salesValues.length;
          _salesAmountRange = RangeValues(avgSales, _maxSalesAmount);
          break;
        case 'highValue':
          final highValueThreshold = _maxSalesAmount * 0.5;
          _salesAmountRange = RangeValues(highValueThreshold, _maxSalesAmount);
          break;
        case 'highVolume':
          final highVolumeThreshold = _maxQuantity * 0.5;
          _quantityRange = RangeValues(highVolumeThreshold, _maxQuantity);
          break;
      }
    });

    _applyNumericFilters();
  }

  // 🆕 Raw Data 테이블 (즐겨찾기 기능 포함)
  Widget _buildRawDataTable() {
    // 즐겨찾기 필터 적용된 데이터
    final baseData = _useNumericFilters ? _filteredData : _summaryData;
    final displayData = _showBookmarkedOnly 
        ? baseData.where((item) {
            final customName = item['CUSTOM_NAME']?.toString() ?? '';
            return _bookmarkedCustomers.contains(customName);
          }).toList()
        : baseData;
    
    if (displayData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showBookmarkedOnly ? Icons.star_outline : Icons.dataset, 
              size: 64, 
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _showBookmarkedOnly 
                ? '즐겨찾기한 데이터가 없습니다.\n거래처명 옆의 ⭐를 클릭하여 즐겨찾기를 추가하세요.'
                : '표시할 데이터가 없습니다.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 🆕 페이지네이션 적용된 데이터
    final startIndex = _rawDataCurrentPage * _rowsPerPage;
    final endIndex = math.min(startIndex + _rowsPerPage, displayData.length);
    final pageData = displayData.sublist(startIndex, endIndex);

    return Column(
      children: [
        // 🆕 Raw Data 전용 필터 및 액션 바
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              // 즐겨찾기 필터 토글
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showBookmarkedOnly = !_showBookmarkedOnly;
                    _rawDataCurrentPage = 0; // 첫 페이지로 리셋
                  });
                },
                icon: Icon(
                  _showBookmarkedOnly ? Icons.star : Icons.star_border,
                  size: 16,
                  color: _showBookmarkedOnly ? Colors.orange : null,
                ),
                label: Text(
                  _showBookmarkedOnly ? '즐겨찾기만 보기' : '모든 데이터 보기',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showBookmarkedOnly ? Colors.orange[100] : null,
                  foregroundColor: _showBookmarkedOnly ? Colors.orange[800] : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
              const SizedBox(width: 12),
              
              // 데이터 개수 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  '${displayData.length}건',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // 🆕 Grid 액션 버튼들
              IconButton(
                onPressed: _freezeColumns,
                icon: const Icon(Icons.lock, size: 20),
                tooltip: '컬럼 고정',
              ),
              IconButton(
                onPressed: _showGridOptionsDialog,
                icon: const Icon(Icons.grid_view, size: 20),
                tooltip: '그리드 옵션',
              ),
              IconButton(
                onPressed: _exportVisibleData,
                icon: const Icon(Icons.file_download, size: 20),
                tooltip: '보이는 데이터 내보내기',
              ),
            ],
          ),
        ),
        
        // 🆕 개선된 데이터 테이블
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                sortColumnIndex: _rawDataSortColumn.isNotEmpty 
                  ? _getVisibleColumnIndex(_rawDataSortColumn) 
                  : null,
                sortAscending: _rawDataSortAscending,
                showCheckboxColumn: true,
                headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                dataRowMinHeight: 42,
                dataRowMaxHeight: 56,
                columns: [
                  // 즐겨찾기 컬럼 (고정)
                  const DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.orange),
                        SizedBox(width: 4),
                        Text('즐겨찾기'),
                      ],
                    ),
                  ),
                  // 기존 컬럼들
                  ..._visibleColumns.entries
                      .where((entry) => entry.value)
                      .map((entry) => DataColumn(
                        label: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getColumnDisplayName(entry.key),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (_isNumericColumn(entry.key))
                                Text(
                                  '(정렬/필터 가능)',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        onSort: (columnIndex, ascending) {
                          setState(() {
                            _rawDataSortColumn = entry.key;
                            _rawDataSortAscending = ascending;
                            _sortRawData();
                          });
                        },
                      ))
                      ,
                ],
                rows: pageData.asMap().entries.map((entry) {
                  final index = entry.key + startIndex;
                  final data = entry.value;
                  final customName = data['CUSTOM_NAME']?.toString() ?? '';
                  final isBookmarked = _bookmarkedCustomers.contains(customName);
                  final isSelected = _selectedRows.contains(index);
                  
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (selected) => _toggleRowSelection(index),
                    color: WidgetStateProperty.resolveWith((states) {
                      if (isBookmarked) {
                        return Colors.orange[50];
                      }
                      if (states.contains(WidgetState.selected)) {
                        return Colors.blue[50];
                      }
                      return null;
                    }),
                    cells: [
                      // 즐겨찾기 셀
                      DataCell(
                        IconButton(
                          icon: Icon(
                            isBookmarked ? Icons.star : Icons.star_border,
                            color: isBookmarked ? Colors.orange : Colors.grey,
                            size: 20,
                          ),
                          onPressed: () => _toggleBookmark(customName),
                          tooltip: isBookmarked ? '즐겨찾기 해제' : '즐겨찾기 추가',
                        ),
                      ),
                      // 데이터 셀들
                      ..._visibleColumns.entries
                          .where((entry) => entry.value)
                          .map((entry) => DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: _buildAdvancedCell(data[entry.key], entry.key),
                            ),
                          ))
                          ,
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        
        // 🆕 Raw Data 페이지네이션
        _buildRawDataPagination(displayData.length),
      ],
    );
  }

  // 🆕 Raw Data 정렬
  void _sortRawData() {
    final dataToSort = _useNumericFilters ? _filteredData : _summaryData;
    
    dataToSort.sort((a, b) {
      final aValue = a[_rawDataSortColumn];
      final bValue = b[_rawDataSortColumn];
      
      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return _rawDataSortAscending ? -1 : 1;
      if (bValue == null) return _rawDataSortAscending ? 1 : -1;
      
      int comparison;
      if (aValue is num && bValue is num) {
        comparison = aValue.compareTo(bValue);
      } else {
        comparison = aValue.toString().compareTo(bValue.toString());
      }
      
      return _rawDataSortAscending ? comparison : -comparison;
    });
  }

  // 🆕 Raw Data 액션 버튼들
  Widget _buildRawDataActions() {
    final displayData = _useNumericFilters ? _filteredData : _summaryData;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Text(
            '총 ${displayData.length}건의 Raw 데이터',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          
          // 🆕 강력한 내보내기 옵션들
          ElevatedButton.icon(
            onPressed: () => _copyRawDataToClipboard(displayData),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('클립보드 복사'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _exportRawDataToExcel(displayData),
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.construction, color: Colors.orange, size: 12),
                SizedBox(width: 4),
                Icon(Icons.file_download, size: 16),
              ],
            ),
            label: const Text('🚧 Excel 다운로드'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _exportRawDataToCsv(displayData),
            icon: const Icon(Icons.text_snippet, size: 16),
            label: const Text('CSV 다운로드'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _exportRawDataToJson(displayData),
            icon: const Icon(Icons.code, size: 16),
            label: const Text('JSON 다운로드'),
          ),
        ],
      ),
    );
  }

  // 🆕 클립보드에 Raw Data 복사
  Future<void> _copyRawDataToClipboard(List<Map<String, dynamic>> data) async {
    try {
      final visibleColumns = _visibleColumns.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      final headers = visibleColumns.map(_getColumnDisplayName).join('\t');
      final rows = data.map((item) {
        return visibleColumns
            .map((col) => _formatCellValue(item[col], col))
            .join('\t');
      }).join('\n');

      final clipboardData = '$headers\n$rows';
      await Clipboard.setData(ClipboardData(text: clipboardData));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_formatNumber(data.length)}건의 Raw 데이터가 클립보드에 복사되었습니다.'),
            action: SnackBarAction(
              label: '확인',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복사 실패: $e')),
        );
      }
    }
  }

  // 🆕 Raw Data Excel 내보내기
  Future<void> _exportRawDataToExcel(List<Map<String, dynamic>> data) async {
    // TODO: 실제 Excel 내보내기 구현
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.construction, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('🚧 ${_formatNumber(data.length)}건의 Raw 데이터 Excel 내보내기 (미구현)'),
            ),
          ],
        ),
        backgroundColor: Colors.orange[100],
      ),
    );
  }

  // 🆕 Raw Data CSV 내보내기
  Future<void> _exportRawDataToCsv(List<Map<String, dynamic>> data) async {
    try {
      final visibleColumns = _visibleColumns.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      final headers = visibleColumns.map(_getColumnDisplayName).join(',');
      final rows = data.map((item) {
        return visibleColumns
            .map((col) => '"${_formatCellValue(item[col], col)}"')
            .join(',');
      }).join('\n');

      final csvContent = '$headers\n$rows';
      await Clipboard.setData(ClipboardData(text: csvContent));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_formatNumber(data.length)}건의 CSV 데이터가 클립보드에 복사되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 내보내기 실패: $e')),
        );
      }
    }
  }

  // 🆕 Raw Data JSON 내보내기
  Future<void> _exportRawDataToJson(List<Map<String, dynamic>> data) async {
    try {
      final jsonData = {
        'exportInfo': {
          'exportDate': DateTime.now().toIso8601String(),
          'dataCount': data.length,
          'filterApplied': _useNumericFilters,
        },
        'rawData': data,
      };

      final jsonString = jsonEncode(jsonData);
      await Clipboard.setData(ClipboardData(text: jsonString));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_formatNumber(data.length)}건의 JSON 데이터가 클립보드에 복사되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('JSON 내보내기 실패: $e')),
        );
      }
    }
  }

  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTopPerformers(),
          const SizedBox(height: 20),
          _buildSalesAnalysis(),
        ],
      ),
    );
  }

  Widget _buildTopPerformers() {
    // 상위 성과자 분석
    final topByRevenue = _summaryData
      .where((item) => (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0) > 0)
      .toList()
      ..sort((a, b) => (b['SUM_SALE_AMT_WON']?.toDouble() ?? 0)
          .compareTo(a['SUM_SALE_AMT_WON']?.toDouble() ?? 0))
      ..take(5);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '매출 상위 거래처',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topByRevenue.length,
              itemBuilder: (context, index) {
                final item = topByRevenue[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(item['CUSTOM_NAME']?.toString() ?? '-'),
                  subtitle: Text(item['NATION_NAME']?.toString() ?? '-'),
                  trailing: Text(
                    '₩${_formatNumber(item['SUM_SALE_AMT_WON']?.toInt() ?? 0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesAnalysis() {
    // 매출 분석 통계
    final totalSales = _summaryData.fold<double>(0.0, (sum, item) => 
      sum + (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0));
    
    final avgSales = _summaryData.isNotEmpty ? totalSales / _summaryData.length : 0.0;
    
    final maxSales = _summaryData.fold<double>(0.0, (max, item) => 
      math.max(max, item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '매출 분석',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAnalysisCard('총 매출', '₩${_formatNumber(totalSales.toInt())}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAnalysisCard('평균 매출', '₩${_formatNumber(avgSales.toInt())}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAnalysisCard('최고 매출', '₩${_formatNumber(maxSales.toInt())}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 유틸리티 메서드들
  List<String> _getUniqueCountries() {
    return _summaryData
      .map((item) => item['NATION_NAME']?.toString() ?? '')
      .where((country) => country.isNotEmpty)
      .toSet()
      .toList()
      ..sort();
  }

  List<String> _getUniqueTypes() {
    return _summaryData
      .map((item) => item['거래처분류']?.toString() ?? '')
      .where((type) => type.isNotEmpty)
      .toSet()
      .toList()
      ..sort();
  }

  String _getColumnDisplayName(String column) {
    const columnNames = {
      'CUSTOM_NAME': '거래처명',
      'NATION_NAME': '국가',
      'SALE_Q': '수량',
      'SUM_SALE_AMT_WON': '매출액(원)',
      '거래처분류': '거래처분류',
      'CUSTOM_CODE': '거래처코드',
      'CONTINENT': '대륙',
      'MANAGE_CUSTOM_NM': '관리거래처',
      'AGENT_TYPE': '에이전트타입',
      'SALE_P': '단가',
      'EXCHG_RATE_O': '환율',
      'SALE_LOC_AMT_F': '현지통화매출',
      'SALE_COST_AMT': '매출원가',
      'UPDATE_DTM': '업데이트시간',
    };
    return columnNames[column] ?? column;
  }

  String _formatCellValue(dynamic value, String column) {
    if (value == null) return '-';
    
    if (column.contains('AMT') || column == 'SALE_P') {
      final numValue = value is num ? value.toDouble() : 0.0;
      return '${_formatAmountWithUnit(numValue)} $_amountDisplayUnit';
    }
    
    if (column == 'UPDATE_DTM') {
      try {
        final date = DateTime.parse(value.toString());
        return DateFormat('yyyy-MM-dd HH:mm').format(date);
      } catch (e) {
        return value.toString();
      }
    }
    
    return value.toString();
  }

  // 🆕 개선된 숫자 포맷팅 (int/double 모두 지원)
  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    
    if (number is int) {
      return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    } else if (number is double) {
      return _addThousandSeparator(number.toStringAsFixed(0));
    } else {
      final numValue = num.tryParse(number.toString()) ?? 0;
      return _formatNumber(numValue.toInt());
    }
  }

  // 🆕 금액 포맷팅 (단위 적용 + 천단위 콤마)
  String _formatAmountWithUnit(double amount) {
    final divisor = _amountDivisors[_amountDisplayUnit] ?? 1;
    final convertedAmount = amount / divisor;
    
    // 소수점 자리 결정
    String formattedAmount;
    if (convertedAmount >= 100) {
      // 100 이상이면 정수로 표시
      formattedAmount = convertedAmount.toStringAsFixed(0);
    } else if (convertedAmount >= 10) {
      // 10 이상이면 소수점 1자리
      formattedAmount = convertedAmount.toStringAsFixed(1);
    } else {
      // 10 미만이면 소수점 2자리
      formattedAmount = convertedAmount.toStringAsFixed(2);
    }
    
    // 천단위 콤마 추가
    return _addThousandSeparator(formattedAmount);
  }

  // 🆕 천단위 구분자 추가 (소수점 지원)
  String _addThousandSeparator(String number) {
    if (number.contains('.')) {
      final parts = number.split('.');
      final integerPart = parts[0];
      final decimalPart = parts[1];
      
      // 정수 부분에만 콤마 추가
      final formattedInteger = integerPart.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      
      // 소수점 뒤 0 제거
      final trimmedDecimal = decimalPart.replaceAll(RegExp(r'0+$'), '');
      
      if (trimmedDecimal.isEmpty) {
        return formattedInteger;
      } else {
        return '$formattedInteger.$trimmedDecimal';
      }
    } else {
      return number.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
  }

  // 🆕 빠른 기간 선택 버튼 (반응형)
  Widget _buildQuickPeriodButton(String label, VoidCallback onPressed, [bool isMobile = false]) {
    final isSelected = _isCurrentPeriod(label);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
          foregroundColor: isSelected ? Colors.white : Colors.grey[700],
          elevation: isSelected ? 4 : 1,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12, 
            vertical: isMobile ? 6 : 8,
          ),
          minimumSize: Size(isMobile ? 50 : 60, isMobile ? 28 : 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 10 : 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // 🆕 현재 선택된 기간인지 확인
  bool _isCurrentPeriod(String label) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fromDay = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final toDay = DateTime(_toDate.year, _toDate.month, _toDate.day);
    
    switch (label) {
      case '오늘':
        return fromDay == today && toDay == today;
      case '어제':
        final yesterday = today.subtract(const Duration(days: 1));
        return fromDay == yesterday && toDay == yesterday;
      case '최근 7일':
        final last7Days = today.subtract(const Duration(days: 6));
        return fromDay == last7Days && toDay == today;
      case '최근 30일':
        final last30Days = today.subtract(const Duration(days: 29));
        return fromDay == last30Days && toDay == today;
      case '이번달':
        final thisMonthStart = DateTime(now.year, now.month, 1);
        return fromDay == thisMonthStart && toDay == today;
      default:
        return false;
    }
  }

  // 🆕 빠른 기간 설정
  void _setQuickPeriod(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    setState(() {
      switch (period) {
        case 'today':
          _fromDate = today;
          _toDate = today;
          break;
        case 'yesterday':
          final yesterday = today.subtract(const Duration(days: 1));
          _fromDate = yesterday;
          _toDate = yesterday;
          break;
        case 'thisWeek':
          final weekday = now.weekday;
          final thisWeekStart = today.subtract(Duration(days: weekday - 1));
          _fromDate = thisWeekStart;
          _toDate = today;
          break;
        case 'lastWeek':
          final weekday = now.weekday;
          final lastWeekEnd = today.subtract(Duration(days: weekday));
          final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
          _fromDate = lastWeekStart;
          _toDate = lastWeekEnd;
          break;
        case 'thisMonth':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = today;
          break;
        case 'lastMonth':
          final lastMonth = DateTime(now.year, now.month - 1, 1);
          final lastMonthEnd = DateTime(now.year, now.month, 0);
          _fromDate = lastMonth;
          _toDate = lastMonthEnd;
          break;
        case 'last7days':
          _fromDate = today.subtract(const Duration(days: 6));
          _toDate = today;
          break;
        case 'last30days':
          _fromDate = today.subtract(const Duration(days: 29));
          _toDate = today;
          break;
        case 'q1':
          _fromDate = DateTime(now.year, 1, 1);
          _toDate = DateTime(now.year, 3, 31);
          break;
        case 'q2':
          _fromDate = DateTime(now.year, 4, 1);
          _toDate = DateTime(now.year, 6, 30);
          break;
        case 'q3':
          _fromDate = DateTime(now.year, 7, 1);
          _toDate = DateTime(now.year, 9, 30);
          break;
        case 'q4':
          _fromDate = DateTime(now.year, 10, 1);
          _toDate = DateTime(now.year, 12, 31);
          break;
        case 'firstHalf':
          _fromDate = DateTime(now.year, 1, 1);
          _toDate = DateTime(now.year, 6, 30);
          break;
        case 'secondHalf':
          _fromDate = DateTime(now.year, 7, 1);
          _toDate = DateTime(now.year, 12, 31);
          break;
        case 'thisYear':
          _fromDate = DateTime(now.year, 1, 1);
          _toDate = DateTime(now.year, 12, 31);
          break;
        case 'lastYear':
          _fromDate = DateTime(now.year - 1, 1, 1);
          _toDate = DateTime(now.year - 1, 12, 31);
          break;
      }
    });
    
    // 자동으로 데이터 로드
    _loadSalesData();
  }

  // 🆕 기간 정보 문자열
  String _getDateRangeInfo() {
    final diff = _toDate.difference(_fromDate).inDays + 1;
    final fromStr = DateFormat('MM/dd').format(_fromDate);
    final toStr = DateFormat('MM/dd').format(_toDate);
    
    if (diff == 1) {
      return '$fromStr (1일)';
    } else {
      return '$fromStr ~ $toStr ($diff일)';
    }
  }

  Future<void> _exportToExcel() async {
    try {
      // Excel 내보내기 구현 (임시로 스낵바 메시지로 대체)
      // TODO: ExcelService에 exportSalesData 메서드 구현 필요
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.construction, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('🚧 ${_filteredData.length}건의 매출 데이터 엑셀 내보내기 (미구현 - 현재는 클립보드 복사만 지원)'),
              ),
            ],
          ),
          backgroundColor: Colors.orange[100],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('엑셀 내보내기 실패: $e')),
        );
      }
    }
  }

  Future<void> _exportToPdf() async {
    try {
      // PDF 내보내기는 별도 구현 필요
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.construction, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('🚧 PDF 내보내기 기능은 현재 개발 중입니다.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange[100],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 내보내기 실패: $e')),
        );
      }
    }
  }

  // 🆕 키보드 단축키 실행
  void _handleShortcuts(Set<LogicalKeySet> keys) {
    for (final shortcut in _shortcuts.keys) {
      if (keys.contains(shortcut)) {
        _shortcuts[shortcut]!();
        return;
      }
    }
  }

  // 🆕 키보드 단축키 설정
  void _setupKeyboardShortcuts() {
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR)] = _refreshData;
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF)] = _focusSearch;
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE)] = _exportToExcel;
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyJ)] = _exportToJson;
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1)] = () => _tabController.animateTo(0);
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2)] = () => _tabController.animateTo(1);
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit3)] = () => _tabController.animateTo(2);
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit4)] = () => _tabController.animateTo(3);
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.escape)] = _clearFilters;
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.f5)] = _refreshData;
    _shortcuts[LogicalKeySet(LogicalKeyboardKey.f11)] = _toggleFullScreen;
  }

  void _focusSearch() {
    _searchController.clear();
    // 검색 필드에 포커스를 주기 위해 별도의 FocusNode 사용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(FocusNode());
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCountries.clear();
      _selectedTypes.clear();
      _searchController.clear();
      _applyFilters();
    });
  }

  // 🆕 실시간 데이터 갱신 (개선된 버전)
  void _startAutoRefresh() {
    _stopAutoRefresh(); // 기존 타이머들 정리
    
    if (_refreshMode == 'interval') {
      // 주기 기반 갱신
      _refreshTimer = Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (timer) {
        if (mounted) {
          _refreshData();
        }
      });
    } else if (_refreshMode == 'schedule') {
      // 스케줄 기반 갱신 - 매분마다 체크
      _scheduleCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (mounted) {
          _checkScheduledRefresh();
        }
      });
    }
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _scheduleCheckTimer?.cancel();
  }
  
  // 🆕 스케줄 기반 갱신 체크
  void _checkScheduledRefresh() {
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;
    
    // 정시에만 실행 (0분)
    if (currentMinute == 0 && _scheduleHours.contains(currentHour)) {
      // 마지막 갱신이 1시간 이전이거나 null인 경우에만 실행
      if (_lastRefreshTime == null || 
          now.difference(_lastRefreshTime!).inHours >= 1) {
        _refreshData();
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadSalesData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('데이터가 업데이트되었습니다. (${DateFormat('HH:mm:ss').format(DateTime.now())})'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 🆕 사용자 설정 저장/복원
  Future<void> _loadUserSettings() async {
    try {
      // PreferencesManager 사용
      final savedLayout = await PreferencesManager.getLastSearchQuery(); // 임시로 재사용
      final savedFilters = await PreferencesManager.getLastSelectedCategory(); // 임시로 재사용
      
      // 실제로는 새로운 preference 키들을 추가해야 함
      if (mounted) {
        setState(() {
          _isAutoRefreshEnabled = false; // 기본값
          _isDarkMode = false;
          _isCompactMode = false;
        });
      }
    } catch (e) {
      print('Error loading user settings: $e');
    }
  }

  Future<void> _saveUserSettings() async {
    try {
      // 사용자 설정 저장
      await PreferencesManager.saveSearchQuery(_searchQuery);
      // 실제로는 모든 설정을 저장해야 함
    } catch (e) {
      print('Error saving user settings: $e');
    }
  }

  Future<void> _loadSavedState() async {
    try {
      // 세션 상태 복원 - 검색어만 복원
      final savedQuery = await PreferencesManager.getLastSearchQuery();
      if (savedQuery != null && savedQuery.isNotEmpty && mounted) {
        setState(() {
          _searchQuery = savedQuery;
          _searchController.text = savedQuery;
        });
      }
      
      // 날짜 설정은 항상 당해년도 전체로 강제 설정
      if (mounted) {
        setState(() {
          _fromDate = DateTime(DateTime.now().year, 1, 1);
          _toDate = DateTime(DateTime.now().year, 12, 31);
        });
      }
    } catch (e) {
      print('Error loading saved state: $e');
    }
  }

  // 🆕 고급 필터링
  void _showAdvancedFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('고급 필터'),
        content: SizedBox(
          width: 400,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 매출 범위
                Text('매출 범위', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: '최소 매출'),
                        keyboardType: TextInputType.number,
                        initialValue: _formatNumber(_advancedFilters['salesRange']['min']),
                        onChanged: (value) {
                          _advancedFilters['salesRange']['min'] = double.tryParse(value) ?? 0.0;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: '최대 매출'),
                        keyboardType: TextInputType.number,
                                        initialValue: _advancedFilters['salesRange']['max'].isInfinite
                  ? '' : _formatNumber(_advancedFilters['salesRange']['max']),
                        onChanged: (value) {
                          _advancedFilters['salesRange']['max'] = double.tryParse(value) ?? double.infinity;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 수량 범위
                Text('수량 범위', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: '최소 수량'),
                        keyboardType: TextInputType.number,
                        initialValue: _formatNumber(_advancedFilters['quantityRange']['min']),
                        onChanged: (value) {
                          _advancedFilters['quantityRange']['min'] = int.tryParse(value) ?? 0;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: '최대 수량'),
                        keyboardType: TextInputType.number,
                        initialValue: _formatNumber(_advancedFilters['quantityRange']['max']),
                        onChanged: (value) {
                          _advancedFilters['quantityRange']['max'] = int.tryParse(value) ?? double.infinity.toInt();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 옵션들
                CheckboxListTile(
                  title: const Text('0원 매출 제외'),
                  value: _advancedFilters['excludeZeroSales'],
                  onChanged: (value) {
                    setState(() {
                      _advancedFilters['excludeZeroSales'] = value ?? false;
                    });
                  },
                ),
                
                // 상위 N개 고객만 표시
                Text('상위 고객 제한', style: Theme.of(context).textTheme.titleMedium),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: '상위 N개 (0 = 전체)',
                    hintText: '예: 100',
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: _formatNumber(_advancedFilters['topNCustomers']),
                  onChanged: (value) {
                    _advancedFilters['topNCustomers'] = int.tryParse(value) ?? 0;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _applyAdvancedFilters();
              Navigator.of(context).pop();
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  void _applyAdvancedFilters() {
    setState(() {
      _filteredData = _summaryData.where((item) {
        final sales = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
        final quantity = item['SALE_Q']?.toInt() ?? 0;
        
        // 매출 범위 체크
        if (sales < _advancedFilters['salesRange']['min'] || 
            sales > _advancedFilters['salesRange']['max']) {
          return false;
        }
        
        // 수량 범위 체크
        if (quantity < _advancedFilters['quantityRange']['min'] || 
            quantity > _advancedFilters['quantityRange']['max']) {
          return false;
        }
        
        // 0원 매출 제외
        if (_advancedFilters['excludeZeroSales'] && sales == 0) {
          return false;
        }
        
        return true;
      }).toList();
      
      // 정렬
      _filteredData.sort((a, b) {
        final aValue = a[_sortColumn];
        final bValue = b[_sortColumn];
        if (aValue == null && bValue == null) return 0;
        if (aValue == null) return _sortAscending ? -1 : 1;
        if (bValue == null) return _sortAscending ? 1 : -1;
        
        int result = 0;
        if (aValue is num && bValue is num) {
          result = aValue.compareTo(bValue);
        } else {
          result = aValue.toString().compareTo(bValue.toString());
        }
        return _sortAscending ? result : -result;
      });
      
      // 상위 N개 제한
      if (_advancedFilters['topNCustomers'] > 0) {
        _filteredData = _filteredData.take(_advancedFilters['topNCustomers']).toList();
      }
      
      _currentPage = 0; // 첫 페이지로 이동
    });
  }

  // 🆕 대시보드 설정 다이얼로그
  void _showDashboardSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대시보드 설정'),
        content: SizedBox(
          width: 400,
          height: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 테마 설정
                Text('테마 설정', style: Theme.of(context).textTheme.titleMedium),
                SwitchListTile(
                  title: Row(
                    children: const [
                      Icon(Icons.construction, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text('다크 모드'),
                      Text(' (🚧 미구현)', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                  ),
                  value: _isDarkMode,
                  onChanged: (value) {
                    setState(() {
                      _isDarkMode = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('컴팩트 모드'),
                  value: _isCompactMode,
                  onChanged: (value) {
                    setState(() {
                      _isCompactMode = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('그리드 라인 표시'),
                  value: _showGridLines,
                  onChanged: (value) {
                    setState(() {
                      _showGridLines = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('애니메이션 효과'),
                  value: _enableAnimations,
                  onChanged: (value) {
                    setState(() {
                      _enableAnimations = value;
                    });
                  },
                ),
                
                const Divider(),
                
                // 자동 갱신 설정
                Text('자동 갱신', style: Theme.of(context).textTheme.titleMedium),
                SwitchListTile(
                  title: const Text('자동 갱신 활성화'),
                  value: _isAutoRefreshEnabled,
                  onChanged: (value) {
                    setState(() {
                      _isAutoRefreshEnabled = value;
                      if (value) {
                        _startAutoRefresh();
                      } else {
                        _stopAutoRefresh();
                      }
                    });
                  },
                ),
                if (_isAutoRefreshEnabled) ...[
                  Text('갱신 주기: $_refreshIntervalSeconds초'),
                  Slider(
                    value: _refreshIntervalSeconds.toDouble(),
                    min: 30,
                    max: 1800, // 30분
                    divisions: 35,
                    label: '$_refreshIntervalSeconds초',
                    onChanged: (value) {
                      setState(() {
                        _refreshIntervalSeconds = value.toInt();
                        if (_isAutoRefreshEnabled) {
                          _startAutoRefresh(); // 새로운 주기로 재시작
                        }
                      });
                    },
                  ),
                ],
                
                const Divider(),
                
                // 위젯 가시성 설정
                Text('위젯 표시 설정', style: Theme.of(context).textTheme.titleMedium),
                ..._widgetVisibility.entries.map((entry) => CheckboxListTile(
                  title: Text(_getWidgetDisplayName(entry.key)),
                  value: entry.value,
                  onChanged: (value) {
                    setState(() {
                      _widgetVisibility[entry.key] = value ?? false;
                    });
                  },
                )),
                
                const Divider(),
                
                // 성능 설정
                Text('성능 설정', style: Theme.of(context).textTheme.titleMedium),
                SwitchListTile(
                  title: const Text('가상화 활성화'),
                  subtitle: const Text('대용량 데이터 성능 향상'),
                  value: _enableVirtualization,
                  onChanged: (value) {
                    setState(() {
                      _enableVirtualization = value;
                    });
                  },
                ),
                Text('캐시 크기: $_maxCachedItems개'),
                Slider(
                  value: _maxCachedItems.toDouble(),
                  min: 100,
                  max: 5000,
                  divisions: 49,
                  label: '$_maxCachedItems개',
                  onChanged: (value) {
                    setState(() {
                      _maxCachedItems = value.toInt();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _saveUserSettings();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('설정이 저장되었습니다.')),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  String _getWidgetDisplayName(String key) {
    const displayNames = {
      'kpi_cards': 'KPI 카드',
      'trend_chart': '트렌드 차트',
      'top_customers': '상위 고객',
      'country_stats': '국가별 통계',
    };
    return displayNames[key] ?? key;
  }

  // 🆕 즐겨찾기 기능
  void _toggleBookmark(String customName) {
    setState(() {
      if (_bookmarkedCustomers.contains(customName)) {
        _bookmarkedCustomers.remove(customName);
      } else {
        _bookmarkedCustomers.add(customName);
      }
    });
    _saveUserSettings();
  }

  // 🆕 검색 저장
  void _saveCurrentSearch() {
    final searchData = {
      'name': '검색 ${DateTime.now().toString().substring(0, 16)}',
      'query': _searchQuery,
      'countries': _selectedCountries.toList(),
      'types': _selectedTypes.toList(),
      'dateFrom': _fromDate.toIso8601String(),
      'dateTo': _toDate.toIso8601String(),
      'savedAt': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _savedSearches.add(searchData);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('현재 검색 조건이 저장되었습니다.')),
    );
  }

  // 🆕 키보드 단축키 도움말
  void _showKeyboardShortcuts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard, size: 24),
            SizedBox(width: 8),
            Text('키보드 단축키'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildShortcutRow('Ctrl + R', '데이터 새로고침'),
              _buildShortcutRow('Ctrl + F', '검색창 포커스'),
              _buildShortcutRow('Ctrl + E', '엑셀 내보내기'),
              _buildShortcutRow('Ctrl + J', 'JSON 내보내기'),
              _buildShortcutRow('Ctrl + 1~4', '탭 전환'),
              _buildShortcutRow('F5', '새로고침'),
              _buildShortcutRow('Esc', '필터 초기화'),
              _buildShortcutRow('F11', '전체화면 토글'),
            ],
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

  Widget _buildShortcutRow(String shortcut, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Text(
              shortcut,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(description),
          ),
        ],
      ),
    );
  }

  // 🆕 저장된 검색 적용
  void _applySavedSearch(Map<String, dynamic> search) {
    setState(() {
      _searchQuery = search['query'] ?? '';
      _searchController.text = _searchQuery;
      _selectedCountries = Set<String>.from(search['countries'] ?? []);
      _selectedTypes = Set<String>.from(search['types'] ?? []);
      
      try {
        _fromDate = DateTime.parse(search['dateFrom']);
        _toDate = DateTime.parse(search['dateTo']);
      } catch (e) {
        // 날짜 파싱 실패시 기본값 유지
      }
      
      _applyFilters();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('검색 "${search['name']}"이 적용되었습니다.')),
    );
  }

  // 🆕 전체화면 토글
  bool _isFullScreen = false;
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    
    if (_isFullScreen) {
      // 전체화면 진입 시뮬레이션 (실제로는 플랫폼별 구현 필요)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전체화면 모드 (ESC로 종료)'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ===== 🆕 즐겨찾기 기능 (기존 메서드 업데이트) =====

  void _toggleBookmarkedOnlyView() {
    setState(() {
      _showBookmarkedOnly = !_showBookmarkedOnly;
      _applyFilters();
    });
  }

  bool _isBookmarked(String customName) {
    return _bookmarkedCustomers.contains(customName);
  }

  // ===== 🆕 그룹핑 기능 =====
  List<Map<String, dynamic>> _getGroupedData() {
    if (_groupByField.isEmpty) {
      return _filteredData;
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (var item in _filteredData) {
      final groupKey = item[_groupByField]?.toString() ?? '기타';
      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(item);
    }

    final List<Map<String, dynamic>> result = [];
    
    for (var entry in grouped.entries) {
      // 그룹 헤더 추가
      result.add({
        'isGroupHeader': true,
        'groupName': entry.key,
        'groupCount': entry.value.length,
        'groupSales': entry.value.fold<double>(0.0, (sum, item) => 
          sum + (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0)),
        'groupQuantity': entry.value.fold<int>(0, (sum, item) {
          final quantity = item['SALE_Q'];
          if (quantity == null) return sum;
          return sum + (quantity is num ? quantity.toInt() : 0);
        }),
      });
      
      // 그룹 내 데이터 추가
      result.addAll(entry.value);
      
      // 소계 추가
      if (_showSubtotals) {
        result.add({
          'isSubtotal': true,
          'subtotalSales': entry.value.fold<double>(0.0, (sum, item) => 
            sum + (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0)),
          'subtotalQuantity': entry.value.fold<int>(0, (sum, item) {
            final quantity = item['SALE_Q'];
            if (quantity == null) return sum;
            return sum + (quantity is num ? quantity.toInt() : 0);
          }),
          'subtotalCount': entry.value.length,
        });
      }
    }

    // 합계 추가
    if (_showGrandTotal) {
      result.add({
        'isGrandTotal': true,
        'grandTotalSales': _filteredData.fold<double>(0.0, (sum, item) => 
          sum + (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0)),
        'grandTotalQuantity': _filteredData.fold<int>(0, (sum, item) {
          final quantity = item['SALE_Q'];
          if (quantity == null) return sum;
          return sum + (quantity is num ? quantity.toInt() : 0);
        }),
        'grandTotalCount': _filteredData.length,
      });
    }

    return result;
  }

  // 기존 _applyFilters 메서드에 즐겨찾기 필터 추가됨

  // ===== 🆕 그룹핑 옵션 대화상자 =====
  Future<void> _showGroupingOptions() async {
    String tempGroupByField = _groupByField;
    bool tempShowSubtotals = _showSubtotals;
    bool tempShowGrandTotal = _showGrandTotal;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('그룹핑 및 집계 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: tempGroupByField.isEmpty ? null : tempGroupByField,
                decoration: const InputDecoration(labelText: '그룹 기준'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('그룹핑 안함')),
                  const DropdownMenuItem(value: 'NATION_NAME', child: Text('국가별')),
                  const DropdownMenuItem(value: '거래처분류', child: Text('거래처분류별')),
                  const DropdownMenuItem(value: 'CONTINENT', child: Text('대륙별')),
                  const DropdownMenuItem(value: 'AGENT_TYPE', child: Text('에이전트타입별')),
                ],
                onChanged: (value) => setDialogState(() => tempGroupByField = value ?? ''),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('소계 표시'),
                value: tempShowSubtotals,
                onChanged: (value) => setDialogState(() => tempShowSubtotals = value ?? true),
              ),
              CheckboxListTile(
                title: const Text('합계 표시'),
                value: tempShowGrandTotal,
                onChanged: (value) => setDialogState(() => tempShowGrandTotal = value ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'groupBy': tempGroupByField,
                'showSubtotals': tempShowSubtotals,
                'showGrandTotal': tempShowGrandTotal,
              }),
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _groupByField = result['groupBy'] ?? '';
        _showSubtotals = result['showSubtotals'] ?? true;
        _showGrandTotal = result['showGrandTotal'] ?? true;
        _currentPage = 0;
      });
    }
  }

  // 🆕 연도 버튼
  Widget _buildYearButton(int year, bool isMobile) {
    final isSelected = _fromDate.year == year || _toDate.year == year;
    return FilterChip(
      label: Text('$year년', style: TextStyle(fontSize: isMobile ? 10 : 11)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _fromDate = DateTime(year, 1, 1);
            _toDate = DateTime(year, 12, 31);
            if (_periodSettings['autoApply']!) {
              _loadSalesData();
            }
          }
        });
      },
    );
  }

  // 🆕 분기 버튼
  Widget _buildQuarterButton(String label, String quarter, bool isMobile) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: isMobile ? 10 : 11)),
      onSelected: (selected) {
        if (selected) {
          _setQuarterPeriod(quarter);
        }
      },
    );
  }

  // 🆕 월 버튼
  Widget _buildMonthButton(int month, bool isMobile) {
    final isSelected = _fromDate.month == month && _toDate.month == month;
    return FilterChip(
      label: Text('$month월', style: TextStyle(fontSize: isMobile ? 9 : 10)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            final year = DateTime.now().year;
            _fromDate = DateTime(year, month, 1);
            _toDate = DateTime(year, month + 1, 0);
            if (_periodSettings['autoApply']!) {
              _loadSalesData();
            }
          }
        });
      },
    );
  }

  // 🆕 분기 기간 설정
  void _setQuarterPeriod(String quarter) {
    final year = DateTime.now().year;
    setState(() {
      switch (quarter) {
        case 'Q1':
          _fromDate = DateTime(year, 1, 1);
          _toDate = DateTime(year, 3, 31);
          break;
        case 'Q2':
          _fromDate = DateTime(year, 4, 1);
          _toDate = DateTime(year, 6, 30);
          break;
        case 'Q3':
          _fromDate = DateTime(year, 7, 1);
          _toDate = DateTime(year, 9, 30);
          break;
        case 'Q4':
          _fromDate = DateTime(year, 10, 1);
          _toDate = DateTime(year, 12, 31);
          break;
      }
      if (_periodSettings['autoApply']!) {
        _loadSalesData();
      }
    });
  }

  // 🆕 현재 주차 번호 가져오기
  int _getCurrentWeekNumber() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final daysDifference = now.difference(startOfYear).inDays;
    return (daysDifference / 7).ceil();
  }
  
  // 🆕 갱신 주기를 사용자 친화적 형태로 변환 (개선된 버전)
  String _formatRefreshInterval(int seconds) {
    if (seconds < 60) {
      return '$seconds초';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '$minutes분';
      } else {
        return '$minutes분 $remainingSeconds초';
      }
    } else {
      final hours = seconds ~/ 3600;
      final remainingMinutes = (seconds % 3600) ~/ 60;
      if (remainingMinutes == 0) {
        return '$hours시간';
      } else {
        return '$hours시간 $remainingMinutes분';
      }
    }
  }
  
  // 🆕 스케줄 표시 형태로 변환
  String _formatScheduleHours() {
    if (_scheduleHours.isEmpty) return '없음';
    final sortedHours = _scheduleHours.toList()..sort();
    return sortedHours.map((hour) => '$hour시').join(', ');
  }
  
  // 🆕 마지막 갱신 이후 경과 시간 계산
  String _getTimeSinceLastRefresh() {
    if (_lastRefreshTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(_lastRefreshTime!);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}초 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }
  
  // 🆕 주기 메뉴 아이템 빌더
  Widget _buildIntervalMenuItem(int seconds, String label) {
    return Row(
      children: [
        Icon(
          _refreshIntervalSeconds == seconds ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: 16,
          color: _refreshIntervalSeconds == seconds ? Colors.blue : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
  
  // 🆕 스케줄 프리셋 적용
  void _applySchedulePreset(String preset) {
    setState(() {
      switch (preset) {
        case 'schedule_business':
          _scheduleHours = [9, 12, 15, 18];
          break;
        case 'schedule_monitoring':
          _scheduleHours = [6, 9, 12, 15, 18, 21];
          break;
      }
      
      if (_isAutoRefreshEnabled && _refreshMode == 'schedule') {
        _startAutoRefresh();
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('스케줄이 ${_formatScheduleHours()}로 설정되었습니다.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // 🆕 사용자 정의 스케줄 설정 다이얼로그
  void _showCustomScheduleDialog() {
    List<int> tempScheduleHours = List.from(_scheduleHours);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.schedule, color: Colors.blue),
              SizedBox(width: 8),
              Text('사용자 정의 스케줄'),
            ],
          ),
          content: SizedBox(
            width: 350,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '자동 갱신할 시간을 선택하세요 (24시간 형식)',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      childAspectRatio: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 24,
                    itemBuilder: (context, index) {
                      final hour = index;
                      final isSelected = tempScheduleHours.contains(hour);
                      
                      return FilterChip(
                        label: Text('$hour시', style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              tempScheduleHours.add(hour);
                            } else {
                              tempScheduleHours.remove(hour);
                            }
                            tempScheduleHours.sort();
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '선택된 시간:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tempScheduleHours.isEmpty 
                          ? '선택된 시간이 없습니다' 
                          : tempScheduleHours.map((h) => '$h시').join(', '),
                        style: TextStyle(
                          color: tempScheduleHours.isEmpty ? Colors.red : Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setDialogState(() {
                  tempScheduleHours.clear();
                });
              },
              child: const Text('모두 해제'),
            ),
            ElevatedButton(
              onPressed: tempScheduleHours.isEmpty ? null : () {
                setState(() {
                  _scheduleHours = tempScheduleHours;
                  if (_isAutoRefreshEnabled && _refreshMode == 'schedule') {
                    _startAutoRefresh();
                  }
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('사용자 정의 스케줄이 설정되었습니다: ${_formatScheduleHours()}'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
  }

  // 모바일용 자동갱신 설정 다이얼로그 (개선된 버전 - 창 유지)
  void _showMobileAutoRefreshDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.refresh, color: Colors.blue),
              SizedBox(width: 8),
              Text('자동갱신 설정'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('주기 갱신'),
                subtitle: Text('${_formatRefreshInterval(_refreshIntervalSeconds)} 간격'),
                trailing: Switch(
                  value: _isAutoRefreshEnabled && _refreshMode == 'interval',
                  onChanged: (value) {
                    setState(() {
                      _refreshMode = 'interval';
                      _isAutoRefreshEnabled = value;
                      if (value) {
                        _startAutoRefresh();
                      } else {
                        _stopAutoRefresh();
                      }
                    });
                    setDialogState(() {}); // 🔧 다이얼로그 UI 업데이트
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('스케줄 갱신'),
                subtitle: Text(_scheduleHours.isEmpty ? '시간 미설정' : _formatScheduleHours()),
                trailing: Switch(
                  value: _isAutoRefreshEnabled && _refreshMode == 'schedule',
                  onChanged: (value) {
                    setState(() {
                      _refreshMode = 'schedule';
                      _isAutoRefreshEnabled = value;
                      if (value) {
                        _startAutoRefresh();
                      } else {
                        _stopAutoRefresh();
                      }
                    });
                    setDialogState(() {}); // 🔧 다이얼로그 UI 업데이트
                  },
                ),
              ),
              
              // 🆕 갱신 주기 조정 (주기 모드일 때만 표시)
              if (_isAutoRefreshEnabled && _refreshMode == 'interval') ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.timer, color: Colors.green),
                  title: const Text('갱신 주기 조정'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('현재: ${_formatRefreshInterval(_refreshIntervalSeconds)}'),
                      Slider(
                        value: _refreshIntervalSeconds.toDouble(),
                        min: 30,
                        max: 1800, // 30분
                        divisions: 35,
                        label: _formatRefreshInterval(_refreshIntervalSeconds),
                        onChanged: (value) {
                          setState(() {
                            _refreshIntervalSeconds = value.toInt();
                            if (_isAutoRefreshEnabled) {
                              _startAutoRefresh(); // 새로운 주기로 재시작
                            }
                          });
                          setDialogState(() {}); // 🔧 다이얼로그 UI 업데이트
                        },
                      ),
                    ],
                  ),
                ),
              ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_calendar, color: Colors.orange),
              title: const Text('사용자 정의 스케줄'),
              subtitle: const Text('원하는 시간대 설정'),
              onTap: () async {
                Navigator.of(context).pop();
                // 다이얼로그 닫힘 완료 후 새 다이얼로그 열기
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  _showCustomScheduleDialog();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
      ), // 🔧 StatefulBuilder 닫는 괄호 추가
    );
  }

  // 🆕 기간 설정 다이얼로그
  void _showPeriodSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('기간 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('자동 적용'),
                subtitle: const Text('기간 선택시 자동으로 데이터 로드'),
                value: _periodSettings['autoApply'],
                onChanged: (value) => setDialogState(() => _periodSettings['autoApply'] = value ?? true),
              ),
              CheckboxListTile(
                title: const Text('주차 번호 표시'),
                subtitle: const Text('고급 모드에서 주차 정보 표시'),
                value: _periodSettings['showWeekNumbers'],
                onChanged: (value) => setDialogState(() => _periodSettings['showWeekNumbers'] = value ?? false),
              ),
              CheckboxListTile(
                title: const Text('분기 표시'),
                subtitle: const Text('분기별 선택 옵션 표시'),
                value: _periodSettings['showQuarters'],
                onChanged: (value) => setDialogState(() => _periodSettings['showQuarters'] = value ?? true),
              ),
              CheckboxListTile(
                title: const Text('사용자 정의 범위'),
                subtitle: const Text('직접 날짜 입력 허용'),
                value: _periodSettings['enableCustomRange'],
                onChanged: (value) => setDialogState(() => _periodSettings['enableCustomRange'] = value ?? true),
              ),
              CheckboxListTile(
                title: const Text('선택 기억하기'),
                subtitle: const Text('마지막 선택한 기간 저장'),
                value: _periodSettings['saveLastSelection'],
                onChanged: (value) => setDialogState(() => _periodSettings['saveLastSelection'] = value ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {}); // 메인 UI 업데이트
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('기간 설정이 저장되었습니다.')),
                );
              },
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
  }

  // 🆕 프리셋 저장 다이얼로그
  void _showSavePresetDialog() {
    String presetName = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기간 프리셋 저장'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '프리셋 이름',
                hintText: '예: 2024년 1분기',
              ),
              onChanged: (value) => presetName = value,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('저장될 기간:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('시작일: ${DateFormat('yyyy-MM-dd').format(_fromDate)}'),
                  Text('종료일: ${DateFormat('yyyy-MM-dd').format(_toDate)}'),
                  Text('총 ${_toDate.difference(_fromDate).inDays + 1}일'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (presetName.isNotEmpty) {
                setState(() {
                  _savedPeriodPresets.add({
                    'name': presetName,
                    'type': 'custom',
                    'fromDate': _fromDate.toIso8601String(),
                    'toDate': _toDate.toIso8601String(),
                    'createdAt': DateTime.now().toIso8601String(),
                  });
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('프리셋 "$presetName"이 저장되었습니다.')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // 🆕 프리셋 적용
  void _applyPeriodPreset(Map<String, dynamic> preset) {
    setState(() {
      switch (preset['type']) {
        case 'quarter':
          if (preset['value'] == 'current') {
            _setQuickPeriod('q${_getCurrentQuarter()}');
          } else if (preset['value'] == 'last') {
            final lastQuarter = _getCurrentQuarter() - 1;
            if (lastQuarter > 0) {
              _setQuickPeriod('q$lastQuarter');
            } else {
              _setQuickPeriod('q4'); // 작년 4분기
            }
          }
          break;
        case 'half':
          if (preset['value'] == 'first') {
            _setQuickPeriod('firstHalf');
          } else {
            _setQuickPeriod('secondHalf');
          }
          break;
        case 'months':
          final months = preset['value'] as int;
          final today = DateTime.now();
          _fromDate = DateTime(today.year, today.month - months + 1, 1);
          _toDate = today;
          break;
        case 'custom':
          _fromDate = DateTime.parse(preset['fromDate']);
          _toDate = DateTime.parse(preset['toDate']);
          break;
      }
    });
    
    if (_periodSettings['autoApply']!) {
      _loadSalesData();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('프리셋 "${preset['name']}"이 적용되었습니다.')),
    );
  }

  // 🆕 프리셋 삭제
  void _deletePeriodPreset(Map<String, dynamic> preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프리셋 삭제'),
        content: Text('프리셋 "${preset['name']}"을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _savedPeriodPresets.remove(preset);
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('프리셋 "${preset['name']}"이 삭제되었습니다.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🆕 현재 분기 구하기
  int _getCurrentQuarter() {
    final month = DateTime.now().month;
    return ((month - 1) ~/ 3) + 1;
  }

  // 🆕 Grid 고급 기능 메서드들
  
  // 컬럼 고정
  void _freezeColumns() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.blue),
            SizedBox(width: 8),
            Text('컬럼 고정'),
          ],
        ),
        content: const Text('🚧 컬럼 고정 기능은 향후 추가 예정입니다.\n현재는 즐겨찾기와 첫 번째 컬럼이 고정되어 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 그리드 옵션 다이얼로그
  void _showGridOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.grid_view, color: Colors.blue),
              SizedBox(width: 8),
              Text('그리드 옵션'),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '표시 설정',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('그리드 라인 표시'),
                    value: _showGridLines,
                    onChanged: (value) => setDialogState(() => _showGridLines = value),
                  ),
                  SwitchListTile(
                    title: const Text('컴팩트 모드'),
                    subtitle: const Text('더 많은 데이터를 화면에 표시'),
                    value: _isCompactMode,
                    onChanged: (value) => setDialogState(() => _isCompactMode = value),
                  ),
                  SwitchListTile(
                    title: const Text('애니메이션 효과'),
                    value: _enableAnimations,
                    onChanged: (value) => setDialogState(() => _enableAnimations = value),
                  ),
                  
                  const Divider(),
                  const Text(
                    '페이지 설정',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Text('페이지당 행 수: $_rowsPerPage'),
                  Slider(
                    value: _rowsPerPage.toDouble(),
                    min: 10,
                    max: 200,
                    divisions: 19,
                    label: '$_rowsPerPage행',
                    onChanged: (value) => setDialogState(() => _rowsPerPage = value.toInt()),
                  ),
                  
                  const Divider(),
                  const Text(
                    '성능 설정',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('가상화 활성화'),
                    subtitle: const Text('대량 데이터 성능 향상'),
                    value: _enableVirtualization,
                    onChanged: (value) => setDialogState(() => _enableVirtualization = value),
                  ),
                  
                  const Divider(),
                  const Text(
                    '고급 설정',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Text('캐시 크기: $_maxCachedItems개'),
                  Slider(
                    value: _maxCachedItems.toDouble(),
                    min: 100,
                    max: 5000,
                    divisions: 49,
                    label: '$_maxCachedItems개',
                    onChanged: (value) => setDialogState(() => _maxCachedItems = value.toInt()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {}); // UI 업데이트
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('그리드 옵션이 적용되었습니다.')),
                );
              },
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
  }

  // 보이는 데이터 내보내기
  void _exportVisibleData() {
    final baseData = _useNumericFilters ? _filteredData : _summaryData;
    final displayData = _showBookmarkedOnly 
        ? baseData.where((item) {
            final customName = item['CUSTOM_NAME']?.toString() ?? '';
            return _bookmarkedCustomers.contains(customName);
          }).toList()
        : baseData;

    // CSV 형식으로 내보내기
    final visibleColumns = _visibleColumns.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    final headers = ['즐겨찾기', ...visibleColumns.map(_getColumnDisplayName)].join(',');
    final rows = displayData.map((data) {
      final customName = data['CUSTOM_NAME']?.toString() ?? '';
      final isBookmarked = _bookmarkedCustomers.contains(customName) ? '★' : '';
      final rowData = [isBookmarked, ...visibleColumns.map((col) => '"${_formatCellValue(data[col], col)}"')];
      return rowData.join(',');
    }).join('\n');

    final csvContent = '$headers\n$rows';
    Clipboard.setData(ClipboardData(text: csvContent));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_formatNumber(displayData.length)}건의 표시된 데이터가 클립보드에 복사되었습니다.'),
        action: SnackBarAction(
          label: '미리보기',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('내보낸 데이터 미리보기'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: SingleChildScrollView(
                    child: Text(
                      csvContent.length > 2000 
                        ? '${csvContent.substring(0, 2000)}...\n\n(총 ${_formatNumber(csvContent.length)}자)'
                        : csvContent,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 보이는 컬럼의 인덱스 가져오기
  int? _getVisibleColumnIndex(String columnKey) {
    final visibleKeys = _visibleColumns.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    final index = visibleKeys.indexOf(columnKey);
    return index >= 0 ? index + 1 : null; // +1은 즐겨찾기 컬럼 때문
  }

  // 숫자형 컬럼인지 확인
  bool _isNumericColumn(String columnKey) {
    const numericColumns = {
      'SALE_Q', 'SUM_SALE_AMT_WON', 'SALE_P', 'EXCHG_RATE_O', 
      'SALE_LOC_AMT_F', 'SALE_COST_AMT'
    };
    return numericColumns.contains(columnKey);
  }

  // 고급 셀 빌더
  Widget _buildAdvancedCell(dynamic value, String columnKey) {
    if (value == null) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }

    // 숫자형 컬럼은 특별 처리
    if (_isNumericColumn(columnKey)) {
      final numValue = value is num ? value.toDouble() : 0.0;
      
      // 색상 코딩
      Color? textColor;
      if (columnKey == 'SUM_SALE_AMT_WON') {
        if (numValue > 1000000) {
          textColor = Colors.green[700];
        } else if (numValue > 100000) textColor = Colors.blue[700];
        else if (numValue > 0) textColor = Colors.orange[700];
        else textColor = Colors.red[700];
      }

      return SelectableText(
        _formatCellValue(value, columnKey),
        style: TextStyle(
          color: textColor,
          fontWeight: _isNumericColumn(columnKey) ? FontWeight.w500 : null,
          fontFamily: _isNumericColumn(columnKey) ? 'monospace' : null,
        ),
      );
    }

    // 일반 텍스트
    return SelectableText(
      _formatCellValue(value, columnKey),
      style: const TextStyle(fontSize: 13),
    );
  }

  // Raw Data 페이지네이션
  Widget _buildRawDataPagination(int totalItems) {
    final totalPages = (totalItems / _rowsPerPage).ceil();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '총 $totalItems건 중 ${_rawDataCurrentPage * _rowsPerPage + 1}-${((_rawDataCurrentPage + 1) * _rowsPerPage).clamp(0, totalItems)}건',
            style: const TextStyle(fontSize: 14),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _rawDataCurrentPage > 0 ? () {
                  setState(() {
                    _rawDataCurrentPage--;
                  });
                } : null,
                icon: const Icon(Icons.first_page),
                tooltip: '첫 페이지',
              ),
              IconButton(
                onPressed: _rawDataCurrentPage > 0 ? () {
                  setState(() {
                    _rawDataCurrentPage--;
                  });
                } : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: '이전 페이지',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  '${_rawDataCurrentPage + 1} / $totalPages',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              IconButton(
                onPressed: _rawDataCurrentPage < totalPages - 1 ? () {
                  setState(() {
                    _rawDataCurrentPage++;
                  });
                } : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: '다음 페이지',
              ),
              IconButton(
                onPressed: _rawDataCurrentPage < totalPages - 1 ? () {
                  setState(() {
                    _rawDataCurrentPage = totalPages - 1;
                  });
                } : null,
                icon: const Icon(Icons.last_page),
                tooltip: '마지막 페이지',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🆕 행 선택 관련 메서드들
  void _toggleSelectAll(bool? selected) {
    setState(() {
      _selectAll = selected ?? false;
      if (_selectAll) {
        _selectedRows = Set.from(List.generate(_filteredData.length, (index) => index));
      } else {
        _selectedRows.clear();
      }
    });
  }

  void _toggleRowSelection(int index) {
    setState(() {
      if (_selectedRows.contains(index)) {
        _selectedRows.remove(index);
      } else {
        _selectedRows.add(index);
      }
      _selectAll = _selectedRows.length == _filteredData.length;
    });
  }

  // 🆕 선택된 행에 대한 일괄 작업
  void _showBulkActionDialog() {
    if (_selectedRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택된 행이 없습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('일괄 작업 (${_selectedRows.length}개 선택)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('즐겨찾기 추가'),
              onTap: () {
                _bulkAddToFavorites();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('즐겨찾기 제거'),
              onTap: () {
                _bulkRemoveFromFavorites();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('선택된 데이터 내보내기'),
              onTap: () {
                _exportSelectedRows();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('선택 해제'),
              onTap: () {
                setState(() {
                  _selectedRows.clear();
                  _selectAll = false;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  void _bulkAddToFavorites() {
    setState(() {
      for (int index in _selectedRows) {
        if (index < _filteredData.length) {
          final customName = _filteredData[index]['CUSTOM_NAME']?.toString() ?? '';
          if (customName.isNotEmpty) {
            _bookmarkedCustomers.add(customName);
          }
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedRows.length}개 거래처를 즐겨찾기에 추가했습니다.')),
    );
  }

  void _bulkRemoveFromFavorites() {
    setState(() {
      for (int index in _selectedRows) {
        if (index < _filteredData.length) {
          final customName = _filteredData[index]['CUSTOM_NAME']?.toString() ?? '';
          _bookmarkedCustomers.remove(customName);
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedRows.length}개 거래처를 즐겨찾기에서 제거했습니다.')),
    );
  }

  void _exportSelectedRows() {
    final selectedData = _selectedRows
        .where((index) => index < _filteredData.length)
        .map((index) => _filteredData[index])
        .toList();
    
    // CSV 형식으로 내보내기
    final headers = _visibleColumns.entries
        .where((entry) => entry.value)
        .map((entry) => _getColumnDisplayName(entry.key))
        .join(',');
    
    final rows = selectedData.map((data) {
      return _visibleColumns.entries
          .where((entry) => entry.value)
          .map((entry) => '"${_formatCellValue(data[entry.key], entry.key)}"')
          .join(',');
    }).join('\n');
    
    final csvContent = '$headers\n$rows';
    
    // 클립보드에 복사
    Clipboard.setData(ClipboardData(text: csvContent));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('선택된 ${selectedData.length}건의 데이터가 클립보드에 복사되었습니다.')),
    );
  }

  // 🆕 Help 다이얼로그
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue[700], size: 28),
            const SizedBox(width: 12),
            const Text(
              '영업매출분석 사용법',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 500,
          child: DefaultTabController(
            length: 5,
            child: Column(
              children: [
                TabBar(
                  labelColor: Colors.blue[700],
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue[700],
                  tabs: const [
                    Tab(text: '기본 사용법'),
                    Tab(text: '고급 기능'),
                    Tab(text: '단축키'),
                    Tab(text: '팁 & 트릭'),
                    Tab(text: '문제해결'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBasicHelpContent(),
                      _buildAdvancedHelpContent(),
                      _buildShortcutsHelpContent(),
                      _buildTipsHelpContent(),
                      _buildTroubleshootingHelpContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showQuickTourDialog();
            },
            icon: const Icon(Icons.tour, size: 16),
            label: const Text('퀵 투어'),
          ),
        ],
      ),
    );
  }

  // 🆕 기본 사용법 도움말
  Widget _buildBasicHelpContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpSection(
            '📅 기간 설정',
            '상단의 "검색조건 설정"을 클릭하여 기간을 선택하세요.',
            [
              '• 간단 모드: 빠른 기간 버튼 사용',
              '• 고급 모드: 연도, 분기, 월별 선택',
              '• 달력 모드: 직접 날짜 선택',
              '• 프리셋: 자주 사용하는 기간 저장',
            ],
          ),
          _buildHelpSection(
            '🔍 데이터 조회',
            '조회 버튼이 기간 설정 헤더에 있습니다.',
            [
              '• 자동 적용: 설정에서 활성화시 날짜 선택시 자동 조회',
              '• 수동 조회: 헤더의 파란색 "조회" 버튼 클릭',
              '• 단축키: F5 또는 Ctrl+R로 새로고침',
            ],
          ),
          _buildHelpSection(
            '📊 탭 구성',
            '5개 탭으로 다양한 관점에서 데이터를 확인하세요.',
            [
              '• 요약: 전체 매출 현황과 KPI 카드',
              '• 데이터: 기본 테이블 뷰와 필터링',
              '• 데이터(상세): 고급 수치 필터와 Raw 데이터',
              '• 차트: 6개 분석 차트 (매출, 트렌드, 지역 등)',
              '• 분석: 상위 성과자 및 통계 분석',
            ],
          ),
          _buildHelpSection(
            '💰 금액 단위',
            '우상단에서 표시 단위를 변경할 수 있습니다.',
            [
              '• 원: 실제 금액 (기본)',
              '• 천원: 큰 금액을 간단히',
              '• 백만원: 월 매출 등에 적합',
              '• 억원: 연간 매출 등에 적합',
            ],
          ),
        ],
      ),
    );
  }

  // 🆕 고급 기능 도움말
  Widget _buildAdvancedHelpContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpSection(
            '🔧 자동 갱신',
            '실시간으로 데이터를 업데이트할 수 있습니다.',
            [
              '• 자동갱신 아이콘을 클릭하여 활성화',
              '• 갱신 주기: 30초 ~ 30분까지 선택',
              '• 상태 표시: 헤더에 자동갱신 상태 표시',
              '• 수동 새로고침: 🔄 아이콘 클릭',
            ],
          ),
          _buildHelpSection(
            '🎯 고급 수치 필터',
            '데이터(상세) 탭에서 정밀한 조건 검색이 가능합니다.',
            [
              '• 매출액 범위: 슬라이더로 최소/최대 설정',
              '• 수량 범위: 거래량 기준 필터링',
              '• 단가 범위: 제품 단가 기준 필터링',
              '• 빠른 프리셋: 상위 10%, 25%, 평균 이상 등',
            ],
          ),
          _buildHelpSection(
            '⭐ 즐겨찾기 시스템',
            '자주 확인하는 거래처를 북마크하세요.',
            [
              '• 테이블의 ★ 아이콘 클릭으로 추가/제거',
              '• 즐겨찾기 보기: 필터에서 ⭐ 버튼 클릭',
              '• 즐겨찾기만 표시하여 빠른 모니터링',
            ],
          ),
          _buildHelpSection(
            '📤 내보내기 옵션',
            '다양한 형식으로 데이터를 내보낼 수 있습니다.',
            [
              '• Excel: 📊 아이콘 (Ctrl+E)',
              '• CSV: 📄 아이콘으로 클립보드 복사',
              '• JSON: 💻 아이콘 (Ctrl+J)',
              '• PDF: 📋 아이콘으로 리포트 생성',
            ],
          ),
          _buildHelpSection(
            '🔖 검색 저장',
            '자주 사용하는 검색 조건을 저장하세요.',
            [
              '• 📖 아이콘으로 현재 검색 저장',
              '• 📚 아이콘으로 저장된 검색 불러오기',
              '• 검색명과 저장 시간 표시',
              '• 원클릭으로 빠른 적용',
            ],
          ),
        ],
      ),
    );
  }

  // 🆕 단축키 도움말
  Widget _buildShortcutsHelpContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⌨️ 키보드 단축키',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildShortcutTable([
            ['Ctrl + R', '데이터 새로고침'],
            ['Ctrl + F', '검색창 포커스'],
            ['Ctrl + E', 'Excel 내보내기'],
            ['Ctrl + J', 'JSON 내보내기'],
            ['F5', '새로고침'],
            ['Esc', '필터 초기화'],
            ['F11', '전체화면 토글'],
            ['Ctrl + 1~5', '탭 전환 (요약~분석)'],
          ]),
          const SizedBox(height: 20),
          const Text(
            '💡 마우스 단축키',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildShortcutTable([
            ['더블클릭', '컬럼 헤더에서 자동 크기 조정'],
            ['우클릭', '컨텍스트 메뉴 (향후 추가)'],
            ['Shift+클릭', '다중 선택 (향후 추가)'],
            ['Ctrl+클릭', '개별 선택/해제 (향후 추가)'],
          ]),
        ],
      ),
    );
  }

  // 🆕 팁 & 트릭 도움말
  Widget _buildTipsHelpContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpSection(
            '🚀 성능 최적화 팁',
            '대용량 데이터를 효율적으로 처리하세요.',
            [
              '• 기간을 짧게 설정하여 조회 속도 향상',
              '• 불필요한 컬럼 숨기기로 렌더링 속도 개선',
              '• 자동갱신 주기를 적절히 설정 (너무 짧으면 성능 저하)',
              '• 고급 필터를 활용한 데이터 범위 제한',
            ],
          ),
          _buildHelpSection(
            '📈 분석 효율성 팁',
            '데이터 분석을 더 효과적으로 수행하세요.',
            [
              '• 차트 탭에서 6가지 관점으로 분석',
              '• 그룹핑 기능으로 국가별/분류별 집계',
              '• 즐겨찾기로 핵심 거래처 모니터링',
              '• 정렬 기능으로 상위/하위 성과 파악',
            ],
          ),
          _buildHelpSection(
            '💾 데이터 관리 팁',
            '검색 조건과 설정을 효율적으로 관리하세요.',
            [
              '• 자주 사용하는 기간을 프리셋으로 저장',
              '• 복잡한 검색 조건을 북마크로 저장',
              '• 대시보드 설정에서 개인화 옵션 조정',
              '• 내보내기 기능으로 정기 리포트 생성',
            ],
          ),
          _buildHelpSection(
            '🎨 UI/UX 활용 팁',
            '인터페이스를 더 효과적으로 사용하세요.',
            [
              '• 컴팩트 모드로 더 많은 데이터 표시',
              '• 금액 단위 변경으로 가독성 향상',
              '• 확장 가능한 섹션으로 화면 공간 절약',
              '• 탭별 특화 기능 활용 (요약→차트→분석 순서 추천)',
            ],
          ),
        ],
      ),
    );
  }

  // 🆕 문제해결 도움말
  Widget _buildTroubleshootingHelpContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpSection(
            '❗ 일반적인 문제',
            '자주 발생하는 문제와 해결 방법입니다.',
            [
              '• 데이터가 안 보임: 기간 설정 확인 → 조회 버튼 클릭',
              '• 로딩이 오래 걸림: 기간을 짧게 설정하거나 필터 활용',
              '• 화면이 깨짐: 브라우저 새로고침 (F5)',
              '• 내보내기 안됨: 팝업 차단 해제 확인',
            ],
          ),
          _buildHelpSection(
            '🔧 성능 문제',
            '느려지거나 멈출 때 해결 방법입니다.',
            [
              '• 자동갱신 중지: 🔄 아이콘에서 일시정지',
              '• 컬럼 수 줄이기: 테이블 설정에서 불필요한 컬럼 숨김',
              '• 페이지 크기 조정: 한 번에 표시할 행 수 줄이기',
              '• 캐시 초기화: 대시보드 설정에서 캐시 크기 조정',
            ],
          ),
          _buildHelpSection(
            '📱 모바일 사용',
            '모바일 환경에서의 최적화 방법입니다.',
            [
              '• 가로 모드 권장: 테이블 뷰에서 더 많은 정보 표시',
              '• 간단 모드 사용: 기간 선택을 간단하게',
              '• 요약 탭 활용: 모바일에서는 KPI 카드가 더 적합',
              '• 확대/축소: 브라우저 줌 기능 활용',
            ],
          ),
          _buildHelpSection(
            '🚧 미구현 기능',
            '현재 개발중이거나 미구현된 기능들입니다.',
            [
              '• 🚧 Excel/PDF 실제 파일 다운로드',
              '• 🚧 달력 위젯 (날짜 선택기)',
              '• 🚧 다크모드 UI 적용',
              '• 🚧 성장률 실제 계산',
              '• 🚧 환율 분석 고도화',
              '• 🚧 대시보드 설정 완전 반영',
            ],
          ),
          _buildHelpSection(
            '🆘 문의 및 지원',
            '추가 도움이 필요할 때 연락처입니다.',
            [
              '• 기술 지원: IT 헬프데스크',
              '• 기능 요청: 개발팀 문의',
              '• 사용법 교육: 사용자 교육 담당자',
              '• 버그 신고: 시스템 관리자',
            ],
          ),
        ],
      ),
    );
  }

  // 🆕 도움말 섹션 빌더
  Widget _buildHelpSection(String title, String description, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Text(item, style: const TextStyle(fontSize: 13)),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  // 🆕 단축키 테이블
  Widget _buildShortcutTable(List<List<String>> shortcuts) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(120),
        1: FlexColumnWidth(),
      },
      children: shortcuts.map((shortcut) => TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Text(
                shortcut[0],
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(shortcut[1], style: const TextStyle(fontSize: 13)),
          ),
        ],
      )).toList(),
    );
  }

  // 🆕 퀵 투어 다이얼로그
  void _showQuickTourDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.tour, color: Colors.green),
            SizedBox(width: 8),
            Text('퀵 투어'),
          ],
        ),
        content: const SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎯 5단계로 빠르게 시작하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('1️⃣ 상단 "검색조건 설정" 클릭'),
              Text('2️⃣ 원하는 기간 선택 (오늘, 이번달 등)'),
              Text('3️⃣ 파란색 "조회" 버튼 클릭'),
              Text('4️⃣ 5개 탭에서 데이터 확인'),
              Text('5️⃣ 필요시 ⭐ 즐겨찾기 추가'),
              SizedBox(height: 16),
              Text(
                '💡 첫 사용 추천 순서: 요약 → 차트 → 데이터',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 자동으로 기간 설정 섹션 확장
              setState(() {
                _isPeriodSelectorExpanded = true;
              });
            },
            child: const Text('시작하기'),
          ),
        ],
      ),
    );
  }

  // ===== 🚀 강화된 차트 기능들 =====

  // 차트 제어 패널
  Widget _buildChartControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: Colors.blue[700], size: 16),  // 아이콘 크기 축소
          const SizedBox(width: 12),
          Text(
            '고급 차트 분석',
            style: TextStyle(
              fontSize: 14,  // 메인메뉴보다 작게
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          const Spacer(),
          
          // 차트 옵션 버튼들
          ElevatedButton.icon(
            onPressed: _showChartOptionsDialog,
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('차트 설정'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[100],
              foregroundColor: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _exportAllCharts,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('차트 내보내기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[100],
              foregroundColor: Colors.green[700],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showChartHelpDialog,
            icon: const Icon(Icons.help_outline, size: 16),
            label: const Text('차트 가이드'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[100],
              foregroundColor: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 고급 매출 차트 (다양한 관점) - 반응형 + 확대 기능
  Widget _buildAdvancedSalesCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 반응형 설계
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        
        final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 2);
        final childAspectRatio = isMobile ? 1.0 : 1.2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildClickableChart(_buildSalesVolumeChart(), '매출 수량 분석'),
            _buildClickableChart(_buildSalesAmountChart(), '매출 금액 분석'), 
            _buildClickableChart(_buildTopCustomersChart(), '상위 거래처 분석'),
            _buildClickableChart(_buildBottomCustomersChart(), '하위 거래처 분석'),
          ],
        );
      },
    );
  }

  // 🚀 클릭 가능한 차트 래퍼 (더블클릭으로 전체 화면 확대)
  Widget _buildClickableChart(Widget chart, String title) {
    return GestureDetector(
      onDoubleTap: () => _showFullScreenChart(chart, title),
      child: Stack(
        children: [
          chart,
          // 🔍 확대 아이콘 오버레이
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.zoom_out_map, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '더블클릭',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 전체 화면 차트 팝업
  void _showFullScreenChart(Widget chart, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.white,
            elevation: 1,
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.grey),
                tooltip: '닫기',
              ),
            ],
          ),
          body: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 📊 전체 화면 차트 영역
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: chart,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 🎮 차트 제어 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: 차트 이미지 저장 기능
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('차트 저장 기능 구현 예정')),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('이미지 저장'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[100],
                        foregroundColor: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: 데이터 내보내기 기능
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('데이터 내보내기 기능 구현 예정')),
                        );
                      },
                      icon: const Icon(Icons.table_chart, size: 16),
                      label: const Text('데이터 내보내기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[100],
                        foregroundColor: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🆕 고급 트렌드 차트
  Widget _buildAdvancedTrendCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        
        final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 2);
        final childAspectRatio = isMobile ? 1.0 : 1.2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildClickableChart(_buildMonthlyTrendAdvanced(), '월별 트렌드 고급 분석'),
            _buildClickableChart(_buildWeeklyTrendChart(), '주간 트렌드 분석'),
            _buildClickableChart(_buildSeasonalityChart(), '계절성 분석'),
            _buildClickableChart(_buildGrowthRateChart(), '성장률 분석'),
          ],
        );
      },
    );
  }

  // 🆕 고급 지역 차트
  Widget _buildAdvancedRegionCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 1 : 2;
        final childAspectRatio = isMobile ? 1.0 : 1.2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildClickableChart(_buildContinentAnalysisChart(), '대륙별 분석'),
            _buildClickableChart(_buildCountryRankingChart(), '국가 순위 분석'),
            _buildClickableChart(_buildRegionalGrowthChart(), '지역 성장 분석'),
            _buildClickableChart(_buildExchangeRateImpactChart(), '환율 영향 분석'),
          ],
        );
      },
    );
  }

  // 🆕 고급 거래처 차트
  Widget _buildAdvancedCustomerCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 1 : 2;
        final childAspectRatio = isMobile ? 1.0 : 1.2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildClickableChart(_buildCustomerSegmentationChart(), '거래처 세분화 분석'),
            _buildClickableChart(_buildCustomerLoyaltyChart(), '거래처 충성도 분석'),
            _buildClickableChart(_buildCustomerLifetimeValueChart(), '거래처 생애가치 분석'),
            _buildClickableChart(_buildNewVsReturningChart(), '신규 vs 기존 거래처'),
          ],
        );
      },
    );
  }

  // 🆕 품목 분석 차트
  Widget _buildProductAnalysisCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 1 : 2;
        final childAspectRatio = isMobile ? 1.0 : 1.2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildClickableChart(_buildProductPerformanceChart(), '품목 성과 분석'),
            _buildClickableChart(_buildProductCategoryChart(), '품목 카테고리 분석'),
            _buildClickableChart(_buildProductTrendChart(), '품목 트렌드 분석'),
            _buildClickableChart(_buildInventoryAnalysisChart(), '재고 분석'),
          ],
        );
      },
    );
  }

  // 🆕 수익성 분석 차트
  Widget _buildProfitabilityCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 1 : 2;
        final childAspectRatio = isMobile ? 1.0 : 1.2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildClickableChart(_buildProfitMarginChart(), '수익률 분석'),
            _buildClickableChart(_buildCostAnalysisChart(), '비용 분석'),
            _buildClickableChart(_buildROIAnalysisChart(), 'ROI 분석'),
            _buildClickableChart(_buildProfitabilityTrendChart(), '수익성 트렌드'),
          ],
        );
      },
    );
  }

  // 🆕 고급 비교 차트
  Widget _buildAdvancedComparisonCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 1 : 2;
        final childAspectRatio = isMobile ? 1.0 : 1.2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildClickableChart(_buildYearOverYearChart(), '년도별 비교'),
            _buildClickableChart(_buildMonthOverMonthChart(), '월별 비교'),
            _buildClickableChart(_buildBenchmarkChart(), '벤치마크 분석'),
            _buildClickableChart(_buildCompetitiveAnalysisChart(), '경쟁 분석'),
          ],
        );
      },
    );
  }

  // 🆕 고급 분포 차트
  Widget _buildAdvancedDistributionCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 1 : 2;
        final childAspectRatio = isMobile ? 1.0 : 1.2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildClickableChart(_buildSalesDistributionChart(), '매출 분포'),
            _buildClickableChart(_buildPriceDistributionChart(), '가격 분포'),
            _buildClickableChart(_buildVolumeDistributionChart(), '수량 분포'),
            _buildClickableChart(_buildCustomerDistributionChart(), '거래처 분포'),
          ],
        );
      },
    );
  }

  // 🆕 성과 분석 차트
  Widget _buildPerformanceCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 1 : 2;
        final childAspectRatio = isMobile ? 1.0 : 1.2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildClickableChart(_buildKPIPerformanceChart(), 'KPI 성과'),
            _buildClickableChart(_buildTargetAchievementChart(), '목표 달성률'),
            _buildClickableChart(_buildEfficiencyChart(), '효율성 분석'),
            _buildClickableChart(_buildQualityMetricsChart(), '품질 지표'),
          ],
        );
      },
    );
  }

  // 🆕 예측 분석 차트
  Widget _buildPredictiveCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 1 : 2;
        final childAspectRatio = isMobile ? 1.0 : 1.2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildClickableChart(_buildSalesForecastChart(), '매출 예측'),
            _buildClickableChart(_buildTrendPredictionChart(), '트렌드 예측'),
            _buildClickableChart(_buildSeasonalForecastChart(), '계절성 예측'),
            _buildClickableChart(_buildRiskAnalysisChart(), '리스크 분석'),
          ],
        );
      },
    );
  }

  // 통합 대시보드
  Widget _buildIntegratedDashboard() {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 통합 대시보드',
            style: TextStyle(
              fontSize: 14,  // 메인메뉴보다 작게
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 8,
            child: LayoutBuilder(
              builder: (context, constraints) => Container(
                padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
                height: constraints.maxWidth < 600 ? 350 : 400,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dashboard, color: Colors.blue[700], size: constraints.maxWidth < 600 ? 14 : 16),  // 아이콘 크기 축소
                        const SizedBox(width: 8),
                        Text(
                          '실시간 종합 현황',
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 600 ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _buildComprehensiveDashboard(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 차트 보조 메서드들 =====

  void _showChartOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차트 설정'),
        content: const Text('🚧 차트 설정 기능은 개발 중입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _exportAllCharts() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.construction, color: Colors.orange),
            SizedBox(width: 8),
            Text('🚧 차트 내보내기 기능은 개발 중입니다.'),
          ],
        ),
      ),
    );
  }

  void _showChartHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue),
            SizedBox(width: 8),
            Text('차트 분석 가이드'),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 차트 종류별 활용법',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildChartGuideItem('📊 매출 분석', '전체 매출 현황과 고객별 성과를 한눈에 파악'),
                _buildChartGuideItem('📈 트렌드 분석', '시간별 변화 추이와 계절성 패턴 분석'),
                _buildChartGuideItem('🌍 지역 분석', '국가/대륙별 시장 성과와 환율 영향 분석'),
                _buildChartGuideItem('🏢 거래처 분석', '고객 세분화와 충성도, 생애가치 분석'),
                _buildChartGuideItem('📦 품목 분석', '제품별 성과와 카테고리별 트렌드'),
                _buildChartGuideItem('💰 수익성 분석', '마진율과 비용 구조, ROI 분석'),
                _buildChartGuideItem('⚖️ 비교 분석', '전년 대비, 전월 대비 성과 비교'),
                _buildChartGuideItem('📏 분포 분석', '매출과 고객 분포의 통계적 특성'),
                _buildChartGuideItem('🎯 성과 분석', 'KPI 달성률과 효율성 지표'),
                _buildChartGuideItem('🔮 예측 분석', '미래 매출 예측과 리스크 분석'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildChartGuideItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ===== 🚀 개별 차트 구현 메서드들 =====

  // 매출 수량 차트
  Widget _buildSalesVolumeChart() {
    final totalVolume = _summaryData.fold<int>(0, (sum, item) => 
      sum + ((item['SALE_Q'] as num?)?.toInt() ?? 0));
    
    return _buildChartCard(
      '📊 총 매출 수량',
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 24, color: Colors.blue[700]),  // 아이콘 크기 축소
          const SizedBox(height: 16),
          Text(
            _formatNumber(totalVolume),
            style: TextStyle(
              fontSize: 14,  // 메인메뉴보다 작게
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '단위',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // 매출 금액 차트
  Widget _buildSalesAmountChart() {
    final totalAmount = _summaryData.fold<double>(0, (sum, item) => 
      sum + ((item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0));
    
    return _buildChartCard(
      '💰 총 매출 금액',
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.attach_money, size: 24, color: Colors.green[700]),  // 아이콘 크기 축소
          const SizedBox(height: 16),
          Text(
            _formatAmountWithUnit(totalAmount),
            style: TextStyle(
              fontSize: 14,  // 메인메뉴보다 작게
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _amountDisplayUnit,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // 상위 고객 차트
  Widget _buildTopCustomersChart() {
    final topCustomers = _summaryData
      .where((item) => (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0) > 0)
      .toList()
      ..sort((a, b) => (b['SUM_SALE_AMT_WON']?.toDouble() ?? 0)
          .compareTo(a['SUM_SALE_AMT_WON']?.toDouble() ?? 0));
    
    final top5 = topCustomers.take(5).toList();
    
    return _buildChartCard(
      '🏆 상위 5개 고객',
      ListView.builder(
        shrinkWrap: true,
        itemCount: top5.length,
        itemBuilder: (context, index) {
          final customer = top5[index];
          final amount = customer['SUM_SALE_AMT_WON']?.toDouble() ?? 0;
          final maxAmount = top5.isNotEmpty ? (top5[0]['SUM_SALE_AMT_WON']?.toDouble() ?? 1) : 1;
          final percentage = (amount / maxAmount * 100).clamp(5, 100);
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: _getCustomerRankColor(index),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        customer['CUSTOM_NAME']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatAmountWithUnit(amount),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(_getCustomerRankColor(index)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 하위 고객 차트 (개선 대상)
  Widget _buildBottomCustomersChart() {
    final bottomCustomers = _summaryData
      .where((item) => (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0) > 0)
      .toList()
      ..sort((a, b) => (a['SUM_SALE_AMT_WON']?.toDouble() ?? 0)
          .compareTo(b['SUM_SALE_AMT_WON']?.toDouble() ?? 0));
    
    final bottom5 = bottomCustomers.take(5).toList();
    
    return _buildChartCard(
      '📉 개선 대상 고객',
      bottom5.isEmpty 
        ? const Center(child: Text('개선 대상 고객이 없습니다.'))
        : Column(
            children: [
              Text(
                '매출액이 낮은 고객들',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: bottom5.length,
                  itemBuilder: (context, index) {
                    final customer = bottom5[index];
                    final amount = customer['SUM_SALE_AMT_WON']?.toDouble() ?? 0;
                    
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.trending_up,
                        color: Colors.orange[600],
                        size: 16,
                      ),
                      title: Text(
                        customer['CUSTOM_NAME']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(
                        _formatAmountWithUnit(amount),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange[600],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  // 통합 대시보드 (핵심 지표)
  Widget _buildComprehensiveDashboard() {
    final totalSales = _summaryData.fold<double>(0, (sum, item) => 
      sum + ((item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0));
    final totalQuantity = _summaryData.fold<int>(0, (sum, item) => 
      sum + ((item['SALE_Q'] as num?)?.toInt() ?? 0));
    final customerCount = _summaryData.length;
    final avgOrderValue = customerCount > 0 ? (totalSales / customerCount) : 0.0;

    return Column(
      children: [
        // KPI 카드들
        Row(
          children: [
            Expanded(child: _buildKPICard('총 매출', _formatAmountWithUnit(totalSales), _amountDisplayUnit, Icons.monetization_on, Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('총 수량', _formatNumber(totalQuantity), '개', Icons.inventory, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('거래처 수', _formatNumber(customerCount), '개', Icons.business, Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard('평균 거래액', _formatAmountWithUnit(avgOrderValue), _amountDisplayUnit, Icons.analytics, Colors.purple)),
          ],
        ),
        const SizedBox(height: 20),
        
        // 🆕 반응형 미니 차트 영역 (오버플로우 방지)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              
              if (isMobile) {
                // 모바일에서는 세로로 배치
                return Column(
                  children: [
                    Expanded(
                      child: _buildMiniChart('국가별 분포', _buildCountryMiniChart()),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _buildMiniChart('거래처 분류', _buildTypeMiniChart()),
                    ),
                  ],
                );
              } else {
                // 데스크톱에서는 가로로 배치
                return Row(
                  children: [
                    Expanded(
                      child: _buildMiniChart('국가별 분포', _buildCountryMiniChart()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMiniChart('거래처 분류', _buildTypeMiniChart()),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ],
    );
  }

  // 🆕 반응형 KPI 카드 (모바일 최적화)
  Widget _buildKPICard(String title, String value, String unit, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        
        return Container(
          padding: EdgeInsets.all(isMobile ? 6 : 8),  // 카드 크기 축소
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isMobile ? 6 : 8),  // 모서리 반경도 축소
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: isMobile ? 16 : 20),
              SizedBox(height: isMobile ? 4 : 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 9 : 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,  // 메인메뉴보다 작게
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: isMobile ? 7 : 9,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 차트 카드 공통 빌더
  Widget _buildChartCard(String title, Widget content) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  // 색상 헬퍼
  Color _getCustomerRankColor(int index) {
    const colors = [
      Colors.amber,     // 1등 - 금색
      Colors.grey,      // 2등 - 은색  
      Colors.brown,     // 3등 - 동색
      Colors.blue,      // 4등
      Colors.green,     // 5등
    ];
    return colors[index % colors.length];
  }

  // 🚀 새로운 차트 템플릿 적용 - 국가별 매출 파이차트
  Widget _buildCountryMiniChart() {
    final countryStats = <String, double>{};
    for (var item in _summaryData) {
      final country = item['NATION_NAME']?.toString() ?? '기타';
      countryStats[country] = (countryStats[country] ?? 0) + ((item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0);
    }
    
    // 상위 5개 국가만 표시, 나머지는 기타로 합계
    final sortedCountries = countryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final chartData = <Map<String, dynamic>>[];
    
    if (sortedCountries.length > 5) {
      chartData.addAll(sortedCountries.take(4).map((entry) => {
        'name': entry.key,
        'value': entry.value,
      }));
      
      final othersSum = sortedCountries.skip(4).fold<double>(0, (sum, entry) => sum + entry.value);
      chartData.add({'name': '기타', 'value': othersSum});
    } else {
      chartData.addAll(sortedCountries.map((entry) => {
        'name': entry.key,
        'value': entry.value,
      }));
    }
    
    if (chartData.isEmpty) {
      return const Center(
        child: Text(
          '국가별 데이터 없음',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return ChartTemplates.buildPieChart(
      data: chartData,
      title: '',  // 제목은 상위에서 표시
      radius: 60,
      showLegend: false,
      showDataLabels: true,
    );
  }

  // 🚀 새로운 차트 템플릿 적용 - 거래처 분류 도넛차트
  Widget _buildTypeMiniChart() {
    final typeStats = <String, int>{};
    for (var item in _summaryData) {
      final type = item['거래처분류']?.toString() ?? '기타';
      typeStats[type] = (typeStats[type] ?? 0) + 1;
    }

    final chartData = typeStats.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value.toDouble(),
    }).toList();
    
    if (chartData.isEmpty) {
      return const Center(
        child: Text(
          '거래처 분류 데이터 없음',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return ChartTemplates.buildDonutChart(
      data: chartData,
      title: '',  // 제목은 상위에서 표시
      centerText: '총계',
      showDataLabels: true,
    );
  }

  Widget _buildMiniChart(String title, Widget chart) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        
        return Container(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isMobile ? 4 : 8),
              Expanded(child: chart),
            ],
          ),
        );
      },
    );
  }

  // ===== 실제 데이터 기반 차트들 =====
  
  // 🚀 월별 트렌드 고급 분석 (실제 구현)
  Widget _buildMonthlyTrendAdvanced() {
    final monthlyData = <String, Map<String, dynamic>>{};
    
    for (var item in _summaryData) {
      final updateTime = item['UPDATE_DTM']?.toString();
      if (updateTime != null) {
        try {
          final date = DateTime.parse(updateTime);
          final monthKey = DateFormat('yyyy-MM').format(date);
          
          if (!monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey] = {'amount': 0.0, 'count': 0, 'quantity': 0.0};
          }
          
          monthlyData[monthKey]!['amount'] = (monthlyData[monthKey]!['amount'] as double) + 
            (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
          monthlyData[monthKey]!['count'] = (monthlyData[monthKey]!['count'] as int) + 1;
          monthlyData[monthKey]!['quantity'] = (monthlyData[monthKey]!['quantity'] as double) + 
            (item['SALE_Q']?.toDouble() ?? 0.0);
        } catch (e) {
          // 날짜 파싱 실패시 무시
        }
      }
    }
    
    if (monthlyData.isEmpty) {
      return _buildPlaceholderChart('📈 월별 트렌드 - 데이터 없음');
    }
    
    // 월별 정렬
    final sortedMonths = monthlyData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final chartData = sortedMonths.map((entry) => {
      'x': entry.key,
      'amount': entry.value['amount'] as double,
      'count': (entry.value['count'] as int).toDouble(),
    }).toList();

    return ChartTemplates.buildComboChart(
      data: chartData,
      title: '📈 월별 매출 트렌드',
      columnField: 'amount',
      lineField: 'count',
      columnName: '매출액',
      lineName: '거래건수',
    );
  }

  // 🚀 주별 트렌드 (실제 구현)
  Widget _buildWeeklyTrendChart() {
    final weeklyData = <String, double>{};
    
    for (var item in _summaryData) {
      final updateTime = item['UPDATE_DTM']?.toString();
      if (updateTime != null) {
        try {
          final date = DateTime.parse(updateTime);
          final weekStart = date.subtract(Duration(days: date.weekday - 1));
          final weekKey = DateFormat('MM/dd').format(weekStart);
          
          weeklyData[weekKey] = (weeklyData[weekKey] ?? 0) + 
            (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
        } catch (e) {
          // 날짜 파싱 실패시 무시
        }
      }
    }
    
    if (weeklyData.isEmpty) {
      return _buildPlaceholderChart('📅 주별 트렌드 - 데이터 없음');
    }
    
    final chartData = weeklyData.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value,
    }).toList();

    return ChartTemplates.buildLineChart(
      data: chartData,
      title: '📅 주별 매출 트렌드',
    );
  }

  // 🚀 대륙별 분석 (실제 구현)
  Widget _buildContinentAnalysisChart() {
    final continentData = <String, double>{};
    
    for (var item in _summaryData) {
      final continent = item['CONTINENT']?.toString() ?? '기타';
      continentData[continent] = (continentData[continent] ?? 0) + 
        (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
    }
    
    if (continentData.isEmpty) {
      return _buildPlaceholderChart('🌎 대륙별 분석 - 데이터 없음');
    }
    
    final chartData = continentData.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value,
    }).toList();

    return ChartTemplates.buildPieChart(
      data: chartData,
      title: '🌎 대륙별 매출 분포',
      showDataLabels: true,
      showLegend: true,
    );
  }

  // 🚀 국가별 순위 (실제 구현)
  Widget _buildCountryRankingChart() {
    final countryData = <String, double>{};
    
    for (var item in _summaryData) {
      final country = item['NATION_NAME']?.toString() ?? '미지정';
      countryData[country] = (countryData[country] ?? 0) + 
        (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
    }
    
    // 상위 10개 국가만 표시
    final sortedCountries = countryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top10 = sortedCountries.take(10);
    final chartData = top10.map((entry) => {
      'name': entry.key.length > 8 ? '${entry.key.substring(0, 8)}...' : entry.key,
      'value': entry.value,
    }).toList();

    if (chartData.isEmpty) {
      return _buildPlaceholderChart('🏆 국가별 순위 - 데이터 없음');
    }

    return ChartTemplates.buildBarChart(
      data: chartData,
      title: '🏆 국가별 매출 순위 (TOP 10)',
    );
  }

  // 🚀 거래처 세분화 (실제 구현)
  Widget _buildCustomerSegmentationChart() {
    final segmentData = <String, Map<String, dynamic>>{};
    
    for (var item in _summaryData) {
      final amount = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
      String segment;
      
      if (amount >= 10000000) {
        segment = 'VIP (1천만원+)';
      } else if (amount >= 5000000) {
        segment = 'Premium (500만원+)';
      } else if (amount >= 1000000) {
        segment = 'Regular (100만원+)';
      } else {
        segment = 'Small (100만원 미만)';
      }
      
      if (!segmentData.containsKey(segment)) {
        segmentData[segment] = {'count': 0, 'amount': 0.0};
      }
      
      segmentData[segment]!['count'] = (segmentData[segment]!['count'] as int) + 1;
      segmentData[segment]!['amount'] = (segmentData[segment]!['amount'] as double) + amount;
    }
    
    if (segmentData.isEmpty) {
      return _buildPlaceholderChart('👥 거래처 세분화 - 데이터 없음');
    }
    
    final chartData = segmentData.entries.map((entry) => {
      'name': entry.key,
      'value': (entry.value['count'] as int).toDouble(),
    }).toList();

         return ChartTemplates.buildDonutChart(
       data: chartData,
       title: '👥 거래처 세분화',
       centerText: '총 거래처',
     );
   }

  // 🚀 계절성 분석 (실제 구현)
  Widget _buildSeasonalityChart() {
    final seasonData = <String, double>{};
    
    for (var item in _summaryData) {
      final updateTime = item['UPDATE_DTM']?.toString();
      if (updateTime != null) {
        try {
          final date = DateTime.parse(updateTime);
          String season;
          
          if (date.month >= 3 && date.month <= 5) {
            season = '봄 (3-5월)';
          } else if (date.month >= 6 && date.month <= 8) {
            season = '여름 (6-8월)';
          } else if (date.month >= 9 && date.month <= 11) {
            season = '가을 (9-11월)';
          } else {
            season = '겨울 (12-2월)';
          }
          
          seasonData[season] = (seasonData[season] ?? 0) + 
            (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
        } catch (e) {
          // 날짜 파싱 실패시 무시
        }
      }
    }
    
    if (seasonData.isEmpty) {
      return _buildPlaceholderChart('🌍 계절성 분석 - 데이터 없음');
    }
    
    final chartData = seasonData.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value,
    }).toList();

    return ChartTemplates.buildPieChart(
      data: chartData,
      title: '🌍 계절별 매출 분석',
    );
  }

  // 🚀 지역별 성장률 (실제 구현)  
  Widget _buildRegionalGrowthChart() {
    final regionData = <String, Map<String, dynamic>>{};
    
    for (var item in _summaryData) {
      final nation = item['NATION_NAME']?.toString() ?? '미지정';
      final amount = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
      final quantity = item['SALE_Q']?.toDouble() ?? 0.0;
      
      if (!regionData.containsKey(nation)) {
        regionData[nation] = {'amount': 0.0, 'quantity': 0.0, 'count': 0};
      }
      
      regionData[nation]!['amount'] = (regionData[nation]!['amount'] as double) + amount;
      regionData[nation]!['quantity'] = (regionData[nation]!['quantity'] as double) + quantity;
      regionData[nation]!['count'] = (regionData[nation]!['count'] as int) + 1;
    }
    
    // 상위 8개 지역만 표시
    final sortedRegions = regionData.entries.toList()
      ..sort((a, b) => (b.value['amount'] as double).compareTo(a.value['amount'] as double));
    
    final top8 = sortedRegions.take(8);
    final chartData = top8.map((entry) => {
      'name': entry.key.length > 6 ? '${entry.key.substring(0, 6)}...' : entry.key,
      'value': entry.value['amount'] as double,
    }).toList();

    if (chartData.isEmpty) {
      return _buildPlaceholderChart('📊 지역별 성장률 - 데이터 없음');
    }

    return ChartTemplates.buildColumnChart(
      data: chartData,
      title: '📊 지역별 매출 성과 (TOP 8)',
    );
  }

  // 🚀 환율 영향도 분석 (실제 구현)
  Widget _buildExchangeRateImpactChart() {
    final exchangeData = <double, Map<String, dynamic>>{};
    
    for (var item in _summaryData) {
      final rate = item['EXCHG_RATE_O']?.toDouble();
      final amount = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
      
      if (rate != null && rate > 0) {
        if (!exchangeData.containsKey(rate)) {
          exchangeData[rate] = {'amount': 0.0, 'count': 0};
        }
        
        exchangeData[rate]!['amount'] = (exchangeData[rate]!['amount'] as double) + amount;
        exchangeData[rate]!['count'] = (exchangeData[rate]!['count'] as int) + 1;
      }
    }
    
    if (exchangeData.isEmpty) {
      return _buildPlaceholderChart('💱 환율 영향도 - 데이터 없음');
    }
    
    final sortedRates = exchangeData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final chartData = sortedRates.map((entry) => {
      'x': entry.key.toStringAsFixed(0),
      'column': entry.value['amount'] as double,
      'line': (entry.value['count'] as int).toDouble(),
    }).toList();

    return ChartTemplates.buildComboChart(
      data: chartData,
      title: '💱 환율별 매출 영향도',
      columnField: 'column',
      lineField: 'line',
      columnName: '매출액',
      lineName: '거래건수',
    );
  }

  // 🚀 거래처 충성도 (실제 구현)
  Widget _buildCustomerLoyaltyChart() {
    final loyaltyData = <String, int>{};
    final customerFreq = <String, int>{};
    
    // 거래처별 거래 빈도 계산
    for (var item in _summaryData) {
      final customer = item['CUSTOM_NAME']?.toString() ?? '미지정';
      customerFreq[customer] = (customerFreq[customer] ?? 0) + 1;
    }
    
    // 충성도 분류
    for (var entry in customerFreq.entries) {
      String loyalty;
      if (entry.value >= 10) {
        loyalty = '매우 높음 (10회+)';
      } else if (entry.value >= 5) {
        loyalty = '높음 (5-9회)';
      } else if (entry.value >= 3) {
        loyalty = '보통 (3-4회)';
      } else {
        loyalty = '낮음 (1-2회)';
      }
      
      loyaltyData[loyalty] = (loyaltyData[loyalty] ?? 0) + 1;
    }
    
    if (loyaltyData.isEmpty) {
      return _buildPlaceholderChart('❤️ 거래처 충성도 - 데이터 없음');
    }
    
    final chartData = loyaltyData.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value.toDouble(),
    }).toList();

    return ChartTemplates.buildDonutChart(
      data: chartData,
      title: '❤️ 거래처 충성도 분석',
      centerText: '총 거래처',
    );
  }

  // 🚀 거래처 생애가치 (실제 구현)
  Widget _buildCustomerLifetimeValueChart() {
    final customerValue = <String, double>{};
    
    for (var item in _summaryData) {
      final customer = item['CUSTOM_NAME']?.toString() ?? '미지정';
      final amount = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
      customerValue[customer] = (customerValue[customer] ?? 0) + amount;
    }
    
    final valueSegments = <String, int>{};
    for (var value in customerValue.values) {
      String segment;
      if (value >= 50000000) {
        segment = '초고가치 (5천만원+)';
      } else if (value >= 20000000) {
        segment = '고가치 (2천만원+)';
      } else if (value >= 5000000) {
        segment = '중가치 (500만원+)';
      } else {
        segment = '저가치 (500만원 미만)';
      }
      
      valueSegments[segment] = (valueSegments[segment] ?? 0) + 1;
    }
    
    if (valueSegments.isEmpty) {
      return _buildPlaceholderChart('💎 거래처 생애가치 - 데이터 없음');
    }
    
    final chartData = valueSegments.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value.toDouble(),
    }).toList();

    return ChartTemplates.buildPieChart(
      data: chartData,
      title: '💎 거래처 생애가치 분포',
    );
  }

  // 🚀 신규 vs 기존 거래처 (실제 구현)
  Widget _buildNewVsReturningChart() {
    final customerFirstDate = <String, DateTime>{};
    final customerCounts = <String, int>{'신규': 0, '기존': 0};
    
    // 거래처별 최초 거래일 찾기
    for (var item in _summaryData) {
      final customer = item['CUSTOM_NAME']?.toString() ?? '미지정';
      final updateTime = item['UPDATE_DTM']?.toString();
      
      if (updateTime != null) {
        try {
          final date = DateTime.parse(updateTime);
          if (!customerFirstDate.containsKey(customer) || 
              date.isBefore(customerFirstDate[customer]!)) {
            customerFirstDate[customer] = date;
          }
        } catch (e) {
          // 날짜 파싱 실패시 무시
        }
      }
    }
    
    // 30일 이내 첫 거래 = 신규, 그 외 = 기존
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    for (var entry in customerFirstDate.entries) {
      if (entry.value.isAfter(thirtyDaysAgo)) {
        customerCounts['신규'] = customerCounts['신규']! + 1;
      } else {
        customerCounts['기존'] = customerCounts['기존']! + 1;
      }
    }
    
    if (customerCounts.values.every((count) => count == 0)) {
      return _buildPlaceholderChart('🆕 신규 vs 기존 - 데이터 없음');
    }
    
    final chartData = customerCounts.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value.toDouble(),
    }).toList();

    return ChartTemplates.buildPieChart(
      data: chartData,
      title: '🆕 신규 vs 기존 거래처',
    );
  }
  // 🚀 실제 제품 성과 차트 구현
  Widget _buildProductPerformanceChart() {
    // 품목별 매출 통계 계산
    final productStats = <String, double>{};
    for (var item in _summaryData) {
      final product = item['ITEM_NM']?.toString() ?? '미지정 품목';
      final amount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
      productStats[product] = (productStats[product] ?? 0) + amount;
    }

    // 상위 10개 제품만 표시
    final sortedProducts = productStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final chartData = sortedProducts.take(10).map((entry) => {
      'x': entry.key.length > 8 ? '${entry.key.substring(0, 8)}...' : entry.key,
      'y': entry.value,
    }).toList();

    if (chartData.isEmpty) {
      return _buildPlaceholderChart('📦 제품 성과 - 데이터 없음');
    }

    return ChartTemplates.buildColumnChart(
      data: chartData,
      title: '📦 상위 제품 매출 성과',
      yAxisTitle: '매출액 (원)',
      enableZooming: true,
    );
  }
  // 🚀 실제 제품 카테고리 차트 구현
  Widget _buildProductCategoryChart() {
    // ITEM_TYPE 또는 다른 카테고리 필드를 사용하여 분류
    final categoryStats = <String, double>{};
    for (var item in _summaryData) {
      // 카테고리 결정 로직 (실제 데이터 구조에 맞게 조정)
      String category = '';
      final itemName = item['ITEM_NM']?.toString() ?? '';
      
      // 간단한 카테고리 분류 로직 (실제로는 DB에서 카테고리 정보를 가져와야 함)
      if (itemName.contains('인공호흡기') || itemName.contains('벤틸레이터')) {
        category = '인공호흡기';
      } else if (itemName.contains('마스크') || itemName.contains('MASK')) {
        category = '마스크';
      } else if (itemName.contains('필터') || itemName.contains('FILTER')) {
        category = '필터';
      } else if (itemName.contains('튜브') || itemName.contains('TUBE')) {
        category = '튜브/호스';
      } else if (itemName.contains('센서') || itemName.contains('SENSOR')) {
        category = '센서';
      } else {
        category = '기타 소모품';
      }
      
      final amount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
      categoryStats[category] = (categoryStats[category] ?? 0) + amount;
    }

    final chartData = categoryStats.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value,
    }).toList();

    if (chartData.isEmpty) {
      return _buildPlaceholderChart('📋 제품 카테고리 - 데이터 없음');
    }

    return ChartTemplates.buildPieChart(
      data: chartData,
      title: '📋 제품 카테고리별 매출 분포',
      showLegend: true,
      showDataLabels: true,
    );
  }
  // 🚀 실제 제품 트렌드 차트 구현
  Widget _buildProductTrendChart() {
    // 날짜별 매출 트렌드 분석
    final trendStats = <String, double>{};
    
    for (var item in _summaryData) {
      final dateStr = item['SALE_YMD']?.toString() ?? '';
      final amount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
      
      if (dateStr.isNotEmpty) {
        // YYYYMMDD 형식을 MM/DD로 변환
        if (dateStr.length >= 8) {
          final month = dateStr.substring(4, 6);
          final day = dateStr.substring(6, 8);
          final displayDate = '$month/$day';
          trendStats[displayDate] = (trendStats[displayDate] ?? 0) + amount;
        }
      }
    }
    
    // 날짜 순으로 정렬
    final sortedTrend = trendStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final chartData = sortedTrend.take(20).map((entry) => {  // 최근 20일만 표시
      'x': entry.key,
      'y': entry.value,
    }).toList();

    if (chartData.isEmpty) {
      return _buildPlaceholderChart('📈 제품 트렌드 - 데이터 없음');
    }

    return ChartTemplates.buildLineChart(
      data: chartData,
      title: '📈 일별 매출 트렌드',
      yAxisTitle: '매출액 (원)',
      showMarkers: true,
      lineColor: Colors.green[600],
    );
  }
  // 🚀 재고 분석 (실제 구현)
  Widget _buildInventoryAnalysisChart() {
    final quantityData = <String, Map<String, dynamic>>{};
    
    for (var item in _summaryData) {
      final customer = item['CUSTOM_NAME']?.toString() ?? '미지정';
      final quantity = item['SALE_Q']?.toDouble() ?? 0.0;
      final amount = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
      
      if (!quantityData.containsKey(customer)) {
        quantityData[customer] = {'quantity': 0.0, 'amount': 0.0};
      }
      
      quantityData[customer]!['quantity'] = (quantityData[customer]!['quantity'] as double) + quantity;
      quantityData[customer]!['amount'] = (quantityData[customer]!['amount'] as double) + amount;
    }
    
    // 상위 8개 거래처만 표시
    final sortedData = quantityData.entries.toList()
      ..sort((a, b) => (b.value['quantity'] as double).compareTo(a.value['quantity'] as double));
    
    final top8 = sortedData.take(8);
    final chartData = top8.map((entry) => {
      'name': entry.key.length > 8 ? '${entry.key.substring(0, 8)}...' : entry.key,
      'value': entry.value['quantity'] as double,
    }).toList();

    if (chartData.isEmpty) {
      return _buildPlaceholderChart('📊 재고 분석 - 데이터 없음');
    }

    return ChartTemplates.buildColumnChart(
      data: chartData,
      title: '📊 거래처별 수량 분석 (TOP 8)',
    );
  }
  // 🚀 실제 이익률 분석 차트 구현
  Widget _buildProfitMarginChart() {
    // 고객별 이익률 분석 (매출액 기준으로 등급 분류)
    final marginStats = <String, double>{};
    final marginCounts = <String, int>{};
    
    for (var item in _summaryData) {
      final amount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
      final quantity = (item['SALE_Q'] as num?)?.toInt() ?? 0;
      
      // 매출액 기준 고객 등급 분류
      String tier = '';
      if (amount >= 10000000) {  // 1천만원 이상
        tier = 'VIP 고객';
      } else if (amount >= 5000000) {  // 500만원 이상
        tier = '우수 고객';
      } else if (amount >= 1000000) {  // 100만원 이상
        tier = '일반 고객';
      } else {
        tier = '소액 고객';
      }
      
      marginStats[tier] = (marginStats[tier] ?? 0) + amount;
      marginCounts[tier] = (marginCounts[tier] ?? 0) + 1;
    }

    final chartData = marginStats.entries.map((entry) => {
      'name': '${entry.key}\n(${marginCounts[entry.key]}건)',
      'value': entry.value,
    }).toList();

    if (chartData.isEmpty) {
      return _buildPlaceholderChart('💰 이익률 분석 - 데이터 없음');
    }

    return ChartTemplates.buildDonutChart(
      data: chartData,
      title: '💰 고객 등급별 매출 분포',
      centerText: '총매출',
      showDataLabels: true,
    );
  }
  // 🚀 실제 비용 분석 차트 구현 (콤보차트)
  Widget _buildCostAnalysisChart() {
    // 고객별 매출액과 거래건수 분석
    final customerStats = <String, Map<String, dynamic>>{};
    
    for (var item in _summaryData) {
      final customer = item['CUSTOM_NAME']?.toString() ?? '미지정';
      final amount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
      
      if (!customerStats.containsKey(customer)) {
        customerStats[customer] = {'amount': 0.0, 'count': 0};
      }
      
      customerStats[customer]!['amount'] = 
        (customerStats[customer]!['amount'] as double) + amount;
      customerStats[customer]!['count'] = 
        (customerStats[customer]!['count'] as int) + 1;
    }
    
    // 상위 8개 고객만 표시
    final sortedCustomers = customerStats.entries.toList()
      ..sort((a, b) => (b.value['amount'] as double).compareTo(a.value['amount'] as double));
    
    final chartData = sortedCustomers.take(8).map((entry) => {
      'x': entry.key.length > 10 ? '${entry.key.substring(0, 10)}...' : entry.key,
      'column': entry.value['amount'] as double,
      'line': (entry.value['count'] as int).toDouble(),
    }).toList();

    if (chartData.isEmpty) {
      return _buildPlaceholderChart('💸 비용 분석 - 데이터 없음');
    }

    return ChartTemplates.buildComboChart(
      data: chartData,
      title: '💸 고객별 매출액 vs 거래건수',
      columnField: 'column',
      lineField: 'line',
      columnName: '매출액',
      lineName: '거래건수',
    );
  }
  // 🚀 ROI 분석 (실제 구현)
  Widget _buildROIAnalysisChart() {
    final roiData = <String, Map<String, dynamic>>{};
    
    for (var item in _summaryData) {
      final nation = item['NATION_NAME']?.toString() ?? '미지정';
      final amount = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
      final quantity = item['SALE_Q']?.toDouble() ?? 0.0;
      
      if (!roiData.containsKey(nation)) {
        roiData[nation] = {'amount': 0.0, 'quantity': 0.0, 'count': 0};
      }
      
      roiData[nation]!['amount'] = (roiData[nation]!['amount'] as double) + amount;
      roiData[nation]!['quantity'] = (roiData[nation]!['quantity'] as double) + quantity;
      roiData[nation]!['count'] = (roiData[nation]!['count'] as int) + 1;
    }
    
    // ROI 계산 (거래당 평균 매출)
    final roiCalculated = roiData.entries.map((entry) {
      final avgROI = (entry.value['count'] as int) > 0 
        ? (entry.value['amount'] as double) / (entry.value['count'] as int)
        : 0.0;
      return {
        'name': entry.key.length > 6 ? '${entry.key.substring(0, 6)}...' : entry.key,
        'value': avgROI,
      };
    }).toList()
      ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    
    final top6 = roiCalculated.take(6).toList();
    
    if (top6.isEmpty) {
      return _buildPlaceholderChart('📊 ROI 분석 - 데이터 없음');
    }

    return ChartTemplates.buildBarChart(
      data: top6,
      title: '📊 국가별 거래당 평균 ROI (TOP 6)',
    );
  }

  // 🚀 수익성 트렌드 (실제 구현)
  Widget _buildProfitabilityTrendChart() {
    final monthlyProfit = <String, Map<String, dynamic>>{};
    
    for (var item in _summaryData) {
      final updateTime = item['UPDATE_DTM']?.toString();
      if (updateTime != null) {
        try {
          final date = DateTime.parse(updateTime);
          final monthKey = DateFormat('yyyy-MM').format(date);
          final amount = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
          final quantity = item['SALE_Q']?.toDouble() ?? 0.0;
          
          if (!monthlyProfit.containsKey(monthKey)) {
            monthlyProfit[monthKey] = {'amount': 0.0, 'quantity': 0.0};
          }
          
          monthlyProfit[monthKey]!['amount'] = (monthlyProfit[monthKey]!['amount'] as double) + amount;
          monthlyProfit[monthKey]!['quantity'] = (monthlyProfit[monthKey]!['quantity'] as double) + quantity;
        } catch (e) {
          // 날짜 파싱 실패시 무시
        }
      }
    }
    
    if (monthlyProfit.isEmpty) {
      return _buildPlaceholderChart('📈 수익성 트렌드 - 데이터 없음');
    }
    
    final sortedMonths = monthlyProfit.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final chartData = sortedMonths.map((entry) => {
      'name': entry.key,
      'value': entry.value['amount'] as double,
    }).toList();

    return ChartTemplates.buildLineChart(
      data: chartData,
      title: '📈 월별 수익성 트렌드',
    );
  }

  // 🚀 매출 분포 (실제 구현)
  Widget _buildSalesDistributionChart() {
    final distributionData = <String, int>{};
    
    for (var item in _summaryData) {
      final amount = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
      
      String range;
      if (amount >= 100000000) {
        range = '1억 이상';
      } else if (amount >= 50000000) {
        range = '5천만-1억';
      } else if (amount >= 10000000) {
        range = '1천만-5천만';
      } else if (amount >= 1000000) {
        range = '100만-1천만';
      } else {
        range = '100만 미만';
      }
      
      distributionData[range] = (distributionData[range] ?? 0) + 1;
    }
    
    if (distributionData.isEmpty) {
      return _buildPlaceholderChart('📊 매출 분포 - 데이터 없음');
    }
    
    final chartData = distributionData.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value.toDouble(),
    }).toList();

    return ChartTemplates.buildDonutChart(
      data: chartData,
      title: '📊 매출 규모별 분포',
      centerText: '총 거래',
    );
  }

  // 🚀 수량 분포 (실제 구현)
  Widget _buildVolumeDistributionChart() {
    final volumeData = <String, int>{};
    
    for (var item in _summaryData) {
      final quantity = item['SALE_Q']?.toDouble() ?? 0.0;
      
      String range;
      if (quantity >= 1000) {
        range = '1000개 이상';
      } else if (quantity >= 500) {
        range = '500-999개';
      } else if (quantity >= 100) {
        range = '100-499개';
      } else if (quantity >= 10) {
        range = '10-99개';
      } else {
        range = '10개 미만';
      }
      
      volumeData[range] = (volumeData[range] ?? 0) + 1;
    }
    
    if (volumeData.isEmpty) {
      return _buildPlaceholderChart('📊 수량 분포 - 데이터 없음');
    }
    
    final chartData = volumeData.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value.toDouble(),
    }).toList();

    return ChartTemplates.buildPieChart(
      data: chartData,
      title: '📊 수량 규모별 분포',
    );
  }

  // 🚀 거래처 분포 (실제 구현)
  Widget _buildCustomerDistributionChart() {
    final continentData = <String, int>{};
    
    for (var item in _summaryData) {
      final continent = item['CONTINENT']?.toString() ?? '기타';
      continentData[continent] = (continentData[continent] ?? 0) + 1;
    }
    
    if (continentData.isEmpty) {
      return _buildPlaceholderChart('👥 거래처 분포 - 데이터 없음');
    }
    
    final chartData = continentData.entries.map((entry) => {
      'name': entry.key,
      'value': entry.value.toDouble(),
    }).toList();

    return ChartTemplates.buildPieChart(
      data: chartData,
      title: '👥 대륙별 거래처 분포',
    );
  }

  // ===== 나머지 placeholder들 (향후 추가 구현 예정) =====
  Widget _buildYearOverYearChart() => _buildPlaceholderChart('📅 전년 대비');
  Widget _buildMonthOverMonthChart() => _buildPlaceholderChart('📅 전월 대비');
  Widget _buildBenchmarkChart() => _buildPlaceholderChart('🎯 벤치마크');
  Widget _buildCompetitiveAnalysisChart() => _buildPlaceholderChart('⚔️ 경쟁 분석');
  // 🚀 KPI 성과 (실제 구현)
  Widget _buildKPIPerformanceChart() {
    final totalSales = _summaryData.fold<double>(0.0, (sum, item) => 
      sum + (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0));
    final totalQuantity = _summaryData.fold<double>(0.0, (sum, item) => 
      sum + (item['SALE_Q']?.toDouble() ?? 0.0));
    final uniqueCustomers = _summaryData.map((item) => item['CUSTOM_NAME']).toSet().length;
    final avgOrderValue = uniqueCustomers > 0 ? totalSales / uniqueCustomers : 0.0;
    
    final kpiData = [
      {'name': '총매출', 'value': totalSales / 1000000, 'unit': '백만원'},
      {'name': '총수량', 'value': totalQuantity, 'unit': '개'},
      {'name': '거래처수', 'value': uniqueCustomers.toDouble(), 'unit': '개'},
      {'name': '평균거래액', 'value': avgOrderValue / 1000000, 'unit': '백만원'},
    ];
    
    final chartData = kpiData.map((entry) => {
      'name': entry['name'] as String,
      'value': entry['value'] as double,
    }).toList();

    return ChartTemplates.buildColumnChart(
      data: chartData,
      title: '🎯 핵심 KPI 성과',
    );
  }

  // 🚀 목표 달성률 (실제 구현)
  Widget _buildTargetAchievementChart() {
    final monthlyData = <String, double>{};
    
    for (var item in _summaryData) {
      final updateTime = item['UPDATE_DTM']?.toString();
      if (updateTime != null) {
        try {
          final date = DateTime.parse(updateTime);
          final monthKey = DateFormat('MM월').format(date);
          monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + 
            (item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0);
        } catch (e) {
          // 날짜 파싱 실패시 무시
        }
      }
    }
    
    if (monthlyData.isEmpty) {
      return _buildPlaceholderChart('🏆 목표 달성률 - 데이터 없음');
    }
    
    // 목표 대비 달성률 계산 (가상의 목표 설정)
    final targetAmount = 100000000.0; // 1억원 목표
    final achievementData = monthlyData.entries.map((entry) {
      final achievementRate = (entry.value / targetAmount) * 100;
      return {
        'name': entry.key,
        'value': achievementRate > 100 ? 100.0 : achievementRate,
      };
    }).toList();

    return ChartTemplates.buildBarChart(
      data: achievementData,
      title: '🏆 월별 목표 달성률 (%)',
    );
  }

  // 🚀 효율성 분석 (실제 구현)
  Widget _buildEfficiencyChart() {
    final efficiencyData = <String, Map<String, dynamic>>{};
    
    for (var item in _summaryData) {
      final nation = item['NATION_NAME']?.toString() ?? '미지정';
      final amount = item['SUM_SALE_AMT_WON']?.toDouble() ?? 0.0;
      final quantity = item['SALE_Q']?.toDouble() ?? 0.0;
      
      if (!efficiencyData.containsKey(nation)) {
        efficiencyData[nation] = {'amount': 0.0, 'quantity': 0.0, 'transactions': 0};
      }
      
      efficiencyData[nation]!['amount'] = (efficiencyData[nation]!['amount'] as double) + amount;
      efficiencyData[nation]!['quantity'] = (efficiencyData[nation]!['quantity'] as double) + quantity;
      efficiencyData[nation]!['transactions'] = (efficiencyData[nation]!['transactions'] as int) + 1;
    }
    
    // 효율성 계산 (거래당 평균 매출)
    final efficiencyCalc = efficiencyData.entries.map((entry) {
      final transactions = entry.value['transactions'] as int;
      final efficiency = transactions > 0 
        ? (entry.value['amount'] as double) / transactions
        : 0.0;
      return {
        'name': entry.key.length > 6 ? '${entry.key.substring(0, 6)}...' : entry.key,
        'value': efficiency,
      };
    }).toList()
      ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    
    final top6 = efficiencyCalc.take(6).toList();
    
    if (top6.isEmpty) {
      return _buildPlaceholderChart('⚡ 효율성 - 데이터 없음');
    }

    return ChartTemplates.buildBarChart(
      data: top6,
      title: '⚡ 국가별 거래 효율성 (TOP 6)',
    );
  }
  Widget _buildQualityMetricsChart() => _buildPlaceholderChart('✨ 품질 지표');
  Widget _buildSalesForecastChart() => _buildPlaceholderChart('🔮 매출 예측');
  Widget _buildTrendPredictionChart() => _buildPlaceholderChart('📈 트렌드 예측');
  Widget _buildSeasonalForecastChart() => _buildPlaceholderChart('🌱 계절 예측');
  Widget _buildRiskAnalysisChart() => _buildPlaceholderChart('⚠️ 리스크 분석');

  Widget _buildPlaceholderChart(String title) {
    return _buildChartCard(
      title,
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 48, color: Colors.orange[600]),
            const SizedBox(height: 16),
            Text(
              '🚧 개발 중',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '향후 업데이트에서 제공될 예정입니다',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===== 🚀 반응형 툴바 전용 메서드들 =====

  // 🔄 자동갱신 시작/중지 버튼 (명확한 기본 액션)
  Widget _buildAutoRefreshToggleButton() {
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _isAutoRefreshEnabled = !_isAutoRefreshEnabled;
          if (_isAutoRefreshEnabled) {
            _startAutoRefresh();
          } else {
            _stopAutoRefresh();
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isAutoRefreshEnabled ? '자동갱신이 시작되었습니다.' : '자동갱신이 중지되었습니다.'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      icon: Icon(
        _isAutoRefreshEnabled ? Icons.pause : Icons.play_arrow,
        size: 18,
      ),
      label: Text(
        _isAutoRefreshEnabled ? '갱신중지' : '자동갱신',
        style: const TextStyle(fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isAutoRefreshEnabled ? Colors.red.shade100 : Colors.green.shade100,
        foregroundColor: _isAutoRefreshEnabled ? Colors.red.shade700 : Colors.green.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ⚙️ 자동갱신 설정 메뉴 (고급 옵션들)
  Widget _buildAutoRefreshSettingsMenu() {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.settings,
        color: Colors.grey[600],
        size: 20,
      ),
      tooltip: '자동갱신 설정',
      itemBuilder: (context) => [
        // 현재 상태 표시
        PopupMenuItem(
          enabled: false,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isAutoRefreshEnabled ? Icons.sync : Icons.sync_disabled,
                      size: 16,
                      color: _isAutoRefreshEnabled ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAutoRefreshEnabled ? '자동갱신 활성화됨' : '자동갱신 비활성화됨',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isAutoRefreshEnabled ? Colors.green[700] : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (_isAutoRefreshEnabled) ...[
                  const SizedBox(height: 4),
                  Text(
                    _refreshMode == 'interval' 
                      ? '현재: 주기 ${_formatRefreshInterval(_refreshIntervalSeconds)}'
                      : '현재: 스케줄 ${_formatScheduleHours()}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        
        // 갱신 모드 선택
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.blue[600]),
              const SizedBox(width: 8),
              const Text(
                '갱신 모드',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'mode_interval',
          child: Row(
            children: [
              Icon(
                _refreshMode == 'interval' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 16,
                color: _refreshMode == 'interval' ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 8),
              const Text('주기 기반'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'mode_schedule',
          child: Row(
            children: [
              Icon(
                _refreshMode == 'schedule' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 16,
                color: _refreshMode == 'schedule' ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 8),
              const Text('시간 스케줄'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        
        // 주기 기반 옵션들
        if (_refreshMode == 'interval') ...[
          const PopupMenuItem(
            enabled: false,
            child: Text(
              '📅 주기 선택',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          PopupMenuItem(
            value: '300', // 5분
            child: _buildIntervalMenuItem(300, '5분'),
          ),
          PopupMenuItem(
            value: '600', // 10분
            child: _buildIntervalMenuItem(600, '10분'),
          ),
          PopupMenuItem(
            value: '1800', // 30분
            child: _buildIntervalMenuItem(1800, '30분'),
          ),
          PopupMenuItem(
            value: '3600', // 1시간
            child: _buildIntervalMenuItem(3600, '1시간'),
          ),
          PopupMenuItem(
            value: '10800', // 3시간
            child: _buildIntervalMenuItem(10800, '3시간'),
          ),
          PopupMenuItem(
            value: '21600', // 6시간
            child: _buildIntervalMenuItem(21600, '6시간'),
          ),
        ],
        
        // 스케줄 기반 옵션들
        if (_refreshMode == 'schedule') ...[
          const PopupMenuItem(
            enabled: false,
            child: Text(
              '⏰ 스케줄 관리',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          PopupMenuItem(
            value: 'schedule_business',
            child: Row(
              children: [
                Icon(Icons.business_center, size: 14, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text('업무시간 (9,12,15,18시)', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'schedule_monitoring',
            child: Row(
              children: [
                Icon(Icons.monitor, size: 14, color: Colors.green[600]),
                const SizedBox(width: 8),
                const Text('모니터링 (6,9,12,15,18,21시)', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'schedule_custom',
            child: Row(
              children: [
                Icon(Icons.edit_calendar, size: 14, color: Colors.orange[600]),
                const SizedBox(width: 8),
                const Text('사용자 정의...', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ],
      onSelected: (value) {
        if (value == 'schedule_custom') {
          // 다이얼로그는 setState 밖에서 열어야 함
          Future.microtask(() => _showCustomScheduleDialog());
          return;
        }
        
        setState(() {
          if (value == 'mode_interval') {
            // 주기 기반 모드로 변경
            _refreshMode = 'interval';
            if (_isAutoRefreshEnabled) {
              _startAutoRefresh();
            }
          } else if (value == 'mode_schedule') {
            // 스케줄 기반 모드로 변경
            _refreshMode = 'schedule';
            if (_isAutoRefreshEnabled) {
              _startAutoRefresh();
            }
          } else if (value.startsWith('schedule_')) {
            // 스케줄 프리셋 적용
            _applySchedulePreset(value);
          } else {
            // 갱신 주기 변경 (숫자 값)
            final seconds = int.tryParse(value);
            if (seconds != null) {
              _refreshIntervalSeconds = seconds;
              if (_isAutoRefreshEnabled) {
                _startAutoRefresh(); // 새로운 주기로 재시작
              }
              
              // 사용자 피드백
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('자동갱신 주기가 ${_formatRefreshInterval(seconds)}로 변경되었습니다.'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        });
      },
    );
  }

  // 저장된 검색 메뉴
  Widget _buildSavedSearchMenu() {
    return PopupMenuButton<Map<String, dynamic>>(
      icon: const Icon(Icons.bookmarks),
      tooltip: '저장된 검색',
      onSelected: _applySavedSearch,
      itemBuilder: (context) => [
        ..._savedSearches.map((search) => PopupMenuItem(
          value: search,
          child: ListTile(
            leading: const Icon(Icons.search),
            title: Text(search['name']),
            subtitle: Text(search['savedAt'].toString().substring(0, 16)),
          ),
        )),
        if (_savedSearches.isEmpty)
          const PopupMenuItem(
            enabled: false,
            child: Text('저장된 검색이 없습니다'),
          ),
      ],
    );
  }

  // 북마크 메뉴 (태블릿용)
  Widget _buildBookmarkMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.star),
      tooltip: '즐겨찾기',
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              const Icon(Icons.bookmark_add, size: 16),
              const SizedBox(width: 8),
              const Text('현재 검색 저장'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_bookmarks',
          child: Row(
            children: [
              Icon(_showBookmarkedOnly ? Icons.star : Icons.star_outline, size: 16),
              const SizedBox(width: 8),
              Text(_showBookmarkedOnly ? '전체 보기' : '즐겨찾기만 보기'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'save') {
          _saveCurrentSearch();
        } else if (value == 'toggle_bookmarks') {
          setState(() {
            _showBookmarkedOnly = !_showBookmarkedOnly;
          });
          _applyFilters();
        }
      },
    );
  }

  // 내보내기 메뉴 (태블릿용)
  Widget _buildExportMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.download),
      tooltip: '내보내기',
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'json',
          child: Row(
            children: [
              const Icon(Icons.code, size: 16),
              const SizedBox(width: 8),
              const Text('JSON'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'csv',
          child: Row(
            children: [
              const Icon(Icons.text_snippet, size: 16),
              const SizedBox(width: 8),
              const Text('CSV'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'excel',
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.construction, color: Colors.orange, size: 12),
                  SizedBox(width: 2),
                  Icon(Icons.file_download, size: 16),
                ],
              ),
              const SizedBox(width: 8),
              const Text('Excel (🚧)'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'json':
            _exportToJson();
            break;
          case 'csv':
            _exportToCsv();
            break;
          case 'excel':
            _exportToExcel();
            break;
        }
      },
    );
  }

  // 데스크톱용 내보내기 버튼들
  Widget _buildExportButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _exportToExcel,
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.construction, color: Colors.orange, size: 12),
              SizedBox(width: 2),
              Icon(Icons.file_download),
            ],
          ),
          tooltip: '🚧 엑셀 내보내기 (미구현) (Ctrl+E)',
        ),
        IconButton(
          onPressed: _exportToPdf,
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.construction, color: Colors.orange, size: 12),
              SizedBox(width: 2),
              Icon(Icons.picture_as_pdf),
            ],
          ),
          tooltip: '🚧 PDF 내보내기 (미구현)',
        ),
        IconButton(
          onPressed: _exportToJson,
          icon: const Icon(Icons.code),
          tooltip: 'JSON 내보내기 (Ctrl+J)',
        ),
        IconButton(
          onPressed: _exportToCsv,
          icon: const Icon(Icons.text_snippet),
          tooltip: 'CSV 내보내기',
        ),
      ],
    );
  }

  // 🛠️ 모바일용 기능 메뉴 (추가 기능들)
  Widget _buildMobileMoreMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.apps, color: Colors.blue),
      tooltip: '모든 기능',
      itemBuilder: (context) => [
        // 📋 메뉴 설명
        const PopupMenuItem(
          enabled: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '🛠️ 추가 기능 메뉴',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '화면에 표시되지 않은 고급 기능들',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        
        // ⚙️ 설정 관련
        const PopupMenuItem(
          enabled: false,
          child: Text(
            '⚙️ 설정',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'auto_refresh_settings',
          child: Row(
            children: [
              const Icon(Icons.autorenew, size: 16),
              const SizedBox(width: 8),
              const Text('자동갱신 설정'),
            ],
          ),
        ),
        // 🆕 사용자 정의 스케줄 직접 접근
        PopupMenuItem(
          value: 'custom_schedule_direct',
          child: Row(
            children: [
              const Icon(Icons.edit_calendar, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('사용자 정의 스케줄'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'advanced_filter',
          child: Row(
            children: [
              const Icon(Icons.tune, size: 16),
              const SizedBox(width: 8),
              const Text('고급 필터'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'dashboard_settings',
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.construction, color: Colors.orange, size: 12),
                  SizedBox(width: 2),
                  Icon(Icons.dashboard_customize, size: 16),
                ],
              ),
              const SizedBox(width: 8),
              const Text('대시보드 설정'),
            ],
          ),
        ),
        
        const PopupMenuDivider(),
        
        // 🔍 검색 관리
        const PopupMenuItem(
          enabled: false,
          child: Text(
            '🔍 검색 관리',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'save_search',
          child: Row(
            children: [
              const Icon(Icons.bookmark_add, size: 16),
              const SizedBox(width: 8),
              const Text('현재 검색 저장'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'saved_searches',
          child: Row(
            children: [
              const Icon(Icons.bookmarks, size: 16),
              const SizedBox(width: 8),
              const Text('저장된 검색 보기'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_favorites',
          child: Row(
            children: [
              Icon(_showBookmarkedOnly ? Icons.star : Icons.star_outline, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text(_showBookmarkedOnly ? '전체 데이터 보기' : '즐겨찾기만 보기'),
            ],
          ),
        ),
        
        const PopupMenuDivider(),
        
        // 📤 데이터 내보내기
        const PopupMenuItem(
          enabled: false,
          child: Text(
            '📤 데이터 내보내기',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'export_excel',
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.construction, color: Colors.orange, size: 12),
                  SizedBox(width: 2),
                  Icon(Icons.table_chart, size: 16),
                ],
              ),
              const SizedBox(width: 8),
              const Text('Excel 파일'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export_pdf',
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.construction, color: Colors.orange, size: 12),
                  SizedBox(width: 2),
                  Icon(Icons.picture_as_pdf, size: 16),
                ],
              ),
              const SizedBox(width: 8),
              const Text('PDF 문서'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export_csv',
          child: Row(
            children: [
              const Icon(Icons.text_snippet, size: 16),
              const SizedBox(width: 8),
              const Text('CSV 파일'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export_json',
          child: Row(
            children: [
              const Icon(Icons.code, size: 16),
              const SizedBox(width: 8),
              const Text('JSON 데이터'),
            ],
          ),
        ),
        
        const PopupMenuDivider(),
        
        // 🎯 기타 기능
        const PopupMenuItem(
          enabled: false,
          child: Text(
            '🎯 기타 기능',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'keyboard_shortcuts',
          child: Row(
            children: [
              const Icon(Icons.keyboard, size: 16),
              const SizedBox(width: 8),
              const Text('키보드 단축키'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'help',
          child: Row(
            children: [
              const Icon(Icons.help_outline, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('사용법 도움말'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'fullscreen',
          child: Row(
            children: [
              const Icon(Icons.fullscreen, size: 16),
              const SizedBox(width: 8),
              const Text('전체화면 모드'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'auto_refresh_settings':
            // 모바일용 자동갱신 설정 다이얼로그 열기
            _showMobileAutoRefreshDialog();
            break;
          case 'custom_schedule_direct':
            // 🆕 사용자 정의 스케줄 직접 열기
            _showCustomScheduleDialog();
            break;
          case 'advanced_filter':
            _showAdvancedFilterDialog();
            break;
          case 'save_search':
            _saveCurrentSearch();
            break;
          case 'saved_searches':
            _showSavedSearchesDialog();
            break;
          case 'toggle_favorites':
            setState(() {
              _showBookmarkedOnly = !_showBookmarkedOnly;
            });
            _applyFilters();
            break;
          case 'export_excel':
            _exportToExcel();
            break;
          case 'export_pdf':
            _exportToPdf();
            break;
          case 'export_json':
            _exportToJson();
            break;
          case 'export_csv':
            _exportToCsv();
            break;
          case 'keyboard_shortcuts':
            _showKeyboardShortcuts();
            break;
          case 'dashboard_settings':
            _showDashboardSettings();
            break;
          case 'help':
            _showHelpDialog();
            break;
          case 'fullscreen':
            _toggleFullScreen();
            break;
        }
      },
    );
  }

  // 태블릿용 더보기 메뉴
  Widget _buildTabletMoreMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      tooltip: '추가 기능',
      itemBuilder: (context) => [
        // 📖 저장된 검색 기능
        PopupMenuItem(
          value: 'save_search',
          child: Row(
            children: [
              const Icon(Icons.bookmark_add, size: 16),
              const SizedBox(width: 8),
              const Text('검색 저장'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'saved_searches',
          child: Row(
            children: [
              const Icon(Icons.bookmarks, size: 16),
              const SizedBox(width: 8),
              const Text('저장된 검색'),
            ],
          ),
        ),
        
        const PopupMenuDivider(),
        
        // 📤 내보내기 기능들
        PopupMenuItem(
          value: 'export_excel',
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.construction, color: Colors.orange, size: 12),
                  SizedBox(width: 2),
                  Icon(Icons.file_download, size: 16),
                ],
              ),
              const SizedBox(width: 8),
              const Text('Excel 내보내기'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export_pdf',
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.construction, color: Colors.orange, size: 12),
                  SizedBox(width: 2),
                  Icon(Icons.picture_as_pdf, size: 16),
                ],
              ),
              const SizedBox(width: 8),
              const Text('PDF 내보내기'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export_json',
          child: Row(
            children: [
              const Icon(Icons.code, size: 16),
              const SizedBox(width: 8),
              const Text('JSON 내보내기'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export_csv',
          child: Row(
            children: [
              const Icon(Icons.text_snippet, size: 16),
              const SizedBox(width: 8),
              const Text('CSV 내보내기'),
            ],
          ),
        ),
        
        const PopupMenuDivider(),
        
        PopupMenuItem(
          value: 'dashboard_settings',
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.construction, color: Colors.orange, size: 12),
                  SizedBox(width: 2),
                  Icon(Icons.settings, size: 16),
                ],
              ),
              const SizedBox(width: 8),
              const Text('대시보드 설정'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'shortcuts',
          child: Row(
            children: [
              const Icon(Icons.keyboard, size: 16),
              const SizedBox(width: 8),
              const Text('키보드 단축키'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'help',
          child: Row(
            children: [
              const Icon(Icons.help_outline, size: 16),
              const SizedBox(width: 8),
              const Text('도움말'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'fullscreen',
          child: Row(
            children: [
              const Icon(Icons.fullscreen, size: 16),
              const SizedBox(width: 8),
              const Text('전체화면'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'save_search':
            _saveCurrentSearch();
            break;
          case 'saved_searches':
            _showSavedSearchesDialog();
            break;
          case 'export_excel':
            _exportToExcel();
            break;
          case 'export_pdf':
            _exportToPdf();
            break;
          case 'export_json':
            _exportToJson();
            break;
          case 'export_csv':
            _exportToCsv();
            break;
          case 'dashboard_settings':
            _showDashboardSettings();
            break;
          case 'shortcuts':
            _showKeyboardShortcuts();
            break;
          case 'help':
            _showHelpDialog();
            break;
          case 'fullscreen':
            _toggleFullScreen();
            break;
        }
      },
    );
  }

  // 저장된 검색 다이얼로그 (모바일용)
  void _showSavedSearchesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장된 검색'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: _savedSearches.isEmpty
            ? const Center(child: Text('저장된 검색이 없습니다'))
            : ListView.builder(
                itemCount: _savedSearches.length,
                itemBuilder: (context, index) {
                  final search = _savedSearches[index];
                  return ListTile(
                    leading: const Icon(Icons.search),
                    title: Text(search['name']),
                    subtitle: Text(search['savedAt'].toString().substring(0, 16)),
                    onTap: () {
                      Navigator.pop(context);
                      _applySavedSearch(search);
                    },
                  );
                },
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 🚀 AI 분석 화면으로 현재 데이터와 함께 이동
  void _navigateToAiAnalysis() {
    if (_summaryData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('분석할 데이터가 없습니다. 먼저 매출 데이터를 조회해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 현재 조회된 데이터와 기간 정보를 AI 분석 화면으로 전달
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiAnalysisScreen(
          preloadedData: _summaryData,
          periodInfo: {
            'fromDate': _fromDate.toIso8601String(),
            'toDate': _toDate.toIso8601String(),
            'dataCount': _summaryData.length,
            'totalAmount': _summaryData.fold<double>(0, (sum, item) => 
              sum + ((item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0)),
            'totalQuantity': _summaryData.fold<int>(0, (sum, item) => 
              sum + ((item['SALE_Q'] as num?)?.toInt() ?? 0)),
          },
        ),
      ),
    );
  }
} 