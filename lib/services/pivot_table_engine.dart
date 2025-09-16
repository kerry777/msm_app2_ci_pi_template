import '../models/pivot_table_data.dart';

// 피벗 테이블 계산 엔진
class PivotTableEngine {
  // 데이터 그룹핑 및 집계 처리
  static PivotTableResult processPivotTable(
    List<PivotTableData> data,
    PivotTableConfiguration config,
  ) {
    // 필터 적용
    final filteredData = _applyFilters(data, config.activeFilters);

    // 행/열 헤더 구성
    final rowHeaders = _buildHeaders(filteredData, config.rowFields, 'row');
    final columnHeaders = _buildHeaders(filteredData, config.columnFields, 'column');

    // 데이터 그리드 생성
    final dataGrid = _buildDataGrid(
      filteredData,
      rowHeaders,
      columnHeaders,
      config,
    );

    return PivotTableResult(
      rowHeaders: rowHeaders,
      columnHeaders: columnHeaders,
      dataGrid: dataGrid,
      totalRows: rowHeaders.length,
      totalColumns: columnHeaders.length,
      grandTotals: _calculateGrandTotals(filteredData, config.valueFields),
    );
  }

  // 필터 적용
  static List<PivotTableData> _applyFilters(
    List<PivotTableData> data,
    Map<String, List<dynamic>> filters,
  ) {
    if (filters.isEmpty) return data;

    return data.where((row) {
      return filters.entries.every((filter) {
        final fieldName = filter.key;
        final allowedValues = filter.value;

        if (!row.hasField(fieldName)) return true;

        final value = row.getValue(fieldName);
        return allowedValues.contains(value);
      });
    }).toList();
  }

  // 헤더 구성 (행 또는 열)
  static List<PivotTableHeader> _buildHeaders(
    List<PivotTableData> data,
    List<PivotField> fields,
    String direction,
  ) {
    if (fields.isEmpty) return [];

    final headerMap = <String, PivotTableHeader>{};

    for (final row in data) {
      final pathParts = fields.map((field) =>
        row.hasField(field.name) ? row.getValue(field.name).toString() : '(빈값)'
      ).toList();

      _buildHeaderHierarchy(headerMap, pathParts, fields, 0, []);
    }

    return _sortHeaders(headerMap.values.toList());
  }

  // 헤더 계층 구조 생성
  static void _buildHeaderHierarchy(
    Map<String, PivotTableHeader> headerMap,
    List<String> pathParts,
    List<PivotField> fields,
    int level,
    List<String> parentPath,
  ) {
    if (level >= pathParts.length) return;

    final currentValue = pathParts[level];
    final currentPath = [...parentPath, currentValue];
    final pathKey = currentPath.join('|');

    if (!headerMap.containsKey(pathKey)) {
      headerMap[pathKey] = PivotTableHeader(
        label: currentValue,
        level: level,
        sourceField: fields[level],
        groupPath: currentPath,
        hasChildren: level < pathParts.length - 1,
        isExpanded: true,
      );
    }

    // 하위 레벨 처리
    if (level < pathParts.length - 1) {
      _buildHeaderHierarchy(headerMap, pathParts, fields, level + 1, currentPath);
    }
  }

  // 헤더 정렬
  static List<PivotTableHeader> _sortHeaders(List<PivotTableHeader> headers) {
    headers.sort((a, b) {
      // 먼저 레벨별로 정렬
      final levelCompare = a.level.compareTo(b.level);
      if (levelCompare != 0) return levelCompare;

      // 같은 레벨 내에서는 알파벳순 정렬
      return a.label.compareTo(b.label);
    });

    return headers;
  }

