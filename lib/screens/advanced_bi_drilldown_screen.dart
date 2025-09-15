import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../services/sales_service.dart';
import '../utils/dialog_utils.dart';

class AdvancedBIDrilldownScreen extends StatefulWidget {
  const AdvancedBIDrilldownScreen({super.key});

  @override
  State<AdvancedBIDrilldownScreen> createState() => _AdvancedBIDrilldownScreenState();
}

class _AdvancedBIDrilldownScreenState extends State<AdvancedBIDrilldownScreen> {
  // 실제 데이터 소스 (통합분석과 동일한 API 사용)
  List<Map<String, dynamic>> _rawData = [];
  List<DrillDownNode> _currentData = [];
  List<String> _drilldownPath = [];
  DrillDownLevel _currentLevel = DrillDownLevel.region;

  bool _isLoading = false;
  late TooltipBehavior _tooltipBehavior;
  late SelectionBehavior _selectionBehavior;
  late ZoomPanBehavior _zoomPanBehavior;

  // 날짜 범위 (통합분석과 동일)
  DateTime _fromDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _toDate = DateTime(DateTime.now().year, 12, 31);

  @override
  void initState() {
    super.initState();
    _initializeChartBehaviors();
    _loadRealData();
  }

  void _initializeChartBehaviors() {
    _tooltipBehavior = TooltipBehavior(
      enable: true,
      format: 'point.x: ₩point.y',
      canShowMarker: false,
      header: '',
      opacity: 0.9,
    );

    _selectionBehavior = SelectionBehavior(enable: true);

    _zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
    );
  }

  // 실제 데이터 로드 (통합분석과 동일한 API 사용)
  Future<void> _loadRealData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 통합분석과 동일한 API 호출
      final result = await SalesService.getSalesSummary(
        fromDate: '${_fromDate.year}-${_fromDate.month.toString().padLeft(2, '0')}-${_fromDate.day.toString().padLeft(2, '0')}',
        toDate: '${_toDate.year}-${_toDate.month.toString().padLeft(2, '0')}-${_toDate.day.toString().padLeft(2, '0')}',
        period: 'ALL',
        trCd: '',
      );

      if (result['success'] == true && result['data'] != null) {
        _rawData = List<Map<String, dynamic>>.from(result['data']);
        _buildRegionLevelData();
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

  // 지역 레벨 데이터 구축
  void _buildRegionLevelData() {
    final Map<String, double> regionData = {};
    final Map<String, int> regionCounts = {};

    for (final item in _rawData) {
      final continent = item['CONTINENT']?.toString() ?? '기타';
      final salesAmount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0.0;

      regionData[continent] = (regionData[continent] ?? 0) + salesAmount;
      regionCounts[continent] = (regionCounts[continent] ?? 0) + 1;
    }

    _currentData = regionData.entries.map((entry) => DrillDownNode(
      category: entry.key,
      value: entry.value,
      count: regionCounts[entry.key] ?? 0,
      metadata: {'level': 'region', 'continent': entry.key},
    )).toList();

    // 매출액 순으로 정렬
    _currentData.sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _currentLevel = DrillDownLevel.region;
      _drilldownPath.clear();
    });
  }

  // 국가 레벨 데이터 구축
  void _buildCountryLevelData(String continent) {
    final Map<String, double> countryData = {};
    final Map<String, int> countryCounts = {};

    final filteredData = _rawData.where((item) =>
      item['CONTINENT']?.toString() == continent).toList();

    for (final item in filteredData) {
      final country = item['NATION_NAME']?.toString() ?? '기타';
      final salesAmount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0.0;

      countryData[country] = (countryData[country] ?? 0) + salesAmount;
      countryCounts[country] = (countryCounts[country] ?? 0) + 1;
    }

    _currentData = countryData.entries.map((entry) => DrillDownNode(
      category: entry.key,
      value: entry.value,
      count: countryCounts[entry.key] ?? 0,
      metadata: {'level': 'country', 'continent': continent, 'country': entry.key},
    )).toList();

    _currentData.sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _currentLevel = DrillDownLevel.country;
      _drilldownPath = [continent];
    });
  }

  // 병원 레벨 데이터 구축
  void _buildHospitalLevelData(String continent, String country) {
    final Map<String, double> hospitalData = {};
    final Map<String, int> hospitalCounts = {};
    final Map<String, String> hospitalTypes = {};

    final filteredData = _rawData.where((item) =>
      item['CONTINENT']?.toString() == continent &&
      item['NATION_NAME']?.toString() == country).toList();

    for (final item in filteredData) {
      final hospital = item['CUSTOM_NAME']?.toString() ?? '기타';
      final salesAmount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0.0;
      final hospitalType = item['거래처분류']?.toString() ?? '기타';

      hospitalData[hospital] = (hospitalData[hospital] ?? 0) + salesAmount;
      hospitalCounts[hospital] = (hospitalCounts[hospital] ?? 0) + 1;
      hospitalTypes[hospital] = hospitalType;
    }

    _currentData = hospitalData.entries.map((entry) => DrillDownNode(
      category: entry.key,
      value: entry.value,
      count: hospitalCounts[entry.key] ?? 0,
      metadata: {
        'level': 'hospital',
        'continent': continent,
        'country': country,
        'hospital': entry.key,
        'hospitalType': hospitalTypes[entry.key],
      },
    )).toList();

    _currentData.sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _currentLevel = DrillDownLevel.hospital;
      _drilldownPath = [continent, country];
    });
  }

  // 거래 상세 데이터 구축
  void _buildTransactionLevelData(String continent, String country, String hospital) {
    final filteredData = _rawData.where((item) =>
      item['CONTINENT']?.toString() == continent &&
      item['NATION_NAME']?.toString() == country &&
      item['CUSTOM_NAME']?.toString() == hospital).toList();

    _currentData = filteredData.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final salesAmount = (item['SUM_SALE_AMT_WON'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['SALE_Q'] as num?)?.toInt() ?? 0;
      final unitPrice = (item['SALE_P'] as num?)?.toDouble() ?? 0.0;

      return DrillDownNode(
        category: '거래 ${index + 1}',
        value: salesAmount,
        count: quantity,
        metadata: {
          'level': 'transaction',
          'continent': continent,
          'country': country,
          'hospital': hospital,
          'customCode': item['CUSTOM_CODE'],
          'quantity': quantity,
          'unitPrice': unitPrice,
          'updateDate': item['UPDATE_DTM'],
        },
      );
    }).toList();

    _currentData.sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _currentLevel = DrillDownLevel.transaction;
      _drilldownPath = [continent, country, hospital];
    });
  }

  // 차트 선택 이벤트 처리 (진정한 드릴다운)
  void _onChartSelectionChanged(SelectionArgs args) {
    if (args.pointIndex == null || args.pointIndex! >= _currentData.length) return;

    final selectedNode = _currentData[args.pointIndex!];
    _performDrilldown(selectedNode);
  }

  // 드릴다운 실행
  void _performDrilldown(DrillDownNode node) {
    switch (_currentLevel) {
      case DrillDownLevel.region:
        _buildCountryLevelData(node.category);
        break;
      case DrillDownLevel.country:
        final continent = _drilldownPath[0];
        _buildHospitalLevelData(continent, node.category);
        break;
      case DrillDownLevel.hospital:
        final continent = _drilldownPath[0];
        final country = _drilldownPath[1];
        _buildTransactionLevelData(continent, country, node.category);
        break;
      case DrillDownLevel.transaction:
        // 최하위 레벨 - 상세 정보 표시
        _showTransactionDetails(node);
        break;
    }
  }

  // 드릴업 (뒤로가기)
  void _drillUp() {
    if (_drilldownPath.isEmpty) return;

    switch (_currentLevel) {
      case DrillDownLevel.country:
        _buildRegionLevelData();
        break;
      case DrillDownLevel.hospital:
        final continent = _drilldownPath[0];
        _buildCountryLevelData(continent);
        break;
      case DrillDownLevel.transaction:
        final continent = _drilldownPath[0];
        final country = _drilldownPath[1];
        _buildHospitalLevelData(continent, country);
        break;
      case DrillDownLevel.region:
        // 최상위 레벨
        break;
    }
  }

  // 처음으로 (홈)
  void _resetDrilldown() {
    _buildRegionLevelData();
  }

  // 거래 상세 정보 표시
  void _showTransactionDetails(DrillDownNode node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('거래 상세 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('대륙', node.metadata['continent']),
            _buildDetailRow('국가', node.metadata['country']),
            _buildDetailRow('병원', node.metadata['hospital']),
            _buildDetailRow('거래처코드', node.metadata['customCode']),
            _buildDetailRow('매출금액', NumberFormat('#,###원').format(node.value)),
            _buildDetailRow('수량', NumberFormat('#,###개').format(node.count)),
            _buildDetailRow('단가', NumberFormat('#,###원').format(node.metadata['unitPrice'] ?? 0)),
            _buildDetailRow('업데이트일', node.metadata['updateDate'] ?? ''),
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

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(value?.toString() ?? ''),
          ),
        ],
      ),
    );
  }

  // 컨텍스트 메뉴 표시
  void _showContextMenu(BuildContext context, Offset position, DrillDownNode node) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        if (_currentLevel != DrillDownLevel.transaction)
          PopupMenuItem(
            child: Row(
              children: [
                const Icon(Icons.zoom_in, size: 16),
                const SizedBox(width: 8),
                Text('${node.category} 드릴다운'),
              ],
            ),
            onTap: () => _performDrilldown(node),
          ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.info, size: 16),
              const SizedBox(width: 8),
              const Text('상세 정보'),
            ],
          ),
          onTap: () => _showNodeDetails(node),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 16),
              const SizedBox(width: 8),
              const Text('필터 설정'),
            ],
          ),
          onTap: () => _showFilterDialog(node),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.file_download, size: 16),
              const SizedBox(width: 8),
              const Text('데이터 내보내기'),
            ],
          ),
          onTap: () => _exportCurrentData(),
        ),
      ],
    );
  }

  void _showNodeDetails(DrillDownNode node) {
    final totalSales = _currentData.fold<double>(0, (sum, item) => sum + item.value);
    final percentage = totalSales > 0 ? (node.value / totalSales * 100) : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${node.category} 상세 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('카테고리', node.category),
            _buildDetailRow('매출액', NumberFormat('#,###원').format(node.value)),
            _buildDetailRow('거래건수', NumberFormat('#,###건').format(node.count)),
            _buildDetailRow('전체 대비', '${percentage.toStringAsFixed(1)}%'),
            _buildDetailRow('현재 레벨', _getLevelName(_currentLevel)),
            if (_drilldownPath.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('드릴다운 경로:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_drilldownPath.join(' → ') + ' → ${node.category}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
          if (_currentLevel != DrillDownLevel.transaction)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performDrilldown(node);
              },
              child: const Text('드릴다운'),
            ),
        ],
      ),
    );
  }

  void _showFilterDialog(DrillDownNode node) {
    // 필터 다이얼로그 구현 (향후 확장)
    DialogUtils.showInfoDialog(context, '필터 기능', '추후 구현 예정입니다.');
  }

  void _exportCurrentData() {
    // 데이터 내보내기 구현 (향후 확장)
    DialogUtils.showInfoDialog(context, '내보내기', '추후 구현 예정입니다.');
  }

  String _getLevelName(DrillDownLevel level) {
    switch (level) {
      case DrillDownLevel.region:
        return '지역/대륙';
      case DrillDownLevel.country:
        return '국가';
      case DrillDownLevel.hospital:
        return '병원/거래처';
      case DrillDownLevel.transaction:
        return '거래 상세';
    }
  }

  double _getTotalSales() {
    return _currentData.fold<double>(0, (sum, item) => sum + item.value);
  }

  int _getTotalCount() {
    return _currentData.fold<int>(0, (sum, item) => sum + item.count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🚀 고급 BI 드릴다운 - ${_getLevelName(_currentLevel)}'),
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
            onPressed: _loadRealData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                                '경로: ${_drilldownPath.join(' → ')}',
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
                          _buildSummaryItem('총 매출', '₩${NumberFormat('#,###').format(_getTotalSales())}', Colors.blue),
                          _buildSummaryItem('항목 수', '${_currentData.length}개', Colors.green),
                          _buildSummaryItem('거래 건수', '${NumberFormat('#,###').format(_getTotalCount())}건', Colors.orange),
                          _buildSummaryItem('드릴다운 레벨', '${_drilldownPath.length + 1}/4', Colors.purple),
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
                                  '${_getLevelName(_currentLevel)} 매출 분석',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                const Text(
                                  '💡 클릭: 드릴다운, 우클릭: 메뉴',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: GestureDetector(
                                onSecondaryTapDown: (details) {
                                  if (_currentData.isNotEmpty) {
                                    _showContextMenu(context, details.globalPosition, _currentData[0]);
                                  }
                                },
                                child: SfCartesianChart(
                                  primaryXAxis: CategoryAxis(
                                    labelRotation: _currentData.length > 10 ? -45 : 0,
                                  ),
                                  primaryYAxis: NumericAxis(
                                    numberFormat: NumberFormat.compact(),
                                  ),
                                  tooltipBehavior: _tooltipBehavior,
                                  zoomPanBehavior: _zoomPanBehavior,
                                  onSelectionChanged: _onChartSelectionChanged,
                                  series: <ColumnSeries<DrillDownNode, String>>[
                                    ColumnSeries<DrillDownNode, String>(
                                      dataSource: _currentData,
                                      xValueMapper: (DrillDownNode data, _) => data.category.length > 15
                                        ? '${data.category.substring(0, 15)}...'
                                        : data.category,
                                      yValueMapper: (DrillDownNode data, _) => data.value,
                                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                                      dataLabelSettings: const DataLabelSettings(
                                        isVisible: true,
                                        labelAlignment: ChartDataLabelAlignment.top,
                                      ),
                                      selectionBehavior: _selectionBehavior,
                                      pointColorMapper: (DrillDownNode data, _) {
                                        final index = _currentData.indexOf(data);
                                        final colors = [
                                          Colors.blue,
                                          Colors.green,
                                          Colors.orange,
                                          Colors.red,
                                          Colors.purple,
                                          Colors.teal,
                                          Colors.indigo,
                                          Colors.pink,
                                        ];
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
                        onPressed: _loadRealData,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('새로고침'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _exportCurrentData,
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

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

// 드릴다운 레벨 열거형
enum DrillDownLevel {
  region,      // 지역/대륙
  country,     // 국가
  hospital,    // 병원/거래처
  transaction, // 거래 상세
}

// 드릴다운 노드 클래스
class DrillDownNode {
  final String category;
  final double value;
  final int count;
  final Map<String, dynamic> metadata;

  DrillDownNode({
    required this.category,
    required this.value,
    required this.count,
    required this.metadata,
  });
}