import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pivot_table_data.dart';
import '../services/pivot_table_engine.dart';

// 피벗 테이블 데이터 그리드 위젯
class PivotTableGrid extends StatefulWidget {
  final PivotTableResult result;
  final PivotTableConfiguration configuration;
  final List<ConditionalFormattingRule> conditionalFormattingRules;
  final Function(PivotTableCell)? onCellTap;
  final Function(PivotTableCell)? onCellDoubleTap;
  final Function(PivotTableHeader, bool)? onHeaderExpandToggle;
  final bool showGridLines;
  final bool freezeHeaders;
  final double cellHeight;
  final double cellWidth;

  const PivotTableGrid({
    Key? key,
    required this.result,
    required this.configuration,
    this.conditionalFormattingRules = const [],
    this.onCellTap,
    this.onCellDoubleTap,
    this.onHeaderExpandToggle,
    this.showGridLines = true,
    this.freezeHeaders = true,
    this.cellHeight = 32.0,
    this.cellWidth = 100.0,
  }) : super(key: key);

  @override
  State<PivotTableGrid> createState() => _PivotTableGridState();
}

class _PivotTableGridState extends State<PivotTableGrid> {
  late ScrollController _horizontalController;
  late ScrollController _verticalController;
  late ScrollController _headerHorizontalController;
  late ScrollController _headerVerticalController;

  Map<String, Map<String, dynamic>>? _fieldStatistics;
  Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
    _verticalController = ScrollController();
    _headerHorizontalController = ScrollController();
    _headerVerticalController = ScrollController();

    // 스크롤 동기화
    _horizontalController.addListener(_syncHorizontalScroll);
    _verticalController.addListener(_syncVerticalScroll);
    _headerHorizontalController.addListener(_syncHeaderHorizontalScroll);
    _headerVerticalController.addListener(_syncHeaderVerticalScroll);

