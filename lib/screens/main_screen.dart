import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:html' as html;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/menu_display_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/font_size_provider.dart';
import '../widgets/app_font_size_button.dart';
import '../config/app_config.dart';
import '../translations.dart';
import '../l10n/app_localizations.dart';
import '../utils/preferences_manager.dart';
import '../language_picker_dialog.dart';
import '../utils/auto_test_system.dart'; // 🤖 자동 테스트 시스템 추가
import 'login_screen.dart';
import 'help_screen.dart';

// 병원재고조사 관련 import 제거됨 - 파일들이 삭제되어 주석 처리

import 'change_password_screen.dart';
// import 'auto_order_history_screen.dart'; // 파일 삭제됨
// import 'hospital_analysis_screen.dart'; // 파일 삭제됨
import 'ai_analysis_screen.dart';
// import 'hospital_master_screen.dart'; // 파일 삭제됨
import 'apk_download_screen.dart';
// import 'agency_sales_screen.dart'; // 파일 삭제됨
import '../services/api_service.dart';
// import 'stock_close_raw_screen.dart'; // 파일 삭제됨
import 'agency_sales_chart_screen.dart';
import 'sales_summary_screen.dart';
// import 'product_order_screen.dart'; // 임시 주석 처리 - 컴파일 에러 수정
import 'order_management_screen.dart';
import 'order_list_screen.dart';
import 'order_analytics_screen.dart';
import 'funnel_analysis_screen.dart';
import 'quote_management_screen.dart';
// import 'excel_template_viewer_screen.dart'; // 삭제됨 - 사용하지 않음
// import 'syncfusion_excel_viewer_screen.dart'; // Temporarily disabled due to API changes
import 'ej2_spreadsheet_screen.dart'; // EJ2 Spreadsheet 스크린 추가
import 'ej2_spreadsheet_debug_screen.dart'; // EJ2 Spreadsheet 디버그 스크린 추가
import 'ej2_spreadsheet_simple_screen.dart'; // EJ2 Spreadsheet 간단한 스크린 추가
import 'analytics_spa_screen.dart'; // 통합분석 SPA 스크린 추가
import 'advanced_pivot_table_screen.dart'; // 고급 피벗 테이블 스크린 추가
import 'order_spa_screen.dart'; // 주문등록 SPA 스크린 추가
import 'integrated_msm_spa_screen.dart'; // MSM 통합시스템 SPA 스크린 추가
// 분석 화면들 임시 제거 (컴파일 에러 해결 후 복구)
import 'customer_analytics_screen.dart';
import 'product_analytics_screen.dart';
// === 🚀 고급 분석 화면들 === (복구 완료!)
// import 'enhanced_analytics_screen.dart';
// import 'enhanced_analytics_with_context_menu_screen.dart';
import 'excel_quotation_screen.dart';
import 'univer_template_editor_screen.dart';

// === 🚀 새로운 Power BI 수준 기능들 ===
import 'advanced_bi_drilldown_screen.dart';
import 'advanced_interactive_chart_screen.dart';
import 'power_bi_dashboard_screen.dart';
import 'advanced_multi_dimensional_screen.dart'; // 통합분석2
// import 'syncfusion_pivot_analysis_screen.dart'; // 피벗분석2_싱크퓨전 - 비활성화
import 'real_interactive_analytics_screen.dart'; // 진짜 인터랙티브 분석

// 공통 폰트 크기 상수 정의
class AppFontSizes {
  static const double topMenu = 14.0;  // Top menu 폰트 크기 (최대값)
  static const double title = 14.0;    // 제목 폰트 크기
  static const double body = 12.0;     // 본문 폰트 크기
  static const double caption = 10.0;  // 캡션 폰트 크기
}

// enum AppTab {
//   itemRelease,
//   itemReturn;

//   String get key {
//     switch (this) {
//       case AppTab.itemRelease:
//         return 'item_release';
//       case AppTab.itemReturn:
//         return 'item_return';
//     }
//   }

//   IconData get icon {
//     switch (this) {
//       case AppTab.itemRelease:
//         return Icons.inventory;
//       case AppTab.itemReturn:
//         return Icons.assignment_return;
//     }
//   }

//   String get title {
//     switch (this) {
//       case AppTab.itemRelease:
//         return 'item_release';
//       case AppTab.itemReturn:
//         return 'item_return';
//     }
//   }
// }

