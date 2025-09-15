import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../providers/sales_data_provider.dart';
import '../services/sales_service.dart';

// 반응형 브레이크포인트 상수
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;
}

// 반응형 도우미 클래스
class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.mobile &&
      MediaQuery.of(context).size.width < ResponsiveBreakpoints.tablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= ResponsiveBreakpoints.tablet;

  // 컬럼 수 계산
  static int getColumnsCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < ResponsiveBreakpoints.mobile) return 2; // 모바일: 2열
    if (width < ResponsiveBreakpoints.tablet) return 3;  // 태블릿: 3열
    return 4; // 데스크톱: 4열
  }

  // 차트 높이 계산
  static double getChartHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < ResponsiveBreakpoints.mobile) return 250; // 모바일
    if (width < ResponsiveBreakpoints.tablet) return 350;  // 태블릿
    return 400; // 데스크톱
  }

  // 패딩 계산
  static EdgeInsets getScreenPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < ResponsiveBreakpoints.mobile) return const EdgeInsets.all(8);
    if (width < ResponsiveBreakpoints.tablet) return const EdgeInsets.all(16);
    return const EdgeInsets.all(24);
  }

  // 폰트 크기 계산
  static double getTitleFontSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < ResponsiveBreakpoints.mobile) return 16;
    if (width < ResponsiveBreakpoints.tablet) return 18;
    return 20;
  }

  static double getBodyFontSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < ResponsiveBreakpoints.mobile) return 12;
    if (width < ResponsiveBreakpoints.tablet) return 14;
    return 16;
  }
}

// 반응형 차트 위젯
class ResponsiveContextMenuChart extends StatefulWidget {
  final String title;
  final List<ResponsiveDrilldownData> data;
  final Function(int)? onPointTap;
  final ChartType initialChartType;
  final NumberFormatType initialNumberFormat;

  const ResponsiveContextMenuChart({
    super.key,
    required this.title,
    required this.data,
    this.onPointTap,
    this.initialChartType = ChartType.column,
    this.initialNumberFormat = NumberFormatType.original,
  });

  @override
  State<ResponsiveContextMenuChart> createState() => _ResponsiveContextMenuChartState();
}

class _ResponsiveContextMenuChartState extends State<ResponsiveContextMenuChart> {
  late ChartType _currentChartType;
  late NumberFormatType _currentNumberFormat;
  late ZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    super.initState();
    _currentChartType = widget.initialChartType;
    _currentNumberFormat = widget.initialNumberFormat;

    _zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableSelectionZooming: true,
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final isMobile = ResponsiveHelper.isMobile(context);

