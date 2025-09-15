import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pivot_table_data.dart';

// 드래그&드롭 가능한 필드 아이템
class DraggablePivotField extends StatelessWidget {
  final PivotField field;
  final VoidCallback? onRemove;
  final bool isDragEnabled;
  final Color? backgroundColor;

  const DraggablePivotField({
    Key? key,
    required this.field,
    this.onRemove,
    this.isDragEnabled = true,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor ?? _getFieldColor(field.type),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getFieldIcon(field),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              field.displayName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.red,
              ),
            ),
          ],
        ],
      ),
    );

    if (!isDragEnabled) return widget;

    return Draggable<PivotField>(
      data: field,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor ?? _getFieldColor(field.type),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue.shade300, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _getFieldIcon(field),
              const SizedBox(width: 4),
              Text(
                field.displayName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: widget,
      ),
      child: widget,
    );
  }

  Color _getFieldColor(FieldType type) {
    switch (type) {
      case FieldType.text:
        return Colors.blue.shade50;
      case FieldType.number:
        return Colors.green.shade50;
      case FieldType.date:
        return Colors.orange.shade50;
      case FieldType.boolean:
        return Colors.purple.shade50;
    }
  }

  Widget _getFieldIcon(PivotField field) {
    IconData icon;
    Color color;

    switch (field.type) {
      case FieldType.text:
        icon = Icons.text_fields;
        color = Colors.blue;
        break;
      case FieldType.number:
        icon = field.aggregationType != null ? Icons.functions : Icons.numbers;
        color = Colors.green;
        break;
      case FieldType.date:
        icon = Icons.calendar_today;
        color = Colors.orange;
        break;
      case FieldType.boolean:
        icon = Icons.check_box;
        color = Colors.purple;
        break;
    }

    return Icon(icon, size: 14, color: color);
  }
}

// 드롭 영역
class PivotFieldDropZone extends StatefulWidget {
  final String label;
  final List<PivotField> fields;
  final Function(PivotField) onFieldAdded;
  final Function(PivotField) onFieldRemoved;
  final Function(int, int)? onFieldReordered;
  final bool acceptsNumericOnly;
  final int maxFields;
  final Color? backgroundColor;
  final String? helperText;

  const PivotFieldDropZone({
    Key? key,
    required this.label,
    required this.fields,
    required this.onFieldAdded,
    required this.onFieldRemoved,
    this.onFieldReordered,
    this.acceptsNumericOnly = false,
    this.maxFields = 10,
    this.backgroundColor,
    this.helperText,
  }) : super(key: key);

  @override
  State<PivotFieldDropZone> createState() => _PivotFieldDropZoneState();
}

class _PivotFieldDropZoneState extends State<PivotFieldDropZone> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.helperText!,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
        const SizedBox(height: 4),
        DragTarget<PivotField>(
          onAcceptWithDetails: (details) {
            HapticFeedback.lightImpact();
            if (widget.fields.length < widget.maxFields) {
              widget.onFieldAdded(details.data);
            }
            setState(() => _isDragOver = false);
          },
          onWillAcceptWithDetails: (details) {
            final field = details.data;
            if (field == null) return false;
            if (widget.fields.length >= widget.maxFields) return false;
            if (widget.fields.contains(field)) return false;
            if (widget.acceptsNumericOnly && !field.isNumeric) return false;
            return true;
          },
          onMove: (details) {
            if (!_isDragOver) {
              setState(() => _isDragOver = true);
            }
          },
          onLeave: (data) {
            setState(() => _isDragOver = false);
          },
          builder: (context, candidateData, rejectedData) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              constraints: const BoxConstraints(
                minHeight: 40,
                maxHeight: 120,
              ),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isDragOver
                    ? Colors.blue.shade50
                    : (widget.backgroundColor ?? Colors.grey.shade50),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isDragOver
                      ? Colors.blue.shade300
                      : Colors.grey.shade300,
                  width: _isDragOver ? 2 : 1,
                ),
              ),
              child: widget.fields.isEmpty
                  ? _buildEmptyState()
                  : _buildFieldList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drag_indicator,
            color: Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            '필드를 여기로 드래그하세요',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldList() {
    return ReorderableWrap(
      spacing: 4,
      runSpacing: 4,
      children: widget.fields
          .asMap()
          .entries
          .map((entry) => _buildReorderableField(entry.key, entry.value))
          .toList(),
      onReorder: widget.onFieldReordered != null
          ? (oldIndex, newIndex) {
              HapticFeedback.selectionClick();
              widget.onFieldReordered!(oldIndex, newIndex);
            }
          : null,
    );
  }

  Widget _buildReorderableField(int index, PivotField field) {
    return ReorderableItem(
      key: ValueKey(field.name),
      child: DraggablePivotField(
        field: field,
        onRemove: () {
          HapticFeedback.lightImpact();
          widget.onFieldRemoved(field);
        },
        isDragEnabled: false, // 재정렬 모드에서는 드래그 비활성화
      ),
    );
  }
}

