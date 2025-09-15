import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../providers/auth_provider.dart';
import '../providers/sales_data_provider.dart';

// 드릴다운을 위한 데이터 모델
class DrilldownData {
  DrilldownData(this.x, this.y, {this.drilldownData, this.level = 0});
  final String x;
  final double y;
  final List<DrilldownData>? drilldownData;
  final int level;
}

// 다차원 데이터 모델
class MultiDimensionalData {
  MultiDimensionalData(this.region, this.hospital, this.product, this.period, this.value);
  final String region;
  final String hospital;
  final String product;
  final String period;
  final double value;
}

// 피벗 데이터 소스
class PivotDataSource extends DataGridSource {
  List<DataGridRow> _pivotData = [];

  PivotDataSource({required List<Map<String, dynamic>> data}) {
    _pivotData = data
        .map<DataGridRow>((item) => DataGridRow(cells: [
              DataGridCell<String>(columnName: 'region', value: item['region']),
              DataGridCell<String>(columnName: 'hospital', value: item['hospital']),
              DataGridCell<String>(columnName: 'product', value: item['product']),
              DataGridCell<double>(columnName: 'q1', value: item['q1']?.toDouble() ?? 0.0),
              DataGridCell<double>(columnName: 'q2', value: item['q2']?.toDouble() ?? 0.0),
              DataGridCell<double>(columnName: 'q3', value: item['q3']?.toDouble() ?? 0.0),
              DataGridCell<double>(columnName: 'q4', value: item['q4']?.toDouble() ?? 0.0),
              DataGridCell<double>(columnName: 'total', value: item['total']?.toDouble() ?? 0.0),
            ]))
        .toList();
  }

  @override
  List<DataGridRow> get rows => _pivotData;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    return DataGridRowAdapter(
        cells: row.getCells().map<Widget>((cell) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8.0),
        child: Text(
          cell.columnName == 'region' || cell.columnName == 'hospital' || cell.columnName == 'product'
              ? cell.value.toString()
              : NumberFormat('#,###').format(cell.value),
          style: TextStyle(
            fontWeight: cell.columnName == 'total' ? FontWeight.bold : FontWeight.normal,
            color: cell.columnName == 'total' ? Colors.blue : Colors.black87,
          ),
        ),
      );
    }).toList());
  }
}

class EnhancedAnalyticsScreen extends StatefulWidget {
  const EnhancedAnalyticsScreen({super.key});

  @override
  State<EnhancedAnalyticsScreen> createState() => _EnhancedAnalyticsScreenState();
}

