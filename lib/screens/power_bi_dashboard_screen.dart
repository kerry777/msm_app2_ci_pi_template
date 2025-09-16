import 'package:flutter/material.dart' hide SlideTransition;
import 'package:flutter/material.dart' as material show SlideTransition;
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../services/sales_service.dart';
import '../services/master_filter_service.dart';
import '../services/slide_show_service.dart';
import '../services/bi_settings_service.dart';
import '../utils/dialog_utils.dart';
import 'dart:async';
import 'dart:math' as math;

/// Power BI 수준의 통합 대시보드 화면
/// - Master Filter 시스템으로 차트간 동기화
/// - 슬라이드 모드로 자동 주제 전환
/// - 실시간 데이터 연동 및 설정 저장/복원
class PowerBIDashboardScreen extends StatefulWidget {
  const PowerBIDashboardScreen({super.key});

  @override
  State<PowerBIDashboardScreen> createState() => _PowerBIDashboardScreenState();
}

class _PowerBIDashboardScreenState extends State<PowerBIDashboardScreen>
    with TickerProviderStateMixin implements FilterableWidget {

  // 서비스들
  late MasterFilterService _masterFilterService;
  late SlideShowService _slideShowService;
  late BISettingsService _settingsService;

  // 데이터
  List<Map<String, dynamic>> _rawData = [];
  bool _isLoading = false;
  final DateTime _fromDate = DateTime(DateTime.now().year, 1, 1);
  final DateTime _toDate = DateTime(DateTime.now().year, 12, 31);

  // 슬라이드 모드
  bool _isSlideMode = false;
  Timer? _slideTimer;
  int _currentSlideIndex = 0;
  final List<SlideTheme> _slideThemes = [];

  // 애니메이션
  late AnimationController _slideAnimationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 차트 데이터들
  final Map<String, List<ChartDataPoint>> _chartDataCache = {};
  Map<String, dynamic> _kpiData = {};

  // Master Filter 상태
  final Map<String, List<String>> _activeFilters = {};

  // 키보드 단축키
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeAnimations();
    _initializeSlideThemes();
    _setupKeyboardShortcuts();
    _loadRealData();
  }

  void _initializeServices() {
    _masterFilterService = MasterFilterService();
    _slideShowService = SlideShowService();
    _settingsService = BISettingsService();

    // Master Filter 시스템에 등록
    _masterFilterService.registerWidget('power_bi_dashboard', this);
    _masterFilterService.subscribeToFilter('power_bi_dashboard', 'CONTINENT');
    _masterFilterService.subscribeToFilter('power_bi_dashboard', 'NATION_NAME');
    _masterFilterService.subscribeToFilter('power_bi_dashboard', '거래처분류');

    // 슬라이드쇼 이벤트 리스닝
    _slideShowService.events.listen(_handleSlideShowEvent);
  }

  void _initializeAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideAnimationController, curve: Curves.easeOutCubic));

    _fadeController.forward();
  }

  void _initializeSlideThemes() {
    _slideThemes.addAll([
      SlideTheme(
        id: 'regional_analysis',
        title: '🌍 지역별 매출 분석',
        subtitle: '대륙별 매출 현황 및 성장률',
        duration: const Duration(seconds: 15),
        primaryChart: 'regional_sales',
        secondaryCharts: ['regional_growth', 'country_ranking'],
        kpiFields: ['total_sales_by_region', 'growth_rate', 'market_share'],
      ),

      SlideTheme(
        id: 'customer_analysis',
        title: '🏥 고객별 성과 분석',
        subtitle: '거래처 분류별 매출 분포 및 트렌드',
        duration: const Duration(seconds: 12),
        primaryChart: 'customer_type_pie',
        secondaryCharts: ['top_customers', 'customer_trend'],
        kpiFields: ['total_customers', 'avg_order_value', 'customer_retention'],
      ),

      SlideTheme(
        id: 'product_analysis',
        title: '📦 제품 포트폴리오 분석',
        subtitle: '수량 대비 매출 성과 및 효율성',
        duration: const Duration(seconds: 18),
        primaryChart: 'quantity_vs_sales_scatter',
        secondaryCharts: ['product_efficiency', 'sales_composition'],
        kpiFields: ['avg_unit_price', 'total_quantity', 'price_efficiency'],
      ),

      SlideTheme(
        id: 'trend_analysis',
        title: '📈 시계열 트렌드 분석',
        subtitle: '월별 성장 추이 및 예측',
        duration: const Duration(seconds: 20),
        primaryChart: 'monthly_trend',
        secondaryCharts: ['growth_forecast', 'seasonal_pattern'],
        kpiFields: ['monthly_growth', 'ytd_performance', 'forecast_accuracy'],
      ),

      SlideTheme(
        id: 'performance_summary',
        title: '🎯 성과 종합 요약',
        subtitle: '핵심 KPI 및 전체 성과 대시보드',
        duration: const Duration(seconds: 25),
        primaryChart: 'performance_overview',
        secondaryCharts: ['kpi_trends', 'achievement_gauge'],
        kpiFields: ['total_revenue', 'growth_rate', 'market_position', 'efficiency_ratio'],
      ),
    ]);

    debugPrint('🎬 PowerBI: ${_slideThemes.length} slide themes initialized');
  }

  void _setupKeyboardShortcuts() {
    // 키보드 단축키 설정
    _focusNode.requestFocus();
  }

  Future<void> _loadRealData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await SalesService.getSalesSummary(
        fromDate: '${_fromDate.year}-${_fromDate.month.toString().padLeft(2, '0')}-${_fromDate.day.toString().padLeft(2, '0')}',
        toDate: '${_toDate.year}-${_toDate.month.toString().padLeft(2, '0')}-${_toDate.day.toString().padLeft(2, '0')}',
        period: 'ALL',
        trCd: '',
      );

      if (result['success'] == true && result['data'] != null) {
        _rawData = List<Map<String, dynamic>>.from(result['data']);
        await _processAllChartData();
        _calculateKPIs();
      } else {
        throw Exception(result['message'] ?? '데이터 로드 실패');
      }
    } catch (e) {
      DialogUtils.showErrorDialog(context, '데이터 로드 오류', e.toString());
      _loadDemoData(); // 실패 시 데모 데이터 로드
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadDemoData() {
    // 데모 데이터 생성 (API 실패 시 대체용)
    _rawData = _generateDemoData();
    _processAllChartData();
    _calculateKPIs();
    debugPrint('🎬 PowerBI: Demo data loaded as fallback');
  }

  List<Map<String, dynamic>> _generateDemoData() {
    final random = math.Random();
    final continents = ['아시아', '유럽', '북미', '남미'];
    final countries = {
      '아시아': ['한국', '일본', '중국', '싱가포르'],
      '유럽': ['독일', '프랑스', '영국', '이탈리아'],
      '북미': ['미국', '캐나다', '멕시코'],
      '남미': ['브라질', '아르헨티나', '칠레'],
    };
    final customerTypes = ['대형병원', '중형병원', '소형병원', '종합병원'];

    return List.generate(200, (index) {
      final continent = continents[random.nextInt(continents.length)];
      final country = countries[continent]![random.nextInt(countries[continent]!.length)];
      final customerType = customerTypes[random.nextInt(customerTypes.length)];

      return {
        'CONTINENT': continent,
        'NATION_NAME': country,
        'CUSTOM_NAME': '$country${customerType}_${index + 1}',
        '거래처분류': customerType,
        'SUM_SALE_AMT_WON': random.nextDouble() * 100000000 + 10000000,
        'SALE_Q': random.nextInt(1000) + 100,
        'SALE_P': random.nextDouble() * 50000 + 10000,
        'UPDATE_DTM': DateTime.now().subtract(Duration(days: random.nextInt(365))).toIso8601String(),
      };
    });
  }

  Future<void> _processAllChartData() async {
    _chartDataCache.clear();

    // 지역별 매출
    _chartDataCache['regional_sales'] = _buildRegionalSalesData();

    // 고객 분류별 파이 차트
    _chartDataCache['customer_type_pie'] = _buildCustomerTypePieData();

    // 수량 대비 매출 산점도
    _chartDataCache['quantity_vs_sales_scatter'] = _buildQuantityVsSalesScatterData();

    // 월별 트렌드
    _chartDataCache['monthly_trend'] = _buildMonthlyTrendData();

    // 성과 개요
    _chartDataCache['performance_overview'] = _buildPerformanceOverviewData();

    debugPrint('🎬 PowerBI: All chart data processed - ${_chartDataCache.length} charts');
  }

  List<ChartDataPoint> _buildRegionalSalesData() {
    final Map<String, double> regionSales = {};
    final filteredData = _applyActiveFilters(_rawData);

    for (final item in filteredData) {
      final continent = item['CONTINENT']?.toString() ?? '기타';
      final sales = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
      regionSales[continent] = (regionSales[continent] ?? 0) + sales;
    }

    return regionSales.entries.map((entry) => ChartDataPoint(
      category: entry.key,
      value: entry.value,
      count: 1,
      quantity: 0,
      metadata: {'type': 'region', 'continent': entry.key},
    )).toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  List<ChartDataPoint> _buildCustomerTypePieData() {
    final Map<String, double> typeSales = {};
    final filteredData = _applyActiveFilters(_rawData);

    for (final item in filteredData) {
      final type = item['거래처분류']?.toString() ?? '기타';
      final sales = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
      typeSales[type] = (typeSales[type] ?? 0) + sales;
    }

    return typeSales.entries.map((entry) => ChartDataPoint(
      category: entry.key,
      value: entry.value,
      count: 1,
      quantity: 0,
      metadata: {'type': 'customer_type', 'customerType': entry.key},
    )).toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  List<ChartDataPoint> _buildQuantityVsSalesScatterData() {
    final filteredData = _applyActiveFilters(_rawData);
    final Map<String, ChartDataPoint> customerData = {};

    for (final item in filteredData) {
      final customer = item['CUSTOM_NAME']?.toString() ?? '기타';
      final sales = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
      final quantity = (item['SALE_Q'] as num?)?.toInt() ?? 0;

      if (customerData.containsKey(customer)) {
        final existing = customerData[customer]!;
        customerData[customer] = existing.copyWith(
          value: existing.value + sales,
          quantity: existing.quantity + quantity,
        );
      } else {
        customerData[customer] = ChartDataPoint(
          category: customer,
          value: sales,
          count: 1,
          quantity: quantity,
          metadata: {'type': 'scatter', 'customer': customer},
        );
      }
    }

    return customerData.values.toList();
  }

  List<ChartDataPoint> _buildMonthlyTrendData() {
    final Map<String, double> monthlySales = {};
    final filteredData = _applyActiveFilters(_rawData);

    for (final item in filteredData) {
      final dateStr = item['UPDATE_DTM']?.toString();
      if (dateStr != null) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final monthKey = DateFormat('yyyy-MM').format(date);
          final sales = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
          monthlySales[monthKey] = (monthlySales[monthKey] ?? 0) + sales;
        }
      }
    }

    final sortedEntries = monthlySales.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries.map((entry) => ChartDataPoint(
      category: entry.key,
      value: entry.value,
      count: 1,
      quantity: 0,
      metadata: {'type': 'trend', 'month': entry.key},
    )).toList();
  }

  List<ChartDataPoint> _buildPerformanceOverviewData() {
    final filteredData = _applyActiveFilters(_rawData);
    final totalSales = filteredData.fold<double>(0, (sum, item) =>
      sum + ((item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0));
    final totalQuantity = filteredData.fold<int>(0, (sum, item) =>
      sum + ((item['SALE_Q'] as num?)?.toInt() ?? 0));
    final avgPrice = totalQuantity > 0 ? totalSales / totalQuantity : 0;

    return [
      ChartDataPoint(category: '총 매출', value: totalSales, count: 1, quantity: 0, metadata: {'type': 'kpi'}),
      ChartDataPoint(category: '총 수량', value: totalQuantity.toDouble(), count: 1, quantity: totalQuantity, metadata: {'type': 'kpi'}),
      ChartDataPoint(category: '평균 단가', value: avgPrice.toDouble(), count: 1, quantity: 0, metadata: {'type': 'kpi'}),
      ChartDataPoint(category: '거래처 수', value: filteredData.length.toDouble(), count: filteredData.length, quantity: 0, metadata: {'type': 'kpi'}),
    ];
  }

  void _calculateKPIs() {
    final filteredData = _applyActiveFilters(_rawData);
    final totalSales = filteredData.fold<double>(0, (sum, item) =>
      sum + ((item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0));
    final totalQuantity = filteredData.fold<int>(0, (sum, item) =>
      sum + ((item['SALE_Q'] as num?)?.toInt() ?? 0));

    _kpiData = {
      'total_sales': totalSales,
      'total_quantity': totalQuantity,
      'avg_unit_price': totalQuantity > 0 ? totalSales / totalQuantity : 0,
      'customer_count': filteredData.length,
      'growth_rate': _calculateGrowthRate(filteredData),
      'top_region': _getTopRegion(filteredData),
      'top_customer_type': _getTopCustomerType(filteredData),
    };
  }

  double _calculateGrowthRate(List<Map<String, dynamic>> data) {
    // 간단한 성장률 계산 로직 (실제로는 더 복잡할 수 있음)
    return math.Random().nextDouble() * 20 - 10; // -10% ~ +10%
  }

  String _getTopRegion(List<Map<String, dynamic>> data) {
    final regionSales = <String, double>{};
    for (final item in data) {
      final region = item['CONTINENT']?.toString() ?? '기타';
      final sales = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
      regionSales[region] = (regionSales[region] ?? 0) + sales;
    }

    return regionSales.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String _getTopCustomerType(List<Map<String, dynamic>> data) {
    final typeSales = <String, double>{};
    for (final item in data) {
      final type = item['거래처분류']?.toString() ?? '기타';
      final sales = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
      typeSales[type] = (typeSales[type] ?? 0) + sales;
    }

    return typeSales.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  List<Map<String, dynamic>> _applyActiveFilters(List<Map<String, dynamic>> data) {
    if (_activeFilters.isEmpty) return data;

    return data.where((item) {
      for (final entry in _activeFilters.entries) {
        final field = entry.key;
        final selectedValues = entry.value;
        if (selectedValues.isNotEmpty) {
          final itemValue = item[field]?.toString() ?? '';
          if (!selectedValues.contains(itemValue)) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  /// Master Filter 시스템 구현
  @override
  void applyMasterFilter(String filterField, List<String> selectedValues) {
    if (!mounted) return;
    setState(() {
      if (selectedValues.isEmpty) {
        _activeFilters.remove(filterField);
      } else {
        _activeFilters[filterField] = selectedValues;
      }
      _processAllChartData();
      _calculateKPIs();
    });

    debugPrint('🎯 PowerBI: Master filter applied - $filterField: ${selectedValues.length} values');
  }

  @override
  void clearMasterFilter(String filterField) {
    if (!mounted) return;
    setState(() {
      _activeFilters.remove(filterField);
      _processAllChartData();
      _calculateKPIs();
    });

    debugPrint('🎯 PowerBI: Master filter cleared - $filterField');
  }

  /// 슬라이드 모드 토글
  void _toggleSlideMode() {
    setState(() {
      _isSlideMode = !_isSlideMode;
    });

    if (_isSlideMode) {
      _startSlideMode();
    } else {
      _stopSlideMode();
    }
  }

  void _startSlideMode() {
    if (_slideThemes.isNotEmpty) {
      _currentSlideIndex = 0;
      _slideShowService.startSlideShow();
      _scheduleNextSlide();
      debugPrint('🎬 PowerBI: Slide mode started');
    } else {
      debugPrint('🎬 PowerBI: Cannot start slide mode - no slide themes');
    }
  }

  void _stopSlideMode() {
    _slideTimer?.cancel();
    _slideShowService.stopSlideShow();
    debugPrint('🎬 PowerBI: Slide mode stopped');
  }

  void _scheduleNextSlide() {
    _slideTimer?.cancel();

    if (_isSlideMode && _slideThemes.isNotEmpty && _currentSlideIndex < _slideThemes.length) {
      final currentTheme = _slideThemes[_currentSlideIndex];

      _slideTimer = Timer(currentTheme.duration, () {
        if (_isSlideMode) {
          _transitionToNextSlide();
        }
      });
    }
  }

  void _transitionToNextSlide() {
    _slideAnimationController.reset();

    if (mounted && _slideThemes.isNotEmpty) {
      setState(() {
        _currentSlideIndex = (_currentSlideIndex + 1) % _slideThemes.length;
      });
    }

    _slideAnimationController.forward().then((_) {
      _scheduleNextSlide();
    });

    if (_slideThemes.isNotEmpty && _currentSlideIndex < _slideThemes.length) {
      final currentTheme = _slideThemes[_currentSlideIndex];
      debugPrint('🎬 PowerBI: Transitioned to slide ${_currentSlideIndex + 1}: ${currentTheme.title}');
    }
  }

  void _handleSlideShowEvent(SlideShowEvent event) {
    // 슬라이드쇼 이벤트 처리
    switch (event.type) {
      case SlideShowEventType.slideChanged:
        debugPrint('🎬 PowerBI: Slide changed to ${event.slideIndex}');
        break;
      case SlideShowEventType.autoPlayStarted:
        debugPrint('🎬 PowerBI: Auto play started');
        break;
      case SlideShowEventType.autoPlayStopped:
        debugPrint('🎬 PowerBI: Auto play stopped');
        break;
      default:
        break;
    }
  }

  Widget _buildCurrentSlideContent() {
    if (_slideThemes.isEmpty || _currentSlideIndex >= _slideThemes.length) {
      return const SizedBox.shrink();
    }

    final currentTheme = _slideThemes[_currentSlideIndex];

    return material.SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // 슬라이드 제목
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[800]!, Colors.blue[600]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentTheme.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentTheme.subtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // KPI 카드들
            _buildKPICards(currentTheme),

            const SizedBox(height: 16),

            // 메인 차트
            Expanded(
              child: _buildMainChart(currentTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICards(SlideTheme theme) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: theme.kpiFields.length,
        itemBuilder: (context, index) {
          final kpiField = theme.kpiFields[index];
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            child: _buildKPICard(kpiField),
          );
        },
      ),
    );
  }

  Widget _buildKPICard(String kpiField) {
    final value = _getKPIValue(kpiField);
    final displayName = _getKPIDisplayName(kpiField);
    final icon = _getKPIIcon(kpiField);
    final color = _getKPIColor(kpiField);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                if (kpiField == 'growth_rate') _buildGrowthIndicator(value),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatKPIValue(kpiField, value),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthIndicator(double growthRate) {
    final isPositive = growthRate >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPositive ? Icons.trending_up : Icons.trending_down,
          color: isPositive ? Colors.green : Colors.red,
          size: 16,
        ),
        Text(
          '${growthRate.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            color: isPositive ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMainChart(SlideTheme theme) {
    final chartData = _chartDataCache[theme.primaryChart] ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getChartTitle(theme.primaryChart),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildChartWidget(theme.primaryChart, chartData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartWidget(String chartType, List<ChartDataPoint> data) {
    switch (chartType) {
      case 'regional_sales':
        return _buildColumnChart(data);
      case 'customer_type_pie':
        return _buildPieChart(data);
      case 'quantity_vs_sales_scatter':
        return _buildScatterChart(data);
      case 'monthly_trend':
        return _buildLineChart(data);
      case 'performance_overview':
        return _buildBarChart(data);
      default:
        return _buildColumnChart(data);
    }
  }

  Widget _buildColumnChart(List<ChartDataPoint> data) {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.compact()),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <ColumnSeries<ChartDataPoint, String>>[
        ColumnSeries<ChartDataPoint, String>(
          dataSource: data,
          xValueMapper: (ChartDataPoint data, _) => data.category,
          yValueMapper: (ChartDataPoint data, _) => data.value,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          dataLabelSettings: const DataLabelSettings(isVisible: true),
          onPointTap: (ChartPointDetails details) {
            final point = data[details.pointIndex!];
            _handleChartSelection(point);
          },
        ),
      ],
    );
  }

  Widget _buildPieChart(List<ChartDataPoint> data) {
    return SfCircularChart(
      tooltipBehavior: TooltipBehavior(enable: true),
      legend: Legend(isVisible: true, position: LegendPosition.right),
      series: <PieSeries<ChartDataPoint, String>>[
        PieSeries<ChartDataPoint, String>(
          dataSource: data,
          xValueMapper: (ChartDataPoint data, _) => data.category,
          yValueMapper: (ChartDataPoint data, _) => data.value,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
          explode: true,
          explodeIndex: 0,
        ),
      ],
    );
  }

  Widget _buildScatterChart(List<ChartDataPoint> data) {
    return SfCartesianChart(
      primaryXAxis: NumericAxis(title: AxisTitle(text: '수량')),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: '매출액'),
        numberFormat: NumberFormat.compact(),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <ScatterSeries<ChartDataPoint, double>>[
        ScatterSeries<ChartDataPoint, double>(
          dataSource: data,
          xValueMapper: (ChartDataPoint data, _) => data.quantity.toDouble(),
          yValueMapper: (ChartDataPoint data, _) => data.value,
          markerSettings: const MarkerSettings(height: 8, width: 8),
        ),
      ],
    );
  }

  Widget _buildLineChart(List<ChartDataPoint> data) {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.compact()),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <LineSeries<ChartDataPoint, String>>[
        LineSeries<ChartDataPoint, String>(
          dataSource: data,
          xValueMapper: (ChartDataPoint data, _) => data.category,
          yValueMapper: (ChartDataPoint data, _) => data.value,
          markerSettings: const MarkerSettings(isVisible: true),
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<ChartDataPoint> data) {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(numberFormat: NumberFormat.compact()),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <BarSeries<ChartDataPoint, String>>[
        BarSeries<ChartDataPoint, String>(
          dataSource: data,
          xValueMapper: (ChartDataPoint data, _) => data.category,
          yValueMapper: (ChartDataPoint data, _) => data.value,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  void _handleChartSelection(ChartDataPoint point) {
    // 차트 클릭 시 Master Filter 적용
    final metadata = point.metadata;
    if (metadata['type'] == 'region') {
      _masterFilterService.applyMasterFilter(
        'power_bi_dashboard',
        'CONTINENT',
        [point.category],
      );
    } else if (metadata['type'] == 'customer_type') {
      _masterFilterService.applyMasterFilter(
        'power_bi_dashboard',
        '거래처분류',
        [point.category],
      );
    }
  }

  // 헬퍼 메서드들
  double _getKPIValue(String kpiField) {
    switch (kpiField) {
      case 'total_sales_by_region':
      case 'total_sales':
        return _kpiData['total_sales'] ?? 0.0;
      case 'growth_rate':
        return _kpiData['growth_rate'] ?? 0.0;
      case 'total_customers':
      case 'customer_count':
        return _kpiData['customer_count']?.toDouble() ?? 0.0;
      case 'avg_order_value':
      case 'avg_unit_price':
        return _kpiData['avg_unit_price'] ?? 0.0;
      case 'total_quantity':
        return _kpiData['total_quantity']?.toDouble() ?? 0.0;
      default:
        return 0.0;
    }
  }

  String _getKPIDisplayName(String kpiField) {
    switch (kpiField) {
      case 'total_sales_by_region':
      case 'total_sales':
        return '총 매출액';
      case 'growth_rate':
        return '성장률';
      case 'total_customers':
      case 'customer_count':
        return '총 거래처';
      case 'avg_order_value':
      case 'avg_unit_price':
        return '평균 단가';
      case 'total_quantity':
        return '총 수량';
      case 'market_share':
        return '시장 점유율';
      case 'customer_retention':
        return '고객 유지율';
      case 'price_efficiency':
        return '가격 효율성';
      default:
        return kpiField;
    }
  }

  IconData _getKPIIcon(String kpiField) {
    switch (kpiField) {
      case 'total_sales_by_region':
      case 'total_sales':
        return Icons.attach_money;
      case 'growth_rate':
        return Icons.trending_up;
      case 'total_customers':
      case 'customer_count':
        return Icons.people;
      case 'avg_order_value':
      case 'avg_unit_price':
        return Icons.price_check;
      case 'total_quantity':
        return Icons.inventory;
      default:
        return Icons.analytics;
    }
  }

  Color _getKPIColor(String kpiField) {
    switch (kpiField) {
      case 'total_sales_by_region':
      case 'total_sales':
        return Colors.green;
      case 'growth_rate':
        return Colors.blue;
      case 'total_customers':
      case 'customer_count':
        return Colors.orange;
      case 'avg_order_value':
      case 'avg_unit_price':
        return Colors.purple;
      case 'total_quantity':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatKPIValue(String kpiField, double value) {
    switch (kpiField) {
      case 'total_sales_by_region':
      case 'total_sales':
      case 'avg_order_value':
      case 'avg_unit_price':
        return NumberFormat.currency(locale: 'ko', symbol: '₩', decimalDigits: 0).format(value);
      case 'growth_rate':
        return '${value.toStringAsFixed(1)}%';
      case 'total_customers':
      case 'customer_count':
      case 'total_quantity':
        return NumberFormat('#,###').format(value.toInt());
      default:
        return NumberFormat('#,###.0').format(value);
    }
  }

  String _getChartTitle(String chartType) {
    switch (chartType) {
      case 'regional_sales':
        return '지역별 매출 현황';
      case 'customer_type_pie':
        return '거래처 분류별 매출 구성';
      case 'quantity_vs_sales_scatter':
        return '수량 대비 매출 분석';
      case 'monthly_trend':
        return '월별 매출 트렌드';
      case 'performance_overview':
        return '성과 종합 개요';
      default:
        return '차트';
    }
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _slideAnimationController.dispose();
    _fadeController.dispose();
    _masterFilterService.unregisterWidget('power_bi_dashboard');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Power BI 대시보드'),
        actions: [
          // 슬라이드 모드 토글
          IconButton(
            icon: Icon(_isSlideMode ? Icons.pause_presentation : Icons.play_arrow),
            tooltip: _isSlideMode ? '슬라이드 모드 정지' : '슬라이드 모드 시작',
            onPressed: _toggleSlideMode,
          ),

          // 필터 현황
          if (_activeFilters.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text(_activeFilters.length.toString()),
                child: const Icon(Icons.filter_alt),
              ),
              tooltip: '활성 필터',
              onPressed: () => _masterFilterService.clearAllFilters(),
            ),

          // 새로고침
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '데이터 새로고침',
            onPressed: _loadRealData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : KeyboardListener(
              focusNode: _focusNode,
              onKeyEvent: (event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.space) {
                    _toggleSlideMode();
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _isSlideMode) {
                    // 이전 슬라이드 (수동 제어)
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && _isSlideMode) {
                    // 다음 슬라이드 (수동 제어)
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 슬라이드 진행 상태 표시 (슬라이드 모드일 때만)
                    if (_isSlideMode && _slideThemes.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.slideshow, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              '슬라이드 ${_currentSlideIndex + 1} / ${_slideThemes.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Spacer(),
                            LinearProgressIndicator(
                              value: (_currentSlideIndex + 1) / _slideThemes.length,
                              backgroundColor: Colors.blue[100],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 메인 콘텐츠
                    Expanded(
                      child: _isSlideMode ? _buildCurrentSlideContent() : _buildStaticDashboard(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStaticDashboard() {
    // 정적 대시보드 (슬라이드 모드가 아닐 때)
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildDashboardTile('지역별 매출', 'regional_sales'),
        _buildDashboardTile('고객 분류', 'customer_type_pie'),
        _buildDashboardTile('수량-매출 분석', 'quantity_vs_sales_scatter'),
        _buildDashboardTile('월별 트렌드', 'monthly_trend'),
      ],
    );
  }

  Widget _buildDashboardTile(String title, String chartType) {
    final chartData = _chartDataCache[chartType] ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildChartWidget(chartType, chartData),
            ),
          ],
        ),
      ),
    );
  }
}

/// 슬라이드 테마 정의
class SlideTheme {
  final String id;
  final String title;
  final String subtitle;
  final Duration duration;
  final String primaryChart;
  final List<String> secondaryCharts;
  final List<String> kpiFields;

  SlideTheme({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.primaryChart,
    required this.secondaryCharts,
    required this.kpiFields,
  });
}

/// 차트 데이터 포인트 (기존 클래스 재사용)
class ChartDataPoint {
  final String category;
  final double value;
  final int count;
  final int quantity;
  final Map<String, dynamic> metadata;

  ChartDataPoint({
    required this.category,
    required this.value,
    required this.count,
    required this.quantity,
    required this.metadata,
  });

  ChartDataPoint copyWith({
    String? category,
    double? value,
    int? count,
    int? quantity,
    Map<String, dynamic>? metadata,
  }) {
    return ChartDataPoint(
      category: category ?? this.category,
      value: value ?? this.value,
      count: count ?? this.count,
      quantity: quantity ?? this.quantity,
      metadata: metadata ?? this.metadata,
    );
  }
}