import 'package:flutter/material.dart';
import 'simple_univer_test_screen.dart';

class TestUniverScreen extends StatelessWidget {
  const TestUniverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Univer 테스트'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 제목
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.table_chart,
                      size: 48,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Univer Excel 뷰어 테스트',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'WebView를 통한 Univer 스프레드시트 엔진 통합',
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

            // 테스트 버튼들
            const Text(
              '테스트 옵션',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 기본 Univer 테스트
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SimpleUniverTestScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('기본 Univer 테스트 (간단)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            // 견적서 템플릿 테스트
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SimpleUniverTestScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.description),
              label: const Text('견적서 템플릿 로드 테스트'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            // PI 템플릿 테스트
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SimpleUniverTestScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('PI 템플릿 로드 테스트'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 12),

            // 발주서 템플릿 테스트
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SimpleUniverTestScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_cart),
              label: const Text('발주서 템플릿 로드 테스트'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 32),

            // 정보 카드
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text(
                          '테스트 정보',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• Univer WebView 통합 상태 확인'),
                    const Text('• CDN 라이브러리 로딩 테스트'),
                    const Text('• Flutter ↔ JavaScript 메시지 브릿지'),
                    const Text('• Excel 파일 로드 및 렌더링'),
                    const Text('• PDF 내보내기 기능'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}