import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:provider/provider.dart';
// import '../services/enhanced_api_service.dart';  // 임시 주석 처리
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class SyncfusionPivotAnalysisScreen extends StatefulWidget {
  const SyncfusionPivotAnalysisScreen({super.key});

  @override
  State<SyncfusionPivotAnalysisScreen> createState() => _SyncfusionPivotAnalysisScreenState();
}

class _SyncfusionPivotAnalysisScreenState extends State<SyncfusionPivotAnalysisScreen> {
  // final EnhancedApiService _apiService = EnhancedApiService();  // 임시 주석 처리
  late PivotDataGridSource _dataSource;
  List<Map<String, dynamic>> _rawData = [];
  bool _isLoading = true;
  String _error = '';
  bool _disposed = false;

  // 피벗 설정
  final List<String> _selectedRowFields = ['HOSP_NM']; // 기본으로 병원명을 행에 배치
  List<String> _selectedColumnFields = ['WORK_DATE']; // 기본으로 작업일을 열에 배치
  final List<String> _selectedValueFields = ['SL_QTY']; // 기본으로 판매수량을 값으로 배치

  // 사용 가능한 필드들
  final List<String> _availableFields = [
    'HOSP_NM',      // 병원명
    'ITEM_NM',      // 품목명
    'WORK_DATE',    // 작업일
    'AREA_NM',      // 지역명
    'COUNTRY_NM',   // 국가명
    'AGENCY_NM',    // 대리점명
    'HOSP_TYPE',    // 병원분류
    'SL_QTY',       // 판매수량
    'SL_AMT',       // 판매금액
    'STOCK_QTY',    // 재고수량
  ];

  final Map<String, String> _fieldLabels = {
    'HOSP_NM': '병원명',
    'ITEM_NM': '품목명',
    'WORK_DATE': '작업일',
    'AREA_NM': '지역명',
    'COUNTRY_NM': '국가명',
    'AGENCY_NM': '대리점명',
    'HOSP_TYPE': '병원분류',
    'SL_QTY': '판매수량',
    'SL_AMT': '판매금액',
    'STOCK_QTY': '재고수량',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted || _disposed) return;

    if (mounted && !_disposed) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      // 임시 목업 데이터 생성 (실제 API 연동 전까지)
      await Future.delayed(const Duration(seconds: 1)); // 로딩 시뮬레이션