  // 데이터 그리드 생성
  static List<List<PivotTableCell>> _buildDataGrid(
    List<PivotTableData> data,
    List<PivotTableHeader> rowHeaders,
    List<PivotTableHeader> columnHeaders,
    PivotTableConfiguration config,
  ) {
    final grid = <List<PivotTableCell>>[];

    // 각 행에 대해
    for (final rowHeader in rowHeaders) {
      final row = <PivotTableCell>[];

      // 각 열에 대해
      for (final columnHeader in columnHeaders) {
        final cell = _calculateCellValue(
          data,
          rowHeader,
          columnHeader,
          config.valueFields,
        );
        row.add(cell);
      }

      grid.add(row);
    }

    return grid;
  }

  // 개별 셀 값 계산
  static PivotTableCell _calculateCellValue(
    List<PivotTableData> data,
    PivotTableHeader rowHeader,
    PivotTableHeader columnHeader,
    List<PivotField> valueFields,
  ) {
    // 해당 행/열 조건에 맞는 데이터 필터링
    final matchingData = data.where((row) {
      return _matchesHeader(row, rowHeader) && _matchesHeader(row, columnHeader);
    }).toList();

    if (matchingData.isEmpty) {
      return const PivotTableCell(value: null);
    }

    // 첫 번째 값 필드로 집계 (다중 값 필드는 추후 확장)
    if (valueFields.isNotEmpty) {
      final valueField = valueFields.first;
      final aggregatedValue = _aggregateValues(
        matchingData,
        valueField,
      );

      return PivotTableCell(
        value: aggregatedValue,
        sourceField: valueField,
        groupPath: [...rowHeader.groupPath, ...columnHeader.groupPath],
      );
    }

    return PivotTableCell(
      value: matchingData.length,
      groupPath: [...rowHeader.groupPath, ...columnHeader.groupPath],
    );
  }

  // 헤더와 데이터 매칭 확인
  static bool _matchesHeader(PivotTableData data, PivotTableHeader header) {
    if (header.groupPath.isEmpty) return true;

    // 각 레벨별로 값 확인
    for (int i = 0; i < header.groupPath.length; i++) {
      final fieldName = header.sourceField.name;
      if (!data.hasField(fieldName)) return false;

      final dataValue = data.getValue(fieldName).toString();
      final headerValue = header.groupPath[i];

      if (dataValue != headerValue) return false;
    }

    return true;
  }

  // 값 집계
  static dynamic _aggregateValues(
    List<PivotTableData> data,
    PivotField valueField,
  ) {
    final values = data
        .where((row) => row.hasField(valueField.name))
        .map((row) => row.getValue(valueField.name))
        .where((value) => value != null)
        .toList();

    if (values.isEmpty) return null;

    switch (valueField.aggregationType) {
      case AggregationType.sum:
        return values.fold<num>(0, (sum, value) => sum + (value as num));

      case AggregationType.average:
        final sum = values.fold<num>(0, (sum, value) => sum + (value as num));
        return sum / values.length;

      case AggregationType.count:
        return values.length;

      case AggregationType.max:
        return values.fold(values.first, (max, value) =>
          (value as num) > (max as num) ? value : max);

      case AggregationType.min:
        return values.fold(values.first, (min, value) =>
          (value as num) < (min as num) ? value : min);

      case AggregationType.countDistinct:
        return values.toSet().length;

      default:
        return values.first;
    }
  }

  // 총계 계산
  static Map<String, dynamic> _calculateGrandTotals(
    List<PivotTableData> data,
    List<PivotField> valueFields,
  ) {
    final totals = <String, dynamic>{};

    for (final valueField in valueFields) {
      totals[valueField.name] = _aggregateValues(data, valueField);
    }

    return totals;
  }

  // 드릴다운 데이터 추출
  static List<PivotTableData> getDrillDownData(
    List<PivotTableData> data,
    PivotTableCell cell,
  ) {
    if (cell.groupPath.isEmpty) return data;

    return data.where((row) {
      // 셀의 그룹 경로에 맞는 데이터만 반환
      for (final pathElement in cell.groupPath) {
        bool found = false;
        for (final fieldName in row.rawData.keys) {
          if (row.getValue(fieldName).toString() == pathElement) {
            found = true;
            break;
          }
        }
        if (!found) return false;
      }
      return true;
    }).toList();
  }

