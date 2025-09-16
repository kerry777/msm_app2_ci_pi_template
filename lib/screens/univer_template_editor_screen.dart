import 'package:flutter/material.dart';
import 'univer_excel_viewer_screen.dart';

class UniverTemplateEditorScreen extends StatelessWidget {
  final bool isSimple;

  const UniverTemplateEditorScreen({
    super.key,
    this.isSimple = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isSimple ? 'Template Editor (Simple)' : 'Template Editor'),
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더 카드
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      isSimple ? Icons.table_view : Icons.table_chart,
                      size: 48,
                      color: Colors.teal[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSimple ? 'Univer Template Editor (Simple)' : 'Univer Template Editor',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Excel 템플릿을 Univer 엔진으로 편집하고 관리',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 템플릿 목록
            const Text(
              '사용 가능한 템플릿',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 템플릿 버튼들
            if (isSimple) ...[
              // Simple 버전 - 기본 템플릿만
              _buildTemplateButton(
                context,
                '한국어 견적서',
                'assets/excel_templates/quotation_kr.xlsx',
                Icons.description,
                Colors.blue[600]!,
              ),
            ] else ...[
              // 전체 버전 - 모든 템플릿
              _buildTemplateButton(
                context,
                '한국어 견적서',
                'assets/excel_templates/quotation_kr.xlsx',
                Icons.description,
                Colors.blue[600]!,
              ),
              const SizedBox(height: 12),
              _buildTemplateButton(
                context,
                'PI (Proforma Invoice)',
                'assets/excel_templates/pi_template.xlsx',
                Icons.receipt_long,
                Colors.green[600]!,
              ),
              const SizedBox(height: 12),
              _buildTemplateButton(
                context,
                'Packing List',
                'assets/excel_templates/packing_list.xlsx',
                Icons.inventory,
                Colors.orange[600]!,
              ),
              const SizedBox(height: 12),
              _buildTemplateButton(
                context,
                'Commercial Invoice',
                'assets/excel_templates/commercial_invoice.xlsx',
                Icons.article,
                Colors.purple[600]!,
              ),
            ],

            const SizedBox(height: 24),

            // 빈 스프레드시트로 시작
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UniverExcelViewerScreen(
                      title: '새 스프레드시트',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('빈 스프레드시트로 시작'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const Spacer(),

            // 정보 카드
            Card(
              color: Colors.teal[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.teal[600]),
                        const SizedBox(width: 8),
                        const Text(
                          'Univer 기반 Template Editor',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• 원본 Excel 포맷 완벽 보존'),
                    const Text('• 실시간 공동 편집 지원'),
                    const Text('• 수식 및 차트 완전 지원'),
                    const Text('• PDF/Excel 내보내기'),
                    if (!isSimple) const Text('• 고급 템플릿 관리 기능'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateButton(
    BuildContext context,
    String title,
    String filePath,
    IconData icon,
    Color color,
  ) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UniverExcelViewerScreen(
              title: title,
              excelFilePath: filePath,
            ),
          ),
        );
      },
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}