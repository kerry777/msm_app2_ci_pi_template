import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../providers/pivot_table_provider.dart';
import '../utils/unit_converter.dart';

class MultiDimensionalAnalysis extends StatefulWidget {
  const MultiDimensionalAnalysis({Key? key}) : super(key: key);

  @override
  State<MultiDimensionalAnalysis> createState() => _MultiDimensionalAnalysisState();
}

class _MultiDimensionalAnalysisState extends State<MultiDimensionalAnalysis>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late PivotDataGridSource _dataGridSource;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _dataGridSource = PivotDataGridSource([]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PivotTableProvider>(
      builder: (context, pivotProvider, child) {
        // DataGrid 데이터 소스 업데이트
        if (pivotProvider.pivotData.isNotEmpty) {
          _dataGridSource = PivotDataGridSource(pivotProvider.pivotData);
        }

        return Column(
          children: [
            // 컨트롤 패널
            _buildControlPanel(pivotProvider),

            const SizedBox(height: 16),

            // 탭바
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: '피벗 테이블', icon: Icon(Icons.table_chart)),
                Tab(text: '필드 설정', icon: Icon(Icons.settings)),
                Tab(text: '필터 & 정렬', icon: Icon(Icons.filter_list)),
              ],
            ),

            // 탭 내용
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPivotTableTab(pivotProvider),
                  _buildFieldSetupTab(pivotProvider),
                  _buildFilterTab(pivotProvider),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 컨트롤 패널
  Widget _buildControlPanel(PivotTableProvider provider) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 상태 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '데이터: ${provider.rawData.length}개',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '피벗: ${provider.pivotData.length - 1}행 × ${provider.pivotData.isNotEmpty ? provider.pivotData.first.length : 0}열',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // 액션 버튼들
            Row(
              children: [
                // 새로고침
                IconButton(
                  onPressed: provider.isLoading ? null : () => provider.initialize(),
                  icon: const Icon(Icons.refresh),
                  tooltip: '데이터 새로고침',
                ),

                // 엑셀 내보내기
                IconButton(
                  onPressed: provider.isLoading ? null : () => _exportToExcel(provider),
                  icon: const Icon(Icons.file_download),
                  tooltip: '엑셀로 내보내기',
                ),

                // 설정 초기화
                IconButton(
                  onPressed: () => _resetConfiguration(provider),
                  icon: const Icon(Icons.restore),
                  tooltip: '설정 초기화',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 피벗 테이블 탭
  Widget _buildPivotTableTab(PivotTableProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('피벗 테이블을 생성하는 중...'),
          ],
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.initialize(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (provider.pivotData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('피벗 테이블 데이터가 없습니다.'),
            SizedBox(height: 8),
            Text('필드를 설정하여 분석을 시작하세요.'),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: SfDataGrid(
        source: _dataGridSource,
        allowSorting: true,
        allowFiltering: true,
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        columnWidthMode: ColumnWidthMode.auto,
        headerRowHeight: 50,
        rowHeight: 40,
        columns: _buildDataGridColumns(provider.pivotData),
        onCellTap: (details) => _handleCellTap(details, provider),
      ),
    );
  }

  // 필드 설정 탭
  Widget _buildFieldSetupTab(PivotTableProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사용 가능한 필드
          _buildAvailableFields(provider),

          const SizedBox(height: 24),

          // 행 필드
          _buildFieldSection(
            title: '행 필드',
            icon: Icons.view_list,
            fields: provider.config.rowFields,
            availableFields: provider.availableFields,
            onAdd: (fieldName) => provider.addRowField(fieldName),
            onRemove: (fieldName) => _removeRowField(provider, fieldName),
          ),

          const SizedBox(height: 16),

          // 열 필드
          _buildFieldSection(
            title: '열 필드',
            icon: Icons.view_column,
            fields: provider.config.columnFields,
            availableFields: provider.availableFields,
            onAdd: (fieldName) => provider.addColumnField(fieldName),
            onRemove: (fieldName) => _removeColumnField(provider, fieldName),
          ),

          const SizedBox(height: 16),

          // 값 필드
          _buildValueFieldSection(provider),

          const SizedBox(height: 24),

          // 계산된 필드
          _buildCalculatedFieldSection(provider),
        ],
      ),
    );
  }

  // 필터 탭
  Widget _buildFilterTab(PivotTableProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 활성 필터
          _buildActiveFilters(provider),

          const SizedBox(height: 24),

          // 필터 추가
          _buildFilterControls(provider),

          const SizedBox(height: 24),

          // 정렬 설정
          _buildSortingControls(provider),
        ],
      ),
    );
  }

  // 사용 가능한 필드 목록
  Widget _buildAvailableFields(PivotTableProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.list_alt, size: 20),
                SizedBox(width: 8),
                Text('사용 가능한 필드', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: provider.availableFields.map((field) {
                return _buildFieldChip(field, provider);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // 필드 칩
  Widget _buildFieldChip(PivotField field, PivotTableProvider provider) {
    final isUsed = provider.config.rowFields.contains(field.name) ||
        provider.config.columnFields.contains(field.name) ||
        provider.config.valueFields.any((vf) => vf.fieldName == field.name);

    return Tooltip(
      message: '${field.displayName} (${field.category})',
      child: Draggable<PivotField>(
        data: field,
        feedback: Material(
          child: Chip(
            label: Text(field.displayName),
            backgroundColor: Colors.blue.withOpacity(0.7),
          ),
        ),
        child: Chip(
          label: Text(field.displayName),
          avatar: _getFieldIcon(field.type),
          backgroundColor: isUsed ? Colors.grey[300] : null,
          onDeleted: isUsed ? null : () {
            // 필드 사용 시작
          },
        ),
      ),
    );
  }

  // 필드 아이콘
  Widget _getFieldIcon(FieldType type) {
    switch (type) {
      case FieldType.dimension:
        return const Icon(Icons.category, size: 16);
      case FieldType.measure:
        return const Icon(Icons.calculate, size: 16);
      case FieldType.date:
        return const Icon(Icons.date_range, size: 16);
      case FieldType.calculated:
        return const Icon(Icons.functions, size: 16);
    }
  }

  // 필드 섹션
  Widget _buildFieldSection({
    required String title,
    required IconData icon,
    required List<String> fields,
    required List<PivotField> availableFields,
    required Function(String) onAdd,
    required Function(String) onRemove,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            DragTarget<PivotField>(
              onWillAccept: (data) => data != null,
              onAccept: (field) => onAdd(field.name),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 60),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: candidateData.isNotEmpty ? Colors.blue : Colors.grey[300]!,
                      width: candidateData.isNotEmpty ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: fields.isEmpty
                      ? Text(
                          '$title를 여기로 드래그하세요',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: fields.map((fieldName) {
                            final field = availableFields.firstWhere(
                              (f) => f.name == fieldName,
                              orElse: () => PivotField(
                                name: fieldName,
                                displayName: fieldName,
                                type: FieldType.dimension,
                                category: 'unknown',
                              ),
                            );
                            return Chip(
                              label: Text(field.displayName),
                              onDeleted: () => onRemove(fieldName),
                            );
                          }).toList(),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 값 필드 섹션
  Widget _buildValueFieldSection(PivotTableProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.calculate, size: 20),
                SizedBox(width: 8),
                Text('값 필드', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 80),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: provider.config.valueFields.isEmpty
                  ? Text(
                      '값 필드를 추가하세요',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.config.valueFields.map((valueField) {
                        return Chip(
                          label: Text(
                            '${valueField.fieldName} (${_getAggregationName(valueField.aggregation)})',
                          ),
                          onDeleted: () => _removeValueField(provider, valueField),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showAddValueFieldDialog(provider),
              icon: const Icon(Icons.add),
              label: const Text('값 필드 추가'),
            ),
          ],
        ),
      ),
    );
  }

  // 계산된 필드 섹션
  Widget _buildCalculatedFieldSection(PivotTableProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.functions, size: 20),
                SizedBox(width: 8),
                Text('계산된 필드', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (provider.calculatedFields.isEmpty)
              Text(
                '계산된 필드가 없습니다.',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              ...provider.calculatedFields.map((field) {
                return ListTile(
                  leading: const Icon(Icons.functions),
                  title: Text(field.displayName),
                  subtitle: Text(field.formula),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeCalculatedField(provider, field),
                  ),
                );
              }),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showAddCalculatedFieldDialog(provider),
              icon: const Icon(Icons.add),
              label: const Text('계산된 필드 추가'),
            ),
          ],
        ),
      ),
    );
  }

  // 활성 필터 표시
  Widget _buildActiveFilters(PivotTableProvider provider) {
    if (provider.config.filters.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '활성 필터가 없습니다.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.filter_alt, size: 20),
                SizedBox(width: 8),
                Text('활성 필터', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...provider.config.filters.entries.map((entry) {
              return Chip(
                label: Text('${entry.key}: ${entry.value.join(', ')}'),
                onDeleted: () => _removeFilter(provider, entry.key),
              );
            }),
          ],
        ),
      ),
    );
  }

  // 필터 컨트롤
  Widget _buildFilterControls(PivotTableProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.add_circle_outline, size: 20),
                SizedBox(width: 8),
                Text('필터 추가', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...provider.availableFields.where((f) => f.type == FieldType.dimension || f.type == FieldType.date).map((field) {
              return ListTile(
                title: Text(field.displayName),
                trailing: ElevatedButton(
                  onPressed: () => _showFilterDialog(provider, field),
                  child: const Text('필터 설정'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // 정렬 컨트롤
  Widget _buildSortingControls(PivotTableProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.sort, size: 20),
                SizedBox(width: 8),
                Text('정렬 설정', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '정렬 기능은 개발 중입니다.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // 데이터 그리드 컬럼 생성
  List<GridColumn> _buildDataGridColumns(List<List<dynamic>> pivotData) {
    if (pivotData.isEmpty) return [];

    final headers = pivotData.first;
    return headers.asMap().entries.map((entry) {
      final index = entry.key;
      final header = entry.value.toString();

      return GridColumn(
        columnName: 'col$index',
        label: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            header,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }).toList();
  }

  // 셀 탭 처리
  void _handleCellTap(DataGridCellTapDetails details, PivotTableProvider provider) {
    // 셀 클릭 시 상세 정보 표시
    if (details.rowColumnIndex.rowIndex > 0 && details.rowColumnIndex.columnIndex > 0) {
      _showCellDetails(details, provider);
    }
  }

  // 셀 상세 정보 다이얼로그
  void _showCellDetails(DataGridCellTapDetails details, PivotTableProvider provider) {
    final rowIndex = details.rowColumnIndex.rowIndex;
    final columnIndex = details.rowColumnIndex.columnIndex;

    if (rowIndex < provider.pivotData.length && columnIndex < provider.pivotData[rowIndex].length) {
      final value = provider.pivotData[rowIndex][columnIndex];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('셀 정보'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('위치: 행 $rowIndex, 열 $columnIndex'),
              Text('값: ${UnitConverter.formatNumberWithSuffix(double.tryParse(value.toString()) ?? 0)}'),
              // 추가 정보는 필요에 따라 구현
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
  }

  // 값 필드 추가 다이얼로그
  void _showAddValueFieldDialog(PivotTableProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('값 필드 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: provider.availableFields.where((f) => f.type == FieldType.measure).map((field) {
            return ListTile(
              title: Text(field.displayName),
              trailing: DropdownButton<AggregationType>(
                value: field.aggregationType ?? AggregationType.sum,
                onChanged: (aggregation) {
                  if (aggregation != null) {
                    provider.addValueField(field.name, aggregation);
                    Navigator.of(context).pop();
                  }
                },
                items: AggregationType.values.map((agg) {
                  return DropdownMenuItem(
                    value: agg,
                    child: Text(_getAggregationName(agg)),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  // 계산된 필드 추가 다이얼로그
  void _showAddCalculatedFieldDialog(PivotTableProvider provider) {
    final nameController = TextEditingController();
    final displayNameController = TextEditingController();
    final formulaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계산된 필드 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '필드명 (영문)'),
            ),
            TextField(
              controller: displayNameController,
              decoration: const InputDecoration(labelText: '표시명'),
            ),
            TextField(
              controller: formulaController,
              decoration: const InputDecoration(
                labelText: '수식',
                hintText: 'salesAmount * quantity',
              ),
              maxLines: 2,
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
              if (nameController.text.isNotEmpty &&
                  displayNameController.text.isNotEmpty &&
                  formulaController.text.isNotEmpty) {
                final field = CalculatedField(
                  name: nameController.text,
                  displayName: displayNameController.text,
                  formula: formulaController.text,
                );
                provider.addCalculatedField(field);
                Navigator.of(context).pop();
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // 필터 다이얼로그
  void _showFilterDialog(PivotTableProvider provider, PivotField field) {
    final availableValues = provider.fieldValues[field.name] ?? [];
    final currentFilter = provider.config.filters[field.name] ?? [];
    final selectedValues = Set<String>.from(currentFilter);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${field.displayName} 필터'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: availableValues.isEmpty
                ? const Text('필터 가능한 값이 없습니다.')
                : ListView(
                    children: availableValues.map((value) {
                      return CheckboxListTile(
                        title: Text(value),
                        value: selectedValues.contains(value),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              selectedValues.add(value);
                            } else {
                              selectedValues.remove(value);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                provider.addFilter(field.name, selectedValues.toList());
                Navigator.of(context).pop();
              },
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
  }

  // 유틸리티 메서드들
  String _getAggregationName(AggregationType type) {
    switch (type) {
      case AggregationType.sum: return '합계';
      case AggregationType.average: return '평균';
      case AggregationType.count: return '개수';
      case AggregationType.min: return '최소';
      case AggregationType.max: return '최대';
    }
  }

  void _removeRowField(PivotTableProvider provider, String fieldName) {
    final newRowFields = List<String>.from(provider.config.rowFields);
    newRowFields.remove(fieldName);
    provider.updateConfiguration(provider.config.copyWith(rowFields: newRowFields));
  }

  void _removeColumnField(PivotTableProvider provider, String fieldName) {
    final newColumnFields = List<String>.from(provider.config.columnFields);
    newColumnFields.remove(fieldName);
    provider.updateConfiguration(provider.config.copyWith(columnFields: newColumnFields));
  }

  void _removeValueField(PivotTableProvider provider, ValueField valueField) {
    final newValueFields = List<ValueField>.from(provider.config.valueFields);
    newValueFields.removeWhere((vf) =>
      vf.fieldName == valueField.fieldName && vf.aggregation == valueField.aggregation);
    provider.updateConfiguration(provider.config.copyWith(valueFields: newValueFields));
  }

  void _removeFilter(PivotTableProvider provider, String fieldName) {
    final newFilters = Map<String, List<String>>.from(provider.config.filters);
    newFilters.remove(fieldName);
    provider.updateConfiguration(provider.config.copyWith(filters: newFilters));
  }

  void _removeCalculatedField(PivotTableProvider provider, CalculatedField field) {
    // 계산된 필드 제거 로직 구현 필요
  }

  void _exportToExcel(PivotTableProvider provider) {
    // 엑셀 내보내기 로직
    provider.exportToExcel().then((filePath) {
      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('엑셀 파일이 저장되었습니다: $filePath')),
        );
      }
    });
  }

  void _resetConfiguration(PivotTableProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정 초기화'),
        content: const Text('모든 피벗 테이블 설정을 초기화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.updateConfiguration(const PivotTableConfiguration());
              Navigator.of(context).pop();
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}

// 피벗 데이터 그리드 소스
class PivotDataGridSource extends DataGridSource {
  PivotDataGridSource(List<List<dynamic>> pivotData) {
    _buildDataRows(pivotData);
  }

  List<DataGridRow> _dataRows = [];

  @override
  List<DataGridRow> get rows => _dataRows;

  void _buildDataRows(List<List<dynamic>> pivotData) {
    if (pivotData.length <= 1) {
      _dataRows = [];
      return;
    }

    // 첫 번째 행은 헤더이므로 제외
    _dataRows = pivotData.skip(1).map((row) {
      return DataGridRow(
        cells: row.asMap().entries.map((entry) {
          return DataGridCell<dynamic>(
            columnName: 'col${entry.key}',
            value: entry.value,
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map((cell) {
        final value = cell.value;
        String displayText;

        if (value is num) {
          displayText = UnitConverter.formatNumberWithSuffix(value.toDouble());
        } else {
          displayText = value.toString();
        }

        return Container(
          alignment: value is num ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            displayText,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}