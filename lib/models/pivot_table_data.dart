// 피벗 테이블을 위한 데이터 모델
class PivotTableData {
  final String id;
  final Map<String, dynamic> rawData;
  final Map<String, dynamic> calculatedFields;

  PivotTableData({
    required this.id,
    required this.rawData,
    this.calculatedFields = const {},
  });

  T getValue<T>(String fieldName) {
    if (calculatedFields.containsKey(fieldName)) {
      return calculatedFields[fieldName] as T;
    }
    return rawData[fieldName] as T;
  }

  bool hasField(String fieldName) {
    return rawData.containsKey(fieldName) || calculatedFields.containsKey(fieldName);
  }

  PivotTableData copyWith({
    Map<String, dynamic>? rawData,
    Map<String, dynamic>? calculatedFields,
  }) {
    return PivotTableData(
      id: id,
      rawData: rawData ?? this.rawData,
      calculatedFields: calculatedFields ?? this.calculatedFields,
    );
  }

  factory PivotTableData.fromSalesData(Map<String, dynamic> salesData) {
    return PivotTableData(
      id: salesData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      rawData: salesData,
    );
  }
}

// 피벗 테이블 필드 정의
enum FieldType {
  text,       // 텍스트 필드 (행/열 그룹핑용)
  number,     // 숫자 필드 (집계용)
  date,       // 날짜 필드 (시간 기반 그룹핑용)
  boolean,    // 불린 필드
}

enum AggregationType {
  sum,        // 합계
  average,    // 평균
  count,      // 개수
  max,        // 최대값
  min,        // 최소값
  countDistinct, // 중복 제거 개수
}

class PivotField {
  final String name;
  final String displayName;
  final FieldType type;
  final AggregationType? aggregationType;
  final bool isVisible;
  final bool isExpandable;
  final String? format; // 숫자 포맷 (예: "#,##0", "0.00%")

  const PivotField({
    required this.name,
    required this.displayName,
    required this.type,
    this.aggregationType,
    this.isVisible = true,
    this.isExpandable = true,
    this.format,
  });

  PivotField copyWith({
    String? name,
    String? displayName,
    FieldType? type,
    AggregationType? aggregationType,
    bool? isVisible,
    bool? isExpandable,
    String? format,
  }) {
    return PivotField(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      type: type ?? this.type,
      aggregationType: aggregationType ?? this.aggregationType,
      isVisible: isVisible ?? this.isVisible,
      isExpandable: isExpandable ?? this.isExpandable,
      format: format ?? this.format,
    );
  }

  bool get isNumeric => type == FieldType.number;
  bool get canAggregate => isNumeric && aggregationType != null;
}

// 피벗 테이블 구성 정보
class PivotTableConfiguration {
  final List<PivotField> rowFields;
  final List<PivotField> columnFields;
  final List<PivotField> valueFields;
  final List<PivotField> filterFields;
  final Map<String, List<dynamic>> activeFilters;
  final Map<String, bool> fieldExpansionState; // 필드별 확장/축소 상태
  final bool showGrandTotals;
  final bool showSubTotals;

  const PivotTableConfiguration({
    this.rowFields = const [],
    this.columnFields = const [],
    this.valueFields = const [],
    this.filterFields = const [],
    this.activeFilters = const {},
    this.fieldExpansionState = const {},
    this.showGrandTotals = true,
    this.showSubTotals = true,
  });

  PivotTableConfiguration copyWith({
    List<PivotField>? rowFields,
    List<PivotField>? columnFields,
    List<PivotField>? valueFields,
    List<PivotField>? filterFields,
    Map<String, List<dynamic>>? activeFilters,
    Map<String, bool>? fieldExpansionState,
    bool? showGrandTotals,
    bool? showSubTotals,
  }) {
    return PivotTableConfiguration(
      rowFields: rowFields ?? this.rowFields,
      columnFields: columnFields ?? this.columnFields,
      valueFields: valueFields ?? this.valueFields,
      filterFields: filterFields ?? this.filterFields,
      activeFilters: activeFilters ?? this.activeFilters,
      fieldExpansionState: fieldExpansionState ?? this.fieldExpansionState,
      showGrandTotals: showGrandTotals ?? this.showGrandTotals,
      showSubTotals: showSubTotals ?? this.showSubTotals,
    );
  }
}

// 피벗 테이블 셀 정보
class PivotTableCell {
  final dynamic value;
  final bool isHeader;
  final bool isTotal;
  final bool isGrandTotal;
  final int rowSpan;
  final int columnSpan;
  final PivotField? sourceField;
  final List<String> groupPath; // 계층적 그룹핑 경로
  final Map<String, dynamic> metadata;

  const PivotTableCell({
    this.value,
    this.isHeader = false,
    this.isTotal = false,
    this.isGrandTotal = false,
    this.rowSpan = 1,
    this.columnSpan = 1,
    this.sourceField,
    this.groupPath = const [],
    this.metadata = const {},
  });

  String get displayValue {
    if (value == null) return '';

    if (sourceField?.format != null && value is num) {
      return _formatNumber(value as num, sourceField!.format!);
    }

    return value.toString();
  }

  bool get isEmpty => value == null;
  bool get isClickable => !isEmpty && !isHeader;
  bool get isExpanded => metadata['expanded'] == true;

