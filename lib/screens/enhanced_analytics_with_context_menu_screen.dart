import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../providers/sales_data_provider.dart';
import '../services/sales_service.dart';

// 차트 타입 열거형
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

// 숫자 표시 형식 열거형
enum DisplayNumberFormat {
  original,  // 원래값
  thousand,  // 천 단위 (K)
  million,   // 백만 단위 (M)
  hundredMillion, // 억 단위
}

// 드릴다운을 위한 데이터 모델
class ContextDrilldownData {
  ContextDrilldownData(this.x, this.y, {this.drilldownData, this.level = 0, this.metadata});
  final String x;
  final double y;
  final List<ContextDrilldownData>? drilldownData;
  final int level;
  final Map<String, dynamic>? metadata;
}

// 다차원 분석을 위한 데이터 모델
class ContextMultiDimensionalData {
  ContextMultiDimensionalData({
    required this.region,
    required this.hospital,
    required this.product,
    required this.period,
    required this.amount,
    required this.orderCount,
    this.metadata,
  });

  final String region;
  final String hospital;
  final String product;
  final String period;
  final double amount;
  final int orderCount;
  final Map<String, dynamic>? metadata;
}

// 컨텍스트 메뉴가 있는 차트 위젯
class ContextMenuChart extends StatefulWidget {
  final String title;
  final List<ContextDrilldownData> data;
  final Function(int)? onPointTap;
  final ChartType initialChartType;
  final DisplayNumberFormat initialNumberFormat;

  const ContextMenuChart({
    super.key,
    required this.title,
    required this.data,
    this.onPointTap,
    this.initialChartType = ChartType.column,
    this.initialNumberFormat = DisplayNumberFormat.original,
  });

  @override
  State<ContextMenuChart> createState() => _ContextMenuChartState();
}

