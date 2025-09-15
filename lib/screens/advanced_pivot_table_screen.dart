import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/pivot_table_data.dart';
import '../services/pivot_table_engine.dart';
import '../services/pivot_table_export_service.dart';
import '../services/sales_service.dart';
import '../widgets/pivot_field_manager.dart';
import '../widgets/pivot_table_grid.dart';
import '../providers/language_provider.dart';

// 고급 피벗 테이블 화면
class AdvancedPivotTableScreen extends StatefulWidget {
  const AdvancedPivotTableScreen({Key? key}) : super(key: key);

  @override
  State<AdvancedPivotTableScreen> createState() => _AdvancedPivotTableScreenState();
}

class _AdvancedPivotTableScreenState extends State<AdvancedPivotTableScreen>
    with TickerProviderStateMixin {
  // 탭 컨트롤러
  late TabController _tabController;

  // 피벗 테이블 상태
  PivotTableConfiguration _configuration = MSMSalesFields.regionAnalysisTemplate;
  PivotTableResult? _pivotResult;
  List<PivotTableData> _rawData = [];
  bool _isLoading = false;
  String? _errorMessage;

  // 조건부 서식 규칙
  final List<ConditionalFormattingRule> _conditionalRules = [
    ConditionalFormattingRule(
      type: ConditionalFormattingType.colorScale,
      fieldName: 'SUM_SALE_AMT_WON',
      colors: ['red', 'yellow', 'green'],
    ),
  ];

  // 필터 및 검색
  final Map<String, List<dynamic>> _activeFilters = {};
  final TextEditingController _searchController = TextEditingController();

  // UI 설정
  bool _showFieldManager = true;
  bool _showGridLines = true;
  bool _freezeHeaders = true;
  double _cellHeight = 32.0;
  double _cellWidth = 120.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 매출 요약 데이터 로드 (지난 6개월)
      final endDate = DateTime.now();
      final startDate = DateTime.now().subtract(const Duration(days: 180));

      final response = await SalesService.getSalesSummary(
        fromDate: startDate.toIso8601String().split('T')[0],
        toDate: endDate.toIso8601String().split('T')[0],
        period: 'monthly',
      );

      if (response['success'] == true && response['data'] != null) {
        final salesData = response['data'] as List<dynamic>;
        _rawData = salesData
            .map((item) => PivotTableData.fromSalesData(item))
            .toList();

        _processPivotTable();
      } else {
        // 데모 데이터로 대체
        _loadDemoData();
      }
    } catch (e) {
      print('데이터 로딩 오류: $e');
      _loadDemoData(); // 오류 시 데모 데이터 사용
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadDemoData() {
    // MSM 매출 데모 데이터 생성
    _rawData = _generateDemoSalesData();
    _processPivotTable();
  }

  List<PivotTableData> _generateDemoSalesData() {
    final demoData = <PivotTableData>[];
    final continents = ['아시아', '유럽', '북미', '남미'];
    final countries = {
      '아시아': ['한국', '일본', '중국', '싱가포르'],
      '유럽': ['독일', '프랑스', '영국', '이탈리아'],
      '북미': ['미국', '캐나다'],
      '남미': ['브라질', '아르헨티나'],
    };
    final customers = [
      '서울대학교병원', '삼성서울병원', '연세의료원', '아산의료센터',
      '도쿄대학병원', '교토의과대학병원', '베이징대학병원', '상하이의과대학병원',
      '샤리테병원', '하이델베르그대학병원', '메이요클리닉', '존스홉킨스병원',
    ];
    final customerTypes = ['대형병원', '중형병원', '소형병원'];

    int id = 1;
    for (final continent in continents) {
      for (final country in countries[continent]!) {
        for (int i = 0; i < 3; i++) {
          final customer = customers[(id + i) % customers.length];
          final customerType = customerTypes[i % customerTypes.length];

          demoData.add(PivotTableData(
            id: id.toString(),
            rawData: {
              'id': id,
              'CONTINENT': continent,
              'NATION_NAME': country,
              'CUSTOM_NAME': customer,
              '거래처분류': customerType,
              'SUM_SALE_AMT_WON': (1000000 + (id * 123456)) % 50000000,
              'SALE_Q': (10 + (id * 7)) % 100,
              'SALE_P': (50000 + (id * 1234)) % 500000,
            },
          ));
          id++;
        }
      }
    }

    return demoData;
  }

  void _processPivotTable() {
    if (_rawData.isEmpty) return;

    try {
      final result = PivotTableEngine.processPivotTable(_rawData, _configuration);
      setState(() {
        _pivotResult = result;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '피벗 테이블 처리 오류: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorState()
                    : _buildMainContent(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        '고급 피벗 테이블 분석',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.blue.shade600,
      foregroundColor: Colors.white,
      elevation: 0,
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        tabs: const [
          Tab(icon: Icon(Icons.dashboard), text: '피벗 테이블'),
          Tab(icon: Icon(Icons.settings), text: '설정'),
          Tab(icon: Icon(Icons.info), text: '정보'),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_showFieldManager ? Icons.view_sidebar : Icons.view_sidebar_outlined),
          onPressed: () {
            setState(() => _showFieldManager = !_showFieldManager);
          },
          tooltip: '필드 관리자 토글',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('새로고침'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export_excel',
              child: Row(
                children: [
                  Icon(Icons.table_chart),
                  SizedBox(width: 8),
                  Text('Excel 내보내기'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export_csv',
              child: Row(
                children: [
                  Icon(Icons.file_download),
                  SizedBox(width: 8),
                  Text('CSV 내보내기'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'template_save',
              child: Row(
                children: [
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text('템플릿 저장'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'template_load',
              child: Row(
                children: [
                  Icon(Icons.folder_open),
                  SizedBox(width: 8),
                  Text('템플릿 불러오기'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    if (_pivotResult == null) return const SizedBox.shrink();

    return PivotTableToolbar(
      configuration: _configuration,
      onConfigurationChanged: _updateConfiguration,
      onExportExcel: () => _handleMenuAction('export_excel'),
      onExportCsv: () => _handleMenuAction('export_csv'),
      onRefresh: () => _handleMenuAction('refresh'),
    );
  }

  Widget _buildMainContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildPivotTableTab(),
        _buildSettingsTab(),
        _buildInfoTab(),
      ],
    );
  }

  Widget _buildPivotTableTab() {
    return Row(
      children: [
        // 필드 관리자 (좌측)
        if (_showFieldManager)
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '필드 관리',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildQuickTemplates(),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PivotTableFieldManager(
                      availableFields: MSMSalesFields.allFields,
                      configuration: _configuration,
                      onConfigurationChanged: _updateConfiguration,
                      isCompact: false,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 피벗 테이블 (우측)
        Expanded(
          child: _pivotResult != null
              ? PivotTableGrid(
                  result: _pivotResult!,
                  configuration: _configuration,
                  conditionalFormattingRules: _conditionalRules,
                  onCellTap: _handleCellTap,
                  onCellDoubleTap: _handleCellDoubleTap,
                  onHeaderExpandToggle: _handleHeaderExpandToggle,
                  showGridLines: _showGridLines,
                  freezeHeaders: _freezeHeaders,
                  cellHeight: _cellHeight,
                  cellWidth: _cellWidth,
                )
              : _buildNoDataState(),
        ),
      ],
    );
  }

  Widget _buildQuickTemplates() {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _buildTemplateChip('지역별 분석', MSMSalesFields.regionAnalysisTemplate),
        _buildTemplateChip('고객별 분석', MSMSalesFields.customerAnalysisTemplate),
        _buildTemplateChip('초기화', const PivotTableConfiguration()),
      ],
    );
  }

  Widget _buildTemplateChip(String label, PivotTableConfiguration config) {
    final isActive = _configuration == config;
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isActive ? Colors.white : Colors.blue.shade700,
        ),
      ),
      backgroundColor: isActive ? Colors.blue.shade600 : Colors.blue.shade50,
      onPressed: () => _updateConfiguration(config),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '표시 설정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 그리드 라인
          SwitchListTile(
            title: const Text('격자선 표시'),
            subtitle: const Text('테이블의 경계선을 표시합니다'),
            value: _showGridLines,
            onChanged: (value) => setState(() => _showGridLines = value),
          ),

          // 헤더 고정
          SwitchListTile(
            title: const Text('헤더 고정'),
            subtitle: const Text('스크롤 시 헤더를 고정합니다'),
            value: _freezeHeaders,
            onChanged: (value) => setState(() => _freezeHeaders = value),
          ),

          const SizedBox(height: 24),
          const Text(
            '셀 크기',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // 셀 높이
          Row(
            children: [
              const Text('높이: '),
              Expanded(
                child: Slider(
                  value: _cellHeight,
                  min: 24,
                  max: 48,
                  divisions: 6,
                  label: '${_cellHeight.round()}px',
                  onChanged: (value) => setState(() => _cellHeight = value),
                ),
              ),
            ],
          ),

          // 셀 너비
          Row(
            children: [
              const Text('너비: '),
              Expanded(
                child: Slider(
                  value: _cellWidth,
                  min: 80,
                  max: 200,
                  divisions: 12,
                  label: '${_cellWidth.round()}px',
                  onChanged: (value) => setState(() => _cellWidth = value),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            '조건부 서식',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('매출액 색상 스케일'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        color: Colors.red.shade200,
                      ),
                      const SizedBox(width: 4),
                      const Text('낮음'),
                      const Spacer(),
                      Container(
                        width: 20,
                        height: 20,
                        color: Colors.yellow.shade200,
                      ),
                      const SizedBox(width: 4),
                      const Text('중간'),
                      const Spacer(),
                      Container(
                        width: 20,
                        height: 20,
                        color: Colors.green.shade200,
                      ),
                      const SizedBox(width: 4),
                      const Text('높음'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    final dataCount = _rawData.length;
    final processedRows = _pivotResult?.totalRows ?? 0;
    final processedCols = _pivotResult?.totalColumns ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '데이터 정보',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow('원본 데이터 수', '$dataCount개'),
                  _buildInfoRow('처리된 행 수', '$processedRows개'),
                  _buildInfoRow('처리된 열 수', '$processedCols개'),
                  _buildInfoRow('행 필드 수', '${_configuration.rowFields.length}개'),
                  _buildInfoRow('열 필드 수', '${_configuration.columnFields.length}개'),
                  _buildInfoRow('값 필드 수', '${_configuration.valueFields.length}개'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            '사용 가능한 필드',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              itemCount: MSMSalesFields.allFields.length,
              itemBuilder: (context, index) {
                final field = MSMSalesFields.allFields[index];
                return Card(
                  child: ListTile(
                    leading: _getFieldIcon(field),
                    title: Text(field.displayName),
                    subtitle: Text('${field.name} (${_getFieldTypeText(field.type)})'),
                    trailing: field.aggregationType != null
                        ? Chip(
                            label: Text(
                              _getAggregationTypeText(field.aggregationType!),
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: Colors.green.shade50,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 16,
              color: Colors.red.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.table_chart_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '필드를 설정하여 피벗 테이블을 생성하세요',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // 이벤트 핸들러들
  void _updateConfiguration(PivotTableConfiguration newConfiguration) {
    setState(() {
      _configuration = newConfiguration;
    });
    _processPivotTable();
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'refresh':
        HapticFeedback.lightImpact();
        await _loadInitialData();
        break;

      case 'export_excel':
        if (_pivotResult != null) {
          try {
            await PivotTableExportService.exportToExcel(
              _pivotResult!,
              _configuration,
              fileName: 'MSM_피벗분석_${DateTime.now().millisecondsSinceEpoch}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Excel 파일이 다운로드되었습니다')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Excel 내보내기 실패: $e')),
            );
          }
        }
        break;

      case 'export_csv':
        if (_pivotResult != null) {
          try {
            await PivotTableExportService.exportToCsv(
              _pivotResult!,
              _configuration,
              fileName: 'MSM_피벗분석_${DateTime.now().millisecondsSinceEpoch}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV 파일이 다운로드되었습니다')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('CSV 내보내기 실패: $e')),
            );
          }
        }
        break;

      case 'template_save':
        _showTemplateSaveDialog();
        break;

      case 'template_load':
        _showTemplateLoadDialog();
        break;
    }
  }

  void _handleCellTap(PivotTableCell cell) {
    // 셀 클릭 시 상세 정보 표시
    if (!cell.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('값: ${cell.displayValue}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleCellDoubleTap(PivotTableCell cell) {
    // 셀 더블클릭 시 드릴다운
    if (!cell.isEmpty) {
      _showDrillDownDialog(cell);
    }
  }

  void _handleHeaderExpandToggle(PivotTableHeader header, bool isExpanded) {
    // 헤더 확장/축소 처리
    HapticFeedback.selectionClick();
    // 실제 구현에서는 상태 업데이트 필요
  }

  // 다이얼로그들
  void _showTemplateSaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('템플릿 저장'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: '템플릿 이름',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 템플릿 저장 로직 구현
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showTemplateLoadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('템플릿 불러오기'),
        content: const Text('저장된 템플릿이 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showDrillDownDialog(PivotTableCell cell) {
    final drillDownData = PivotTableEngine.getDrillDownData(_rawData, cell);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('상세 데이터 (${drillDownData.length}건)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: DataTable(
              columns: MSMSalesFields.allFields
                  .take(5)
                  .map((field) => DataColumn(label: Text(field.displayName)))
                  .toList(),
              rows: drillDownData
                  .take(20)
                  .map((data) => DataRow(
                        cells: MSMSalesFields.allFields
                            .take(5)
                            .map((field) => DataCell(
                                  Text(data.getValue(field.name).toString()),
                                ))
                            .toList(),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 더미 PivotTableResult 생성 (임시)
              final dummyResult = PivotTableResult(
                rowHeaders: [],
                columnHeaders: [],
                dataGrid: [],
                totalRows: drillDownData.length,
                totalColumns: 0,
                grandTotals: {},
              );
              PivotTableExportService.exportToJson(
                dummyResult,
                _configuration,
                fileName: 'drill_down_data_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
            child: const Text('내보내기'),
          ),
        ],
      ),
    );
  }

  // 헬퍼 함수들
  Widget _getFieldIcon(PivotField field) {
    switch (field.type) {
      case FieldType.text:
        return const Icon(Icons.text_fields, color: Colors.blue);
      case FieldType.number:
        return const Icon(Icons.numbers, color: Colors.green);
      case FieldType.date:
        return const Icon(Icons.calendar_today, color: Colors.orange);
      case FieldType.boolean:
        return const Icon(Icons.check_box, color: Colors.purple);
    }
  }

  String _getFieldTypeText(FieldType type) {
    switch (type) {
      case FieldType.text:
        return '텍스트';
      case FieldType.number:
        return '숫자';
      case FieldType.date:
        return '날짜';
      case FieldType.boolean:
        return '불린';
    }
  }

  String _getAggregationTypeText(AggregationType type) {
    switch (type) {
      case AggregationType.sum:
        return '합계';
      case AggregationType.average:
        return '평균';
      case AggregationType.count:
        return '개수';
      case AggregationType.max:
        return '최대';
      case AggregationType.min:
        return '최소';
      case AggregationType.countDistinct:
        return '고유개수';
    }
  }
}