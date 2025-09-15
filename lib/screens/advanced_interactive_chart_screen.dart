import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../services/sales_service.dart';
import '../utils/dialog_utils.dart';
import 'dart:math' as math;

class AdvancedInteractiveChartScreen extends StatefulWidget {
  const AdvancedInteractiveChartScreen({super.key});

  @override
  State<AdvancedInteractiveChartScreen> createState() => _AdvancedInteractiveChartScreenState();
}

class _AdvancedInteractiveChartScreenState extends State<AdvancedInteractiveChartScreen>
    with TickerProviderStateMixin {

  // 실제 데이터 소스
  List<Map<String, dynamic>> _rawData = [];
  List<ChartDataPoint> _chartData = [];
  List<ChartDataPoint> _filteredData = [];

  bool _isLoading = false;
  DateTime _fromDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _toDate = DateTime(DateTime.now().year, 12, 31);

  // 차트 설정
  ChartType _currentChartType = ChartType.column;
  late TooltipBehavior _tooltipBehavior;
  late SelectionBehavior _selectionBehavior;
  late ZoomPanBehavior _zoomPanBehavior;
  late CrosshairBehavior _crosshairBehavior;
  late TrackballBehavior _trackballBehavior;

  // 인터랙티브 필터
  final Map<String, List<String>> _availableFilters = {};
  final Map<String, Set<String>> _activeFilters = {};
  RangeValues _salesRange = const RangeValues(0, 100000000);
  RangeValues _quantityRange = const RangeValues(0, 1000);
  double _minSales = 0;
  double _maxSales = 100000000;
  double _minQuantity = 0;
  double _maxQuantity = 1000;

  // 차트 애니메이션
  late AnimationController _animationController;
  late AnimationController _filterController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 데이터 그룹핑 설정
  String _groupByField = 'CONTINENT';
  String _valueField = 'SUM_SALE_AMT_WON';
  String _aggregation = 'sum'; // sum, avg, count, min, max

  // 차트 상호작용 상태
  bool _isSelectionMode = false;
  bool _isZoomMode = true;
  bool _showDataLabels = true;
  bool _showGridLines = true;
  bool _showLegend = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChartBehaviors();
    _loadRealData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _filterController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _filterController, curve: Curves.easeOutBack));
  }

  void _initializeChartBehaviors() {
    _tooltipBehavior = TooltipBehavior(
      enable: true,
      format: 'point.x: point.y',
      canShowMarker: true,
      header: '',
      opacity: 0.9,
      elevation: 3,
      duration: 2000,
    );

    _selectionBehavior = SelectionBehavior(
      enable: true,
      selectedColor: Colors.red,
      unselectedColor: Colors.grey,
    );

    _zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      zoomMode: ZoomMode.xy,
    );

    _crosshairBehavior = CrosshairBehavior(
      enable: true,
      activationMode: ActivationMode.longPress,
    );

    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipSettings: const InteractiveTooltip(enable: true),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  // 실제 데이터 로드
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
        _processRealData();
        _animationController.forward();
      } else {
        throw Exception(result['message'] ?? '데이터 로드 실패');
      }
    } catch (e) {
      DialogUtils.showErrorDialog(context, '데이터 로드 오류', e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 실제 데이터 처리 및 차트 데이터 생성
  void _processRealData() {
    // 필터 옵션 구축
    _availableFilters.clear();
    _availableFilters['CONTINENT'] = _rawData.map((item) => item['CONTINENT']?.toString() ?? '기타').toSet().toList();
    _availableFilters['NATION_NAME'] = _rawData.map((item) => item['NATION_NAME']?.toString() ?? '기타').toSet().toList();
    _availableFilters['거래처분류'] = _rawData.map((item) => item['거래처분류']?.toString() ?? '기타').toSet().toList();

    // 수치 범위 설정
    final salesValues = _rawData.map((item) => (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0).where((v) => v > 0).toList();
    final quantityValues = _rawData.map((item) => (item['SALE_Q'] as num?)?.toDouble() ?? 0).where((v) => v > 0).toList();

    if (salesValues.isNotEmpty) {
      _minSales = salesValues.reduce(math.min);
      _maxSales = salesValues.reduce(math.max);
      _salesRange = RangeValues(_minSales, _maxSales);
    }

    if (quantityValues.isNotEmpty) {
      _minQuantity = quantityValues.reduce(math.min);
      _maxQuantity = quantityValues.reduce(math.max);
      _quantityRange = RangeValues(_minQuantity, _maxQuantity);
    }

    _buildChartData();
  }

  // 차트 데이터 구축
  void _buildChartData() {
    final Map<String, ChartDataPoint> groupedData = {};

    for (final item in _rawData) {
      // 필터 적용
      if (!_passesFilters(item)) continue;

      final groupKey = item[_groupByField]?.toString() ?? '기타';
      final value = (item[_valueField] as num?)?.toDouble() ?? 0;
      final quantity = (item['SALE_Q'] as num?)?.toInt() ?? 0;

      if (groupedData.containsKey(groupKey)) {
        // 집계 방식에 따라 처리
        switch (_aggregation) {
          case 'sum':
            groupedData[groupKey] = groupedData[groupKey]!.copyWith(
              value: groupedData[groupKey]!.value + value,
              count: groupedData[groupKey]!.count + 1,
              quantity: groupedData[groupKey]!.quantity + quantity,
            );
            break;
          case 'avg':
            final existing = groupedData[groupKey]!;
            final newCount = existing.count + 1;
            groupedData[groupKey] = existing.copyWith(
              value: ((existing.value * existing.count) + value) / newCount,
              count: newCount,
              quantity: ((existing.quantity * existing.count) + quantity) ~/ newCount,
            );
            break;
          case 'count':
            groupedData[groupKey] = groupedData[groupKey]!.copyWith(
              count: groupedData[groupKey]!.count + 1,
            );
            break;
          case 'max':
            groupedData[groupKey] = groupedData[groupKey]!.copyWith(
              value: math.max(groupedData[groupKey]!.value, value),
            );
            break;
          case 'min':
            groupedData[groupKey] = groupedData[groupKey]!.copyWith(
              value: math.min(groupedData[groupKey]!.value, value),
            );
            break;
        }
      } else {
        groupedData[groupKey] = ChartDataPoint(
          category: groupKey,
          value: value,
          count: 1,
          quantity: quantity,
          metadata: {
            'groupBy': _groupByField,
            'valueField': _valueField,
            'aggregation': _aggregation,
          },
        );
      }
    }

    _chartData = groupedData.values.toList();
    _chartData.sort((a, b) => b.value.compareTo(a.value));

    _filteredData = List.from(_chartData);
    setState(() {});
  }

  // 필터 적용 확인
  bool _passesFilters(Map<String, dynamic> item) {
    // 카테고리 필터
    for (final entry in _activeFilters.entries) {
      final field = entry.key;
      final selectedValues = entry.value;
      if (selectedValues.isNotEmpty) {
        final itemValue = item[field]?.toString() ?? '기타';
        if (!selectedValues.contains(itemValue)) {
          return false;
        }
      }
    }

    // 수치 범위 필터
    final salesValue = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0;
    final quantityValue = (item['SALE_Q'] as num?)?.toDouble() ?? 0;

    if (salesValue < _salesRange.start || salesValue > _salesRange.end) {
      return false;
    }

    if (quantityValue < _quantityRange.start || quantityValue > _quantityRange.end) {
      return false;
    }

    return true;
  }

  // 필터 다이얼로그 표시
  void _showFilterDialog() {
    _filterController.forward();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎛️ 고급 필터 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 카테고리 필터들
              ..._availableFilters.entries.map((entry) => _buildCategoryFilter(entry.key, entry.value)),

              const SizedBox(height: 16),

              // 매출액 범위 필터
              const Text('매출액 범위', style: TextStyle(fontWeight: FontWeight.bold)),
              RangeSlider(
                values: _salesRange,
                min: _minSales,
                max: _maxSales,
                divisions: 100,
                labels: RangeLabels(
                  NumberFormat.compact().format(_salesRange.start),
                  NumberFormat.compact().format(_salesRange.end),
                ),
                onChanged: (values) {
                  setState(() {
                    _salesRange = values;
                  });
                },
              ),

              const SizedBox(height: 8),

              // 수량 범위 필터
              const Text('수량 범위', style: TextStyle(fontWeight: FontWeight.bold)),
              RangeSlider(
                values: _quantityRange,
                min: _minQuantity,
                max: _maxQuantity,
                divisions: 50,
                labels: RangeLabels(
                  _quantityRange.start.toInt().toString(),
                  _quantityRange.end.toInt().toString(),
                ),
                onChanged: (values) {
                  setState(() {
                    _quantityRange = values;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _activeFilters.clear();
                _salesRange = RangeValues(_minSales, _maxSales);
                _quantityRange = RangeValues(_minQuantity, _maxQuantity);
                _buildChartData();
              });
              Navigator.of(context).pop();
            },
            child: const Text('초기화'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              _buildChartData();
              Navigator.of(context).pop();
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(String field, List<String> values) {
    final selectedValues = _activeFilters[field] ?? <String>{};

    return ExpansionTile(
      title: Text(_getFieldDisplayName(field)),
      children: [
        Container(
          height: 150,
          child: ListView(
            children: values.map((value) => CheckboxListTile(
              title: Text(value),
              value: selectedValues.contains(value),
              dense: true,
              onChanged: (checked) {
                setState(() {
                  _activeFilters[field] ??= <String>{};
                  if (checked == true) {
                    _activeFilters[field]!.add(value);
                  } else {
                    _activeFilters[field]!.remove(value);
                  }
                  if (_activeFilters[field]!.isEmpty) {
                    _activeFilters.remove(field);
                  }
                });
              },
            )).toList(),
          ),
        ),
      ],
    );
  }

  String _getFieldDisplayName(String field) {
    switch (field) {
      case 'CONTINENT':
        return '대륙';
      case 'NATION_NAME':
        return '국가';
      case '거래처분류':
        return '거래처분류';
      default:
        return field;
    }
  }

  // 차트 설정 다이얼로그
  void _showChartSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎨 차트 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 차트 타입 선택
            const Text('차트 타입', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<ChartType>(
              value: _currentChartType,
              isExpanded: true,
              items: ChartType.values.map((type) => DropdownMenuItem(
                value: type,
                child: Text(_getChartTypeName(type)),
              )).toList(),
              onChanged: (type) {
                if (type != null) {
                  setState(() {
                    _currentChartType = type;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // 그룹화 필드 선택
            const Text('그룹화 기준', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _groupByField,
              isExpanded: true,
              items: ['CONTINENT', 'NATION_NAME', '거래처분류', 'CUSTOM_NAME'].map((field) => DropdownMenuItem(
                value: field,
                child: Text(_getFieldDisplayName(field)),
              )).toList(),
              onChanged: (field) {
                if (field != null) {
                  setState(() {
                    _groupByField = field;
                    _buildChartData();
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // 값 필드 선택
            const Text('값 필드', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _valueField,
              isExpanded: true,
              items: ['SUM_SALE_AMT_WON', 'SALE_Q', 'SALE_P'].map((field) => DropdownMenuItem(
                value: field,
                child: Text(_getFieldDisplayName(field)),
              )).toList(),
              onChanged: (field) {
                if (field != null) {
                  setState(() {
                    _valueField = field;
                    _buildChartData();
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // 집계 방식 선택
            const Text('집계 방식', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _aggregation,
              isExpanded: true,
              items: ['sum', 'avg', 'count', 'max', 'min'].map((agg) => DropdownMenuItem(
                value: agg,
                child: Text(_getAggregationName(agg)),
              )).toList(),
              onChanged: (agg) {
                if (agg != null) {
                  setState(() {
                    _aggregation = agg;
                    _buildChartData();
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // 차트 옵션들
            SwitchListTile(
              title: const Text('데이터 레이블 표시'),
              value: _showDataLabels,
              onChanged: (value) {
                setState(() {
                  _showDataLabels = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('격자선 표시'),
              value: _showGridLines,
              onChanged: (value) {
                setState(() {
                  _showGridLines = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('범례 표시'),
              value: _showLegend,
              onChanged: (value) {
                setState(() {
                  _showLegend = value;
                });
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
    );
  }

  String _getChartTypeName(ChartType type) {
    switch (type) {
      case ChartType.column:
        return '세로 막대 차트';
      case ChartType.bar:
        return '가로 막대 차트';
      case ChartType.line:
        return '선형 차트';
      case ChartType.area:
        return '영역 차트';
      case ChartType.pie:
        return '파이 차트';
      case ChartType.scatter:
        return '산점도';
      default:
        return type.toString();
    }
  }

  String _getAggregationName(String agg) {
    switch (agg) {
      case 'sum':
        return '합계';
      case 'avg':
        return '평균';
      case 'count':
        return '개수';
      case 'max':
        return '최대값';
      case 'min':
        return '최소값';
      default:
        return agg;
    }
  }

  // 차트 위젯 생성
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
      case ChartType.scatter:
        return _buildScatterChart();
      default:
        return _buildColumnChart();
    }
  }

  Widget _buildColumnChart() {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        labelRotation: _filteredData.length > 10 ? -45 : 0,
        majorGridLines: MajorGridLines(width: _showGridLines ? 1 : 0),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compact(),
        majorGridLines: MajorGridLines(width: _showGridLines ? 1 : 0),
      ),
      tooltipBehavior: _tooltipBehavior,
      zoomPanBehavior: _isZoomMode ? _zoomPanBehavior : null,
      crosshairBehavior: _crosshairBehavior,
      trackballBehavior: _trackballBehavior,
      legend: Legend(isVisible: _showLegend),
      series: <ColumnSeries<ChartDataPoint, String>>[
        ColumnSeries<ChartDataPoint, String>(
          dataSource: _filteredData,
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          dataLabelSettings: DataLabelSettings(isVisible: _showDataLabels),
          selectionBehavior: _isSelectionMode ? _selectionBehavior : null,
          pointColorMapper: (data, _) {
            final index = _filteredData.indexOf(data);
            final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple];
            return colors[index % colors.length];
          },
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    return SfCartesianChart(
      primaryXAxis: NumericAxis(
        numberFormat: NumberFormat.compact(),
        majorGridLines: MajorGridLines(width: _showGridLines ? 1 : 0),
      ),
      primaryYAxis: CategoryAxis(
        majorGridLines: MajorGridLines(width: _showGridLines ? 1 : 0),
      ),
      tooltipBehavior: _tooltipBehavior,
      zoomPanBehavior: _isZoomMode ? _zoomPanBehavior : null,
      legend: Legend(isVisible: _showLegend),
      series: <BarSeries<ChartDataPoint, String>>[
        BarSeries<ChartDataPoint, String>(
          dataSource: _filteredData,
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          dataLabelSettings: DataLabelSettings(isVisible: _showDataLabels),
          selectionBehavior: _isSelectionMode ? _selectionBehavior : null,
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        majorGridLines: MajorGridLines(width: _showGridLines ? 1 : 0),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compact(),
        majorGridLines: MajorGridLines(width: _showGridLines ? 1 : 0),
      ),
      tooltipBehavior: _tooltipBehavior,
      zoomPanBehavior: _isZoomMode ? _zoomPanBehavior : null,
      crosshairBehavior: _crosshairBehavior,
      trackballBehavior: _trackballBehavior,
      legend: Legend(isVisible: _showLegend),
      series: <LineSeries<ChartDataPoint, String>>[
        LineSeries<ChartDataPoint, String>(
          dataSource: _filteredData,
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
          markerSettings: const MarkerSettings(isVisible: true),
          dataLabelSettings: DataLabelSettings(isVisible: _showDataLabels),
        ),
      ],
    );
  }

  Widget _buildAreaChart() {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        majorGridLines: MajorGridLines(width: _showGridLines ? 1 : 0),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compact(),
        majorGridLines: MajorGridLines(width: _showGridLines ? 1 : 0),
      ),
      tooltipBehavior: _tooltipBehavior,
      zoomPanBehavior: _isZoomMode ? _zoomPanBehavior : null,
      legend: Legend(isVisible: _showLegend),
      series: <AreaSeries<ChartDataPoint, String>>[
        AreaSeries<ChartDataPoint, String>(
          dataSource: _filteredData,
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
          dataLabelSettings: DataLabelSettings(isVisible: _showDataLabels),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    return SfCircularChart(
      tooltipBehavior: _tooltipBehavior,
      legend: Legend(isVisible: _showLegend),
      series: <PieSeries<ChartDataPoint, String>>[
        PieSeries<ChartDataPoint, String>(
          dataSource: _filteredData.take(10).toList(), // 파이 차트는 최대 10개 항목만
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.value,
          dataLabelSettings: DataLabelSettings(isVisible: _showDataLabels),
          explode: true,
          explodeIndex: 0,
        ),
      ],
    );
  }

  Widget _buildScatterChart() {
    return SfCartesianChart(
      primaryXAxis: NumericAxis(
        majorGridLines: MajorGridLines(width: _showGridLines ? 1 : 0),
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compact(),
        majorGridLines: MajorGridLines(width: _showGridLines ? 1 : 0),
      ),
      tooltipBehavior: _tooltipBehavior,
      zoomPanBehavior: _isZoomMode ? _zoomPanBehavior : null,
      series: <ScatterSeries<ChartDataPoint, double>>[
        ScatterSeries<ChartDataPoint, double>(
          dataSource: _filteredData,
          xValueMapper: (data, _) => data.quantity.toDouble(),
          yValueMapper: (data, _) => data.value,
          markerSettings: const MarkerSettings(height: 8, width: 8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 고급 인터랙티브 차트'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '필터 설정',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '차트 설정',
            onPressed: _showChartSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _loadRealData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 컨트롤 패널
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_getFieldDisplayName(_groupByField)}별 ${_getFieldDisplayName(_valueField)} ${_getAggregationName(_aggregation)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text('${_filteredData.length}개 항목'),
                            const SizedBox(width: 16),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: true, label: Text('줌'), icon: Icon(Icons.zoom_in, size: 16)),
                                ButtonSegment(value: false, label: Text('선택'), icon: Icon(Icons.touch_app, size: 16)),
                              ],
                              selected: {_isZoomMode},
                              onSelectionChanged: (selected) {
                                setState(() {
                                  _isZoomMode = selected.first;
                                  _isSelectionMode = !_isZoomMode;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 활성 필터 표시
                    if (_activeFilters.isNotEmpty ||
                        _salesRange.start > _minSales ||
                        _salesRange.end < _maxSales ||
                        _quantityRange.start > _minQuantity ||
                        _quantityRange.end < _maxQuantity)
                      SlideTransition(
                        position: _slideAnimation,
                        child: Card(
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    const Text('활성 필터', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _activeFilters.clear();
                                          _salesRange = RangeValues(_minSales, _maxSales);
                                          _quantityRange = RangeValues(_minQuantity, _maxQuantity);
                                          _buildChartData();
                                        });
                                      },
                                      icon: const Icon(Icons.clear, size: 16),
                                      label: const Text('모두 해제'),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    ..._activeFilters.entries.expand((entry) =>
                                      entry.value.map((value) => Chip(
                                        label: Text('${_getFieldDisplayName(entry.key)}: $value'),
                                        deleteIcon: const Icon(Icons.close, size: 16),
                                        onDeleted: () {
                                          setState(() {
                                            entry.value.remove(value);
                                            if (entry.value.isEmpty) {
                                              _activeFilters.remove(entry.key);
                                            }
                                            _buildChartData();
                                          });
                                        },
                                      ))),
                                    if (_salesRange.start > _minSales || _salesRange.end < _maxSales)
                                      Chip(
                                        label: Text('매출: ${NumberFormat.compact().format(_salesRange.start)}~${NumberFormat.compact().format(_salesRange.end)}'),
                                        deleteIcon: const Icon(Icons.close, size: 16),
                                        onDeleted: () {
                                          setState(() {
                                            _salesRange = RangeValues(_minSales, _maxSales);
                                            _buildChartData();
                                          });
                                        },
                                      ),
                                    if (_quantityRange.start > _minQuantity || _quantityRange.end < _maxQuantity)
                                      Chip(
                                        label: Text('수량: ${_quantityRange.start.toInt()}~${_quantityRange.end.toInt()}'),
                                        deleteIcon: const Icon(Icons.close, size: 16),
                                        onDeleted: () {
                                          setState(() {
                                            _quantityRange = RangeValues(_minQuantity, _maxQuantity);
                                            _buildChartData();
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // 차트 영역
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildChart(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// 차트 타입 열거형
enum ChartType {
  column,
  bar,
  line,
  area,
  pie,
  scatter,
}

// 차트 데이터 포인트 클래스
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