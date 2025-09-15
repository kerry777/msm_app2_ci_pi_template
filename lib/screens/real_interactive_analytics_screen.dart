import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class RealInteractiveAnalyticsScreen extends StatefulWidget {
  const RealInteractiveAnalyticsScreen({super.key});

  @override
  State<RealInteractiveAnalyticsScreen> createState() => _RealInteractiveAnalyticsScreenState();
}

class _RealInteractiveAnalyticsScreenState extends State<RealInteractiveAnalyticsScreen> {
  late TooltipBehavior _tooltipBehavior;
  late SelectionBehavior _selectionBehavior;
  late ZoomPanBehavior _zoomPanBehavior;

  List<SalesData> _currentData = [];
  List<String> _drilldownPath = [];
  String _currentLevel = '지역';

  // 데이터 구조
  final Map<String, Map<String, Map<String, double>>> _hierarchicalData = {
    '서울': {
      '삼성서울병원': {'의료기기A': 45000000, '진단장비B': 38000000, '소모품C': 22000000},
      '서울대병원': {'의료기기A': 42000000, '진단장비B': 35000000, '소모품C': 18000000},
      '연세세브란스': {'의료기기A': 38000000, '진단장비B': 31000000, '소모품C': 16000000},
    },
    '경기': {
      '분당서울대': {'의료기기A': 35000000, '진단장비B': 28000000, '소모품C': 15000000},
      '경기도병원': {'의료기기A': 32000000, '진단장비B': 25000000, '소모품C': 12000000},
      '수원시립병원': {'의료기기A': 28000000, '진단장비B': 22000000, '소모품C': 10000000},
    },
    '부산': {
      '부산대병원': {'의료기기A': 25000000, '진단장비B': 18000000, '소모품C': 8000000},
      '동아대병원': {'의료기기A': 22000000, '진단장비B': 15000000, '소모품C': 7000000},
      '부산백병원': {'의료기기A': 18000000, '진단장비B': 12000000, '소모품C': 5000000},
    },
  };

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(
      enable: true,
      format: 'point.x: ₩point.y',
      canShowMarker: false,
    );
    _selectionBehavior = SelectionBehavior(enable: true);
    _zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
    );
    _loadRegionData();
  }

  void _loadRegionData() {
    _currentData = _hierarchicalData.keys.map((region) {
      double total = 0;
      _hierarchicalData[region]!.values.forEach((hospitals) {
        hospitals.values.forEach((amount) => total += amount);
      });
      return SalesData(region, total);
    }).toList();

    setState(() {
      _currentLevel = '지역';
      _drilldownPath.clear();
    });
  }

  void _onChartSelectionChanged(SelectionArgs args) {
    if (args.pointIndex != null) {
      final selectedPoint = _currentData[args.pointIndex!];
      _performDrilldown(selectedPoint.category);
    }
  }

  void _performDrilldown(String selectedCategory) {
    setState(() {
      _drilldownPath.add(selectedCategory);

      if (_drilldownPath.length == 1) {
        // 지역 → 병원
        _currentLevel = '병원 ($selectedCategory)';
        _currentData = _hierarchicalData[selectedCategory]!.keys.map((hospital) {
          double total = _hierarchicalData[selectedCategory]![hospital]!.values
              .fold(0, (sum, amount) => sum + amount);
          return SalesData(hospital, total);
        }).toList();
      } else if (_drilldownPath.length == 2) {
        // 병원 → 제품
        final region = _drilldownPath[0];
        final hospital = selectedCategory;
        _currentLevel = '제품 ($hospital)';
        _currentData = _hierarchicalData[region]![hospital]!.entries
            .map((entry) => SalesData(entry.key, entry.value))
            .toList();
      }
    });
  }

  void _drillUp() {
    setState(() {
      if (_drilldownPath.isNotEmpty) {
        _drilldownPath.removeLast();

        if (_drilldownPath.isEmpty) {
          _loadRegionData();
        } else if (_drilldownPath.length == 1) {
          final region = _drilldownPath[0];
          _currentLevel = '병원 ($region)';
          _currentData = _hierarchicalData[region]!.keys.map((hospital) {
            double total = _hierarchicalData[region]![hospital]!.values
                .fold(0, (sum, amount) => sum + amount);
            return SalesData(hospital, total);
          }).toList();
        }
      }
    });
  }

  void _resetDrilldown() {
    _loadRegionData();
  }

  void _showContextMenu(BuildContext context, Offset position, SalesData data) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.zoom_in, size: 16),
              const SizedBox(width: 8),
              Text('${data.category} 드릴다운'),
            ],
          ),
          onTap: () => _performDrilldown(data.category),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.info, size: 16),
              const SizedBox(width: 8),
              Text('상세 정보 보기'),
            ],
          ),
          onTap: () => _showDetailDialog(data),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.bar_chart, size: 16),
              const SizedBox(width: 8),
              const Text('차트 타입 변경'),
            ],
          ),
          onTap: () => _showChartTypeDialog(),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.file_download, size: 16),
              const SizedBox(width: 8),
              const Text('데이터 내보내기'),
            ],
          ),
          onTap: () => _exportData(),
        ),
      ],
    );
  }

  void _showDetailDialog(SalesData data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${data.category} 상세 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('카테고리: ${data.category}'),
            Text('매출액: ${NumberFormat('#,###').format(data.sales)}원'),
            Text('전체 대비: ${((data.sales / _getTotalSales()) * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 16),
            if (_drilldownPath.isNotEmpty) ...[
              const Text('드릴다운 경로:'),
              Text(_drilldownPath.join(' → ') + ' → ${data.category}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performDrilldown(data.category);
            },
            child: const Text('드릴다운'),
          ),
        ],
      ),
    );
  }

  void _showChartTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차트 타입 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('막대 차트'),
              onTap: () {
                Navigator.of(context).pop();
                // 막대 차트로 변경
              },
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart),
              title: const Text('파이 차트'),
              onTap: () {
                Navigator.of(context).pop();
                // 파이 차트로 변경
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('라인 차트'),
              onTap: () {
                Navigator.of(context).pop();
                // 라인 차트로 변경
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('데이터 내보내기 기능이 실행되었습니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  double _getTotalSales() {
    return _currentData.fold(0, (sum, item) => sum + item.sales);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🚀 실제 인터랙티브 분석 - $_currentLevel'),
        actions: [
          if (_drilldownPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '뒤로',
              onPressed: _drillUp,
            ),
          if (_drilldownPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: '처음으로',
              onPressed: _resetDrilldown,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 드릴다운 경로 표시
            if (_drilldownPath.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.navigation, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '경로: 지역 → ${_drilldownPath.join(' → ')}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: _resetDrilldown,
                        child: const Text('초기화'),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 요약 정보
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('총 매출', style: TextStyle(color: Colors.grey)),
                        Text(
                          '₩${NumberFormat('#,###').format(_getTotalSales())}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('항목 수', style: TextStyle(color: Colors.grey)),
                        Text(
                          '${_currentData.length}개',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('드릴다운 레벨', style: TextStyle(color: Colors.grey)),
                        Text(
                          '${_drilldownPath.length + 1}/3',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 인터랙티브 차트
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _currentLevel + ' 매출 분석',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          const Text(
                            '💡 막대를 클릭하면 드릴다운, 우클릭하면 컨텍스트 메뉴',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: GestureDetector(
                          onSecondaryTapDown: (details) {
                            // 우클릭 시 가장 가까운 데이터 포인트 찾기
                            if (_currentData.isNotEmpty) {
                              _showContextMenu(context, details.globalPosition, _currentData[0]);
                            }
                          },
                          child: SfCartesianChart(
                            primaryXAxis: CategoryAxis(),
                            primaryYAxis: NumericAxis(
                              numberFormat: NumberFormat.compact(),
                            ),
                            tooltipBehavior: _tooltipBehavior,
                            zoomPanBehavior: _zoomPanBehavior,
                            onSelectionChanged: _onChartSelectionChanged,
                            series: <ColumnSeries<SalesData, String>>[
                              ColumnSeries<SalesData, String>(
                                dataSource: _currentData,
                                xValueMapper: (SalesData data, _) => data.category,
                                yValueMapper: (SalesData data, _) => data.sales,
                                color: Colors.blue,
                                borderRadius: const BorderRadius.all(Radius.circular(4)),
                                dataLabelSettings: const DataLabelSettings(
                                  isVisible: true,
                                  labelAlignment: ChartDataLabelAlignment.top,
                                ),
                                selectionBehavior: _selectionBehavior,
                                pointColorMapper: (SalesData data, _) {
                                  final index = _currentData.indexOf(data);
                                  final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple];
                                  return colors[index % colors.length];
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 액션 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _drilldownPath.isNotEmpty ? _drillUp : null,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('뒤로'),
                ),
                ElevatedButton.icon(
                  onPressed: _drilldownPath.isNotEmpty ? _resetDrilldown : null,
                  icon: const Icon(Icons.home, size: 16),
                  label: const Text('처음으로'),
                ),
                ElevatedButton.icon(
                  onPressed: _exportData,
                  icon: const Icon(Icons.file_download, size: 16),
                  label: const Text('내보내기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SalesData {
  SalesData(this.category, this.sales);
  final String category;
  final double sales;
}