class _EnhancedAnalyticsScreenState extends State<EnhancedAnalyticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TooltipBehavior _tooltip;
  late SelectionBehavior _selectionBehavior;
  late ZoomPanBehavior _zoomPanBehavior;

  bool _isLoading = true;
  Map<String, dynamic> _analyticsData = {};
  List<DrilldownData> _drilldownData = [];
  List<MultiDimensionalData> _multiDimData = [];
  late PivotDataSource _pivotDataSource;

  // 필터 상태
  String _selectedRegion = '전체';
  String _selectedPeriod = '2024';
  String _selectedMetric = 'revenue';
  List<String> _selectedHospitals = [];

  // 드릴다운 상태
  List<String> _drilldownPath = [];
  int _currentDrillLevel = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tooltip = TooltipBehavior(enable: true, format: 'point.x : point.y');
    _selectionBehavior = SelectionBehavior(enable: true);
    _zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableSelectionZooming: true,
    );
    _fetchEnhancedAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchEnhancedAnalyticsData() async {
    final salesProvider = Provider.of<SalesDataProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      await salesProvider.loadSalesData();
      final salesData = salesProvider.salesSummaryData;
      final stats = salesProvider.getSummaryStats();

      setState(() {
        _analyticsData = {
          'summary': {
            'total_revenue': stats['totalSales'],
            'total_orders': stats['totalOrders'],
            'average_order': stats['averageSales'],
            'growth_rate': 12.5,
          },
          'sales_data': salesData,
          'period_info': {
            'from': DateFormat('yyyy-MM-dd').format(salesProvider.fromDate),
            'to': DateFormat('yyyy-MM-dd').format(salesProvider.toDate),
          }
        };

        _generateDrilldownData();
        _generateMultiDimensionalData();
        _generatePivotData();
        _isLoading = false;
      });
    } catch (e) {
      print('Enhanced analytics data load failed: $e');
      _loadMockData();
    }
  }

  void _generateDrilldownData() {
    // 지역 → 병원 → 제품 3단계 드릴다운 데이터 생성
    final regions = ['서울', '경기', '부산', '대구', '기타'];
    final hospitals = {
      '서울': ['삼성서울병원', '서울대병원', '연세세브란스', '서울아산병원'],
      '경기': ['분당서울대', '경기도병원', '수원시립병원'],
      '부산': ['부산대병원', '동아대병원', '부산백병원'],
      '대구': ['대구가톨릭대', '계명대병원'],
      '기타': ['전남대병원', '조선대병원', '원광대병원'],
    };
    final products = ['의료기기A', '진단장비B', '소모품C', '치료용품D', '검사용품E'];

    _drilldownData = regions.map((region) {
      final regionValue = (50 + regions.indexOf(region) * 20).toDouble();
      final hospitalData = hospitals[region]!.map((hospital) {
        final hospitalValue = regionValue * (0.1 + hospitals[region]!.indexOf(hospital) * 0.2);
        final productData = products.map((product) {
          return DrilldownData(
            product,
            hospitalValue * (0.1 + products.indexOf(product) * 0.15),
            level: 2,
          );
        }).toList();

        return DrilldownData(
          hospital,
          hospitalValue,
          drilldownData: productData,
          level: 1,
        );
      }).toList();

      return DrilldownData(
        region,
        regionValue,
        drilldownData: hospitalData,
        level: 0,
      );
    }).toList();
  }

  void _generateMultiDimensionalData() {
    // 4차원 데이터 생성: 지역 × 병원 × 제품 × 시간
    final regions = ['서울', '경기', '부산'];
    final hospitals = ['대형병원', '중형병원', '소형병원'];
    final products = ['의료기기', '소모품', '검사용품'];
    final periods = ['Q1', 'Q2', 'Q3', 'Q4'];

    _multiDimData = [];
    for (final region in regions) {
      for (final hospital in hospitals) {
        for (final product in products) {
          for (final period in periods) {
            final value = (100 +
              regions.indexOf(region) * 50 +
              hospitals.indexOf(hospital) * 30 +
              products.indexOf(product) * 20 +
              periods.indexOf(period) * 15).toDouble();

            _multiDimData.add(MultiDimensionalData(region, hospital, product, period, value));
          }
        }
      }
    }
  }

  void _generatePivotData() {
    // 피벗 테이블 데이터 생성
    final pivotData = [
      {
        'region': '서울',
        'hospital': '삼성서울병원',
        'product': '의료기기A',
        'q1': 12500000,
        'q2': 15600000,
        'q3': 14200000,
        'q4': 18900000,
        'total': 61200000,
      },
      {
        'region': '서울',
        'hospital': '서울대병원',
        'product': '진단장비B',
        'q1': 8900000,
        'q2': 11200000,
        'q3': 9800000,
        'q4': 13500000,
        'total': 43400000,
      },
      {
        'region': '경기',
        'hospital': '분당서울대',
        'product': '소모품C',
        'q1': 5600000,
        'q2': 6800000,
        'q3': 7200000,
        'q4': 8400000,
        'total': 28000000,
      },
      // 더 많은 데이터...
    ];

    _pivotDataSource = PivotDataSource(data: pivotData);
  }

  void _loadMockData() {
    setState(() {
      _analyticsData = {
        'summary': {
          'total_revenue': 450000000,
          'total_orders': 1250,
          'average_order': 360000,
          'growth_rate': 15.8,
        }
      };
      _generateDrilldownData();
      _generateMultiDimensionalData();
      _generatePivotData();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 통합분석 대시보드'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '드릴다운 분석', icon: Icon(Icons.trending_down)),
            Tab(text: '다차원 분석', icon: Icon(Icons.view_in_ar)),
            Tab(text: '피벗 분석', icon: Icon(Icons.pivot_table_chart)),
            Tab(text: '고급 차트', icon: Icon(Icons.auto_graph)),
          ],
        ),
        actions: [
          _buildFilterButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEnhancedAnalyticsData,
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
                _buildMultiDimensionalTab(),
                _buildPivotTab(),
                _buildAdvancedChartsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton(
      icon: const Icon(Icons.filter_alt),
      itemBuilder: (context) => [
        PopupMenuItem(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('지역 선택:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedRegion,
                items: ['전체', '서울', '경기', '부산', '대구', '기타']
                    .map((region) => DropdownMenuItem(value: region, child: Text(region)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRegion = value!;
                  });
                },
              ),
              const SizedBox(height: 10),
              const Text('기간 선택:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedPeriod,
                items: ['2024', '2023', '2022', '전체']
                    .map((period) => DropdownMenuItem(value: period, child: Text(period)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPeriod = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final summary = _analyticsData['summary'] ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSummaryCard('총 매출', '₩${NumberFormat('#,###').format(summary['total_revenue'] ?? 0)}', Colors.blue, Icons.attach_money),
          _buildSummaryCard('총 주문', '${NumberFormat('#,###').format(summary['total_orders'] ?? 0)}건', Colors.green, Icons.shopping_cart),
          _buildSummaryCard('평균 주문', '₩${NumberFormat('#,###').format(summary['average_order'] ?? 0)}', Colors.orange, Icons.trending_up),
          _buildSummaryCard('성장률', '${summary['growth_rate'] ?? 0}%', Colors.purple, Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrilldownTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 드릴다운 경로 표시
          if (_drilldownPath.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Text('경로: '),
                    ..._drilldownPath.asMap().entries.map((entry) => Row(
                      children: [
                        if (entry.key > 0) const Icon(Icons.chevron_right, size: 16),
                        TextButton(
                          onPressed: () => _drillUp(entry.key),
                          child: Text(entry.value),
                        ),
                      ],
                    )),
                    const Spacer(),
                    TextButton(
                      onPressed: _resetDrilldown,
                      child: const Text('초기화', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),

          // 드릴다운 차트
          Expanded(
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(),
              primaryYAxis: NumericAxis(numberFormat: NumberFormat.compact()),
              tooltipBehavior: _tooltip,
              selectionGesture: ActivationMode.singleTap,
              onSelectionChanged: (SelectionArgs args) {
                _onDrilldown(args.pointIndex!);
              },
              series: <CartesianSeries<DrilldownData, String>>[
                ColumnSeries<DrilldownData, String>(
                  dataSource: _getCurrentDrilldownData(),
                  xValueMapper: (DrilldownData data, _) => data.x,
                  yValueMapper: (DrilldownData data, _) => data.y,
                  color: _getDrilldownColor(),
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                  selectionBehavior: _selectionBehavior,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiDimensionalTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 차원 선택 컨트롤
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('다차원 분석 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('X축 (지역)'),
                            Switch(value: true, onChanged: (value) {}),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Y축 (매출)'),
                            Switch(value: true, onChanged: (value) {}),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('크기 (주문량)'),
                            Switch(value: true, onChanged: (value) {}),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('색상 (제품)'),
                            Switch(value: true, onChanged: (value) {}),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4차원 버블 차트
          Expanded(
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(),
              primaryYAxis: NumericAxis(),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                format: '지역: point.x\n매출: point.y\n제품: point.series'
              ),
              zoomPanBehavior: _zoomPanBehavior,
              series: _buildMultiDimensionalSeries(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPivotTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('피벗 테이블 분석', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('행/열을 드래그하여 다차원 분석을 수행하세요.'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('행 그룹: '),
                      Chip(label: const Text('지역'), onDeleted: () {}),
                      const SizedBox(width: 8),
                      Chip(label: const Text('병원'), onDeleted: () {}),
                      const SizedBox(width: 16),
                      const Text('열 그룹: '),
                      Chip(label: const Text('분기'), onDeleted: () {}),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SfDataGrid(
              source: _pivotDataSource,
              allowSorting: true,
              allowMultiColumnSorting: true,
              allowFiltering: true,
              columnWidthMode: ColumnWidthMode.fill,
              gridLinesVisibility: GridLinesVisibility.both,
              headerGridLinesVisibility: GridLinesVisibility.both,
              columns: <GridColumn>[
                GridColumn(
                  columnName: 'region',
                  label: Container(
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: const Text('지역', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                GridColumn(
                  columnName: 'hospital',
                  label: Container(
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: const Text('병원', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                GridColumn(
                  columnName: 'product',
                  label: Container(
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: const Text('제품', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                GridColumn(
                  columnName: 'q1',
                  label: Container(
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: const Text('Q1', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                GridColumn(
                  columnName: 'q2',
                  label: Container(
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: const Text('Q2', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                GridColumn(
                  columnName: 'q3',
                  label: Container(
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: const Text('Q3', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                GridColumn(
                  columnName: 'q4',
                  label: Container(
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: const Text('Q4', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                GridColumn(
                  columnName: 'total',
                  label: Container(
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    child: const Text('합계', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedChartsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 히트맵
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📊 매출 히트맵 (지역 × 월별)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      primaryXAxis: CategoryAxis(),
                      primaryYAxis: CategoryAxis(),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries>[
                        LineSeries<Map<String, dynamic>, String>(
                          dataSource: _getHeatmapData(),
                          xValueMapper: (data, _) => data['region'],
                          yValueMapper: (data, _) => data['high'],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 트리맵
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🌳 제품별 매출 트리맵', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    height: 300,
                    child: _buildTreemapVisualization(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3D 차트 (의사 3D)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📈 3D 매출 분석', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      primaryXAxis: CategoryAxis(),
                      primaryYAxis: NumericAxis(),
                      zoomPanBehavior: _zoomPanBehavior,
                      series: <CartesianSeries>[
                        ColumnSeries<Map<String, dynamic>, String>(
                          dataSource: _get3DData(),
                          xValueMapper: (data, _) => data['category'],
                          yValueMapper: (data, _) => data['value'],
                          pointColorMapper: (data, _) => data['color'],
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
                        ),
                      ],
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

  // 드릴다운 관련 메서드들
  List<DrilldownData> _getCurrentDrilldownData() {
    if (_currentDrillLevel == 0) {
      return _drilldownData;
    }

    DrilldownData currentData = _drilldownData
        .where((item) => item.x == _drilldownPath[0])
        .first;

    for (int i = 1; i < _drilldownPath.length; i++) {
      currentData = currentData.drilldownData!
          .where((item) => item.x == _drilldownPath[i])
          .first;
    }

    return currentData.drilldownData ?? [];
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

  void _drillUp(int level) {
    setState(() {
      _drilldownPath = _drilldownPath.take(level + 1).toList();
      _currentDrillLevel = level;
    });
  }

  void _resetDrilldown() {
    setState(() {
      _drilldownPath.clear();
      _currentDrillLevel = 0;
    });
  }

  Color _getDrilldownColor() {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple];
    return colors[_currentDrillLevel % colors.length];
  }

  // 다차원 차트 시리즈 생성
  List<CartesianSeries> _buildMultiDimensionalSeries() {
    final Map<String, List<MultiDimensionalData>> groupedByProduct = {};

    for (final data in _multiDimData) {
      if (!groupedByProduct.containsKey(data.product)) {
        groupedByProduct[data.product] = [];
      }
      groupedByProduct[data.product]!.add(data);
    }

    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple];

    return groupedByProduct.entries.map((entry) {
      final productIndex = groupedByProduct.keys.toList().indexOf(entry.key);
      return BubbleSeries<MultiDimensionalData, String>(
        dataSource: entry.value,
        xValueMapper: (data, _) => data.region,
        yValueMapper: (data, _) => data.value,
        sizeValueMapper: (data, _) => data.value / 10,
        color: colors[productIndex % colors.length],
        name: entry.key,
      );
    }).toList();
  }

  // 히트맵 데이터 생성
  List<Map<String, dynamic>> _getHeatmapData() {
    return [
      {'region': '서울', 'low': 100.0, 'high': 200.0, 'open': 120.0, 'close': 180.0},
      {'region': '경기', 'low': 80.0, 'high': 160.0, 'open': 100.0, 'close': 140.0},
      {'region': '부산', 'low': 60.0, 'high': 120.0, 'open': 80.0, 'close': 100.0},
      {'region': '대구', 'low': 40.0, 'high': 80.0, 'open': 50.0, 'close': 70.0},
    ];
  }

  // 트리맵 시각화
  Widget _buildTreemapVisualization() {
    return GridView.count(
      crossAxisCount: 4,
      children: [
        _buildTreemapItem('의료기기A', 45.5, Colors.blue),
        _buildTreemapItem('진단장비B', 32.1, Colors.green),
        _buildTreemapItem('소모품C', 28.7, Colors.orange),
        _buildTreemapItem('치료용품D', 19.3, Colors.purple),
        _buildTreemapItem('검사용품E', 15.8, Colors.red),
        _buildTreemapItem('기타', 8.6, Colors.grey),
      ],
    );
  }

  Widget _buildTreemapItem(String title, double percentage, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${percentage}%',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // 3D 데이터 생성
  List<Map<String, dynamic>> _get3DData() {
    return [
      {'category': '의료기기', 'value': 450, 'color': Colors.blue},
      {'category': '진단장비', 'value': 380, 'color': Colors.green},
      {'category': '소모품', 'value': 290, 'color': Colors.orange},
      {'category': '치료용품', 'value': 220, 'color': Colors.purple},
      {'category': '검사용품', 'value': 180, 'color': Colors.red},
    ];
  }
}