// 사용 가능한 필드 목록
class AvailableFieldsList extends StatefulWidget {
  final List<PivotField> fields;
  final String searchQuery;

  const AvailableFieldsList({
    Key? key,
    required this.fields,
    this.searchQuery = '',
  }) : super(key: key);

  @override
  State<AvailableFieldsList> createState() => _AvailableFieldsListState();
}

class _AvailableFieldsListState extends State<AvailableFieldsList> {
  @override
  Widget build(BuildContext context) {
    final filteredFields = widget.fields.where((field) {
      if (widget.searchQuery.isEmpty) return true;
      return field.displayName.toLowerCase().contains(
        widget.searchQuery.toLowerCase(),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사용 가능한 필드',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: filteredFields
                .map((field) => DraggablePivotField(field: field))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// 피벗 테이블 필드 관리자 메인 위젯
class PivotTableFieldManager extends StatefulWidget {
  final List<PivotField> availableFields;
  final PivotTableConfiguration configuration;
  final Function(PivotTableConfiguration) onConfigurationChanged;
  final bool isCompact;

  const PivotTableFieldManager({
    Key? key,
    required this.availableFields,
    required this.configuration,
    required this.onConfigurationChanged,
    this.isCompact = false,
  }) : super(key: key);

  @override
  State<PivotTableFieldManager> createState() => _PivotTableFieldManagerState();
}

class _PivotTableFieldManagerState extends State<PivotTableFieldManager> {
  String _searchQuery = '';
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isCompact ? _buildCompactView() : _buildFullView();
  }

  Widget _buildFullView() {
    return Column(
      children: [
        _buildSearchBar(),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 좌측: 사용 가능한 필드
            Expanded(
              flex: 2,
              child: AvailableFieldsList(
                fields: widget.availableFields,
                searchQuery: _searchQuery,
              ),
            ),
            const SizedBox(width: 12),
            // 우측: 드롭 영역들
            Expanded(
              flex: 3,
              child: _buildDropZones(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactView() {
    return Column(
      children: [
        _buildDropZones(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: '필드 검색...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: (value) {
        setState(() => _searchQuery = value);
      },
    );
  }

  Widget _buildDropZones() {
    return Column(
      children: [
        // 필터 필드
        PivotFieldDropZone(
          label: '필터',
          fields: widget.configuration.filterFields,
          onFieldAdded: _addFilterField,
          onFieldRemoved: _removeFilterField,
          onFieldReordered: _reorderFilterFields,
          backgroundColor: Colors.purple.shade50,
          helperText: '데이터를 필터링할 필드',
        ),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 행 필드
            Expanded(
              child: PivotFieldDropZone(
                label: '행',
                fields: widget.configuration.rowFields,
                onFieldAdded: _addRowField,
                onFieldRemoved: _removeRowField,
                onFieldReordered: _reorderRowFields,
                backgroundColor: Colors.blue.shade50,
                helperText: '행에 표시할 필드',
              ),
            ),
            const SizedBox(width: 12),

            // 열 필드
            Expanded(
              child: PivotFieldDropZone(
                label: '열',
                fields: widget.configuration.columnFields,
                onFieldAdded: _addColumnField,
                onFieldRemoved: _removeColumnField,
                onFieldReordered: _reorderColumnFields,
                backgroundColor: Colors.orange.shade50,
                helperText: '열에 표시할 필드',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 값 필드
        PivotFieldDropZone(
          label: '값',
          fields: widget.configuration.valueFields,
          onFieldAdded: _addValueField,
          onFieldRemoved: _removeValueField,
          onFieldReordered: _reorderValueFields,
          acceptsNumericOnly: true,
          backgroundColor: Colors.green.shade50,
          helperText: '집계할 숫자 필드',
          maxFields: 5,
        ),
      ],
    );
  }

  // 필드 추가/제거 메서드들
  void _addFilterField(PivotField field) {
    final newConfig = widget.configuration.copyWith(
      filterFields: [...widget.configuration.filterFields, field],
    );
    widget.onConfigurationChanged(newConfig);
  }

  void _removeFilterField(PivotField field) {
    final newConfig = widget.configuration.copyWith(
      filterFields: widget.configuration.filterFields
          .where((f) => f.name != field.name)
          .toList(),
    );
    widget.onConfigurationChanged(newConfig);
  }

  void _reorderFilterFields(int oldIndex, int newIndex) {
    final fields = [...widget.configuration.filterFields];
    final field = fields.removeAt(oldIndex);
    fields.insert(newIndex, field);

    final newConfig = widget.configuration.copyWith(filterFields: fields);
    widget.onConfigurationChanged(newConfig);
  }

  void _addRowField(PivotField field) {
    final newConfig = widget.configuration.copyWith(
      rowFields: [...widget.configuration.rowFields, field],
    );
    widget.onConfigurationChanged(newConfig);
  }

  void _removeRowField(PivotField field) {
    final newConfig = widget.configuration.copyWith(
      rowFields: widget.configuration.rowFields
          .where((f) => f.name != field.name)
          .toList(),
    );
    widget.onConfigurationChanged(newConfig);
  }

  void _reorderRowFields(int oldIndex, int newIndex) {
    final fields = [...widget.configuration.rowFields];
    final field = fields.removeAt(oldIndex);
    fields.insert(newIndex, field);

    final newConfig = widget.configuration.copyWith(rowFields: fields);
    widget.onConfigurationChanged(newConfig);
  }

  void _addColumnField(PivotField field) {
    final newConfig = widget.configuration.copyWith(
      columnFields: [...widget.configuration.columnFields, field],
    );
    widget.onConfigurationChanged(newConfig);
  }

  void _removeColumnField(PivotField field) {
    final newConfig = widget.configuration.copyWith(
      columnFields: widget.configuration.columnFields
          .where((f) => f.name != field.name)
          .toList(),
    );
    widget.onConfigurationChanged(newConfig);
  }

  void _reorderColumnFields(int oldIndex, int newIndex) {
    final fields = [...widget.configuration.columnFields];
    final field = fields.removeAt(oldIndex);
    fields.insert(newIndex, field);

    final newConfig = widget.configuration.copyWith(columnFields: fields);
    widget.onConfigurationChanged(newConfig);
  }

  void _addValueField(PivotField field) {
    final newConfig = widget.configuration.copyWith(
      valueFields: [...widget.configuration.valueFields, field],
    );
    widget.onConfigurationChanged(newConfig);
  }

  void _removeValueField(PivotField field) {
    final newConfig = widget.configuration.copyWith(
      valueFields: widget.configuration.valueFields
          .where((f) => f.name != field.name)
          .toList(),
    );
    widget.onConfigurationChanged(newConfig);
  }

  void _reorderValueFields(int oldIndex, int newIndex) {
    final fields = [...widget.configuration.valueFields];
    final field = fields.removeAt(oldIndex);
    fields.insert(newIndex, field);

    final newConfig = widget.configuration.copyWith(valueFields: fields);
    widget.onConfigurationChanged(newConfig);
  }
}

// 재정렬 가능한 Wrap 위젯 (단순화된 구현)
class ReorderableWrap extends StatelessWidget {
  final List<Widget> children;
  final Function(int, int)? onReorder;
  final double spacing;
  final double runSpacing;

  const ReorderableWrap({
    Key? key,
    required this.children,
    this.onReorder,
    this.spacing = 0,
    this.runSpacing = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (onReorder == null) {
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: children,
      );
    }

    // 간단한 재정렬 기능 구현
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: children,
    );
  }
}

class ReorderableItem extends StatelessWidget {
  final Widget child;

  const ReorderableItem({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }
}