  // 조건부 서식 적용
  static Map<String, String> applyConditionalFormatting(
    PivotTableCell cell,
    List<ConditionalFormattingRule> rules,
    Map<String, dynamic> fieldStatistics,
  ) {
    final styles = <String, String>{};

    for (final rule in rules) {
      if (rule.fieldName == cell.sourceField?.name) {
        switch (rule.type) {
          case ConditionalFormattingType.colorScale:
            final color = _getColorScaleColor(
              cell.value,
              fieldStatistics[rule.fieldName],
              rule.colors,
            );
            if (color != null) {
              styles['backgroundColor'] = color;
            }
            break;

          case ConditionalFormattingType.dataBar:
            final percentage = _getDataBarPercentage(
              cell.value,
              fieldStatistics[rule.fieldName],
            );
            if (percentage != null) {
              styles['dataBar'] = '$percentage%';
            }
            break;

          default:
            break;
        }
      }
    }

    return styles;
  }

  static String? _getColorScaleColor(
    dynamic value,
    Map<String, dynamic>? stats,
    List<String> colors,
  ) {
    if (value == null || stats == null || colors.isEmpty) return null;

    final numValue = value is num ? value.toDouble() : null;
    if (numValue == null) return null;

    final min = stats['min']?.toDouble() ?? 0.0;
    final max = stats['max']?.toDouble() ?? 1.0;

    if (max <= min) return colors.first;

    final percentage = (numValue - min) / (max - min);
    final index = (percentage * (colors.length - 1)).round().clamp(0, colors.length - 1);

    return colors[index];
  }

  static double? _getDataBarPercentage(
    dynamic value,
    Map<String, dynamic>? stats,
  ) {
    if (value == null || stats == null) return null;

    final numValue = value is num ? value.toDouble() : null;
    if (numValue == null) return null;

    final min = stats['min']?.toDouble() ?? 0.0;
    final max = stats['max']?.toDouble() ?? 1.0;

    if (max <= min) return 100.0;

    return ((numValue - min) / (max - min) * 100).clamp(0, 100);
  }

  // 필드 통계 계산 (조건부 서식용)
  static Map<String, Map<String, dynamic>> calculateFieldStatistics(
    List<PivotTableData> data,
    List<PivotField> numericFields,
  ) {
    final statistics = <String, Map<String, dynamic>>{};

    for (final field in numericFields.where((f) => f.isNumeric)) {
      final values = data
          .where((row) => row.hasField(field.name))
          .map((row) => row.getValue(field.name))
          .whereType<num>()
          .cast<num>()
          .toList();

      if (values.isNotEmpty) {
        values.sort();
        statistics[field.name] = {
          'min': values.first,
          'max': values.last,
          'average': values.fold<double>(0, (sum, v) => sum + v) / values.length,
          'median': values.length.isOdd
              ? values[values.length ~/ 2]
              : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2,
        };
      }
    }

    return statistics;
  }
}

// 피벗 테이블 처리 결과
class PivotTableResult {
  final List<PivotTableHeader> rowHeaders;
  final List<PivotTableHeader> columnHeaders;
  final List<List<PivotTableCell>> dataGrid;
  final int totalRows;
  final int totalColumns;
  final Map<String, dynamic> grandTotals;

  const PivotTableResult({
    required this.rowHeaders,
    required this.columnHeaders,
    required this.dataGrid,
    required this.totalRows,
    required this.totalColumns,
    required this.grandTotals,
  });

  bool get isEmpty => totalRows == 0 || totalColumns == 0;

  PivotTableCell? getCell(int row, int column) {
    if (row < 0 || row >= dataGrid.length) return null;
    if (column < 0 || column >= dataGrid[row].length) return null;
    return dataGrid[row][column];
  }
}