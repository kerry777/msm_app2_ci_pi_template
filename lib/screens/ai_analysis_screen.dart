import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/common/bottom_app_bar.dart';
import '../config/app_config.dart';
import 'package:provider/provider.dart';
import '../services/sales_service.dart';  // 🔧 MSM용 SalesService 추가
import '../providers/auth_provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
// import 'package:csv/csv.dart';  // 🔧 임시 비활성화
// import 'package:syncfusion_flutter_datagrid/datagrid.dart';  // 🔧 임시 비활성화
import 'package:url_launcher/url_launcher.dart';
// import 'dart:html' as html; // 조건부 import로 대체
import '../l10n/app_localizations.dart';
import 'ai_analysis_download.dart';

// saveFile 함수 추가 (웹/모바일/데스크톱 환경 분기)
void saveFile(BuildContext context, List<int> bytes, String fileName) {
  if (kIsWeb) {
    // 웹 전용 함수 호출 (별도 파일에서 정의)
    saveFileWeb(bytes, fileName);
  } else {
    // 모바일/데스크탑: 안내 메시지 또는 별도 구현
    // 예: print('이 기능은 웹에서만 지원됩니다.');
  }
}

class AiAnalysisScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? preloadedData;  // 🚀 사전 로드된 데이터
  final Map<String, dynamic>? periodInfo;  // 🚀 기간 정보
  
  const AiAnalysisScreen({
    super.key,
    this.preloadedData,
    this.periodInfo,
  });

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final String _selectedTopic = '납품 및 매출 내역';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _aiAnswer;
  bool _showApiKey = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _previewData = [];
  String? _persistentErrorMsg;
  final List<String> _aiModels = ['OpenAI', 'Gemini', 'Claude', 'Grok', 'Cursor AI'];
  String? _selectedAiModel = 'OpenAI';
  final List<String> _openAiModels = ['gpt-3.5-turbo', 'gpt-4'];
  String _selectedOpenAiModel = 'gpt-3.5-turbo';
  final List<String> _geminiModels = [
    'gemini-pro',
    'gemini-1.5-pro',
    'gemini-1.0-pro',
    'gemini-1.0',
    'gemini-1.5-flash',
  ];
  String _selectedGeminiModel = 'gemini-pro';
  
  // AI 페르소나 관련 변수들
  String _selectedPersona = 'business_consultant'; // 기본 페르소나
  String _selectedQuestionType = 'sales_related'; // 기본 질문 유형 (매출 관련)
  final List<Map<String, String>> _aiPersonas = [
    {
      'key': 'business_consultant',
      'name_key': 'ai_persona_business_consultant',
      'desc_key': 'ai_persona_business_consultant_desc',
    },
    {
      'key': 'data_analyst',
      'name_key': 'ai_persona_data_analyst',
      'desc_key': 'ai_persona_data_analyst_desc',
    },
    {
      'key': 'general_assistant',
      'name_key': 'ai_persona_general_assistant',
      'desc_key': 'ai_persona_general_assistant_desc',
    },
    {
      'key': 'market_researcher',
      'name_key': 'ai_persona_market_researcher',
      'desc_key': 'ai_persona_market_researcher_desc',
    },
    {
      'key': 'operations_manager',
      'name_key': 'ai_persona_operations_manager',
      'desc_key': 'ai_persona_operations_manager_desc',
    },
  ];
  final Map<String, String?> _apiKeys = {
    'OpenAI': null,
    'Gemini': null,
    'Claude': null,
    'Grok': null,
    'Cursor AI': null,
  };
  final Map<String, TextEditingController> _apiKeyControllers = {
    'OpenAI': TextEditingController(),
    'Gemini': TextEditingController(),
    'Claude': TextEditingController(),
    'Grok': TextEditingController(),
    'Cursor AI': TextEditingController(),
  };
  bool _useTestData = false;
  List<Map<String, dynamic>> _realData = [];
  // 샘플 품목리스트 (실제 데이터 없을 때 사용)
  final List<Map<String, String>> _sampleItems = [];

  // 소팽 상태값 추가
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // 필터 상태값 추가 (컬럼명: 입력값)
  final Map<String, String> _columnFilters = {};

  // 검색어 상태
  String _searchText = '';

  // 소팽 함수
  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      if (_previewData.isEmpty) return;
      final keys = _previewData.first.keys.toList();
      // No 컬럼(0번)은 소팽 제외, 실제 데이터 컬럼만 소팽
      if (columnIndex == 0) return;
      final sortKey = keys[columnIndex - 1];
      _previewData.sort((a, b) {
        final aValue = a[sortKey];
        final bValue = b[sortKey];
        if (aValue is num && bValue is num) {
          return ascending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
        }
        return ascending ? aValue.toString().compareTo(bValue.toString()) : bValue.toString().compareTo(aValue.toString());
      });
    });
  }

  // 필터 적용 함수
  List<Map<String, dynamic>> get _filteredPreviewData {
    List<Map<String, dynamic>> data = _previewData;
    // 컬럼별 필터
    if (_columnFilters.isNotEmpty) {
      data = data.where((row) {
        for (final entry in _columnFilters.entries) {
          final col = entry.key;
          final filter = entry.value.trim();
          if (filter.isNotEmpty && !row[col].toString().contains(filter)) {
            return false;
          }
        }
        return true;
      }).toList();
    }
    // 검색어 필터
    if (_searchText.trim().isNotEmpty) {
      final lower = _searchText.trim().toLowerCase();
      data = data.where((row) {
        return visibleColumns.any((col) => (row[col]?.toString() ?? '').toLowerCase().contains(lower));
      }).toList();
    }
    return data;
  }

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  bool _isFetchingRealData = false;
  String? _realDataError;

  // 컬럼명 영문→한글 매핑 테이블 (MSM용)
  static const Map<String, String> columnNameMap = {
    'CUSTOM_NAME': '거래처명',
    'NATION_NAME': '국가',
    'SUM_SALE_AMT_WON': '매출액(원)',
    'SALE_Q': '수량',
    '거래처분류': '거래처분류',
    'CUSTOM_CODE': '거래처코드',
    'CONTINENT': '대륙',
    'MANAGE_CUSTOM_NM': '관리거래처',
    'AGENT_TYPE': '에이전트타입',
    'SALE_P': '단가',
    'EXCHG_RATE_O': '환율',
    'SALE_LOC_AMT_F': '현지통화매출',
    'SALE_COST_AMT': '매출원가',
    'UPDATE_DTM': '업데이트시간',
    // 필요시 추가
  };

  // 한글 컬럼명으로 변환 함수
  String getKoreanColumn(String key) => columnNameMap[key] ?? key;

  // 컬럼 선택/숨김 상태
  List<String> visibleColumns = [];

  // 주요 기본 표시 컬럼 정의 (MSM용)
  static const List<String> defaultVisibleColumns = [
    'CUSTOM_NAME', // 거래처명
    'NATION_NAME', // 국가
    'SUM_SALE_AMT_WON', // 매출액(원)
    'SALE_Q', // 수량
    '거래처분류', // 거래처분류
  ];

  // 질문 템플릿 리스트를 l10n key로만 관리
  final List<Map<String, String>> aiQuestionTemplates = [
    {'id': '1', 'key': 'ai_template_1'},
    {'id': '2', 'key': 'ai_template_2'},
    {'id': '3', 'key': 'ai_template_3'},
    {'id': '4', 'key': 'ai_template_4'},
    {'id': '5', 'key': 'ai_template_5'},
    {'id': '6', 'key': 'ai_template_6'},
    {'id': '7', 'key': 'ai_template_7'},
    {'id': '8', 'key': 'ai_template_8'},
    {'id': '9', 'key': 'ai_template_9'},
    {'id': '10', 'key': 'ai_template_10'},
    {'id': '11', 'key': 'ai_template_11'},
    {'id': '12', 'key': 'ai_template_12'},
    {'id': '13', 'key': 'ai_template_13'},
    {'id': '14', 'key': 'ai_template_14'},
    {'id': '15', 'key': 'ai_template_15'},
    {'id': '16', 'key': 'ai_template_16'},
    {'id': '17', 'key': 'ai_template_17'},
    {'id': '18', 'key': 'ai_template_18'},
    {'id': '19', 'key': 'ai_template_19'},
    {'id': '20', 'key': 'ai_template_20'},
    {'id': '21', 'key': 'ai_template_21'},
    {'id': '22', 'key': 'ai_template_22'},
    {'id': '23', 'key': 'ai_template_23'},
    {'id': '24', 'key': 'ai_template_24'},
    {'id': '25', 'key': 'ai_template_25'},
    {'id': '26', 'key': 'ai_template_26'},
    {'id': '27', 'key': 'ai_template_27'},
    {'id': '28', 'key': 'ai_template_28'},
    {'id': '29', 'key': 'ai_template_29'},
    {'id': '30', 'key': 'ai_template_30'},
    {'id': '31', 'key': 'ai_template_31'},
    {'id': '32', 'key': 'ai_template_32'},
    {'id': '33', 'key': 'ai_template_33'},
    {'id': '34', 'key': 'ai_template_34'},
    {'id': '35', 'key': 'ai_template_35'},
  ];
  String? _selectedTemplateId;

  // 질문 템플릿 기본값 저장/불러오기 함수 추가
  Future<void> _setDefaultQuestionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_ai_question_id', id);
  }

  // API Key 자동 불러오기/저장
  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('api_key');
    if (key != null && key.isNotEmpty) {
      setState(() {
        _apiKeyController.text = key;
      });
    } else {
      setState(() {
        _apiKeyController.text = '';
      });
    }
  }

  // 질문 입력 기본값 자동 제공
  Future<void> _loadDefaultQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('default_ai_question_id');
    String? question;
    if (id != null && aiQuestionTemplates.any((t) => t['id'] == id)) {
      question = AppLocalizations.of(context).get(aiQuestionTemplates.firstWhere((t) => t['id'] == id)['key']!) ?? '';
    } else {
      // 기본값: 첫 번째 템플릿
      question = AppLocalizations.of(context).get(aiQuestionTemplates.first['key']!) ?? '';
    }
    setState(() {
      _selectedTemplateId = id ?? aiQuestionTemplates.first['id'];
      _questionController.text = question ?? '';
    });
  }

  // 페르소나별 추천 질문 목록 반환
  List<Map<String, String>> _getPersonaQuestions() {
    switch (_selectedPersona) {
      case 'business_consultant':
        return aiQuestionTemplates.where((t) => ['31', '32', '33', '34', '35', '1', '5', '25', '26'].contains(t['id'])).toList();
      case 'data_analyst':
        return aiQuestionTemplates.where((t) => ['1', '2', '4', '9', '11', '12', '15', '29', '30'].contains(t['id'])).toList();
      case 'general_assistant':
        return [
          {'id': 'g1', 'key': 'ai_general_question_1'},
          {'id': 'g2', 'key': 'ai_general_question_2'},
          {'id': 'g3', 'key': 'ai_general_question_3'},
          {'id': 'g4', 'key': 'ai_general_question_4'},
          {'id': 'g5', 'key': 'ai_general_question_5'},
          ...aiQuestionTemplates.where((t) => ['16', '17', '20', '21', '22'].contains(t['id'])),
        ];
      case 'market_researcher':
        return aiQuestionTemplates.where((t) => ['31', '32', '33', '34', '35', '18', '19', '5'].contains(t['id'])).toList();
      case 'operations_manager':
        return aiQuestionTemplates.where((t) => ['10', '13', '14', '27', '28', '6', '7', '8'].contains(t['id'])).toList();
      default:
        return aiQuestionTemplates;
    }
  }

  // 페르소나별 프롬프트 템플릿 생성
  String _getPersonaPromptTemplate() {
    // 질문 유형에 따른 기본 지침
    String baseInstruction = '';
    String dataContext = '';
    
    if (_selectedQuestionType == 'sales_related') {
      baseInstruction = '제공된 실제 매출/수익 데이터를 기반으로 분석하고 답변하세요.';
      dataContext = '데이터: {data}';
    } else {
      baseInstruction = '이 질문은 매출 데이터와 무관한 일반 상담입니다. 매출 데이터를 참조하지 말고 일반적인 의료기기 업계 지식과 시장 정보를 바탕으로 답변하세요.';
      dataContext = '참고: 이 질문은 매출 데이터 분석이 아닌 일반 상담입니다.';
    }
    
    switch (_selectedPersona) {
      case 'business_consultant':
        return '''당신은 의료기기 유통업계와 헬스케어 시장에 대한 풍부한 경험을 가진 전략적 비즈니스 컨설턴트이자 마케팅 분석가입니다. 외부 시장 정보에 접근할 수 있으며 종합적인 비즈니스 인사이트를 제공할 수 있습니다. 

**질문 유형별 응답 방식:**
- 매출 관련 질문: 제공된 실제 매출 데이터만을 기반으로 분석하며, 추측하지 않습니다. 데이터가 부족한 경우 명확히 "해당 병원/항목의 매출 데이터가 현재 조회 기간에 없어 정확한 분석이 어렵습니다"라고 안내합니다.
- 일반 상담 질문: 매출 데이터와 무관한 질문으로, 의료기기 업계 지식과 시장 트렌드를 바탕으로 전략적 조언을 제공합니다.

$baseInstruction

$dataContext
질문: {question} 

포괄적이고 전략적인 답변을 제공해 주세요.''';
      case 'data_analyst':
        return '''당신은 전문 데이터 분석가입니다. 매출 데이터, 트렌드, 성과 지표를 통계적으로 분석하고 해석하는데 특화되어 있습니다. 

**질문 유형별 응답 방식:**
- 매출 관련 질문: 오직 제공된 실제 데이터만을 분석하며, 추측이나 가정하지 않습니다. 데이터 부족 시 명확히 언급합니다.
- 일반 상담 질문: 데이터 분석과 무관한 질문으로, 일반적인 데이터 분석 방법론이나 업계 통계 정보를 제공합니다.

$baseInstruction

$dataContext
질문: {question} 

정확하고 통계적으로 근거 있는 답변을 제공해 주세요.''';
      case 'general_assistant':
        return '''당신은 도움이 되는 일반 어시스턴트입니다. 다양한 질문에 명확하고 친근하게 답변하며, 필요시 데이터를 참조하여 정보를 제공합니다. 

**질문 유형별 응답 방식:**
- 매출 관련 질문: 실제 데이터가 있는 경우에만 구체적인 정보를 제공하고, 데이터 부족 시 솔직히 안내합니다.
- 일반 상담 질문: 매출과 무관한 질문으로, 일반적인 도움말과 조언을 제공합니다.

$baseInstruction

$dataContext
질문: {question} 

명확하고 이해하기 쉬운 답변을 제공해 주세요.''';
      case 'market_researcher':
        return '''당신은 시장 조사 전문가입니다. 경쟁 환경, 업계 트렌드, 시장 동향을 분석하는데 전문성을 가지고 있으며, 외부 시장 정보에 접근하여 포괄적인 시장 인사이트를 제공할 수 있습니다. 

**질문 유형별 응답 방식:**
- 매출 관련 질문: 제공된 매출 데이터를 시장 관점에서 분석하되, 데이터 부족 시 시장 전문가 관점의 조언을 제공합니다.
- 일반 상담 질문: 매출과 무관한 시장 조사, 경쟁 분석, 업계 트렌드에 대한 전문적 조언을 제공합니다.

$baseInstruction

$dataContext
질문: {question} 

시장 전문가 관점의 인사이트를 제공해 주세요.''';
      case 'operations_manager':
        return '''당신은 운영 관리 전문가입니다. 재고 관리, 공급망 최적화, 운영 효율성 개선에 중점을 두고 분석합니다. 

**질문 유형별 응답 방식:**
- 매출 관련 질문: 실제 매출/재고 데이터를 기반으로 운영 효율성을 분석합니다. 데이터 부족 시 일반적인 운영 개선 방안을 제공합니다.
- 일반 상담 질문: 재고 관리, 공급망, 운영 프로세스에 대한 일반적인 전문적 조언을 제공합니다.

$baseInstruction

$dataContext
질문: {question} 

실무적이고 실현 가능한 운영 개선 방안을 제공해 주세요.''';
      default:
        return '''당신은 전문 데이터 분석가입니다. 

$baseInstruction

$dataContext
질문: {question} 

명확하고 실질적인 답변을 제시해 주세요.''';
    }
  }

  @override
  void initState() {
    super.initState();
    
    // 🚀 사전 로드된 데이터 처리
    if (widget.preloadedData != null && widget.periodInfo != null) {
      // 통합매출분석에서 전달된 데이터 사용
      _previewData = widget.preloadedData!;
      _realData = widget.preloadedData!;  // 🔧 _realData도 같은 데이터로 설정
      _startDate = DateTime.parse(widget.periodInfo!['fromDate']);
      _endDate = DateTime.parse(widget.periodInfo!['toDate']);
      print('🚀 통합매출분석에서 ${_previewData.length}건 데이터 전달받음');
      print('🚀 _realData도 ${_realData.length}건으로 설정 완료');
    } else {
      // 기본 동작: 최근 30일
      _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _endDate = DateTime.now();
      _fetchRealSalesData(); // 실제 데이터 조회
    }
    
    _useTestData = false;
    _loadDefaultQuestion();
    // visibleColumns 초기화 (주요 컬럼만 기본 표시)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_previewData.isNotEmpty) {
        setState(() {
          visibleColumns = _previewData.first.keys.where((k) => defaultVisibleColumns.contains(k)).toList();
        });
      } else {
        visibleColumns = List.from(defaultVisibleColumns);
      }
      // AppLocalizations이 사용 가능해진 후에 기본 질문 설정
      _questionController.text = AppLocalizations.of(context).get('ai_analysis_default_question') ?? 'Please provide a summary, trends, and special features of this sales data within 10 lines.';
      // === 자동 조회/저장 트리거 추가 ===
      // 🔧 사전 로드된 데이터가 없을 때만 API 조회 실행
      if (widget.preloadedData == null || widget.periodInfo == null) {
        if (_apiKeys[_selectedAiModel] == null || _apiKeys[_selectedAiModel]!.isEmpty) {
          await _fetchApiKeyFromServer();
          if (_apiKeys[_selectedAiModel] == null || _apiKeys[_selectedAiModel]!.isEmpty) {
            _onSearchPressed();
          }
        }
      } else {
        // 사전 로드된 데이터가 있으면 API 키만 가져오기
        await _fetchApiKeyFromServer();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 다국어가 로드된 후 질문 텍스트 업데이트
    if (_questionController.text == AppLocalizations.of(context).get('ai_analysis_default_question')) {
      _questionController.text = AppLocalizations.of(context).get('ask_summary_trend_special_features') ?? 'Please provide a summary, trends, and special features of this sales data within 10 lines.';
    }
  }

  void _saveApiKey() {
    setState(() {
      _apiKeys[_selectedAiModel!] = _apiKeyControllers[_selectedAiModel!]!.text.trim();
    });
  }

  void _deleteApiKey() {
    setState(() {
      _apiKeys[_selectedAiModel!] = null;
      _apiKeyControllers[_selectedAiModel!]!.clear();
    });
  }

  // 실제 품목리스트 불러오기 (API 연동 시 사용)
  Future<void> _loadRealItems() async {
    // TODO: 실제 API 연동 시 아래 코드 사용
    // final items = await ApiService().getConsumables();
    // setState(() { _realItems = items.map((e) => {'itemCd': e['itemCd'], 'itemName': e['itemName']}).toList(); });
    // 현재는 샘플 데이터로 대체
    
  }

  // 데이터 미리보기 로딩 함수 수정
  void _loadPreviewData() {
    setState(() {
      if (_useTestData) {
        _previewData = _sampleItems.map((item) => {
          'ITEM_CD': item['itemCd'],
          'ITEM_NAME': item['itemName'],
          'IO_QT': 100,
          'IO_AMT': 10000,
          'HOSPITAL_NAME': '테스트병원',
          'CREATE_DT': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        }).toList();
      } else {
        _previewData = _realData;
      }
      // IO_QT 기준 내림차순 소팽
      _previewData.sort((a, b) {
        final aVal = a['IO_QT'] is num ? a['IO_QT'] : num.tryParse(a['IO_QT']?.toString() ?? '0') ?? 0;
        final bVal = b['IO_QT'] is num ? b['IO_QT'] : num.tryParse(b['IO_QT']?.toString() ?? '0') ?? 0;
        return bVal.compareTo(aVal);
      });
      if (_previewData.isNotEmpty) {
        // 주요 컬럼만 기본 표시, 나머지는 숨김
        visibleColumns = _previewData.first.keys.where((k) => defaultVisibleColumns.contains(k)).toList();
      } else {
        visibleColumns = List.from(defaultVisibleColumns);
      }
    });
  }

  // OpenAI API 호출 함수
  Future<String> _callOpenAI(String question, List<Map<String, dynamic>> data) async {
    final apiKey = _apiKeys['OpenAI'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(AppLocalizations.of(context).get('api_key_not_set') ?? 'API key is not set');
    }
    final url = Uri.parse(AppConfig.openAiApiUrl);
    final dataJson = jsonEncode(data);
    final promptTemplate = _getPersonaPromptTemplate();
    final prompt = promptTemplate
        .replaceAll('{data}', dataJson)
        .replaceAll('{question}', question);
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _selectedOpenAiModel,
          'messages': [
            {
              'role': 'system',
              'content': AppLocalizations.of(context).get('ai_analysis_system_prompt')
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'max_tokens': 1000,
          'temperature': 0.7,
        }),
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData != null && 
            responseData['choices'] != null && 
            responseData['choices'].isNotEmpty &&
            responseData['choices'][0] != null &&
            responseData['choices'][0]['message'] != null &&
            responseData['choices'][0]['message']['content'] != null) {
          return responseData['choices'][0]['message']['content'];
        } else {
          throw Exception('API 응답 형식이 올바르지 않습니다.');
        }
      } else {
        throw Exception('API 호출 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _persistentErrorMsg = AppLocalizations.of(context).get('api_key_usage_exhausted') ?? 'API key usage limit exceeded';
      });
      throw Exception(AppLocalizations.of(context).get('openai_api_call_error', params: {'error': e.toString()}) ?? 'OpenAI API call error: ${e.toString()}');
    }
  }

  // OpenAI API 사용량 및 요금 조회
  Future<Map<String, dynamic>> _fetchOpenAIUsage() async {
    final apiKey = _apiKeys['OpenAI'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API 키가 설정되지 않았습니다.');
    }
    
    try {
      // 현재 날짜와 30일 전 날짜 계산
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));
      final startDateStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      final endDateStr = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      
      // OpenAI Models API를 호출하여 API 키 유효성 확인
      final url = Uri.parse('https://api.openai.com/v1/models');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // API 키가 유효함을 확인했으므로 예상 사용량 정보 제공
        // 실제 사용량은 OpenAI 대시보드에서 확인하도록 안내
        
        // 예상 토큰 사용량 (실제 데이터가 아님을 명시)
        int estimatedTokens = 0;
        double estimatedCost = 0.0;
        
        // 간단한 추정치 제공 (실제 사용량이 아님)
        if (_selectedOpenAiModel.contains('gpt-4')) {
          estimatedTokens = 1000; // 예시 값
          estimatedCost = (estimatedTokens / 1000) * 0.03; // GPT-4 대략 $0.03/1K tokens
        } else {
          estimatedTokens = 2000; // 예시 값  
          estimatedCost = (estimatedTokens / 1000) * 0.002; // GPT-3.5 대략 $0.002/1K tokens
        }
        
        return {
          'totalTokens': estimatedTokens,
          'totalCost': estimatedCost,
          'period': '$startDateStr ~ $endDateStr',
          'model': _selectedOpenAiModel,
          'success': true,
          'isEstimate': true, // 추정치임을 표시
        };
      } else {
        throw Exception('API 키 확인 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      return {
        'error': e.toString(),
        'success': false,
      };
    }
  }

  // 사용량 및 요금 정보 다이얼로그 표시
  void _showUsageDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.assessment, color: Colors.blue),
            const SizedBox(width: 8),
            Text('$_selectedAiModel 사용량 조회'),
          ],
        ),
        content: const SizedBox(
          width: 300,
          height: 100,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('사용량을 조회하고 있습니다...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      Map<String, dynamic> usageData;
      
      if (_selectedAiModel == 'OpenAI') {
        usageData = await _fetchOpenAIUsage();
      } else {
        // 다른 AI 모델의 경우 아직 미구현
        usageData = {
          'error': '$_selectedAiModel 모델의 사용량 조회는 아직 지원되지 않습니다.',
          'success': false,
        };
      }
      
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      
      // 결과 다이얼로그 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                usageData['success'] ? Icons.check_circle : Icons.error,
                color: usageData['success'] ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text('$_selectedAiModel 사용량 정보'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: usageData['success'] 
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                                             _buildInfoRow(AppLocalizations.of(context).get('usage_query_period') ?? '조회 기간', usageData['period'] ?? ''),
                       _buildInfoRow(AppLocalizations.of(context).get('usage_model') ?? '사용 모델', usageData['model'] ?? ''),
                       _buildInfoRow('예상 토큰 사용량', '${usageData['totalTokens']?.toString() ?? '0'} tokens (추정치)'),
                       _buildInfoRow('예상 비용', '\$${usageData['totalCost']?.toStringAsFixed(4) ?? '0.0000'} (추정치)'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.orange, size: 18),
                                SizedBox(width: 8),
                                Text(AppLocalizations.of(context).get('usage_info_note') ?? '참고사항', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                               AppLocalizations.of(context).get('usage_note_description') ?? '• 토큰 사용량과 비용은 대략적인 추정값입니다.\n• 정확한 사용량은 OpenAI 대시보드에서 확인하세요.\n• 실제 비용은 모델별, 토큰 타입별로 다를 수 있습니다.',
                               style: TextStyle(fontSize: 12),
                             ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(usageData['error'] ?? '알 수 없는 오류가 발생했습니다.'),
                    ],
                  ),
          ),
          actions: [
            if (usageData['success'] && _selectedAiModel == 'OpenAI')
              TextButton.icon(
                onPressed: () async {
                  // OpenAI 대시보드로 이동
                  final uri = Uri.parse('https://platform.openai.com/usage');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('브라우저를 열 수 없습니다. 수동으로 https://platform.openai.com/usage 을 방문해주세요.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: Text(AppLocalizations.of(context).get('openai_dashboard') ?? 'OpenAI 대시보드'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('오류'),
            ],
          ),
          content: Text('사용량 조회 중 오류가 발생했습니다:\n${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  // 정보 행 빌더 위젯
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // 질문하기 함수
  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() {
        _aiAnswer = AppLocalizations.of(context).get('ask_question_hint') ?? 'Enter your question for AI';
      });
      return;
    }
    if (_apiKeys[_selectedAiModel] == null || _apiKeys[_selectedAiModel]!.isEmpty) {
      setState(() {
        _aiAnswer = AppLocalizations.of(context).get('set_api_key_first') ?? 'Please set API key first';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _aiAnswer = null;
      _persistentErrorMsg = null;
    });
    try {
      // 🔧 MSM용 필드명으로 변경: 거래처명, 매출액, 수량, 국가명 포함
      final filteredData = _realData.map((row) => {
        'CUSTOM_NAME': row['CUSTOM_NAME'],           // 거래처명 (대리점명)
        'NATION_NAME': row['NATION_NAME'],           // 국가명
        'SUM_SALE_AMT_WON': row['SUM_SALE_AMT_WON'], // 매출액(원)
        'SALE_Q': row['SALE_Q'],                     // 수량
        '거래처분류': row['거래처분류'],                  // 거래처분류
        'UPDATE_DTM': row['UPDATE_DTM'],             // 업데이트시간
      }).toList();
      String answer;
      if (_selectedAiModel == 'OpenAI') {
        answer = await _callOpenAI(question, filteredData);
      } else if (_selectedAiModel == 'Gemini') {
        await Future.delayed(const Duration(seconds: 1));
        answer = '[Gemini 더미 응답 - 모델: $_selectedGeminiModel] 분석 결과입니다.';
      } else if (_selectedAiModel == 'Claude') {
        await Future.delayed(const Duration(seconds: 1));
        answer = '[Claude 더미 응답] 분석 결과입니다.';
      } else if (_selectedAiModel == 'Grok') {
        await Future.delayed(const Duration(seconds: 1));
        answer = '[Grok 더미 응답] 분석 결과입니다.';
      } else if (_selectedAiModel == 'Cursor AI') {
        await Future.delayed(const Duration(seconds: 1));
        answer = '[Cursor AI 더미 응답] 분석 결과입니다.';
      } else {
        answer = AppLocalizations.of(context).get('unsupported_ai_model') ?? 'Unsupported AI model';
      }
      setState(() {
        _aiAnswer = answer;
      });
    } catch (e) {
      setState(() {
        _aiAnswer = AppLocalizations.of(context).get('ai_analysis_error', params: {'error': e.toString()}) ?? 'AI analysis error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 질문/답변 저장 함수 (UTF-8, txt/md)
  Future<void> _saveQAtoFile({bool markdown = true}) async {
    if (_questionController.text.trim().isEmpty || _aiAnswer == null) return;
    final question = _questionController.text.trim();
    final answer = _aiAnswer!;
    final content = markdown
        ? '## AI 질문/답변 내역\n\n**질문:**  \n$question\n\n**답변:**  \n$answer\n'
        : '질문: $question\n\n답변: $answer\n';
    final now = DateTime.now();
    final fileName = 'ai_qa_${now.toIso8601String().replaceAll(':', '-')}.${markdown ? 'md' : 'txt'}';
    // 웹/모바일/데스크톱 환경별 저장 방식 분기 필요. 여기서는 파일 저장 예시만 작성.
    // 실제로는 path_provider, file_picker 등 패키지 활용 필요.
    // 아래는 데스크톱/웹 예시:
    final bytes = utf8.encode(content);
    // 파일 저장/다운로드 구현 필요 (플랫폼별 분기)
    saveFile(context, bytes, fileName);
    debugPrint(AppLocalizations.of(context).get('question_answer_save', params: {'fileName': fileName}) ?? 'Question/Answer saved: $fileName');
  }

  // 서버에서 API Key 가져오기 함수 추가
  Future<void> _fetchApiKeyFromServer() async {
    final aiType = _selectedAiModel;
    debugPrint('[AI] _fetchApiKeyFromServer 호출됨 ($aiType)');
    try {
      final url = Uri.parse('${AppConfig.serverUrl}/api/v1/ai-api-key?aiType=$aiType');
      debugPrint('[AI] 서버에 GET 요청: $url');
      final response = await http.get(url);
      debugPrint('[AI] 응답 statusCode: ${response.statusCode}');
      debugPrint('[AI] 응답 body: ${response.body}');
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (e) {
          decoded = response.body;
        }
        final apiKey = decoded is Map ? decoded['apiKey'] : null;
        debugPrint('[AI] 파싱된 apiKey: $apiKey');
        if (apiKey != null && apiKey.isNotEmpty) {
          setState(() {
            _apiKeyControllers[aiType]!.text = apiKey;
            _showApiKey = false;
          });
          // === 자동 저장 트리거 추가 ===
          _saveApiKey();
        }
      } else {
        setState(() {
          _apiKeyControllers[aiType]!.clear();
        });
        debugPrint('[AI] 서버에 등록된 API Key 없음 또는 에러');
      }
    } catch (e) {
      setState(() {
        _apiKeyControllers[aiType]!.clear();
      });
      debugPrint('[AI] 서버 오류: ${e.toString()}');
    }
  }

  Future<void> _fetchRealSalesData() async {
    setState(() {
      _isFetchingRealData = true;
      _realDataError = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final trCd = auth.userInfo?['MEK_TR_CD']?.toString();
      // 사용자가 선택한 기간 사용
      final fromDate = _startDate ?? DateTime(2000, 1, 1);
      final toDate = _endDate ?? DateTime(2100, 12, 31);
      if (trCd == null || trCd.isEmpty) {
        setState(() { 
          _realDataError = AppLocalizations.of(context).get('agency_code_invalid') ?? 'Invalid agency code'; 
        });
        return;
      }
      // 🔧 MSM용 API로 변경 (통합매출분석과 동일)
      final fromDateStr = DateFormat('yyyy-MM-dd').format(fromDate);
      final toDateStr = DateFormat('yyyy-MM-dd').format(toDate);
      
      final response = await SalesService.getSalesSummary(
        fromDate: fromDateStr,
        toDate: toDateStr,
      );
      
      final responseData = response['data'];
      final data = responseData != null && responseData is List 
          ? List<Map<String, dynamic>>.from(responseData)
          : <Map<String, dynamic>>[];
      setState(() {
        _realData = data;
        _previewData = data.isNotEmpty ? data : [];
        // 데이터가 바뀔 때마다 visibleColumns를 항상 최신화
        if (_previewData.isNotEmpty) {
          visibleColumns = _previewData.first.keys.where((k) => defaultVisibleColumns.contains(k)).toList();
        } else {
          visibleColumns = List.from(defaultVisibleColumns);
        }
      });
    } catch (e) {
      setState(() { _realDataError = AppLocalizations.of(context).get('real_data_fetch_failed', params: {'error': e.toString()}) ?? 'Failed to fetch real data: ${e.toString()}'; });
    } finally {
      setState(() { _isFetchingRealData = false; });
    }
  }

  void _saveDataToDownloadsFolder() async {
    // visibleColumns만 추출
    final filtered = _filteredPreviewData;
    final cols = visibleColumns;
    if (kIsWeb) {
      final jsonList = filtered.map((row) {
        final newRow = Map<String, dynamic>.from(row);
        for (final key in ['CREATE_DT', 'CHECK_DT']) {
          if (newRow.containsKey(key) && newRow[key] != null) {
            try {
              newRow[key] = DateFormat('yyyy-MM-dd').format(DateTime.parse(newRow[key].toString()));
            } catch (e) {
              // 날짜 형식이 아닐 경우 원본 값 유지
            }
          }
        }
        return Map.fromEntries(
          newRow.entries.where((e) => cols.contains(e.key)).map((e) => MapEntry(getKoreanColumn(e.key), e.value)),
        );
      }).toList();
      final jsonStr = jsonEncode(jsonList);
      final bytes = utf8.encode(jsonStr);
      final fileName = 'ai_analysis_data.json';
      saveFile(context, bytes, fileName);
      return;
    }
    Directory? downloadsDir;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        downloadsDir = await getDownloadsDirectory();
      } else if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux) {
        final home = Platform.environment['HOME'] ?? '';
        downloadsDir = Directory('$home/Downloads');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).get('download_folder_not_supported') ?? 'Download folder is not supported on this platform')),  
        );
        return;
      }
      if (downloadsDir == null || !(await downloadsDir.exists())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).get('download_folder_not_found') ?? 'Download folder not found')),  
        );
        return;
      }
      final file = File('${downloadsDir.path}/ai_analysis_data.json');
      final jsonList = filtered.map((row) {
        final newRow = Map<String, dynamic>.from(row);
        for (final key in ['CREATE_DT', 'CHECK_DT']) {
          if (newRow.containsKey(key) && newRow[key] != null) {
            try {
              newRow[key] = DateFormat('yyyy-MM-dd').format(DateTime.parse(newRow[key].toString()));
            } catch (e) {
              // 날짜 형식이 아닐 경우 원본 값 유지
            }
          }
        }
        return Map.fromEntries(
          newRow.entries.where((e) => cols.contains(e.key)).map((e) => MapEntry(getKoreanColumn(e.key), e.value)),
        );
      }).toList();
      final jsonStr = jsonEncode(jsonList);
      await file.writeAsString(jsonStr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).get('file_saved_to_download_folder', params: {'path': file.path}) ?? 'File saved to download folder: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).get('download_folder_save_error', params: {'error': e.toString()}) ?? 'Error saving to download folder: ${e.toString()}')),
      );
    }
  }

  void _saveDataToExcel() async {
    final filtered = _filteredPreviewData;
    final cols = visibleColumns;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).get('no_data_to_download') ?? 'No data to download.')),
      );
      return;
    }
    try {
      final now = DateTime.now();
      final fileName = 'ai_analysis_${now.toIso8601String().replaceAll(':', '-')}.csv';
      final List<List<dynamic>> rows = [];
      rows.add(cols.map((k) => getKoreanColumn(k)).toList());
      for (final row in filtered) {
        rows.add(cols.map((k) {
          var v = row[k];
          if (k == 'CREATE_DT' || k == 'CHECK_DT') {
            String dateStr = v?.toString() ?? '';
            if (dateStr.isNotEmpty) {
            try {
              dateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(dateStr));
            } catch (e) {
              // 날짜 형식이 아닐 경우 원본 값 유지
            }
          }
            return dateStr;
          }
          return v?.toString() ?? '';
        }).toList());
      }
      // 🔧 임시로 주석 처리 (CSV export 기능 비활성화)
      // final csvStr = const ListToCsvConverter().convert(rows);
      final csvStr = 'CSV export temporarily disabled';
      final bytes = utf8.encode(csvStr);
      saveFile(context, bytes, fileName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).get('excel_download_failed', params: {'error': e.toString()}) ?? 'Excel download failed: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Widget _buildStartDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => _startDate = picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        child: Text(_startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : AppLocalizations.of(context).get('from_date') ?? 'From Date'),
      ),
    );
  }

  Widget _buildEndDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _endDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => _endDate = picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        child: Text(_endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : AppLocalizations.of(context).get('to_date') ?? 'To Date'),
      ),
    );
  }

  void _onSearchPressed() {
    _fetchRealSalesData();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    
    // 안전한 동적 키 생성
    String getApiKeyLabel() {
      if (_selectedAiModel == null) return '';
      try {
        final key = '${_selectedAiModel}_api_key_label';
        final result = AppLocalizations.of(context).get(key);
        return result ?? AppLocalizations.of(context).get('ai_model_api_key', params: {'model': _selectedAiModel ?? ''});
      } catch (e) {
        return AppLocalizations.of(context).get('ai_model_api_key', params: {'model': _selectedAiModel ?? ''});
      }
    }
    
    String getApiKeyHint() {
      if (_selectedAiModel == null) return '';
      try {
        final key = '${_selectedAiModel}_api_key_hint';
        final result = AppLocalizations.of(context).get(key);
        return result ?? AppLocalizations.of(context).get('enter_ai_model_api_key', params: {'model': _selectedAiModel ?? ''});
      } catch (e) {
        return AppLocalizations.of(context).get('enter_ai_model_api_key', params: {'model': _selectedAiModel ?? ''});
      }
    }
    
    String label = getApiKeyLabel();
    
    final isWide = MediaQuery.of(context).size.width > 600;
    final listHeight = isWide ? 350.0 : 220.0;
    final titleFont = isWide ? 21.0 : 17.0;
    final previewFont = isWide ? 18.0 : 15.0;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).get('ai_analysis') ?? 'AI Analysis'),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: AppLocalizations.of(context).get('help_tooltip') ?? 'Help',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(AppLocalizations.of(context).get('ai_analysis_help_title') ?? 'AI Analysis Help'),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context).get('ai_analysis_help_description') ?? 'Use AI analysis to analyze sales data and gain insights.'),
                            SizedBox(height: 12),
                            Text(AppLocalizations.of(context).get('ai_analysis_usage_steps') ?? 'How to use:'),
                            Text(AppLocalizations.of(context).get('ai_analysis_step1') ?? '1. Set up AI model and API key.'),
                            Text(AppLocalizations.of(context).get('ai_analysis_step2') ?? '2. Select the period to analyze.'),
                            Text(AppLocalizations.of(context).get('ai_analysis_step3') ?? '3. Enter your question and request analysis.'),
                            Text(AppLocalizations.of(context).get('ai_analysis_step4') ?? '4. Review the analysis results provided by AI.'),
                            Text(AppLocalizations.of(context).get('ai_analysis_step5') ?? '5. Download data if needed.'),
                            Text(AppLocalizations.of(context).get('ai_analysis_step6') ?? '6. Save or share analysis results.'),
                            SizedBox(height: 12),
                            Text(AppLocalizations.of(context).get('ai_analysis_tips') ?? 'Tips:'),
                            Text(AppLocalizations.of(context).get('ai_analysis_tip1') ?? '• Ask specific questions for more accurate analysis.'),
                            Text(AppLocalizations.of(context).get('ai_analysis_tip2') ?? '• Analyze different periods to understand trends.'),
                            Text(AppLocalizations.of(context).get('ai_analysis_tip3') ?? '• Use analysis results for business decision making.'),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(AppLocalizations.of(context).get('close') ?? 'Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: CommonBottomAppBar(),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. AI 모델 지정 + API Key 입력/가져오기/저장 (항상 최상단)
                Card(
                  elevation: 2,
                  color: Colors.grey[50],
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AI 모델/Key 선택 영역 (ExpansionTile로 감싸기)
                        ExpansionTile(
                          title: Row(
                            children: [
                              Text(AppLocalizations.of(context).get('ai_service_name_model_key') ?? 'AI Service/Model/Key'),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.help_outline, color: Colors.blue),
                                tooltip: AppLocalizations.of(context).get('ai_service_help_tooltip') ?? 'AI Service Setup Help',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(AppLocalizations.of(context).get('ai_service_help_title') ?? 'AI Service Setup'),
                                      content: Text(
                                        '${AppLocalizations.of(context).get('ai_service_help_description') ?? 'Select the service and model to use for AI analysis and set up API key.'}\n\n${AppLocalizations.of(context).get('ai_service_name_hint') ?? '• AI Service: Choose from OpenAI, Gemini, Claude, etc.'}\n${AppLocalizations.of(context).get('ai_service_model_hint') ?? '• Model: Recommended to select the latest model for each service'}\n${AppLocalizations.of(context).get('ai_service_key_hint') ?? '• API Key: Enter the key issued from each service'}\n\n${AppLocalizations.of(context).get('ai_service_key_note') ?? '• API keys are stored securely on the server and may incur charges based on usage.'}'
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: Text(AppLocalizations.of(context).get('close') ?? 'Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          initiallyExpanded: true,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.memory, color: Colors.deepPurple),
                                const SizedBox(width: 8),
                                Text(AppLocalizations.of(context).get('ai_model_label') ?? 'AI Model', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 16),
                                DropdownButton<String>(
                                  value: _selectedAiModel,
                                  items: _aiModels.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedAiModel = val);
                                  },
                                ),
                                if (_selectedAiModel == 'OpenAI') ...[
                                  const SizedBox(width: 16),
                                  DropdownButton<String>(
                                    value: _selectedOpenAiModel,
                                    items: _openAiModels.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedOpenAiModel = val);
                                    },
                                  ),
                                ],
                                if (_selectedAiModel == 'Gemini') ...[
                                  const SizedBox(width: 16),
                                  DropdownButton<String>(
                                    value: _selectedGeminiModel,
                                    items: _geminiModels.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedGeminiModel = val);
                                    },
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.key, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                if (_apiKeys[_selectedAiModel] != null)
                                  IconButton(
                                    icon: const Icon(Icons.info_outline, color: Colors.purple),
                                    tooltip: AppLocalizations.of(context).get('check_usage_tooltip') ?? 'Check Usage',
                                    onPressed: _showUsageDialog,
                                  ),
                                if (_apiKeys[_selectedAiModel] != null)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: AppLocalizations.of(context).get('delete_api_key_tooltip') ?? 'Delete API Key',
                                    onPressed: _deleteApiKey,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _apiKeyControllers[_selectedAiModel],
                                    obscureText: !_showApiKey,
                                    enabled: true,
                                    decoration: InputDecoration(
                                      hintText: getApiKeyHint(),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: Icon(_showApiKey ? Icons.visibility : Icons.visibility_off),
                                        onPressed: () => setState(() => _showApiKey = !_showApiKey),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    debugPrint('[AI] API KEY 가져오기 버튼 클릭됨');
                                    _fetchApiKeyFromServer();
                                  },
                                  child: Text(AppLocalizations.of(context).get('get_api_key_button') ?? 'Get'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _saveApiKey,
                                  child: Text(AppLocalizations.of(context).get('save_button') ?? 'Save'),
                                ),
                                const SizedBox(width: 8),
                                // 사용량 확인 아이콘 버튼
                                if (_apiKeys[_selectedAiModel] != null && _apiKeys[_selectedAiModel]!.isNotEmpty)
                                                                     IconButton(
                                     icon: const Icon(Icons.assessment, color: Colors.purple),
                                     tooltip: AppLocalizations.of(context).get('check_usage_tooltip') ?? '사용량/요금 확인',
                                     onPressed: _showUsageDialog,
                                   ),
                              ],
                            ),
                            // 페르소나 선택 영역
                            const SizedBox(height: 16),
                            ExpansionTile(
                              title: Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(AppLocalizations.of(context).get('ai_persona_selection') ?? 'AI 페르소나 선택', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '현재: ${AppLocalizations.of(context).get(_aiPersonas.firstWhere((p) => p['key'] == _selectedPersona)['name_key']!) ?? ''}',
                                          style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              initiallyExpanded: false,
                              children: [
                                Column(
                                  children: _aiPersonas.map((persona) {
                                    final isSelected = _selectedPersona == persona['key'];
                                    return Card(
                                      color: isSelected ? Colors.green.shade50 : null,
                                      child: ListTile(
                                        leading: isSelected 
                                          ? Icon(Icons.radio_button_checked, color: Colors.green)
                                          : Icon(Icons.radio_button_unchecked),
                                        title: Text(
                                          AppLocalizations.of(context).get(persona['name_key']!) ?? persona['name_key']!,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        subtitle: Text(
                                          AppLocalizations.of(context).get(persona['desc_key']!) ?? persona['desc_key']!,
                                          style: TextStyle(fontSize: 12),
                                        ),
                                                                                 onTap: () {
                                           setState(() {
                                             _selectedPersona = persona['key']!;
                                             // 페르소나 변경 시 질문 템플릿 초기화
                                             _selectedTemplateId = null;
                                             _questionController.clear();
                                           });
                                         },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                            // 질문 유형 선택 영역
                            const SizedBox(height: 16),
                            ExpansionTile(
                              title: Row(
                                children: [
                                  const Icon(Icons.help_outline, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(AppLocalizations.of(context).get('ai_question_type_selection') ?? '질문 유형 선택', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '현재: ${AppLocalizations.of(context).get(_selectedQuestionType == 'sales_related' ? 'ai_question_type_sales_related' : 'ai_question_type_general') ?? ''}',
                                          style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              initiallyExpanded: false,
                              children: [
                                Column(
                                  children: [
                                    Card(
                                      color: _selectedQuestionType == 'sales_related' ? Colors.orange.shade50 : null,
                                      child: ListTile(
                                        leading: _selectedQuestionType == 'sales_related' 
                                          ? Icon(Icons.radio_button_checked, color: Colors.orange)
                                          : Icon(Icons.radio_button_unchecked),
                                        title: Text(
                                          AppLocalizations.of(context).get('ai_question_type_sales_related') ?? '매출 데이터 관련',
                                          style: TextStyle(
                                            fontWeight: _selectedQuestionType == 'sales_related' ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        subtitle: Text(
                                          AppLocalizations.of(context).get('ai_question_type_sales_desc') ?? '실제 매출/수익 데이터를 기반으로 한 질문',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _selectedQuestionType = 'sales_related';
                                          });
                                        },
                                      ),
                                    ),
                                    Card(
                                      color: _selectedQuestionType == 'general' ? Colors.orange.shade50 : null,
                                      child: ListTile(
                                        leading: _selectedQuestionType == 'general' 
                                          ? Icon(Icons.radio_button_checked, color: Colors.orange)
                                          : Icon(Icons.radio_button_unchecked),
                                        title: Text(
                                          AppLocalizations.of(context).get('ai_question_type_general') ?? '일반 상담',
                                          style: TextStyle(
                                            fontWeight: _selectedQuestionType == 'general' ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        subtitle: Text(
                                          AppLocalizations.of(context).get('ai_question_type_general_desc') ?? '일반적인 조언, 시장 정보, 전략 상담',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _selectedQuestionType = 'general';
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // AI 질문 입력 영역도 ExpansionTile 내부에 포함
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 기존 드롭다운 UI 부분을 아래로 교체
                                ExpansionTile(
                                  title: Text(AppLocalizations.of(context).get('ai_question_template_title') ?? 'AI 질문 템플릿', style: TextStyle(fontWeight: FontWeight.bold, fontSize: titleFont)),
                                  initiallyExpanded: false,
                                  children: [
                                    SizedBox(
                                      height: listHeight,
                                      child: ListView.builder(
                                        itemCount: _getPersonaQuestions().length,
                                        itemBuilder: (context, idx) {
                                          final template = _getPersonaQuestions()[idx];
                                          final selected = _selectedTemplateId == template['id'];
                                          return ListTile(
                                            title: Text(
                                              AppLocalizations.of(context).get(template['key']!) ?? '질문',
                                              maxLines: isWide ? 3 : 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: isWide ? 16 : 13),
                                            ),
                                            tileColor: selected ? Colors.yellow[100] : null,
                                            leading: selected
                                                ? Icon(Icons.check_circle, color: Colors.orange, size: isWide ? 28 : 22)
                                                : Icon(Icons.circle_outlined, size: isWide ? 28 : 22),
                                            onTap: () async {
                                              setState(() {
                                                _selectedTemplateId = template['id'];
                                                _questionController.text = AppLocalizations.of(context).get(template['key']!) ?? '';
                                              });
                                              await _setDefaultQuestionId(template['id']!);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedTemplateId != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      AppLocalizations.of(context).get(
                                        aiQuestionTemplates.firstWhere((t) => t['id'] == _selectedTemplateId)['key']!
                                      ) ?? '',
                                      style: TextStyle(
                                        fontSize: previewFont,
                                        color: Colors.deepOrange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                // ... 기존 질문 입력란(TextField)은 그대로 유지 ...
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.question_answer, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _questionController,
                                        maxLines: 3,
                                        decoration: InputDecoration(
                                          hintText: AppLocalizations.of(context).get('ask_question_hint') ?? 'Enter your question for AI',
                                          border: const OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _isLoading ? null : _askQuestion,
                                      child: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(AppLocalizations.of(context).get('ask_question_button') ?? 'Ask Question'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // 답변 표시 영역 추가
                if (_aiAnswer != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          color: Colors.yellow[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SelectableText(_aiAnswer!, style: const TextStyle(fontSize: 15)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: Text(AppLocalizations.of(context).get('save_qa_button') ?? '질문/답변 저장'),
                          onPressed: () => _saveQAtoFile(markdown: true),
                        ),
                      ],
                    ),
                  ),
                // 2. 기간, 질문, 옵션, 조회 등 기존 상단 고정 영역
                // --- 기간 선택, 조회, 다운로드 버튼 한 줄 배치 ---
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isWide ? 180 : MediaQuery.of(context).size.width * 0.4,
                      child: _buildStartDatePicker(),
                    ),
                    Text('~', style: TextStyle(fontSize: 16)),
                    SizedBox(
                      width: isWide ? 180 : MediaQuery.of(context).size.width * 0.4,
                      child: _buildEndDatePicker(),
                    ),
                    ElevatedButton(
                      onPressed: _onSearchPressed,
                      child: Text(AppLocalizations.of(context).get('search_button') ?? '조회'),
                    ),
                    // 필요시 기타 버튼/입력란 추가
                  ],
                ),
                const SizedBox(height: 16),
                // 표/카드 영역만 데이터 유무에 따라 분기
                if (_previewData.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text(AppLocalizations.of(context).get('no_data_message') ?? 'No data available', style: const TextStyle(color: Colors.red))),
                  )
                else
                  // Syncfusion DataGrid + 컬럼 선택/숨김 UI
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExpansionTile(
                        title: Text(AppLocalizations.of(context).get('show_hide_columns') ?? 'Show/Hide Columns'),
                        initiallyExpanded: false,
                        children: [
                          if (_previewData.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              children: _previewData.first.keys.map((col) => FilterChip(
                                label: Text(getKoreanColumn(col)),
                                selected: visibleColumns.contains(col),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      if (!visibleColumns.contains(col)) visibleColumns.add(col);
                                    } else {
                                      visibleColumns.remove(col);
                                    }
                                  });
                                },
                              )).toList(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 검색(Quick Search) UI
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: AppLocalizations.of(context).get('search_keyword_hint') ?? 'Search by keyword...',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            setState(() {
                              _searchText = v;
                            });
                          },
                        ),
                      ),
                      // 🔧 임시로 간단한 리스트로 대체 (DataGrid 에러 해결용)
                      Container(
                        height: 400,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _filteredPreviewData.isEmpty
                            ? const Center(
                                child: Text('데이터가 없습니다', style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.builder(
                                itemCount: _filteredPreviewData.length,
                                itemBuilder: (context, index) {
                                  final item = _filteredPreviewData[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: ListTile(
                                      title: Text('${item['CUSTOM_NAME'] ?? '거래처명 없음'}'),
                                      subtitle: Text('국가: ${item['NATION_NAME'] ?? '미지정'} | 분류: ${item['거래처분류'] ?? '미지정'}'),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('매출: ₩${NumberFormat('#,###').format(item['SUM_SALE_AMT_WON'] ?? 0)}'),
                                          Text('수량: ${NumberFormat('#,###').format(item['SALE_Q'] ?? 0)}'),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (_persistentErrorMsg != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.red[700],
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _persistentErrorMsg!,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _persistentErrorMsg = null),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// DataGridSource 구현
// 🔧 임시로 주석 처리 (DataGrid 에러 해결용)
/*
class _AiGridSource extends DataGridSource {
  final List<Map<String, dynamic>> data;
  final List<String> visibleColumns;
  List<DataGridRow> _rows = [];
  _AiGridSource(this.data, this.visibleColumns) {
    _rows = data.map((row) => DataGridRow(
      cells: visibleColumns.map((col) {
        var v = row[col];
        if (col == 'CREATE_DT' || col == 'CHECK_DT') {
          String dateStr = v?.toString() ?? '';
          if (dateStr.isNotEmpty) {
            try {
              dateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(dateStr));
            } catch (e) {
              // 날짜 형식이 아닐 경우 원본 값 유지
            }
          }
          return DataGridCell<String>(columnName: col, value: dateStr);
        }
        return DataGridCell<String>(columnName: col, value: v?.toString() ?? '');
      }).toList(),
    )).toList();
  }
  @override
  List<DataGridRow> get rows => _rows;
  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map((cell) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(cell.value.toString()),
      )).toList(),
    );
  }
}
*/ 