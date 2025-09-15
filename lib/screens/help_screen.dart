import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../translations.dart';
import '../l10n/app_localizations.dart';
import '../services/help_service.dart';
import '../widgets/common/bottom_app_bar.dart';

class HelpScreen extends StatefulWidget {
  final String helpType;
  
  const HelpScreen({super.key, required this.helpType});

  @override
  HelpScreenState createState() => HelpScreenState();
}

class HelpScreenState extends State<HelpScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _usageContent = '';
  String _faqContent = '';
  String _contactContent = '';
  bool _isLoading = true;

  // 반응형 디자인을 위한 헬퍼 메서드들
  double getFontSize(BuildContext context, double base) {
    final width = MediaQuery.of(context).size.width;
    if (width < 480) return base - 2;
    if (width < 800) return base;
    if (width < 1200) return base + 1;
    return base + 2;
  }

  EdgeInsets getPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 480) return const EdgeInsets.all(12.0);
    if (width < 800) return const EdgeInsets.all(16.0);
    if (width < 1200) return const EdgeInsets.all(20.0);
    return const EdgeInsets.all(24.0);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHelpContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHelpContent() async {
    setState(() => _isLoading = true);
    
    try {
      // 사용법 내용 로드
      _usageContent = await HelpService.getHelpContent(widget.helpType);
      
      // FAQ 내용 로드
      _faqContent = await HelpService.getFAQContent();
      
      // 연락처 내용 로드
      _contactContent = await HelpService.getContactContent();
    } catch (e) {
      debugPrint('Error loading help content: $e');
      _usageContent = AppLocalizations.of(context).get('help_load_error');
      _faqContent = AppLocalizations.of(context).get('faq_load_error');
      _contactContent = AppLocalizations.of(context).get('contact_load_error');
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguage = Provider.of<LanguageProvider>(context).currentLanguage;
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).get('help'),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: TextStyle(fontSize: getFontSize(context, 14)),
          unselectedLabelStyle: TextStyle(fontSize: getFontSize(context, 14)),
          tabs: [
            Tab(text: AppLocalizations.of(context).get('usage')),
            Tab(text: AppLocalizations.of(context).get('faq')),
            Tab(text: AppLocalizations.of(context).get('contact')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsageGuide(),
                _buildFAQ(),
                _buildContact(),
              ],
            ),
      bottomNavigationBar: const CommonBottomAppBar(),
    );
  }

  String _getHelpTitle() {
    final currentLanguage = Provider.of<LanguageProvider>(context, listen: false).currentLanguage;
    
    switch (widget.helpType) {
      case 'all':
        return AppLocalizations.of(context).get('help_all');
      case 'stock_status':
        return AppLocalizations.of(context).get('help_stock_status');
      case 'stock_manage':
        return AppLocalizations.of(context).get('help_stock_manage');
      case 'stock_close':
        return AppLocalizations.of(context).get('help_stock_close');
      case 'charts':
        return AppLocalizations.of(context).get('help_charts');
      case 'stock_settings':
        return AppLocalizations.of(context).get('help_stock_settings');
      default:
        return AppLocalizations.of(context).get('help');
    }
  }

  Widget _buildUsageGuide() {
    return SingleChildScrollView(
      padding: getPadding(context),
      child: _buildMarkdownContent(_usageContent),
    );
  }

  Widget _buildFAQ() {
    return SingleChildScrollView(
      padding: getPadding(context),
      child: _buildMarkdownContent(_faqContent),
    );
  }

  Widget _buildContact() {
    return SingleChildScrollView(
      padding: getPadding(context),
      child: _buildMarkdownContent(_contactContent),
    );
  }

  Widget _buildMarkdownContent(String content) {
    // 간단한 마크다운 파싱 (실제 프로덕션에서는 flutter_markdown 패키지 사용 권장)
    final lines = content.split('\n');
    final widgets = <Widget>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      
      if (line.startsWith('# ')) {
        // H1 제목
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              line.substring(2),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        // H2 제목
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              line.substring(3),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        // H3 제목
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              line.substring(4),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        // 리스트 항목
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).get('dot') ?? '• ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    line.substring(2),
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.startsWith('**') && line.endsWith('**')) {
        // 굵은 텍스트
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              line.substring(2, line.length - 2),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (line.startsWith('Q: ')) {
        // FAQ 질문
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        );
      } else if (line.startsWith('A: ')) {
        // FAQ 답변
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              line.substring(3),
              style: TextStyle(fontSize: 14),
            ),
          ),
        );
      } else if (line.contains('http')) {
        // 링크 (간단한 처리)
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        );
      } else {
        // 일반 텍스트
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              AppLocalizations.of(context).get('help_line') ?? line,
              style: TextStyle(fontSize: 14),
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}