  PivotTableCell copyWith({
    dynamic value,
    bool? isHeader,
    bool? isTotal,
    bool? isGrandTotal,
    int? rowSpan,
    int? columnSpan,
    PivotField? sourceField,
    List<String>? groupPath,
    Map<String, dynamic>? metadata,
  }) {
    return PivotTableCell(
      value: value ?? this.value,
      isHeader: isHeader ?? this.isHeader,
      isTotal: isTotal ?? this.isTotal,
      isGrandTotal: isGrandTotal ?? this.isGrandTotal,
      rowSpan: rowSpan ?? this.rowSpan,
      columnSpan: columnSpan ?? this.columnSpan,
      sourceField: sourceField ?? this.sourceField,
      groupPath: groupPath ?? this.groupPath,
      metadata: metadata ?? this.metadata,
    );
  }

  String _formatNumber(num value, String format) {
    // 간단한 숫자 포맷팅 구현
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

// 피벗 테이블 행/열 구조
class PivotTableHeader {
  final String label;
  final int level;
  final bool isExpanded;
  final bool hasChildren;
  final List<PivotTableHeader> children;
  final PivotField sourceField;
  final List<String> groupPath;

  const PivotTableHeader({
    required this.label,
    required this.level,
    required this.sourceField,
    this.isExpanded = true,
    this.hasChildren = false,
    this.children = const [],
    this.groupPath = const [],
  });

  PivotTableHeader copyWith({
    String? label,
    int? level,
    bool? isExpanded,
    bool? hasChildren,
    List<PivotTableHeader>? children,
    PivotField? sourceField,
    List<String>? groupPath,
  }) {
    return PivotTableHeader(
      label: label ?? this.label,
      level: level ?? this.level,
      isExpanded: isExpanded ?? this.isExpanded,
      hasChildren: hasChildren ?? this.hasChildren,
      children: children ?? this.children,
      sourceField: sourceField ?? this.sourceField,
      groupPath: groupPath ?? this.groupPath,
    );
  }
}

// 조건부 서식 규칙
enum ConditionalFormattingType {
  colorScale,     // 색상 스케일
  dataBar,        // 데이터 바
  iconSet,        // 아이콘 셋
  cellHighlight,  // 셀 하이라이트
}

class ConditionalFormattingRule {
  final ConditionalFormattingType type;
  final String fieldName;
  final double? minValue;
  final double? maxValue;
  final List<String> colors;
  final String? condition; // 조건식 (예: "> 1000000")

  const ConditionalFormattingRule({
    required this.type,
    required this.fieldName,
    this.minValue,
    this.maxValue,
    this.colors = const [],
    this.condition,
  });
}

// MSM 매출 데이터를 위한 사전 정의된 필드들
class MSMSalesFields {
  static const List<PivotField> allFields = [
    PivotField(
      name: 'CONTINENT',
      displayName: '대륙',
      type: FieldType.text,
    ),
    PivotField(
      name: 'NATION_NAME',
      displayName: '국가',
      type: FieldType.text,
    ),
    PivotField(
      name: 'CUSTOM_NAME',
      displayName: '거래처명',
      type: FieldType.text,
    ),
    PivotField(
      name: '거래처분류',
      displayName: '거래처분류',
      type: FieldType.text,
    ),
    PivotField(
      name: 'SUM_SALE_AMT_WON',
      displayName: '매출액(원)',
      type: FieldType.number,
      aggregationType: AggregationType.sum,
      format: '#,##0',
    ),
    PivotField(
      name: 'SALE_Q',
      displayName: '수량',
      type: FieldType.number,
      aggregationType: AggregationType.sum,
      format: '#,##0',
    ),
    PivotField(
      name: 'SALE_P',
      displayName: '단가',
      type: FieldType.number,
      aggregationType: AggregationType.average,
      format: '#,##0',
    ),
  ];

  // 기본 피벗 구성 템플릿들
  static const PivotTableConfiguration regionAnalysisTemplate = PivotTableConfiguration(
    rowFields: [
      PivotField(name: 'CONTINENT', displayName: '대륙', type: FieldType.text),
      PivotField(name: 'NATION_NAME', displayName: '국가', type: FieldType.text),
    ],
    columnFields: [
      PivotField(name: '거래처분류', displayName: '거래처분류', type: FieldType.text),
    ],
    valueFields: [
      PivotField(
        name: 'SUM_SALE_AMT_WON',
        displayName: '매출액',
        type: FieldType.number,
        aggregationType: AggregationType.sum,
        format: '#,##0',
      ),
    ],
  );

  static const PivotTableConfiguration customerAnalysisTemplate = PivotTableConfiguration(
    rowFields: [
      PivotField(name: 'CUSTOM_NAME', displayName: '거래처명', type: FieldType.text),
    ],
    columnFields: [
      PivotField(name: 'CONTINENT', displayName: '대륙', type: FieldType.text),
    ],
    valueFields: [
      PivotField(
        name: 'SUM_SALE_AMT_WON',
        displayName: '매출액',
        type: FieldType.number,
        aggregationType: AggregationType.sum,
        format: '#,##0',
      ),
      PivotField(
        name: 'SALE_Q',
        displayName: '수량',
        type: FieldType.number,
        aggregationType: AggregationType.sum,
        format: '#,##0',
      ),
    ],
  );
}