// final Map<AppTab, Map<String, dynamic>> menuData = {
//   AppTab.itemRelease: {
//     'title': 'item_release',
//     'icon': Icons.inventory,
//   },
//   AppTab.itemReturn: {
//     'title': 'item_return',
//     'icon': Icons.assignment_return,
//   },
// };



// 메인 메뉴별 배경색 반환
Color getMainMenuBackgroundColor(String mainKey) {
  switch (mainKey) {
    case 'orders':
      return Colors.orange; // 주문 - 주황색
    case 'charts':
      return Colors.red.shade300; // 재고분석 - 연한 빨간색
    case 'help':
      return Colors.green; // 헬프 - 초록색
    case 'my_info':
      return Colors.green; // 내정보 - 초록색
    default:
      return Colors.blue; // 기본값
  }
}


// 🔄 MSM 전환 계획: MDM(납품관리) → MSM(매출분석시스템)
// 현재: 기존 메뉴 구조 유지 (안전성)
// 미래: 점진적으로 납품/물류 → 분석/BI/AI 중심 전환
final Map<String, Map<String, dynamic>> menuData = {
  'report': {
    'title': 'analysis_reports', // 분석/보고서
    'icon': Icons.bar_chart,
    'subMenus': [
      // === 📊 핵심 매출분석 ===
      {'sub_key': 'sales_summary', 'title': 'sales_summary', 'icon': Icons.summarize}, // 🎯 통합매출분석 (메인)
      {'sub_key': 'ai_analysis', 'title': 'ai_analysis', 'icon': Icons.smart_toy}, // AI 매출분석
      {'sub_key': 'customer_focused_analytics', 'title': '고객 중심 분석', 'icon': Icons.people},
      {'sub_key': 'product_focused_analytics', 'title': '상품 중심 분석', 'icon': Icons.inventory},
      // === 🚀 고급 분석 기능들 ===
      {'sub_key': 'enhanced_analytics', 'title': '📈 통합분석2', 'icon': Icons.dashboard},
      {'sub_key': 'enhanced_analytics_context', 'title': '⚡ 인터랙티브 분석', 'icon': Icons.touch_app},
      {'sub_key': 'advanced_pivot_table', 'title': '📊 고급 피벗 테이블', 'icon': Icons.pivot_table_chart},
      {'sub_key': 'syncfusion_pivot_analysis', 'title': '🔄 피벗분석2_싱크퓨전', 'icon': Icons.table_view},
      // === 🚀 새로운 Power BI 수준 기능들 ===
      {'sub_key': 'advanced_bi_drilldown', 'title': '🌟 실제 드릴다운 분석', 'icon': Icons.explore},
      {'sub_key': 'advanced_interactive_chart', 'title': '🎛️ 고급 인터랙티브 차트', 'icon': Icons.multiline_chart},
      {'sub_key': 'power_bi_dashboard', 'title': '⚡ Power BI 대시보드', 'icon': Icons.speed},
      // === 📊 주문 관련 분석 ===
      {'sub_key': 'order_analytics', 'title': 'order_analytics', 'icon': Icons.analytics}, // 주문 분석
      {'sub_key': 'funnel_analysis', 'title': 'funnel_analysis', 'icon': Icons.filter_list}, // Funnel 분석
      // === 🌐 SPA 기반 분석 도구들 ===
      {'sub_key': 'analytics_spa', 'title': '통합분석 SPA', 'icon': Icons.dashboard}, // 통합분석 SPA
      {'sub_key': 'order_spa', 'title': '주문등록 SPA', 'icon': Icons.shopping_basket}, // 주문등록 SPA
      {'sub_key': 'integrated_msm_spa', 'title': 'MSM 통합시스템', 'icon': Icons.apps}, // MSM 통합시스템
      {'sub_key': 'ej2_spreadsheet', 'title': 'Template Editor', 'icon': Icons.table_chart}, // Template Editor (Main)
      {'sub_key': 'ej2_spreadsheet_simple', 'title': 'Template Editor (Simple)', 'icon': Icons.table_view}, // Template Editor (Simple)
    ],
  },
  // 납품관리를 주문으로 변경 - 주문과 견적만 포함
  'orders': {
    'title': 'orders', // 주문
    'icon': Icons.shopping_cart,
    'subMenus': [
      {'sub_key': 'product_order', 'title': 'product_order', 'icon': Icons.shopping_cart}, // 주문_펀넬_등록
      {'sub_key': 'order_management', 'title': 'order_management', 'icon': Icons.dashboard}, // 주문 관리
      {'sub_key': 'order_list', 'title': 'order_list', 'icon': Icons.list_alt}, // 주문 목록
      {'sub_key': 'quote_management', 'title': 'quote_management', 'icon': Icons.receipt_long}, // 견적 관리
      {'sub_key': 'excel_quotation', 'title': 'Excel 견적서 편집기', 'icon': Icons.grid_on}, // Excel 견적서 편집기
    ],
  },
  'help': {
    'title': 'help',
    'icon': Icons.help,
    'subMenus': [
      {'sub_key': 'help_all', 'title': 'help_all'},
    ],
  },
  'my_info': {
    'title': 'my_info',
    'icon': Icons.person,
    'subMenus': [
      {'sub_key': 'change_password', 'title': 'change_password'},
    ],
  },
  'etc': {
    'title': 'etc',
    'icon': Icons.more_horiz,
    'subMenus': [
      {'sub_key': 'apk_download', 'title': 'apk_download'},
    ],
  },
};

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _selectedMainKey = '';
  String _selectedSubKey = '';
  final List<Map<String, String>> _menuHistory = [];
  
  // 🤖 자동 테스트 시스템
  final AutoTestSystem _autoTestSystem = AutoTestSystem();

  @override
  void initState() {
    super.initState();
    // 카드 형태 메뉴가 나타나도록 초기값을 비워둠
    _selectedMainKey = '';
    _selectedSubKey = '';
  }

  // 🤖 자동 테스트를 위한 화면 전환 메서드
  void navigateToScreenForTest(String subKey) {
    // 어떤 메인 카테고리에 속하는지 찾기
    String? mainKey;
    for (var entry in menuData.entries) {
      final subMenus = entry.value['subMenus'] as List;
      if (subMenus.any((subMenu) => subMenu['sub_key'] == subKey)) {
        mainKey = entry.key;
        break;
      }
    }
    
    if (mainKey != null) {
      setState(() {
        _selectedMainKey = mainKey!;
        _selectedSubKey = subKey;
      });
      print('🔄 화면 전환: $mainKey > $subKey');
    } else {
      print('❌ 화면을 찾을 수 없음: $subKey');
    }
  }

  void _goBackMenu() {
    if (_menuHistory.isNotEmpty) {
      final prev = _menuHistory.removeLast();
      setState(() {
        _selectedMainKey = prev['main']!;
        _selectedSubKey = prev['sub']!;
      });
    }
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  void _logout(BuildContext context) async {
    // 로그아웃 확인 다이얼로그
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).get('confirm_logout')),
        content: Text(AppLocalizations.of(context).get('logout_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).get('logout')),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // AuthProvider 로그아웃
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.logout();
      
      // FavoritesProvider 초기화
      final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
      await favoritesProvider.clearAllFavorites();
      
      // 로그인 화면으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  Widget _getScreenWidget(String mainKey, String subKey) {
    switch (subKey) {
      case 'auto_order_history':
        return Scaffold(
          appBar: AppBar(title: const Text('자동주문내역')),
          body: const Center(child: Text('준비중인 기능입니다')),
        ); // AutoOrderHistoryScreen 삭제됨
      // 매출현황 관련
      case 'sales_summary':
        return const SalesSummaryScreen();
      // 구분선
      case 'divider':
        return const SizedBox.shrink();
      case 'product_order':
        return const Center(child: Text('주문등록 화면 (임시 비활성화)'));
        // return const ProductOrderScreen(); // 임시 주석 처리 - 컴파일 에러 수정
      case 'order_management':
        return const OrderManagementScreen();
      case 'order_list':
        return const OrderListScreen();
      case 'order_analytics':
        return const OrderAnalyticsScreen();
      case 'funnel_analysis':
        return const FunnelAnalysisScreen();
      case 'quote_management':
        return const QuoteManagementScreen();

      case 'excel_template_viewer':
        return const UniverTemplateEditorScreen(); // Use Univer Template Editor instead
      case 'syncfusion_excel_viewer':
        return const UniverTemplateEditorScreen(); // Use Univer Template Editor instead  
      case 'excel_quotation':
        return const ExcelQuotationScreen(); // Excel 견적서 편집기
      case 'ej2_spreadsheet':
        return const UniverTemplateEditorScreen(); // Univer Template Editor (Main)
      case 'ej2_spreadsheet_debug':
        return const EJ2SpreadsheetDebugScreen(); // EJ2 Spreadsheet 디버그 스크린
      case 'ej2_spreadsheet_simple':
        return const UniverTemplateEditorScreen(isSimple: true); // Univer Template Editor (Simple)

      // SPA 시스템 관련
      case 'analytics_spa':
        return const AnalyticsSpaScreen(); // 통합분석 SPA 스크린
      case 'order_spa':
        return const OrderSpaScreen(); // 주문등록 SPA 스크린
      case 'integrated_msm_spa':
        return const IntegratedMsmSpaScreen(); // MSM 통합시스템 SPA 스크린

      // 재고마감 관련

      case 'agency_item_receive_regist':
        return Scaffold(
          appBar: AppBar(title: const Text('대리점입고등록')),
          body: const Center(child: Text('준비중인 기능입니다')),
        ); // AgencyItemReceiveRegistScreen 삭제됨
      case 'agency_item_receive_edit':
        return Scaffold(
          appBar: AppBar(title: const Text('대리점입고등록')),
          body: const Center(child: Text('준비중인 기능입니다')),
        ); // AgencyItemReceiveRegistScreen 삭제됨
      case 'agency_stock_analytics':
        return Scaffold(
          appBar: AppBar(title: const Text('대리점재고분석')),
          body: const Center(child: Text('준비중인 기능입니다')),
        ); // AgencyStockAnalyticsScreen 삭제됨
      case 'change_password':
        return const ChangePasswordScreen();
      // Help 메뉴 라우팅
      case 'help_all':
        return const HelpScreen(helpType: 'all');
      case 'hospital_analysis':
        return Scaffold(
          appBar: AppBar(title: const Text('병원분석')),
          body: const Center(child: Text('준비중인 기능입니다')),
        ); // HospitalAnalysisScreen 삭제됨
      case 'hospital_master':
        return Scaffold(
          appBar: AppBar(title: const Text('병원마스터')),
          body: const Center(child: Text('준비중인 기능입니다')),
        ); // HospitalMasterScreen 삭제됨
      case 'apk_download':
        return const ApkDownloadScreen();
      case 'agency_sales_chart':
        return const AgencySalesChartScreen();
      case 'agency_stock_status_agency':
        return Scaffold(
          appBar: AppBar(title: const Text('대리점재고현황')),
          body: const Center(child: Text('준비중인 기능입니다')),
        ); // AgencyStockStatusScreen 삭제됨
      case 'my_stock_report':
        return Scaffold(
          appBar: AppBar(title: const Text('영업사원재고현황')),
          body: const Center(child: Text('준비중인 기능입니다')),
        ); // AgentStockStatusScreen 삭제됨
      case 'ai_analysis':
        return const AiAnalysisScreen();
      case 'ai_analysis_drawer':
        return const AiAnalysisScreen();
      case 'customer_focused_analytics':
        return const CustomerAnalyticsScreen();
      case 'product_focused_analytics':
        return const ProductAnalyticsScreen();
      // === 🚀 고급 분석 기능들 === (통합분석으로 연결)
      case 'enhanced_analytics':
        return const AdvancedMultiDimensionalScreen(); // 통합분석2 → 다차원 분석 시스템
      case 'enhanced_analytics_context':
        return const RealInteractiveAnalyticsScreen(); // 인터랙티브 분석 → 진짜 인터랙티브 분석
      case 'advanced_pivot_table':
        return const AdvancedPivotTableScreen(); // 고급 피벗 테이블
      case 'syncfusion_pivot_analysis':
        return const Placeholder(); // 피벗분석2_싱크퓨전 - 임시 비활성화

      // === 🚀 새로운 Power BI 수준 기능들 ===
      case 'advanced_bi_drilldown':
        return AdvancedBIDrilldownScreen(); // 실제 드릴다운 분석
      case 'advanced_interactive_chart':
        return AdvancedInteractiveChartScreen(); // 고급 인터랙티브 차트
      case 'power_bi_dashboard':
        return PowerBIDashboardScreen(); // Power BI 대시보드

      // 분석 화면들 임시 제거
      default:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 메인 카테고리 카드들
              Text(
                '메인 메뉴',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildMenuCard('견적', Icons.receipt_long, Colors.blue, () {
                    if (kIsWeb) {
                      html.window.location.href = '/univer_final_solution.html';
                    } else {
                      setState(() {
                        _selectedMainKey = 'order';
                        _selectedSubKey = 'quote_management';
                      });
                    }
                  }),
                  _buildMenuCard('주문', Icons.shopping_cart, Colors.green, () {
                    setState(() {
                      _selectedMainKey = 'order';
                      _selectedSubKey = 'order_management';
                    });
                  }),
                  _buildMenuCard('분석', Icons.analytics, Colors.orange, () {
                    setState(() {
                      _selectedMainKey = 'report';
                      _selectedSubKey = 'power_bi_dashboard';
                    });
                  }),
                  _buildMenuCard('기타', Icons.more_horiz, Colors.purple, () {
                    setState(() {
                      _selectedMainKey = 'etc';
                      _selectedSubKey = 'help_all';
                    });
                  }),
                ],
              ),
              SizedBox(height: 24),
              // 하단 세부 기능 카드들
              Text(
                '빠른 접근',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildQuickCard('견적_KR', Icons.description, Colors.blue.shade300, () {
                    setState(() {
                      _selectedMainKey = 'order';
                      _selectedSubKey = 'excel_quotation';
                    });
                  }),
                  _buildQuickCard('CI_해외', Icons.public, Colors.green.shade300, () {
                    setState(() {
                      _selectedMainKey = 'order';
                      _selectedSubKey = 'order_management';
                    });
                  }),
                  _buildQuickCard('PI_해외', Icons.inventory, Colors.orange.shade300, () {
                    setState(() {
                      _selectedMainKey = 'order';
                      _selectedSubKey = 'order_list';
                    });
                  }),
                ],
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;
    final mekAccessType = auth.userInfo?['MEK_ACCESS_TYPE']?.toString() ?? 'N/A';
    
    String title = AppLocalizations.of(context).get('app_title') ?? 'MDM';
    try {
      final mainMenu = menuData[_selectedMainKey];
      
      if (mainMenu != null && mainMenu['subMenus'] != null) {
        final subMenus = mainMenu['subMenus'] as List;
        
        final selectedSubMenu = subMenus.firstWhere(
          (subMenu) => subMenu['sub_key'] == _selectedSubKey,
          orElse: () => {'title': 'MDM'},
        );
        
        title = AppLocalizations.of(context).get(selectedSubMenu['title'] ?? 'MDM');
      }
    } catch (e) {
      // print('Error getting title: $e');
    }
    
    // AS일 때만 숨길 메뉴 키
    final hiddenMenuKeys = [];
    
    return WillPopScope(
      onWillPop: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).get('top_level_screen')),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).get('notice')),
            content: Text(AppLocalizations.of(context).get('top_level_screen')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context).get('confirm')),
              ),
            ],
          ),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: AppFontSizes.topMenu,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            // 🤖 개발 모드에서만 자동 테스트 버튼 표시
            if (kDebugMode)
              IconButton(
                icon: const Icon(Icons.smart_toy, color: Colors.orange),
                tooltip: '🤖 자동 테스트 실행',
                onPressed: () async {
                  await _autoTestSystem.startAutoTest(context);
                },
              ),
            // 폰트 크기 조절 버튼
            AppFontSizeButton(iconColor: Colors.white),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: AppLocalizations.of(context).get('logout'),
              onPressed: () => _logout(context),
            ),
            _buildLanguageSelector(),
            const SizedBox(width: 8),
          ],
        ),
        body: Consumer2<LanguageProvider, FontSizeProvider>(
          builder: (context, languageProvider, fontSizeProvider, child) {
            final lang = languageProvider.currentLanguage;
            return Column(
              children: [
                // Top Menu (2번째 줄)
                Container(
                  height: 48 * fontSizeProvider.scaleFactor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: menuData.entries
                                .where((entry) => !hiddenMenuKeys.contains(entry.key))
                                .map((entry) {
                                  final isSelected = _selectedMainKey == entry.key;
                                  return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                                      child: PopupMenuButton<String>(
                                        onSelected: (subKey) {
                                          setState(() {
                                            _menuHistory.add({'main': _selectedMainKey, 'sub': _selectedSubKey});
                                            _selectedMainKey = entry.key;
                                            _selectedSubKey = subKey;
                                          });
                                        },
                                        offset: const Offset(0, 40),
                                        itemBuilder: (context) {
                                          final subMenus = entry.value['subMenus'] as List;

                                          return subMenus
                                              .map<PopupMenuEntry<String>>((subMenu) => PopupMenuItem<String>(
                                                    value: subMenu['sub_key'],
                                                    child: Text(
                                                      AppLocalizations.of(context).get(subMenu['title'] as String),
                                                      style: TextStyle(
                                                        color: _selectedSubKey == subMenu['sub_key'] ? Theme.of(context).primaryColor : Colors.black,
                                                        fontWeight: _selectedSubKey == subMenu['sub_key'] ? FontWeight.bold : FontWeight.normal,
                                                        fontSize: AppFontSizes.body,
                                                      ),
                                                    ),
                                                  ))
                                              .toList();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                          decoration: BoxDecoration(
                                            color: isSelected ? getMainMenuBackgroundColor(entry.key) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(entry.value['icon'] as IconData, color: Colors.green, size: 20),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  AppLocalizations.of(context).get(entry.value['title'] as String),
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : Colors.black87,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: AppFontSizes.topMenu,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(Icons.arrow_drop_down, color: isSelected ? Colors.white : Colors.grey[600], size: 20),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                })
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content
                Expanded(
                  child: _getScreenWidget(_selectedMainKey, _selectedSubKey),
                ),
              ],
            );
          },
        ),
        drawer: Drawer(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: AppLocalizations.of(context).get('previous_menu'),
                          onPressed: _menuHistory.isNotEmpty ? _goBackMenu : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout),
                          tooltip: AppLocalizations.of(context).get('logout'),
                          onPressed: () => _logout(context),
                        ),
                      ],
                    ),
                    ...menuData.entries
                        .where((entry) => !hiddenMenuKeys.contains(entry.key))
                        .map((entry) => ExpansionTile(
                              leading: Icon(entry.value['icon'] as IconData),
                              title: Consumer<LanguageProvider>(
                                builder: (context, languageProvider, child) {
                                  return Text(
                                    AppLocalizations.of(context).get(entry.value['title'] as String),
                                    style: TextStyle(fontSize: AppFontSizes.body),
                                  );
                                },
                              ),
                              initiallyExpanded: _selectedMainKey == entry.key,
                              backgroundColor: Colors.indigo.shade50,
                              collapsedBackgroundColor: Colors.indigo.shade50,
                              children: (entry.value['subMenus'] as List)
                                  .map((subMenu) => Consumer<LanguageProvider>(
                                        builder: (context, languageProvider, child) {
                                          final subKey = subMenu['sub_key'] as String;
                                          final title = AppLocalizations.of(context).get(subMenu['title'] as String);
                                          final isSelected = _selectedMainKey == entry.key && _selectedSubKey == subKey;

                                          if (title == 'divider') {
                                            return const Divider(height: 24, thickness: 1, indent: 8, endIndent: 8);
                                          }

                                          return ListTile(
                                            leading: subMenu['icon'] != null ? Icon(subMenu['icon'], color: Colors.green) : null,
                                            title: Text(
                                              title,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                                                fontSize: AppFontSizes.body,
                                              ),
                                            ),
                                            tileColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _menuHistory.add({'main': _selectedMainKey, 'sub': _selectedSubKey});
                                                _selectedMainKey = entry.key;
                                                _selectedSubKey = subKey;
                                              });
                                              Navigator.pop(context);
                                            },
                                          );
                                        },
                                      ))
                                  .toList(),
                            ))
                        ,
                  ],
                ),
              ),
              // FutureBuilder<PackageInfo>(
              //   future: PackageInfo.fromPlatform(),
              //   builder: (context, snapshot) {
              //     if (!snapshot.hasData) return SizedBox();
              //     final info = snapshot.data!;
              //     return Padding(
              //       padding: const EdgeInsets.symmetric(vertical: 8.0),
              //       child: Text(
              //         '버전:  [36m{info.version} [0m (빌드:  [36m{info.buildNumber} [0m)',
              //         style: TextStyle(fontSize: 12, color: Colors.grey),
              //       ),
              //     );
              //   },
              // ),
            ],
          ),
        ),
        bottomNavigationBar: null,
      ),
    );
  }


  Widget _buildDesktopMenu(String? userGrade) {
    List<String> availableMenus = menuData.keys.toList();
    if (userGrade == 'AS') {
      availableMenus.remove('stock_settings');
    }

    return Row(
      children: availableMenus.map((key) {
        return _MenuButton(
          menuKey: key,
          isSelected: _selectedMainKey == key,
          onPressed: () {
            // 서브메뉴가 있는 경우 첫 번째 항목으로 자동 이동
            final subMenus = (menuData[key]?['subMenus'] as List? ?? []);
            if (subMenus.isNotEmpty) {
              setState(() {
                _menuHistory.add({'main': _selectedMainKey, 'sub': _selectedSubKey});
                _selectedMainKey = key;
                _selectedSubKey = subMenus.first['sub_key'];
              });
            }
          },
          subMenus: (menuData[key]?['subMenus'] as List<Map<String, dynamic>>? ?? []),
          onSubMenuSelected: (subKey) {
            setState(() {
              _menuHistory.add({'main': _selectedMainKey, 'sub': _selectedSubKey});
              _selectedMainKey = key; // 메인 키도 업데이트
              _selectedSubKey = subKey;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildLanguageSelector() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: IconButton(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  languageProvider.supportedLanguages[languageProvider.currentLanguage]?.flag ?? '🌐',
                  style: TextStyle(fontSize: AppFontSizes.topMenu),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => LanguagePickerDialog(
                  currentLanguage: languageProvider.currentLanguage,
                  supportedLanguages: languageProvider.supportedLanguages,
                  onSelected: (languageCode) {
                    languageProvider.setLanguage(languageCode);
                  },
                ),
              );
            },
            tooltip: AppLocalizations.of(context).get('selectLanguage'),
          ),
        );
      },
    );
  }

  // 메인 메뉴 카드 빌더
  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.white),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 빠른 접근 카드 빌더
  Widget _buildQuickCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String menuKey;
  final bool isSelected;
  final VoidCallback onPressed;
  final List<Map<String, dynamic>> subMenus;
  final ValueChanged<String> onSubMenuSelected;

  const _MenuButton({
    required this.menuKey,
    required this.isSelected,
    required this.onPressed,
    required this.subMenus,
    required this.onSubMenuSelected,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final title = AppLocalizations.of(context).get(menuData[widget.menuKey]?['title'] as String? ?? '');
    final selectedColor = Theme.of(context).primaryColor;
    final unselectedColor = Colors.black87;
    final backgroundColor = widget.isSelected
        ? selectedColor.withOpacity(0.1)
        : _isHovered
            ? Colors.grey.withOpacity(0.1)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(8),
          child: PopupMenuButton<String>(
            tooltip: '', // 기본 툴크 비활성화
            onSelected: widget.onSubMenuSelected,
            itemBuilder: (context) => widget.subMenus.map((subMenu) {
              return PopupMenuItem<String>(
                value: subMenu['sub_key'] as String,
                child: Text(AppLocalizations.of(context).get(subMenu['title'] as String)),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.isSelected ? selectedColor : unselectedColor,
                  fontSize: AppFontSizes.topMenu,
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  final String selectedMainKey;
  final String selectedSubKey;
  final Function(String) onSubMenuSelected;

  const _SideMenu({
    required this.selectedMainKey,
    required this.selectedSubKey,
    required this.onSubMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final subMenus = (menuData[selectedMainKey]?['subMenus'] as List? ?? []);
    if (subMenus.isEmpty) {
      return const SizedBox(width: 0); // 서브메뉴가 없으면 아무것도 표시하지 않음
    }
    return Material(
      elevation: 2,
      shadowColor: Colors.grey.withOpacity(0.2),
      child: Container(
        width: 200,
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                AppLocalizations.of(context).get(menuData[selectedMainKey]?['title'] as String? ?? ''),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSizes.topMenu,
                    ),
              ),
            ),
            ...subMenus.map((subMenu) {
              final subKey = subMenu['sub_key'] as String;
              final title = AppLocalizations.of(context).get(subMenu['title'] as String);
              final isSelected = selectedSubKey == subKey;

              if (title == 'divider') {
                return const Divider(height: 24, thickness: 1, indent: 8, endIndent: 8);
              }

              return ListTile(
                leading: subMenu['icon'] != null ? Icon(subMenu['icon'], color: Colors.green) : null,
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                    fontSize: AppFontSizes.body,
                  ),
                ),
                tileColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () => onSubMenuSelected(subKey),
              );
            }),
          ],
        ),
      ),
    );
  }

}