    _initializeFieldStatistics();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _headerHorizontalController.dispose();
    _headerVerticalController.dispose();
    super.dispose();
  }

  void _syncHorizontalScroll() {
    if (_headerHorizontalController.hasClients) {
      _headerHorizontalController.jumpTo(_horizontalController.offset);
    }
  }

  void _syncVerticalScroll() {
    if (_headerVerticalController.hasClients) {
      _headerVerticalController.jumpTo(_verticalController.offset);
    }
  }

  void _syncHeaderHorizontalScroll() {
    if (_horizontalController.hasClients) {
      _horizontalController.jumpTo(_headerHorizontalController.offset);
    }
  }

  void _syncHeaderVerticalScroll() {
    if (_verticalController.hasClients) {
      _verticalController.jumpTo(_headerVerticalController.offset);
    }
  }

  void _initializeFieldStatistics() {
    // 조건부 서식을 위한 필드 통계 계산
    // 실제 데이터가 필요하므로 임시로 빈 상태로 초기화
    _fieldStatistics = {};
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result.isEmpty) {
      return _buildEmptyState();
    }

    return widget.freezeHeaders ? _buildFrozenHeaderGrid() : _buildSimpleGrid();
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.grid_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '피벗 테이블에 표시할 데이터가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '행, 열, 값 필드를 설정해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrozenHeaderGrid() {
    return Container(
      decoration: BoxDecoration(
        border: widget.showGridLines
            ? Border.all(color: Colors.grey.shade300)
            : null,
      ),
      child: Column(
        children: [
          // 상단 헤더 (열 헤더)
          SizedBox(
            height: _calculateColumnHeaderHeight(),
            child: Row(
              children: [
                // 좌상단 코너 (행 헤더 크기만큼)
                Container(
                  width: _calculateRowHeaderWidth(),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: widget.showGridLines
                        ? Border(
                            right: BorderSide(color: Colors.grey.shade400),
                            bottom: BorderSide(color: Colors.grey.shade400),
                          )
                        : null,
                  ),
                ),
                // 열 헤더
                Expanded(
                  child: SingleChildScrollView(
                    controller: _headerHorizontalController,
                    scrollDirection: Axis.horizontal,
                    child: _buildColumnHeaders(),
                  ),
                ),
              ],
            ),
          ),
          // 메인 그리드
          Expanded(
            child: Row(
              children: [
                // 행 헤더
                SizedBox(
                  width: _calculateRowHeaderWidth(),
                  child: SingleChildScrollView(
                    controller: _headerVerticalController,
                    child: _buildRowHeaders(),
                  ),
                ),
                // 데이터 그리드
                Expanded(
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: _buildDataGrid(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleGrid() {
    return SingleChildScrollView(
      controller: _verticalController,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: _buildFullGrid(),
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return Container(
      height: _calculateColumnHeaderHeight(),
      child: Column(
        children: widget.configuration.columnFields
            .asMap()
            .entries
            .map((entry) => _buildColumnHeaderLevel(entry.key))
            .toList(),
      ),
    );
  }

  Widget _buildColumnHeaderLevel(int level) {
    final columnHeaders = widget.result.columnHeaders
        .where((header) => header.level == level)
        .toList();

    return SizedBox(
      height: widget.cellHeight,
      child: Row(
        children: columnHeaders
            .map((header) => _buildColumnHeaderCell(header))
            .toList(),
      ),
    );
  }

  Widget _buildColumnHeaderCell(PivotTableHeader header) {
    return Container(
      width: widget.cellWidth,
      height: widget.cellHeight,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: widget.showGridLines
            ? Border.all(color: Colors.grey.shade300)
            : null,
      ),
      child: InkWell(
        onTap: header.hasChildren && widget.onHeaderExpandToggle != null
            ? () => widget.onHeaderExpandToggle!(header, !header.isExpanded)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              if (header.hasChildren)
                Icon(
                  header.isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 16,
                ),
              Expanded(
                child: Text(
                  header.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRowHeaders() {
    return Column(
      children: widget.result.rowHeaders
          .map((header) => _buildRowHeaderCell(header))
          .toList(),
    );
  }

  Widget _buildRowHeaderCell(PivotTableHeader header) {
    final isExpanded = _expandedGroups.contains(_getGroupKey(header));

    return Container(
      width: _calculateRowHeaderWidth(),
      height: widget.cellHeight,
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: widget.showGridLines
            ? Border.all(color: Colors.grey.shade300)
            : null,
      ),
      child: InkWell(
        onTap: header.hasChildren
            ? () {
                setState(() {
                  final groupKey = _getGroupKey(header);
                  if (isExpanded) {
                    _expandedGroups.remove(groupKey);
                  } else {
                    _expandedGroups.add(groupKey);
                  }
                });
                HapticFeedback.selectionClick();
              }
            : null,
        child: Padding(
          padding: EdgeInsets.only(
            left: 8.0 + (header.level * 16.0), // 계층별 들여쓰기
            right: 8.0,
            top: 4.0,
            bottom: 4.0,
          ),
          child: Row(
            children: [
              if (header.hasChildren)
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 16,
                ),
              Expanded(
                child: Text(
                  header.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: header.level == 0
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataGrid() {
    return Column(
      children: widget.result.dataGrid
          .asMap()
          .entries
          .map((entry) => _buildDataRow(entry.key, entry.value))
          .toList(),
    );
  }

  Widget _buildDataRow(int rowIndex, List<PivotTableCell> row) {
    return SizedBox(
      height: widget.cellHeight,
      child: Row(
        children: row
            .asMap()
            .entries
            .map((entry) => _buildDataCell(
                  rowIndex,
                  entry.key,
                  entry.value,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDataCell(int row, int column, PivotTableCell cell) {
    final styles = _getCellStyles(cell);

    return Container(
      width: widget.cellWidth,
      height: widget.cellHeight,
      decoration: BoxDecoration(
        color: styles['backgroundColor'] != null
            ? _parseColor(styles['backgroundColor']!)
            : (cell.isTotal
                ? Colors.yellow.shade50
                : cell.isGrandTotal
                    ? Colors.orange.shade100
                    : Colors.white),
        border: widget.showGridLines
            ? Border.all(
                color: cell.isTotal || cell.isGrandTotal
                    ? Colors.orange.shade400
                    : Colors.grey.shade300,
                width: cell.isTotal || cell.isGrandTotal ? 1.5 : 1,
              )
            : null,
      ),
      child: Stack(
        children: [
          // 데이터 바 (조건부 서식)
          if (styles['dataBar'] != null) _buildDataBar(styles['dataBar']!),
          // 셀 내용
          InkWell(
            onTap: cell.isClickable && widget.onCellTap != null
                ? () => widget.onCellTap!(cell)
                : null,
            onDoubleTap: cell.isClickable && widget.onCellDoubleTap != null
                ? () => widget.onCellDoubleTap!(cell)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              alignment: cell.sourceField?.isNumeric == true
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(
                cell.displayValue,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: cell.isTotal || cell.isGrandTotal
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: cell.isEmpty
                      ? Colors.grey.shade500
                      : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataBar(String percentage) {
    final percent = double.tryParse(percentage.replaceAll('%', '')) ?? 0;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade200, Colors.transparent],
            stops: [percent / 100, percent / 100],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }

  Widget _buildFullGrid() {
    // 간단한 전체 그리드 (헤더 고정 없음)
    return Container(
      decoration: BoxDecoration(
        border: widget.showGridLines
            ? Border.all(color: Colors.grey.shade300)
            : null,
      ),
      child: Column(
        children: [
          // 헤더
          _buildSimpleHeader(),
          // 데이터
          ..._buildSimpleDataRows(),
          // 총계
          if (widget.configuration.showGrandTotals) _buildGrandTotalRow(),
        ],
      ),
    );
  }

  Widget _buildSimpleHeader() {
    return Container(
      height: widget.cellHeight,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: widget.showGridLines
            ? Border(bottom: BorderSide(color: Colors.grey.shade400))
            : null,
      ),
      child: Row(
        children: [
          // 행 헤더 영역
          ...widget.configuration.rowFields.map((field) => Container(
                width: widget.cellWidth,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  field.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
          // 값 필드 헤더
          ...widget.configuration.valueFields.map((field) => Container(
                width: widget.cellWidth,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  field.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
        ],
      ),
    );
  }

  List<Widget> _buildSimpleDataRows() {
    // 간단한 데이터 행들 (실제 구현에서는 더 복잡한 로직 필요)
    return [];
  }

  Widget _buildGrandTotalRow() {
    return Container(
      height: widget.cellHeight,
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        border: widget.showGridLines
            ? Border.all(color: Colors.orange.shade400, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: widget.cellWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: const Text(
              '총계',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...widget.result.grandTotals.entries.map((entry) => Container(
                width: widget.cellWidth,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                alignment: Alignment.centerRight,
                child: Text(
                  _formatValue(entry.value, entry.key),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
        ],
      ),
    );
  }

  // 헬퍼 메서드들
  double _calculateColumnHeaderHeight() {
    return widget.cellHeight * widget.configuration.columnFields.length;
  }

  double _calculateRowHeaderWidth() {
    return widget.cellWidth * 1.5; // 행 헤더는 좀 더 넓게
  }

  String _getGroupKey(PivotTableHeader header) {
    return header.groupPath.join('|');
  }

  Map<String, String> _getCellStyles(PivotTableCell cell) {
    if (_fieldStatistics == null) return {};

    return PivotTableEngine.applyConditionalFormatting(
      cell,
      widget.conditionalFormattingRules,
      _fieldStatistics!,
    );
  }

  Color _parseColor(String colorString) {
    // 간단한 색상 파싱 (실제로는 더 정교한 구현 필요)
    switch (colorString.toLowerCase()) {
      case 'red':
        return Colors.red.shade100;
      case 'green':
        return Colors.green.shade100;
      case 'blue':
        return Colors.blue.shade100;
      case 'yellow':
        return Colors.yellow.shade100;
      default:
        return Colors.white;
    }
  }

  String _formatValue(dynamic value, String fieldName) {
    if (value == null) return '';

    // 필드별 포맷 찾기
    final field = [
      ...widget.configuration.valueFields,
      ...widget.configuration.rowFields,
      ...widget.configuration.columnFields,
    ].where((f) => f.name == fieldName).firstOrNull;

    if (field?.format != null && value is num) {
      return _formatNumber(value, field!.format!);
    }

    return value.toString();
  }

  String _formatNumber(num value, String format) {
    if (format.contains('%')) {
      return '${(value * 100).toStringAsFixed(2)}%';
    } else if (format.contains('#,##0')) {
      return value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match match) => '${match[1]},',
      );
    } else if (format.contains('0.00')) {
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }
}

// 피벗 테이블 툴바
class PivotTableToolbar extends StatelessWidget {
  final PivotTableConfiguration configuration;
  final Function(PivotTableConfiguration) onConfigurationChanged;
  final VoidCallback? onExportExcel;
  final VoidCallback? onExportCsv;
  final VoidCallback? onRefresh;
  final bool showExportButtons;

  const PivotTableToolbar({
    Key? key,
    required this.configuration,
    required this.onConfigurationChanged,
    this.onExportExcel,
    this.onExportCsv,
    this.onRefresh,
    this.showExportButtons = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          // 새로고침 버튼
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
              tooltip: '새로고침',
              iconSize: 20,
            ),

          const SizedBox(width: 8),

          // 총계 표시 토글
          Text('총계:', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Checkbox(
            value: configuration.showGrandTotals,
            onChanged: (value) {
              onConfigurationChanged(
                configuration.copyWith(showGrandTotals: value),
              );
            },
          ),

          const SizedBox(width: 16),

          // 소계 표시 토글
          Text('소계:', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Checkbox(
            value: configuration.showSubTotals,
            onChanged: (value) {
              onConfigurationChanged(
                configuration.copyWith(showSubTotals: value),
              );
            },
          ),

          const Spacer(),

          // 내보내기 버튼들
          if (showExportButtons) ...[
            if (onExportExcel != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.table_chart, size: 16),
                label: const Text('Excel', style: TextStyle(fontSize: 12)),
                onPressed: onExportExcel,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            const SizedBox(width: 8),
            if (onExportCsv != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.file_download, size: 16),
                label: const Text('CSV', style: TextStyle(fontSize: 12)),
                onPressed: onExportCsv,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ],
      ),
    );
  }
}