      if (mounted && !_disposed) {
        setState(() {
          _rawData = _generateMockData();
          _dataSource = PivotDataGridSource(
            data: _rawData,
            rowFields: _selectedRowFields,
            columnFields: _selectedColumnFields,
            valueFields: _selectedValueFields,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !_disposed) {
        setState(() {
          _error = '데이터 로딩 실패: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _generateMockData() {
    final data = <Map<String, dynamic>>[];
    final hospitals = ['서울대병원', '연세세브란스', '삼성서울병원', '아산의료원', '서울아산병원'];
    final items = ['CT스캔', 'MRI', '초음파기', 'X레이기', '혈액검사기'];
    final areas = ['서울', '경기', '부산', '대구', '인천'];
    final countries = ['한국', '미국', '독일', '일본'];
    final agencies = ['에이전시A', '에이전시B', '에이전시C', '에이전시D'];
    final hospTypes = ['대학병원', '종합병원', '전문병원'];

    final random = DateTime.now().millisecondsSinceEpoch % 1000;

    for (int i = 0; i < 50; i++) {
      final hospIndex = (random + i) % hospitals.length;
      final itemIndex = (random + i * 2) % items.length;
      final areaIndex = (random + i * 3) % areas.length;
      final countryIndex = (random + i * 4) % countries.length;
      final agencyIndex = (random + i * 5) % agencies.length;
      final typeIndex = (random + i * 6) % hospTypes.length;

      data.add({
        'HOSP_NM': hospitals[hospIndex],
        'ITEM_NM': items[itemIndex],
        'WORK_DATE': DateTime.now().subtract(Duration(days: i % 30)).toIso8601String().split('T')[0],
        'AREA_NM': areas[areaIndex],
        'COUNTRY_NM': countries[countryIndex],
        'AGENCY_NM': agencies[agencyIndex],
        'HOSP_TYPE': hospTypes[typeIndex],
        'SL_QTY': ((random + i * 7) % 100) + 1,
        'SL_AMT': ((random + i * 8) % 1000000) + 100000,
        'STOCK_QTY': ((random + i * 9) % 500) + 10,
      });
    }

    return data;
  }

  void _updatePivotConfiguration() {
    if (!mounted || _disposed || _rawData.isEmpty) return;

    if (mounted && !_disposed) {
      setState(() {
        _dataSource = PivotDataGridSource(
          data: _rawData,
          rowFields: _selectedRowFields,
          columnFields: _selectedColumnFields,
          valueFields: _selectedValueFields,
        );
      });
    }
  }

  void _showFieldSelector() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('피벗 테이블 설정'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 행 필드 설정 (드래그 가능)
                const Text('행 필드 (드래그하여 순서 조정)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: ReorderableListView(
                    scrollDirection: Axis.horizontal,
                    onReorder: (oldIndex, newIndex) {
                      setDialogState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final field = _selectedRowFields.removeAt(oldIndex);
                        _selectedRowFields.insert(newIndex, field);
                      });
                    },
                    children: _selectedRowFields.map((field) {
                      return Container(
                        key: ValueKey(field),
                        margin: const EdgeInsets.all(4),
                        child: Chip(
                          label: Text(_fieldLabels[field] ?? field),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setDialogState(() {
                              _selectedRowFields.remove(field);
                            });
                          },
                          backgroundColor: Colors.green.shade100,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // 사용 가능한 행 필드들
                Wrap(
                  spacing: 8,
                  children: _availableFields.where((f) => !['SL_QTY', 'SL_AMT', 'STOCK_QTY'].contains(f) && !_selectedRowFields.contains(f)).map((field) {
                    return ActionChip(
                      label: Text(_fieldLabels[field] ?? field),
                      onPressed: () {
                        setDialogState(() {
                          _selectedRowFields.add(field);
                        });
                      },
                      backgroundColor: Colors.grey.shade200,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // 열 필드 설정
                const Text('열 필드',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.blue.shade50,
                  ),
                  child: _selectedColumnFields.isNotEmpty
                    ? Center(
                        child: Chip(
                          label: Text(_fieldLabels[_selectedColumnFields.first] ?? _selectedColumnFields.first),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setDialogState(() {
                              _selectedColumnFields.clear();
                            });
                          },
                          backgroundColor: Colors.blue.shade100,
                        ),
                      )
                    : const Center(
                        child: Text(
                          '열 필드를 선택하세요',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _availableFields.where((f) => !['SL_QTY', 'SL_AMT', 'STOCK_QTY'].contains(f) && !_selectedColumnFields.contains(f)).map((field) {
                    return ActionChip(
                      label: Text(_fieldLabels[field] ?? field),
                      onPressed: () {
                        setDialogState(() {
                          _selectedColumnFields = [field]; // 열은 하나만 선택 가능
                        });
                      },
                      backgroundColor: Colors.grey.shade200,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // 값 필드 설정 (드래그 가능)
                const Text('값 필드 (드래그하여 순서 조정)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.orange.shade50,
                  ),
                  child: ReorderableListView(
                    scrollDirection: Axis.horizontal,
                    onReorder: (oldIndex, newIndex) {
                      setDialogState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final field = _selectedValueFields.removeAt(oldIndex);
                        _selectedValueFields.insert(newIndex, field);
                      });
                    },
                    children: _selectedValueFields.map((field) {
                      return Container(
                        key: ValueKey(field),
                        margin: const EdgeInsets.all(4),
                        child: Chip(
                          label: Text(_fieldLabels[field] ?? field),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setDialogState(() {
                              _selectedValueFields.remove(field);
                            });
                          },
                          backgroundColor: Colors.orange.shade100,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['SL_QTY', 'SL_AMT', 'STOCK_QTY'].where((f) => !_selectedValueFields.contains(f)).map((field) {
                    return ActionChip(
                      label: Text(_fieldLabels[field] ?? field),
                      onPressed: () {
                        setDialogState(() {
                          _selectedValueFields.add(field);
                        });
                      },
                      backgroundColor: Colors.grey.shade200,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updatePivotConfiguration();
              },
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔄 피벗분석2_싱크퓨전'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '피벗 설정',
            onPressed: _showFieldSelector,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // 현재 피벗 설정 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade100, Colors.indigo.shade50],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🏢 현재 피벗 설정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildConfigurationChip(
                      '행 필드',
                      _selectedRowFields.map((f) => _fieldLabels[f] ?? f).join(', '),
                      Icons.view_week,
                      Colors.green,
                    ),
                    _buildConfigurationChip(
                      '열 필드',
                      _selectedColumnFields.map((f) => _fieldLabels[f] ?? f).join(', '),
                      Icons.view_column,
                      Colors.blue,
                    ),
                    _buildConfigurationChip(
                      '값 필드',
                      _selectedValueFields.map((f) => _fieldLabels[f] ?? f).join(', '),
                      Icons.calculate,
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 피벗 테이블
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('데이터를 로딩 중입니다...'),
                      ],
                    ),
                  )
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        child: SfDataGridTheme(
                          data: SfDataGridThemeData(
                            headerColor: Colors.indigo.shade50,
                            gridLineColor: Colors.grey.shade300,
                            gridLineStrokeWidth: 1.0,
                          ),
                          child: SfDataGrid(
                            source: _dataSource,
                            allowSorting: true,
                            allowMultiColumnSorting: true,
                            gridLinesVisibility: GridLinesVisibility.both,
                            headerGridLinesVisibility: GridLinesVisibility.both,
                            headerRowHeight: 50,
                            rowHeight: 40,
                            columns: _buildGridColumns(),
                          ),
                        ),
                      ),
          ),

          // 통계 요약 정보
          if (!_isLoading && _error.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard('총 데이터', '${_rawData.length}', Icons.dataset, Colors.blue),
                  _buildStatCard('행 필드', '${_selectedRowFields.length}', Icons.view_week, Colors.green),
                  _buildStatCard('값 필드', '${_selectedValueFields.length}', Icons.calculate, Colors.orange),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfigurationChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
          Text(
            value.isEmpty ? '없음' : value,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  List<GridColumn> _buildGridColumns() {
    List<GridColumn> columns = [];

    // 행 필드들에 대한 컬럼 생성
    for (String field in _selectedRowFields) {
      columns.add(GridColumn(
        columnName: field,
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: Text(
            _fieldLabels[field] ?? field,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ),
        width: 120,
      ));
    }

    // 값 필드들에 대한 컬럼 생성 (열 필드와 조합)
    for (String valueField in _selectedValueFields) {
      columns.add(GridColumn(
        columnName: valueField,
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.center,
          child: Text(
            _fieldLabels[valueField] ?? valueField,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
        width: 100,
      ));
    }

    return columns;
  }
}

// Syncfusion DataGrid를 위한 데이터 소스
class PivotDataGridSource extends DataGridSource {
  List<DataGridRow> _rows = [];
  final List<Map<String, dynamic>> data;
  final List<String> rowFields;
  final List<String> columnFields;
  final List<String> valueFields;

  PivotDataGridSource({
    required this.data,
    required this.rowFields,
    required this.columnFields,
    required this.valueFields,
  }) {
    _buildPivotData();
  }

  void _buildPivotData() {
    if (data.isEmpty || rowFields.isEmpty || valueFields.isEmpty) {
      _rows = [];
      return;
    }

    // 그룹핑된 데이터 생성
    Map<String, Map<String, dynamic>> groupedData = {};

    for (var record in data) {
      // 행 키 생성 (여러 행 필드를 조합)
      String rowKey = rowFields.map((field) => record[field]?.toString() ?? '').join('|');

      if (!groupedData.containsKey(rowKey)) {
        groupedData[rowKey] = {};
        // 행 필드들 복사
        for (String field in rowFields) {
          groupedData[rowKey]![field] = record[field];
        }
        // 값 필드들 초기화
        for (String field in valueFields) {
          groupedData[rowKey]![field] = 0.0;
        }
      }

      // 값 필드들 집계
      for (String field in valueFields) {
        var value = record[field];
        if (value is num) {
          groupedData[rowKey]![field] = (groupedData[rowKey]![field] ?? 0.0) + value.toDouble();
        }
      }
    }

    // DataGridRow로 변환
    _rows = groupedData.entries.map((entry) {
      List<DataGridCell> cells = [];

      // 행 필드 셀들 추가
      for (String field in rowFields) {
        cells.add(DataGridCell(
          columnName: field,
          value: entry.value[field]?.toString() ?? '',
        ));
      }

      // 값 필드 셀들 추가
      for (String field in valueFields) {
        var value = entry.value[field];
        String displayValue = '';
        if (value is num) {
          displayValue = NumberFormat('#,###').format(value);
        }
        cells.add(DataGridCell(
          columnName: field,
          value: displayValue,
        ));
      }

      return DataGridRow(cells: cells);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            cell.value.toString(),
            style: TextStyle(
              fontSize: 12,
              color: cell.columnName == 'SL_AMT' || cell.columnName == 'SL_QTY' || cell.columnName == 'STOCK_QTY'
                  ? Colors.blue.shade700
                  : Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }
}