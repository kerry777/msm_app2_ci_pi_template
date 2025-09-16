import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import 'dart:typed_data';
import 'dart:convert';
// 웹 전용 import
import 'dart:html' as html show Blob, Url, document, AnchorElement, IFrameElement, window;
import 'dart:ui_web' as ui_web;

class ExcelQuotationScreen extends StatefulWidget {
  const ExcelQuotationScreen({super.key});

  @override
  State<ExcelQuotationScreen> createState() => _ExcelQuotationScreenState();
}

class _ExcelQuotationScreenState extends State<ExcelQuotationScreen> {
  String _selectedTemplate = 'MEK 견적서(한국어)';
  bool _isLoading = false;

  // 사용자가 업로드한 실제 Excel 파일 관리
  Uint8List? _uploadedExcelData;
  String? _uploadedFileName;

  final Map<String, String> _assetTemplates = {
    'MEK 견적서(한국어)': 'assets/MEK_SALES_TEMPLATE_QT_KR.xlsx',
    'MEK 견적서(영어)': 'assets/MEK_SALES_TEMPLATE_QT_EN.xlsx',
    'MEK 견적서(아랍어)': 'assets/MEK_SALES_TEMPLATE_QT_AS.xlsx',
    'MEK 판매리스트': 'assets/MEK_SALES_TEMPLATE_PL.xlsx',
    'MEK 상업송장': 'assets/MEK_SALES_TEMPLATE_CI.xlsx',
    'MEK 포장리스트': 'assets/MEK_SALES_TEMPLATE_PI.xlsx',
  };

  @override
  void initState() {
    super.initState();
  }

  // 원본 Excel 파일 뷰어 (실제 파일 내용 읽기)
  Future<void> _openOriginalExcelViewer(String templateName, String assetPath) async {
    print('📁 원본 Excel 파일 뷰어 시작: $templateName');

    try {
      setState(() {
        _isLoading = true;
      });

      // 템플릿 타입 결정
      String templateType = 'QT';
      if (templateName.contains('견적서') || templateName.contains('QT')) {
        templateType = 'QT';
      } else if (templateName.contains('판매리스트') || templateName.contains('PL')) {
        templateType = 'PL';
      } else if (templateName.contains('상업송장') || templateName.contains('CI')) {
        templateType = 'CI';
      } else if (templateName.contains('포장리스트') || templateName.contains('PI')) {
        templateType = 'PI';
      }

      // 간단한 URL 방식으로 원본 뷰어 열기 (localhost/msm 경로 사용)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final editorUrl = 'http://localhost/msm/univer_template.html?template=$templateType&file=${Uri.encodeComponent(assetPath)}&mode=original&v=$timestamp&fix=3';

      print('🔗 원본 Excel 뷰어 URL: $editorUrl');

      final script = '''
        console.log('🚀 원본 Excel 뷰어 실행: $templateName');
        const newWindow = window.open('$editorUrl', '_blank', 'width=1400,height=900,scrollbars=yes,resizable=yes');
        console.log('✅ 원본 뷰어 창 열기 완료');
      ''';

      final scriptElement = html.document.createElement('script');
      scriptElement.text = script;
      html.document.head!.append(scriptElement);
      scriptElement.remove();

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📁 원본 Excel 파일 뷰어 실행: $templateName'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      print('원본 Excel 뷰어 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('원본 Excel 뷰어 실행 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // MEK Univer Excel 뷰어 버튼이 눌렸을 때 (Univer 기반)
  Future<void> _openUniverExcelViewer(String templateName, String assetPath) async {
    print('🚨🚨🚨 MODIFIED FUNCTION CALLED! 🚨🚨🚨 templateName: $templateName');

    try {
      // 템플릿 이름을 기반으로 Excel 편집기 타입 결정
      String templateType = 'QT'; // 기본값은 견적서
      if (templateName.contains('견적서') || templateName.contains('QT')) {
        templateType = 'QT';
      } else if (templateName.contains('판매리스트') || templateName.contains('PL')) {
        templateType = 'PL';
      } else if (templateName.contains('상업송장') || templateName.contains('CI')) {
        templateType = 'CI';
      } else if (templateName.contains('포장리스트') || templateName.contains('PI')) {
        templateType = 'PI';
      }

      // Univer Excel 뷰어 URL 생성 (Flutter web에서 직접 접근)
      final editorUrl = 'univer_template.html?template=$templateType&file=${Uri.encodeComponent(assetPath)}';
      print('🔗 Excel 편집기 URL: $editorUrl');

      // 팝업 차단 방지를 위해 현재 창에서 직접 이동
      final script = '''
        console.log('🚀 JavaScript 실행 시작: $editorUrl');
        console.log('🔄 현재 창에서 Univer로 이동...');
        window.location.href = '$editorUrl';
        console.log('✅ location.href 실행 완료');
      ''';

      // HTML 문서에 script 요소 추가하여 실행
      final scriptElement = html.document.createElement('script');
      scriptElement.text = script;
      html.document.head!.append(scriptElement);
      scriptElement.remove();

      print('Excel 편집기 URL 생성: $editorUrl');
      print('JavaScript 스크립트 실행 완료');

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔧 Excel 편집기 실행 완료: $templateName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Excel 편집기 실행 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel 편집기 실행 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        title: const Text('📊 Excel 견적서 편집기'),
        elevation: 2,
        actions: [],
      ),
      body: Column(
        children: [
          // 상단 컨트롤 패널
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MEK Excel 편집기 설명
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'MEK Excel 편집기 안내',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '아래 버튼을 클릭하면 새 창에서 고급 Excel 편집기가 열립니다. '
                          '실제 Excel 기능을 사용하여 템플릿을 편집할 수 있습니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // MEK Excel 편집기 실행 버튼들
                Row(
                  children: [
                    const Text('MEK Excel 편집기 실행:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: _assetTemplates.entries.map((entry) {
                          return ElevatedButton(
                            onPressed: () => _openUniverExcelViewer(entry.key, entry.value),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(120, 32),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.table_chart, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${entry.key} 편집기',
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 원본 Excel 파일 뷰어 버튼들 (테스트용 - 한국어 견적서만)
                Row(
                  children: [
                    const Text('원본 Excel 파일 뷰어:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => _openOriginalExcelViewer('MEK 견적서(한국어)', 'assets/MEK_SALES_TEMPLATE_QT_KR.xlsx'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 32),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            '원본 MEK 견적서 보기',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            const Text('사용자:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Text(authProvider.userInfo?['KOR_NM'] ?? '익명'),
                            const Spacer(),
                            const SizedBox(width: 16),
                            if (_isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('버전:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text(
                              'Web v${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())} | Excel 뷰어 업데이트됨',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Excel 편집기 사용 안내
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.table_chart,
                        size: 64,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Univer Excel 편집기',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '위에서 원하는 템플릿을 선택하여 Excel 편집기를 시작하세요.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.tips_and_updates,
                              color: Colors.blue.shade600,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '새 창에서 열리는 고급 Excel 편집기로\n'
                              '실제 Excel 기능을 모두 사용할 수 있습니다.',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}