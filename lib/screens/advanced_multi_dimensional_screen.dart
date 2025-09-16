import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../services/sales_service.dart';
import '../utils/dialog_utils.dart';
import 'dart:math' as math;

/// 통합분석2 - 다차원 분석 시스템
/// 1레벨: 단일축 분석 (거래처별/월별, 품목별/월별)
/// 2레벨: 교차축 분석 (거래처별×품목별, 지역별×거래처분류별)
class AdvancedMultiDimensionalScreen extends StatefulWidget {
  const AdvancedMultiDimensionalScreen({super.key});

  @override
  State<AdvancedMultiDimensionalScreen> createState() => _AdvancedMultiDimensionalScreenState();
}

class _AdvancedMultiDimensionalScreenState extends State<AdvancedMultiDimensionalScreen>
    with TickerProviderStateMixin {

  // 데이터
  List<Map<String, dynamic>> _rawData = [];
  bool _isLoading = false;
  final DateTime _fromDate = DateTime(DateTime.now().year, 1, 1);
  final DateTime _toDate = DateTime(DateTime.now().year, 12, 31);

  // 분석 레벨 및 축 설정
  int _analysisLevel = 1; // 1: 단일축, 2: 교차축
  String _primaryAxis = '거래처별'; // 1차축
  String _secondaryAxis = '품목별'; // 2차축 (2레벨에서만)
  String _timeGrouping = '월별'; // 시간 축

  // 탭 컨트롤러
  late TabController _tabController;

  // 차트 관련
  late TooltipBehavior _tooltipBehavior;
  late ZoomPanBehavior _zoomPanBehavior;

  // 처리된 차트 데이터들
  final Map<String, List<ChartDataPoint>> _chartData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tooltipBehavior = TooltipBehavior(
      enable: true,
      format: 'point.x: ₩point.y',
      canShowMarker: false,
    );

    _zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
    );

    _loadRealData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 실제 MSM 데이터 로드
  Future<void> _loadRealData() async {
    if (_isLoading) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await SalesService.getSalesSummary(
        fromDate: '${_fromDate.year}-${_fromDate.month.toString().padLeft(2, '0')}-${_fromDate.day.toString().padLeft(2, '0')}',
        toDate: '${_toDate.year}-${_toDate.month.toString().padLeft(2, '0')}-${_toDate.day.toString().padLeft(2, '0')}',
        period: 'monthly',
        trCd: '',
      );

      if (result['success'] == true && result['data'] != null) {
        _rawData = List<Map<String, dynamic>>.from(result['data']);
        _processMultiDimensionalData();
        debugPrint('🎯 통합분석2: ${_rawData.length}건 실제 MSM 데이터 로드 완료');
      } else {
        throw Exception(result['message'] ?? '데이터 로드 실패');
      }
    } catch (e) {
      debugPrint('❌ 통합분석2 데이터 로드 오류: $e');
      if (mounted) {
        DialogUtils.showErrorDialog(context, '데이터 로드 오류', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 다차원 데이터 처리
  void _processMultiDimensionalData() {
    _chartData.clear();

    if (_analysisLevel == 1) {
      _processSingleAxisData();
    } else {
      _processCrossAxisData();
    }

    debugPrint('🎯 통합분석2: 레벨$_analysisLevel $_primaryAxis${_analysisLevel == 2 ? ' × $_secondaryAxis' : ''} 데이터 처리 완료');
  }

  // 1레벨: 단일축 분석
  void _processSingleAxisData() {
    final aggregatedData = <String, double>{};

    for (final item in _rawData) {
      String key;

      switch (_primaryAxis) {
        case '거래처별':
          key = item['CUSTOM_NAME']?.toString() ?? '미분류';
          break;
        case '지역별':
          key = item['CONTINENT']?.toString() ?? '미분류';
          break;
        case '국가별':
          key = item['NATION_NAME']?.toString() ?? '미분류';
          break;
        case '거래처분류별':
          key = item['거래처분류']?.toString() ?? '미분류';
          break;
        case '대리점별':
          key = item['MANAGE_CUSTOM_NM']?.toString() ?? '직접관리';
          break;
        default:
          key = '기타';
      }

      final salesAmount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0.0;
      aggregatedData[key] = (aggregatedData[key] ?? 0) + salesAmount;
    }

    // 상위 20개만 표시
    final sortedEntries = aggregatedData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _chartData[_primaryAxis] = sortedEntries.take(20).map((entry) =>
      ChartDataPoint(
        category: entry.key.length > 15 ? '${entry.key.substring(0, 12)}...' : entry.key,
        value: entry.value,
        originalCategory: entry.key,
      )
    ).toList();
  }

  // 2레벨: 교차축 분석
  void _processCrossAxisData() {
    final crossData = <String, Map<String, double>>{};

    for (final item in _rawData) {
      String primaryKey;
      String secondaryKey;

      // 1차축 키 결정
      switch (_primaryAxis) {
        case '거래처별':
          primaryKey = item['CUSTOM_NAME']?.toString() ?? '미분류';
          break;
        case '지역별':
          primaryKey = item['CONTINENT']?.toString() ?? '미분류';
          break;
        case '국가별':
          primaryKey = item['NATION_NAME']?.toString() ?? '미분류';
          break;
        case '거래처분류별':
          primaryKey = item['거래처분류']?.toString() ?? '미분류';
          break;
        default:
          primaryKey = '기타';
      }

      // 2차축 키 결정
      switch (_secondaryAxis) {
        case '거래처분류별':
          secondaryKey = item['거래처분류']?.toString() ?? '미분류';
          break;
        case '지역별':
          secondaryKey = item['CONTINENT']?.toString() ?? '미분류';
          break;
        case '국가별':
          secondaryKey = item['NATION_NAME']?.toString() ?? '미분류';
          break;
        case '품목별':
          // 실제 품목 데이터가 없으므로 거래처분류를 대신 사용
          secondaryKey = item['거래처분류']?.toString() ?? '미분류';
          break;
        default:
          secondaryKey = '기타';
      }

      final salesAmount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0.0;

      crossData[primaryKey] ??= {};
      crossData[primaryKey]![secondaryKey] =
        (crossData[primaryKey]![secondaryKey] ?? 0) + salesAmount;
    }

    // 교차 분석 결과를 차트 데이터로 변환
    final allSecondaryKeys = <String>{};
    for (var map in crossData.values) {
      allSecondaryKeys.addAll(map.keys);
    }

    // 상위 10개 primary key만 선택
    final sortedPrimary = crossData.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.values.fold<double>(0, (sum, val) => sum + val);
        final bTotal = b.value.values.fold<double>(0, (sum, val) => sum + val);
        return bTotal.compareTo(aTotal);
      });

    // 각 secondary key별로 시리즈 생성
    for (final secondaryKey in allSecondaryKeys.take(5)) {
      _chartData[secondaryKey] = sortedPrimary.take(10).map((entry) {
        final value = entry.value[secondaryKey] ?? 0.0;
        return ChartDataPoint(
          category: entry.key.length > 10 ? '${entry.key.substring(0, 8)}...' : entry.key,
          value: value,
          originalCategory: entry.key,
          secondaryCategory: secondaryKey,
        );
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📈 통합분석2 - ${_analysisLevel == 1 ? '단일축' : '교차축'} 분석'),
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRealData,
            tooltip: '데이터 새로고침',
          ),
          IconButton(
            icon: Icon(_analysisLevel == 1 ? Icons.looks_one : Icons.looks_two),
            onPressed: () {
              if (mounted) {
                setState(() {
                  _analysisLevel = _analysisLevel == 1 ? 2 : 1;
                });
              }
              _processMultiDimensionalData();
            },
            tooltip: '분석 레벨 변경',
          ),
        ],
      ),
      body: Column(
        children: [
          // 분석 설정 패널
          _buildAnalysisControlPanel(),

          // 분석 결과 차트
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildAnalysisContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '분석 레벨: $_analysisLevel레벨',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 20),
              Text(
                _analysisLevel == 1
                  ? '단일축 분석 ($_primaryAxis/$_timeGrouping)'
                  : '교차축 분석 ($_primaryAxis × $_secondaryAxis)',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 축 선택 컨트롤
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildAxisSelector('1차축:', _primaryAxis, ['거래처별', '지역별', '국가별', '거래처분류별', '대리점별'], (value) {
                if (mounted) {
                  setState(() {
                    _primaryAxis = value;
                  });
                }
                _processMultiDimensionalData();
              }),

              if (_analysisLevel == 2)
                _buildAxisSelector('2차축:', _secondaryAxis, ['거래처분류별', '지역별', '국가별', '품목별'], (value) {
                  if (mounted) {
                    setState(() {
                      _secondaryAxis = value;
                    });
                  }
                  _processMultiDimensionalData();
                }),

              _buildAxisSelector('시간:', _timeGrouping, ['월별', '분기별', '연도별'], (value) {
                if (mounted) {
                  setState(() {
                    _timeGrouping = value;
                  });
                }
                _processMultiDimensionalData();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAxisSelector(String label, String current, List<String> options, Function(String) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        DropdownButton<String>(
          value: current,
          items: options.map((option) => DropdownMenuItem(
            value: option,
            child: Text(option),
          )).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }

  Widget _buildAnalysisContent() {
    if (_rawData.isEmpty) {
      return const Center(
        child: Text('분석할 데이터가 없습니다.'),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // 차트 탭
        _buildChartView(),

        // 상세 데이터 탭
        _buildDetailView(),
      ],
    );
  }

  Widget _buildChartView() {
    if (_chartData.isEmpty) {
      return const Center(child: Text('차트 데이터가 없습니다.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 탭 헤더
          TabBar(
            controller: _tabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: '📊 차트 분석'),
              Tab(text: '📋 상세 데이터'),
            ],
          ),
          const SizedBox(height: 20),

          if (_analysisLevel == 1)
            _buildSingleAxisChart()
          else
            _buildCrossAxisChart(),
        ],
      ),
    );
  }

  Widget _buildSingleAxisChart() {
    final data = _chartData[_primaryAxis] ?? [];

    return SizedBox(
      height: 400,
      child: SfCartesianChart(
        title: ChartTitle(text: '$_primaryAxis 매출 분석'),
        tooltipBehavior: _tooltipBehavior,
        zoomPanBehavior: _zoomPanBehavior,
        primaryXAxis: CategoryAxis(
          labelRotation: -45,
          maximumLabels: 20,
        ),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat('#,###'),
          title: AxisTitle(text: '매출액 (원)'),
        ),
        series: <CartesianSeries>[
          ColumnSeries<ChartDataPoint, String>(
            dataSource: data,
            xValueMapper: (ChartDataPoint data, _) => data.category,
            yValueMapper: (ChartDataPoint data, _) => data.value,
            color: Colors.indigo[400],
            dataLabelSettings: const DataLabelSettings(isVisible: false),
          ),
        ],
      ),
    );
  }

  Widget _buildCrossAxisChart() {
    final seriesData = <CartesianSeries>[];
    final colors = [
      Colors.indigo[400], Colors.blue[400], Colors.cyan[400],
      Colors.teal[400], Colors.green[400]
    ];

    int colorIndex = 0;
    for (final entry in _chartData.entries) {
      seriesData.add(
        ColumnSeries<ChartDataPoint, String>(
          name: entry.key,
          dataSource: entry.value,
          xValueMapper: (ChartDataPoint data, _) => data.category,
          yValueMapper: (ChartDataPoint data, _) => data.value,
          color: colors[colorIndex % colors.length],
        ),
      );
      colorIndex++;
    }

    return SizedBox(
      height: 500,
      child: SfCartesianChart(
        title: ChartTitle(text: '$_primaryAxis × $_secondaryAxis 교차 분석'),
        tooltipBehavior: _tooltipBehavior,
        zoomPanBehavior: _zoomPanBehavior,
        legend: Legend(isVisible: true, position: LegendPosition.bottom),
        primaryXAxis: CategoryAxis(
          labelRotation: -45,
          maximumLabels: 15,
        ),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat('#,###'),
          title: AxisTitle(text: '매출액 (원)'),
        ),
        series: seriesData,
      ),
    );
  }

  Widget _buildDetailView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 분석 요약',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• 총 데이터: ${NumberFormat('#,###').format(_rawData.length)}건'),
                  Text('• 분석 기간: ${DateFormat('yyyy-MM-dd').format(_fromDate)} ~ ${DateFormat('yyyy-MM-dd').format(_toDate)}'),
                  Text('• 분석 레벨: $_analysisLevel레벨 (${_analysisLevel == 1 ? '단일축' : '교차축'})'),
                  Text('• 1차축: $_primaryAxis'),
                  if (_analysisLevel == 2) Text('• 2차축: $_secondaryAxis'),
                  Text('• 시간축: $_timeGrouping'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            '📈 상위 데이터',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _buildDataTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    if (_chartData.isEmpty) {
      return const Center(child: Text('표시할 데이터가 없습니다.'));
    }

    if (_analysisLevel == 1) {
      final data = _chartData[_primaryAxis] ?? [];
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(_primaryAxis)),
            const DataColumn(label: Text('매출액')),
            const DataColumn(label: Text('비중')),
          ],
          rows: data.map((item) {
            final total = data.fold<double>(0, (sum, data) => sum + data.value);
            final percentage = total > 0 ? (item.value / total * 100) : 0.0;

            return DataRow(cells: [
              DataCell(Text(item.originalCategory ?? item.category)),
              DataCell(Text(NumberFormat('#,###').format(item.value.round()))),
              DataCell(Text('${percentage.toStringAsFixed(1)}%')),
            ]);
          }).toList(),
        ),
      );
    } else {
      // 2레벨 교차 분석 테이블
      return SingleChildScrollView(
        child: Column(
          children: _chartData.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ExpansionTile(
                title: Text('${entry.key} 상세'),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text(_primaryAxis)),
                        const DataColumn(label: Text('매출액')),
                      ],
                      rows: entry.value.map((item) => DataRow(cells: [
                        DataCell(Text(item.originalCategory ?? item.category)),
                        DataCell(Text(NumberFormat('#,###').format(item.value.round()))),
                      ])).toList(),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
  }
}

// 차트 데이터 포인트 클래스
class ChartDataPoint {
  final String category;
  final double value;
  final String? originalCategory;
  final String? secondaryCategory;

  ChartDataPoint({
    required this.category,
    required this.value,
    this.originalCategory,
    this.secondaryCategory,
  });
}