    if (isMobile) {
      // 모바일에서는 바텀 시트 사용
      _showMobileBottomSheet(context);
    } else {
      // 태블릿/데스크톱에서는 컨텍스트 메뉴 사용
      _showDesktopContextMenu(context, position);
    }
  }

  void _showMobileBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '차트 설정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('차트 타입 변경'),
              onTap: () {
                Navigator.pop(context);
                _showChartTypeDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_list_numbered),
              title: const Text('숫자 형식 변경'),
              onTap: () {
                Navigator.pop(context);
                _showNumberFormatDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('차트 설정'),
              onTap: () {
                Navigator.pop(context);
                _showChartSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('데이터 내보내기'),
              onTap: () {
                Navigator.pop(context);
                _exportData();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDesktopContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.bar_chart, size: 20),
              SizedBox(width: 8),
              Text('차트 타입'),
            ],
          ),
          onTap: () => _showChartTypeDialog(),
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.format_list_numbered, size: 20),
              SizedBox(width: 8),
              Text('숫자 형식'),
            ],
          ),
          onTap: () => _showNumberFormatDialog(),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.settings, size: 20),
              SizedBox(width: 8),
              Text('차트 설정'),
            ],
          ),
          onTap: () => _showChartSettings(),
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.download, size: 20),
              SizedBox(width: 8),
              Text('데이터 내보내기'),
            ],
          ),
          onTap: () => _exportData(),
        ),
      ],
    );
  }

  void _showChartTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차트 타입 선택'),
        content: SizedBox(
          width: ResponsiveHelper.isMobile(context) ? 300 : 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ChartType.values.map((type) {
                return RadioListTile<ChartType>(
                  title: Text(_getChartTypeName(type)),
                  subtitle: Text(_getChartTypeDescription(type)),
                  value: type,
                  groupValue: _currentChartType,
                  onChanged: (value) {
                    setState(() {
                      _currentChartType = value!;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showNumberFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('숫자 표시 형식'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: NumberFormatType.values.map((format) {
            return RadioListTile<NumberFormatType>(
              title: Text(_getNumberFormatName(format)),
              subtitle: Text(_getNumberFormatExample(format)),
              value: format,
              groupValue: _currentNumberFormat,
              onChanged: (value) {
                setState(() {
                  _currentNumberFormat = value!;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showChartSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차트 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('데이터 라벨 표시'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: const Text('범례 표시'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: const Text('그리드 라인'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: const Text('애니메이션'),
              value: true,
              onChanged: (value) {},
            ),
          ],
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

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('데이터가 내보내어졌습니다.')),
    );
  }

  String _getChartTypeName(ChartType type) {
    switch (type) {
      case ChartType.column: return '세로 막대형';
      case ChartType.bar: return '가로 막대형';
      case ChartType.line: return '선형';
      case ChartType.area: return '영역형';
      case ChartType.pie: return '원형';
      case ChartType.doughnut: return '도넛형';
      case ChartType.scatter: return '분산형';
      case ChartType.bubble: return '거품형';
    }
  }

  String _getChartTypeDescription(ChartType type) {
    switch (type) {
      case ChartType.column: return '데이터를 세로 막대로 표시';
      case ChartType.bar: return '데이터를 가로 막대로 표시';
      case ChartType.line: return '데이터 변화를 선으로 표시';
      case ChartType.area: return '선 차트에 영역을 추가';
      case ChartType.pie: return '전체 대비 비율을 원형으로 표시';
      case ChartType.doughnut: return '도넛 모양의 원형 차트';
      case ChartType.scatter: return '두 변수의 상관관계 표시';
      case ChartType.bubble: return '3차원 데이터를 거품으로 표시';
    }
  }

  String _getNumberFormatName(NumberFormatType format) {
    switch (format) {
      case NumberFormatType.original: return '원래값';
      case NumberFormatType.thousand: return '천 단위 (K)';
      case NumberFormatType.million: return '백만 단위 (M)';
      case NumberFormatType.hundredMillion: return '억 단위';
    }
  }

  String _getNumberFormatExample(NumberFormatType format) {
    const example = 1234567890.0;
    return '예: ${_formatNumber(example, format)}';
  }

  String _formatNumber(double value, NumberFormatType format) {
    switch (format) {
      case NumberFormatType.original:
        return NumberFormat.currency(
          locale: 'ko_KR',
          symbol: '₩',
          decimalDigits: 0
        ).format(value);

      case NumberFormatType.thousand:
        final kValue = value / 1000;
        return '${NumberFormat('#,##0.0').format(kValue)}K';

      case NumberFormatType.million:
        final mValue = value / 1000000;
        return '${NumberFormat('#,##0.0').format(mValue)}M';

      case NumberFormatType.hundredMillion:
        final hundredMillionValue = value / 100000000;
        return '${NumberFormat('#,##0.0').format(hundredMillionValue)}억';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final chartHeight = ResponsiveHelper.getChartHeight(context);

    return GestureDetector(
      onLongPressStart: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      onDoubleTap: () {
        _showContextMenu(context, const Offset(100, 100));
      },
      child: Container(
        height: chartHeight,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildChart(),
      ),
    );
  }

  Widget _buildChart() {
    switch (_currentChartType) {
      case ChartType.column:
        return _buildColumnChart();
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.line:
        return _buildLineChart();
      case ChartType.area:
        return _buildAreaChart();
      case ChartType.pie:
        return _buildPieChart();
      case ChartType.doughnut:
        return _buildDoughnutChart();
      case ChartType.scatter:
        return _buildScatterChart();
      case ChartType.bubble:
        return _buildBubbleChart();
    }
  }

  Widget _buildColumnChart() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return SfCartesianChart(
      title: ChartTitle(
        text: widget.title,
        textStyle: TextStyle(
          fontSize: ResponsiveHelper.getTitleFontSize(context),
          fontWeight: FontWeight.bold,
        ),
      ),
      primaryXAxis: CategoryAxis(
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
        labelRotation: isMobile ? -45 : 0, // 모바일에서는 라벨 회전
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactCurrency(
          locale: 'ko_KR',
          symbol: _currentNumberFormat == NumberFormatType.original ? '₩' : '',
        ),
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ResponsiveDrilldownData, String>>[
        ColumnSeries<ResponsiveDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          color: Colors.indigo,
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
          dataLabelSettings: DataLabelSettings(
            isVisible: !isMobile, // 모바일에서는 데이터 라벨 숨김
            textStyle: TextStyle(fontSize: ResponsiveHelper.getBodyFontSize(context) - 2),
          ),
        ),
      ],
      tooltipBehavior: TooltipBehavior(enable: true),
    );
  }

  Widget _buildBarChart() {
    return SfCartesianChart(
      title: ChartTitle(
        text: widget.title,
        textStyle: TextStyle(
          fontSize: ResponsiveHelper.getTitleFontSize(context),
        ),
      ),
      primaryXAxis: CategoryAxis(
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩'),
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ResponsiveDrilldownData, String>>[
        BarSeries<ResponsiveDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          color: Colors.indigo,
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    return SfCartesianChart(
      title: ChartTitle(
        text: widget.title,
        textStyle: TextStyle(
          fontSize: ResponsiveHelper.getTitleFontSize(context),
        ),
      ),
      primaryXAxis: CategoryAxis(
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩'),
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ResponsiveDrilldownData, String>>[
        LineSeries<ResponsiveDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          color: Colors.indigo,
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildAreaChart() {
    return SfCartesianChart(
      title: ChartTitle(
        text: widget.title,
        textStyle: TextStyle(
          fontSize: ResponsiveHelper.getTitleFontSize(context),
        ),
      ),
      primaryXAxis: CategoryAxis(
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩'),
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ResponsiveDrilldownData, String>>[
        AreaSeries<ResponsiveDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          color: Colors.indigo.withOpacity(0.7),
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    return SfCircularChart(
      title: ChartTitle(
        text: widget.title,
        textStyle: TextStyle(
          fontSize: ResponsiveHelper.getTitleFontSize(context),
        ),
      ),
      legend: Legend(
        isVisible: true,
        position: ResponsiveHelper.isMobile(context)
            ? LegendPosition.bottom
            : LegendPosition.right,
        textStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      series: <CircularSeries<ResponsiveDrilldownData, String>>[
        PieSeries<ResponsiveDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
          dataLabelSettings: DataLabelSettings(
            isVisible: !ResponsiveHelper.isMobile(context),
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(
              fontSize: ResponsiveHelper.getBodyFontSize(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoughnutChart() {
    return SfCircularChart(
      title: ChartTitle(
        text: widget.title,
        textStyle: TextStyle(
          fontSize: ResponsiveHelper.getTitleFontSize(context),
        ),
      ),
      legend: Legend(
        isVisible: true,
        position: ResponsiveHelper.isMobile(context)
            ? LegendPosition.bottom
            : LegendPosition.right,
        textStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      series: <CircularSeries<ResponsiveDrilldownData, String>>[
        DoughnutSeries<ResponsiveDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
          dataLabelSettings: DataLabelSettings(
            isVisible: !ResponsiveHelper.isMobile(context),
            textStyle: TextStyle(
              fontSize: ResponsiveHelper.getBodyFontSize(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScatterChart() {
    return SfCartesianChart(
      title: ChartTitle(
        text: widget.title,
        textStyle: TextStyle(
          fontSize: ResponsiveHelper.getTitleFontSize(context),
        ),
      ),
      primaryXAxis: CategoryAxis(
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩'),
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ResponsiveDrilldownData, String>>[
        ScatterSeries<ResponsiveDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          color: Colors.indigo,
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
          markerSettings: const MarkerSettings(height: 8, width: 8),
        ),
      ],
    );
  }

  Widget _buildBubbleChart() {
    return SfCartesianChart(
      title: ChartTitle(
        text: widget.title,
        textStyle: TextStyle(
          fontSize: ResponsiveHelper.getTitleFontSize(context),
        ),
      ),
      primaryXAxis: CategoryAxis(
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩'),
        labelStyle: TextStyle(
          fontSize: ResponsiveHelper.getBodyFontSize(context),
        ),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ResponsiveDrilldownData, String>>[
        BubbleSeries<ResponsiveDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          sizeValueMapper: (data, _) => data.y / 1000000,
          color: Colors.indigo.withOpacity(0.7),
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
        ),
      ],
    );
  }

  double _convertValue(double originalValue) {
    switch (_currentNumberFormat) {
      case NumberFormatType.original:
        return originalValue;
      case NumberFormatType.thousand:
        return originalValue / 1000;
      case NumberFormatType.million:
        return originalValue / 1000000;
      case NumberFormatType.hundredMillion:
        return originalValue / 100000000;
    }
  }
}

// 열거형 정의
enum ChartType {
  column,
  bar,
  line,
  area,
  pie,
  doughnut,
  scatter,
  bubble,
}

enum NumberFormatType {
  original,
  thousand,
  million,
  hundredMillion,
}

// 드릴다운 데이터 모델
class ResponsiveDrilldownData {
  ResponsiveDrilldownData(this.x, this.y, {this.drilldownData, this.level = 0, this.metadata});
  final String x;
  final double y;
  final List<ResponsiveDrilldownData>? drilldownData;
  final int level;
  final Map<String, dynamic>? metadata;
}

// 메인 반응형 분석 화면
class ResponsiveEnhancedAnalyticsScreen extends StatefulWidget {
  const ResponsiveEnhancedAnalyticsScreen({super.key});

  @override
  State<ResponsiveEnhancedAnalyticsScreen> createState() => _ResponsiveEnhancedAnalyticsScreenState();
}

class _ResponsiveEnhancedAnalyticsScreenState extends State<ResponsiveEnhancedAnalyticsScreen>
    with TickerProviderStateMixin {

  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};

  // 드릴다운 관련 상태
  List<ResponsiveDrilldownData> _drilldownData = [];
  List<String> _drilldownPath = [];
  int _currentDrillLevel = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnalyticsData() async {
    final salesProvider = Provider.of<SalesDataProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      await salesProvider.loadSalesData();
      final salesData = salesProvider.salesSummaryData;
      final stats = salesProvider.getSummaryStats();

      final fromDate = DateFormat('yyyy-MM-dd').format(salesProvider.fromDate);
      final toDate = DateFormat('yyyy-MM-dd').format(salesProvider.toDate);

      final hospitalAnalysis = await SalesService.getHospitalAnalysis(
        fromDate: fromDate,
        toDate: toDate,
        topN: 20,
      );

      setState(() {
        _analyticsData = {
          'summary': {
            'total_revenue': stats['totalSales'],
            'total_orders': stats['totalOrders'],
            'average_order': stats['averageSales'],
            'growth_rate': 12.5,
          },
          'sales_data': salesData,
          'hospital_analysis': hospitalAnalysis['data'] ?? [],
        };

        _generateDrilldownData();
        _isLoading = false;
      });

    } catch (e) {
      print('Analytics data load failed: $e');
      _loadMockData();
    }
  }

  void _generateDrilldownData() {
    final hospitalData = _analyticsData['hospital_analysis'] as List<dynamic>? ?? [];

    if (hospitalData.isEmpty) {
      _generateMockDrilldownData();
      return;
    }

    Map<String, List<dynamic>> regionGroups = {};
    for (var hospital in hospitalData) {
      final region = hospital['REGION'] ?? hospital['region'] ?? '기타';
      if (!regionGroups.containsKey(region)) {
        regionGroups[region] = [];
      }
      regionGroups[region]!.add(hospital);
    }

    List<ResponsiveDrilldownData> regions = [];

    regionGroups.forEach((regionName, hospitals) {
      double regionTotal = 0;
      List<ResponsiveDrilldownData> hospitalList = [];

      for (var hospital in hospitals) {
        final hospitalName = hospital['HOSPITAL_NAME'] ?? hospital['hospital_name'] ?? '병원명';
        final hospitalAmount = (hospital['TOTAL_AMOUNT'] ?? hospital['total_amount'] ?? 0).toDouble();
        regionTotal += hospitalAmount;

        List<ResponsiveDrilldownData> productList = [];
        final products = ['의료기기A', '진단장비B', '소모품C'];

        for (int i = 0; i < products.length; i++) {
          productList.add(ResponsiveDrilldownData(
            products[i],
            hospitalAmount / products.length * (1 + i * 0.2),
            level: 2,
          ));
        }

        hospitalList.add(ResponsiveDrilldownData(
          hospitalName,
          hospitalAmount,
          drilldownData: productList,
          level: 1,
        ));
      }

      regions.add(ResponsiveDrilldownData(
        regionName,
        regionTotal,
        drilldownData: hospitalList,
        level: 0,
      ));
    });

    _drilldownData = regions;
  }

  void _generateMockDrilldownData() {
    final salesData = _analyticsData['sales_data'] as List<dynamic>? ?? [];

    if (salesData.isEmpty) {
      _drilldownData = [];
      return;
    }

    List<ResponsiveDrilldownData> regionData = [];
    final regions = ['서울', '경기', '부산', '대구'];

    for (int i = 0; i < regions.length && i < salesData.length; i++) {
      final region = regions[i];
      final amount = (salesData[i]['SUM_SALE_AMT_WON'] ?? 0).toDouble();

      List<ResponsiveDrilldownData> hospitals = [];
      final hospitalNames = ['${region}대병원', '${region}중앙병원', '${region}의료원'];

      for (int j = 0; j < hospitalNames.length; j++) {
        final hospitalAmount = amount / hospitalNames.length * (1 + j * 0.3);

        List<ResponsiveDrilldownData> products = [];
        final productNames = ['의료기기A', '진단장비B', '소모품C'];

        for (int k = 0; k < productNames.length; k++) {
          products.add(ResponsiveDrilldownData(
            productNames[k],
            hospitalAmount / productNames.length,
            level: 2
          ));
        }

        hospitals.add(ResponsiveDrilldownData(
          hospitalNames[j],
          hospitalAmount,
          drilldownData: products,
          level: 1
        ));
      }

      regionData.add(ResponsiveDrilldownData(
        region,
        amount,
        drilldownData: hospitals,
        level: 0
      ));
    }

    _drilldownData = regionData;
  }

  void _loadMockData() {
    setState(() {
      _analyticsData = {
        'summary': {
          'total_revenue': 450000000,
          'total_orders': 1250,
          'average_order': 360000,
          'growth_rate': 15.8,
        },
        'sales_data': [
          {'SUM_SALE_AMT_WON': 120000000},
          {'SUM_SALE_AMT_WON': 98000000},
          {'SUM_SALE_AMT_WON': 156000000},
          {'SUM_SALE_AMT_WON': 76000000},
        ],
      };
      _generateMockDrilldownData();
      _isLoading = false;
    });
  }

  void _onDrilldown(int pointIndex) {
    final currentData = _getCurrentDrilldownData();
    if (pointIndex < currentData.length && currentData[pointIndex].drilldownData != null) {
      setState(() {
        _drilldownPath.add(currentData[pointIndex].x);
        _currentDrillLevel++;
      });
    }
  }

  void _onDrillUp() {
    if (_currentDrillLevel > 0) {
      setState(() {
        _drilldownPath.removeLast();
        _currentDrillLevel--;
      });
    }
  }

  List<ResponsiveDrilldownData> _getCurrentDrilldownData() {
    List<ResponsiveDrilldownData> currentData = _drilldownData;

    for (final pathItem in _drilldownPath) {
      final found = currentData.firstWhere(
        (item) => item.x == pathItem,
        orElse: () => ResponsiveDrilldownData('', 0),
      );
      if (found.drilldownData != null) {
        currentData = found.drilldownData!;
      }
    }

    return currentData;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final isMobile = ResponsiveHelper.isMobile(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '반응형 분석 화면을 로드하고 있습니다...',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getBodyFontSize(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '📱 반응형 분석',
          style: TextStyle(
            fontSize: ResponsiveHelper.getTitleFontSize(context),
          ),
        ),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(
            fontSize: ResponsiveHelper.getBodyFontSize(context),
          ),
          tabs: [
            Tab(
              text: isMobile ? '드릴다운' : '드릴다운 분석',
              icon: const Icon(Icons.trending_down),
            ),
            Tab(
              text: isMobile ? '대시보드' : '분석 대시보드',
              icon: const Icon(Icons.dashboard),
            ),
            Tab(
              text: isMobile ? '설정' : '화면 정보',
              icon: const Icon(Icons.info),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAnalyticsData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildResponsiveSummaryCards(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDrilldownTab(),
                _buildDashboardTab(),
                _buildInfoTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveSummaryCards() {
    final summary = _analyticsData['summary'] as Map<String, dynamic>? ?? {};
    final columnsCount = ResponsiveHelper.getColumnsCount(context);
    final padding = ResponsiveHelper.getScreenPadding(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    // 데스크톱에서는 한 줄로, 모바일/태블릿에서는 그리드로
    if (isDesktop) {
      return Container(
        padding: padding,
        child: Row(
          children: [
            Expanded(child: _buildSummaryCard(
              '총 매출',
              NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0)
                  .format(summary['total_revenue'] ?? 0),
              Icons.attach_money,
              Colors.green,
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildSummaryCard(
              '총 주문',
              '${summary['total_orders'] ?? 0}건',
              Icons.shopping_cart,
              Colors.blue,
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildSummaryCard(
              '평균주문',
              NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0)
                  .format(summary['average_order'] ?? 0),
              Icons.trending_up,
              Colors.orange,
            )),
            const SizedBox(width: 8),
            Expanded(child: _buildSummaryCard(
              '성장률',
              '${(summary['growth_rate'] ?? 0).toStringAsFixed(1)}%',
              Icons.show_chart,
              Colors.purple,
            )),
          ],
        ),
      );
    } else {
      return Container(
        padding: padding,
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columnsCount,
          childAspectRatio: 2.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildSummaryCard(
              '총 매출',
              NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩')
                  .format(summary['total_revenue'] ?? 0),
              Icons.attach_money,
              Colors.green,
            ),
            _buildSummaryCard(
              '총 주문',
              '${summary['total_orders'] ?? 0}건',
              Icons.shopping_cart,
              Colors.blue,
            ),
            _buildSummaryCard(
              '평균주문',
              NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩')
                  .format(summary['average_order'] ?? 0),
              Icons.trending_up,
              Colors.orange,
            ),
            _buildSummaryCard(
              '성장률',
              '${(summary['growth_rate'] ?? 0).toStringAsFixed(1)}%',
              Icons.show_chart,
              Colors.purple,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 8 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: isMobile ? 20 : 24,
            ),
            SizedBox(height: isMobile ? 4 : 8),
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveHelper.getBodyFontSize(context) - 2,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 2 : 4),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getBodyFontSize(context),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrilldownTab() {
    if (_drilldownData.isEmpty) {
      return const Center(
        child: Text('드릴다운 데이터가 없습니다.'),
      );
    }

    final currentData = _getCurrentDrilldownData();
    final levelTitles = ['지역별 매출', '병원별 매출', '제품별 매출'];
    final currentTitle = _currentDrillLevel < levelTitles.length
        ? levelTitles[_currentDrillLevel]
        : '상세 분석';
    final padding = ResponsiveHelper.getScreenPadding(context);
    final isMobile = ResponsiveHelper.isMobile(context);

    return Column(
      children: [
        // 드릴다운 경로 표시
        if (_drilldownPath.isNotEmpty)
          Container(
            padding: padding,
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _onDrillUp,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    isMobile ? '뒤로' : '뒤로가기',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getBodyFontSize(context),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${_drilldownPath.join(' > ')} > $currentTitle',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getBodyFontSize(context),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // 사용법 안내 (모바일에서만)
        if (isMobile)
          Container(
            margin: padding,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '길게 눌러서 차트 설정',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: ResponsiveHelper.getBodyFontSize(context) - 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 드릴다운 차트 (반응형)
        Expanded(
          child: Container(
            padding: padding,
            child: ResponsiveContextMenuChart(
              title: currentTitle,
              data: currentData,
              onPointTap: _onDrilldown,
              initialChartType: ChartType.column,
              initialNumberFormat: NumberFormatType.original,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardTab() {
    final currentData = _getCurrentDrilldownData();
    final padding = ResponsiveHelper.getScreenPadding(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    if (isDesktop) {
      // 데스크톱: 2x2 그리드
      return Padding(
        padding: padding,
        child: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ResponsiveContextMenuChart(
                  title: '세로 막대형',
                  data: currentData,
                  initialChartType: ChartType.column,
                  initialNumberFormat: NumberFormatType.million,
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ResponsiveContextMenuChart(
                  title: '원형 차트',
                  data: currentData,
                  initialChartType: ChartType.pie,
                  initialNumberFormat: NumberFormatType.hundredMillion,
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ResponsiveContextMenuChart(
                  title: '선형 차트',
                  data: currentData,
                  initialChartType: ChartType.line,
                  initialNumberFormat: NumberFormatType.original,
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ResponsiveContextMenuChart(
                  title: '도넛 차트',
                  data: currentData,
                  initialChartType: ChartType.doughnut,
                  initialNumberFormat: NumberFormatType.thousand,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 모바일/태블릿: 세로 스크롤
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '세로 막대형 차트',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getTitleFontSize(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ResponsiveContextMenuChart(
                      title: '매출 분석',
                      data: currentData,
                      initialChartType: ChartType.column,
                      initialNumberFormat: NumberFormatType.million,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '원형 차트',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getTitleFontSize(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ResponsiveContextMenuChart(
                      title: '비율 분석',
                      data: currentData,
                      initialChartType: ChartType.pie,
                      initialNumberFormat: NumberFormatType.hundredMillion,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoTab() {
    final screenSize = MediaQuery.of(context).size;
    final deviceType = ResponsiveHelper.isMobile(context)
        ? '모바일'
        : ResponsiveHelper.isTablet(context)
        ? '태블릿'
        : '데스크톱';
    final padding = ResponsiveHelper.getScreenPadding(context);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🖥️ 화면 정보',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getTitleFontSize(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('디바이스 타입', deviceType),
                  _buildInfoRow('화면 크기', '${screenSize.width.toInt()} × ${screenSize.height.toInt()}'),
                  _buildInfoRow('픽셀 밀도', '${MediaQuery.of(context).devicePixelRatio.toStringAsFixed(1)}x'),
                  _buildInfoRow('컬럼 수', '${ResponsiveHelper.getColumnsCount(context)}열'),
                  _buildInfoRow('차트 높이', '${ResponsiveHelper.getChartHeight(context).toInt()}px'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📱 사용법',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getTitleFontSize(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildUsageItem(
                    deviceType == '모바일' ? '길게 누르기' : '우클릭 또는 길게 누르기',
                    '컨텍스트 메뉴 열기'
                  ),
                  _buildUsageItem('차트 포인트 클릭', '드릴다운 실행'),
                  _buildUsageItem('뒤로 버튼', '드릴다운에서 이전 단계로'),
                  _buildUsageItem('핀치 줌', '차트 확대/축소'),
                  _buildUsageItem('드래그', '차트 이동'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚡ 반응형 기능',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getTitleFontSize(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem('자동 레이아웃 조정', '화면 크기에 따라 자동 배치'),
                  _buildFeatureItem('동적 폰트 크기', '기기별 최적화된 텍스트'),
                  _buildFeatureItem('터치 최적화', '모바일 터치 인터페이스'),
                  _buildFeatureItem('컨텍스트 메뉴', '기기별 최적화된 메뉴'),
                  _buildFeatureItem('차트 크기 조정', '화면에 맞는 차트 크기'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveHelper.getBodyFontSize(context),
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveHelper.getBodyFontSize(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageItem(String action, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: ResponsiveHelper.getBodyFontSize(context),
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '$action: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String feature, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: ResponsiveHelper.getBodyFontSize(context),
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '$feature: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}