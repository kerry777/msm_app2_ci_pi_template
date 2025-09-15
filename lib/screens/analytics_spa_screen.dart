import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AnalyticsSpaScreen extends StatefulWidget {
  const AnalyticsSpaScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsSpaScreen> createState() => _AnalyticsSpaScreenState();
}

class _AnalyticsSpaScreenState extends State<AnalyticsSpaScreen> {
  String _status = 'Analytics Ready';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 통합분석'),
        backgroundColor: const Color(0xFF667EEA),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _status = 'Refreshing...';
              });
              // 새로고침 시뮬레이션
              Future.delayed(const Duration(seconds: 1), () {
                setState(() {
                  _status = 'Analytics Ready';
                });
              });
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
            ),
            child: Text(
              _status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // 통합분석 컨텐츠
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Column(
                    children: [
                      // 사용자 정보 카드
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 24, color: Colors.blue[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${authProvider.userInfo?['KOR_NM']?.toString() ?? 'MSM 사용자'}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'ID: ${authProvider.userInfo?['LOGINID']?.toString() ?? 'Unknown'}',
                                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.verified_user, color: Colors.green[600]),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 분석 메뉴 그리드
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          children: [
                            _buildAnalyticsCard('매출 분석', Icons.trending_up, Colors.green, () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('매출 분석 기능이 로드됩니다')),
                              );
                            }),
                            _buildAnalyticsCard('고객 분석', Icons.people, Colors.blue, () {
                              Navigator.pushNamed(context, '/customer-analytics');
                            }),
                            _buildAnalyticsCard('상품 분석', Icons.inventory, Colors.orange, () {
                              Navigator.pushNamed(context, '/product-analytics');
                            }),
                            _buildAnalyticsCard('AI 예측', Icons.smart_toy, Colors.purple, () {
                              Navigator.pushNamed(context, '/ai-analysis');
                            }),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          // 하단 컨트롤
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('뒤로'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.home, size: 16),
                  label: const Text('메인'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
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