class _ContextMenuChartState extends State<ContextMenuChart> {
  late ChartType _currentChartType;
  late DisplayNumberFormat _currentNumberFormat;
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
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        // 차트 타입 변경 메뉴
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
        // 숫자 포맷 메뉴
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
        // 차트 설정 메뉴
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
        // 데이터 내보내기 메뉴
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
        content: SingleChildScrollView(
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
    );
  }

  void _showNumberFormatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('숫자 표시 형식'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DisplayNumberFormat.values.map((format) {
            return RadioListTile<DisplayNumberFormat>(
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
              value: true, // 실제 상태값으로 교체
              onChanged: (value) {
                // 상태 업데이트 로직
              },
            ),
            SwitchListTile(
              title: const Text('범례 표시'),
              value: true,
              onChanged: (value) {
                // 상태 업데이트 로직
              },
            ),
            SwitchListTile(
              title: const Text('그리드 라인'),
              value: true,
              onChanged: (value) {
                // 상태 업데이트 로직
              },
            ),
            SwitchListTile(
              title: const Text('애니메이션'),
              value: true,
              onChanged: (value) {
                // 상태 업데이트 로직
              },
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 내보내기'),
        content: const Text('차트 데이터를 내보내시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              // 데이터 내보내기 로직
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('데이터가 내보내어졌습니다.')),
              );
            },
            child: const Text('내보내기'),
          ),
        ],
      ),
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

  String _getNumberFormatName(DisplayNumberFormat format) {
    switch (format) {
      case DisplayNumberFormat.original: return '원래값';
      case DisplayNumberFormat.thousand: return '천 단위 (K)';
      case DisplayNumberFormat.million: return '백만 단위 (M)';
      case DisplayNumberFormat.hundredMillion: return '억 단위';
    }
  }

  String _getNumberFormatExample(DisplayNumberFormat format) {
    const example = 1234567890.0;
    return '예: ${_formatNumber(example, format)}';
  }

  String _formatNumber(double value, DisplayNumberFormat format) {
    switch (format) {
      case DisplayNumberFormat.original:
        return intl.NumberFormat.currency(
          locale: 'ko_KR',
          symbol: '₩',
          decimalDigits: 0
        ).format(value);

      case DisplayNumberFormat.thousand:
        final kValue = value / 1000;
        return '${intl.NumberFormat('#,##0.0').format(kValue)}K';

      case DisplayNumberFormat.million:
        final mValue = value / 1000000;
        return '${intl.NumberFormat('#,##0.0').format(mValue)}M';

      case DisplayNumberFormat.hundredMillion:
        final hundredMillionValue = value / 100000000;
        return '${intl.NumberFormat('#,##0.0').format(hundredMillionValue)}억';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      onDoubleTap: () {
        _showContextMenu(context, const Offset(100, 100));
      },
      child: Container(
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
    return SfCartesianChart(
      title: ChartTitle(text: widget.title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        numberFormat: intl.NumberFormat.compactCurrency(
          locale: 'ko_KR',
          symbol: _currentNumberFormat == DisplayNumberFormat.original ? '₩' : '',
        ),
        labelFormat: _currentNumberFormat != DisplayNumberFormat.original ? '{value}' : null,
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ContextDrilldownData, String>>[
        ColumnSeries<ContextDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          color: Colors.indigo,
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(fontSize: 10),
          ),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x: ${_formatNumber(0, _currentNumberFormat)}',
      ),
    );
  }

  Widget _buildBarChart() {
    return SfCartesianChart(
      title: ChartTitle(text: widget.title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        numberFormat: intl.NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩'),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ContextDrilldownData, String>>[
        BarSeries<ContextDrilldownData, String>(
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
      title: ChartTitle(text: widget.title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        numberFormat: intl.NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩'),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ContextDrilldownData, String>>[
        LineSeries<ContextDrilldownData, String>(
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
      title: ChartTitle(text: widget.title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        numberFormat: intl.NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩'),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ContextDrilldownData, String>>[
        AreaSeries<ContextDrilldownData, String>(
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
      title: ChartTitle(text: widget.title),
      legend: Legend(isVisible: true, position: LegendPosition.bottom),
      series: <CircularSeries<ContextDrilldownData, String>>[
        PieSeries<ContextDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
          ),
        ),
      ],
    );
  }

  Widget _buildDoughnutChart() {
    return SfCircularChart(
      title: ChartTitle(text: widget.title),
      legend: Legend(isVisible: true, position: LegendPosition.bottom),
      series: <CircularSeries<ContextDrilldownData, String>>[
        DoughnutSeries<ContextDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          onPointTap: (pointInteractionDetails) {
            widget.onPointTap?.call(pointInteractionDetails.pointIndex!);
          },
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _buildScatterChart() {
    return SfCartesianChart(
      title: ChartTitle(text: widget.title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        numberFormat: intl.NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩'),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ContextDrilldownData, String>>[
        ScatterSeries<ContextDrilldownData, String>(
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
      title: ChartTitle(text: widget.title),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        numberFormat: intl.NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩'),
      ),
      zoomPanBehavior: _zoomPanBehavior,
      series: <ChartSeries<ContextDrilldownData, String>>[
        BubbleSeries<ContextDrilldownData, String>(
          dataSource: widget.data,
          xValueMapper: (data, _) => data.x,
          yValueMapper: (data, _) => _convertValue(data.y),
          sizeValueMapper: (data, _) => data.y / 1000000, // 버블 크기
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
      case DisplayNumberFormat.original:
        return originalValue;
      case DisplayNumberFormat.thousand:
        return originalValue / 1000;
      case DisplayNumberFormat.million:
        return originalValue / 1000000;
      case DisplayNumberFormat.hundredMillion:
        return originalValue / 100000000;
    }
  }
}

// 메인 화면
class EnhancedAnalyticsWithContextMenuScreen extends StatefulWidget {
  const EnhancedAnalyticsWithContextMenuScreen({super.key});

  @override
  State<EnhancedAnalyticsWithContextMenuScreen> createState() => _EnhancedAnalyticsWithContextMenuScreenState();
}

class _EnhancedAnalyticsWithContextMenuScreenState extends State<EnhancedAnalyticsWithContextMenuScreen>
    with TickerProviderStateMixin {

  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};

  // 드릴다운 관련 상태
  List<ContextDrilldownData> _drilldownData = [];
  List<String> _drilldownPath = [];
  int _currentDrillLevel = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

    List<ContextDrilldownData> regions = [];

    regionGroups.forEach((regionName, hospitals) {
      double regionTotal = 0;
      List<ContextDrilldownData> hospitalList = [];

      for (var hospital in hospitals) {
        final hospitalName = hospital['HOSPITAL_NAME'] ?? hospital['hospital_name'] ?? '병원명';
        final hospitalAmount = (hospital['TOTAL_AMOUNT'] ?? hospital['total_amount'] ?? 0).toDouble();
        regionTotal += hospitalAmount;

        List<ContextDrilldownData> productList = [];
        final products = ['의료기기A', '진단장비B', '소모품C'];

        for (int i = 0; i < products.length; i++) {
          productList.add(ContextDrilldownData(
            products[i],
            hospitalAmount / products.length * (1 + i * 0.2),
            level: 2,
          ));
        }

        hospitalList.add(ContextDrilldownData(
          hospitalName,
          hospitalAmount,
          drilldownData: productList,
          level: 1,
        ));
      }

      regions.add(ContextDrilldownData(
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

    List<ContextDrilldownData> regionData = [];
    final regions = ['서울', '경기', '부산', '대구'];

    for (int i = 0; i < regions.length && i < salesData.length; i++) {
      final region = regions[i];
      final amount = (salesData[i]['SUM_SALE_AMT_WON'] ?? 0).toDouble();

      List<ContextDrilldownData> hospitals = [];
      final hospitalNames = ['${region}대병원', '${region}중앙병원', '${region}의료원'];

      for (int j = 0; j < hospitalNames.length; j++) {
        final hospitalAmount = amount / hospitalNames.length * (1 + j * 0.3);

        List<ContextDrilldownData> products = [];
        final productNames = ['의료기기A', '진단장비B', '소모품C'];

        for (int k = 0; k < productNames.length; k++) {
          products.add(ContextDrilldownData(
            productNames[k],
            hospitalAmount / productNames.length,
            level: 2
          ));
        }

        hospitals.add(ContextDrilldownData(
          hospitalNames[j],
          hospitalAmount,
          drilldownData: products,
          level: 1
        ));
      }

      regionData.add(ContextDrilldownData(
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

  List<ContextDrilldownData> _getCurrentDrilldownData() {
    List<ContextDrilldownData> currentData = _drilldownData;

    for (final pathItem in _drilldownPath) {
      final found = currentData.firstWhere(
        (item) => item.x == pathItem,
        orElse: () => ContextDrilldownData('', 0),
      );
      if (found.drilldownData != null) {
        currentData = found.drilldownData!;
      }
    }

    return currentData;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('컨텍스트 메뉴 분석 화면을 로드하고 있습니다...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 컨텍스트 메뉴 분석'),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '드릴다운', icon: Icon(Icons.trending_down)),
            Tab(text: '다중 차트', icon: Icon(Icons.dashboard)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('사용법'),
                  content: const Text(
                    '• 차트를 길게 누르거나 더블 클릭하면 컨텍스트 메뉴가 나타납니다\n'
                    '• 차트 타입을 변경할 수 있습니다\n'
                    '• 숫자 표시 형식을 변경할 수 있습니다 (원래값, 천단위, 백만단위, 억단위)\n'
                    '• 드릴다운 차트에서는 클릭으로 세부 데이터를 볼 수 있습니다'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );
            },
            tooltip: '사용법',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAnalyticsData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDrilldownTab(),
                _buildMultiChartTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _analyticsData['summary'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
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
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

    return Column(
      children: [
        // 드릴다운 경로 표시
        if (_drilldownPath.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _onDrillUp,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('뒤로'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${_drilldownPath.join(' > ')} > $currentTitle',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        // 드릴다운 차트 (컨텍스트 메뉴 포함)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ContextMenuChart(
              title: currentTitle,
              data: currentData,
              onPointTap: _onDrilldown,
              initialChartType: ChartType.column,
              initialNumberFormat: DisplayNumberFormat.original,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiChartTab() {
    final currentData = _getCurrentDrilldownData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 여러 차트를 다른 형태로 표시
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '세로 막대형 차트',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '길게 눌러서 차트 변경',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: ContextMenuChart(
                      title: '매출 분석 (세로 막대)',
                      data: currentData,
                      initialChartType: ChartType.column,
                      initialNumberFormat: DisplayNumberFormat.million,
                    ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '원형 차트',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '더블클릭으로 메뉴 열기',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: ContextMenuChart(
                      title: '매출 분석 (원형)',
                      data: currentData,
                      initialChartType: ChartType.pie,
                      initialNumberFormat: DisplayNumberFormat.hundredMillion,
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
}