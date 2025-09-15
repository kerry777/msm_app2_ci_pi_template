import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class IntegratedMsmSpaScreen extends StatefulWidget {
  const IntegratedMsmSpaScreen({Key? key}) : super(key: key);

  @override
  State<IntegratedMsmSpaScreen> createState() => _IntegratedMsmSpaScreenState();
}

class _IntegratedMsmSpaScreenState extends State<IntegratedMsmSpaScreen> {
  String _status = 'MSM System Ready';
  String _currentPage = 'Main Menu';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🏢 MSM'),
            if (_currentPage != 'MSM System') ...[
              const Text(' • '),
              Text(
                _currentPage,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFF667EEA),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  setState(() {
                    _status = 'Refreshing...';
                  });
                  Future.delayed(const Duration(seconds: 1), () {
                    setState(() {
                      _status = 'MSM System Ready';
                    });
                  });
                  break;
                case 'home':
                  setState(() {
                    _currentPage = 'Main Menu';
                    _status = 'MSM System Ready';
                  });
                  break;
              }
            },
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
                value: 'home',
                child: Row(
                  children: [
                    Icon(Icons.home),
                    SizedBox(width: 8),
                    Text('메인 메뉴'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 표시 및 빠른 네비게이션
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // 빠른 네비게이션 버튼들
                Row(
                  children: [
                    _buildQuickNavButton(Icons.analytics, 'Analytics', () {
                      setState(() {
                        _currentPage = 'Analytics';
                        _status = 'Analytics System Loaded';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Analytics 시스템을 로드합니다')),
                      );
                    }),
                    const SizedBox(width: 8),
                    _buildQuickNavButton(Icons.shopping_cart, 'Order', () {
                      setState(() {
                        _currentPage = 'Order System';
                        _status = 'Order System Loaded';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('주문 시스템을 로드합니다')),
                      );
                    }),
                    const SizedBox(width: 8),
                    _buildQuickNavButton(Icons.description, 'Template', () {
                      setState(() {
                        _currentPage = 'Template Editor';
                        _status = 'Template Editor Loaded';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('템플릿 에디터를 로드합니다')),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          // MSM 메인 컨텐츠
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8.0),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Column(
                    children: [
                      // 사용자 환영 카드
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.business, size: 32, color: Colors.blue[600]),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'MSM 통합시스템',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${authProvider.userInfo?['KOR_NM']?.toString() ?? 'MSM 사용자'}님 환영합니다',
                                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'ID: ${authProvider.userInfo?['LOGINID']?.toString() ?? 'Unknown'} | 접속시간: ${DateTime.now().toString().substring(0, 16)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // MSM 시스템 컨텐츠
                      Expanded(
                        child: _buildCurrentPageContent(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // Floating Action Button for quick actions
      floatingActionButton: _currentPage != 'Main Menu'
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _currentPage = 'Main Menu';
                  _status = 'MSM System Ready';
                });
              },
              backgroundColor: const Color(0xFF667EEA),
              child: const Icon(Icons.home, color: Colors.white),
              tooltip: '메인 메뉴로',
            )
          : null,
    );
  }

  Widget _buildQuickNavButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildCurrentPageContent() {
    switch (_currentPage) {
      case 'Main Menu':
        return GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildSystemCard('매출 분석', Icons.bar_chart, Colors.green, () {
              setState(() {
                _currentPage = 'Sales Analytics';
                _status = 'Sales Analytics Loaded';
              });
            }),
            _buildSystemCard('재고 관리', Icons.inventory, Colors.orange, () {
              setState(() {
                _currentPage = 'Inventory Management';
                _status = 'Inventory Management Loaded';
              });
            }),
            _buildSystemCard('주문 처리', Icons.shopping_basket, Colors.blue, () {
              setState(() {
                _currentPage = 'Order Processing';
                _status = 'Order Processing Loaded';
              });
            }),
            _buildSystemCard('고객 관리', Icons.people, Colors.purple, () {
              setState(() {
                _currentPage = 'Customer Management';
                _status = 'Customer Management Loaded';
              });
            }),
            _buildSystemCard('보고서', Icons.description, Colors.teal, () {
              setState(() {
                _currentPage = 'Reports';
                _status = 'Reports System Loaded';
              });
            }),
            _buildSystemCard('설정', Icons.settings, Colors.grey, () {
              setState(() {
                _currentPage = 'System Settings';
                _status = 'System Settings Loaded';
              });
            }),
          ],
        );
      case 'Sales Analytics':
        return _buildAnalyticsContent();
      case 'Inventory Management':
        return _buildInventoryContent();
      case 'Order Processing':
        return _buildOrderContent();
      case 'Customer Management':
        return _buildCustomerContent();
      case 'Reports':
        return _buildReportsContent();
      case 'System Settings':
        return _buildSettingsContent();
      case 'Analytics':
        return _buildAnalyticsContent();
      case 'Order System':
        return _buildOrderContent();
      case 'Template Editor':
        return _buildTemplateContent();
      default:
        return _buildDefaultContent();
    }
  }

  Widget _buildAnalyticsContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.green, size: 32),
                const SizedBox(width: 16),
                const Text('매출 분석 시스템', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.trending_up),
                    title: const Text('월별 매출 현황'),
                    subtitle: const Text('월별 매출 추이 및 성장률 분석'),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('월별 매출 현황을 불러옵니다')),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.pie_chart),
                    title: const Text('제품별 매출 분석'),
                    subtitle: const Text('제품 카테고리별 매출 비중 분석'),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('제품별 분석을 불러옵니다')),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: const Text('지역별 매출 분석'),
                    subtitle: const Text('지역별 매출 현황 및 시장 점유율'),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('지역별 분석을 불러옵니다')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: Colors.orange, size: 32),
                const SizedBox(width: 16),
                const Text('재고 관리 시스템', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('재고 관리 기능', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('현재 재고 현황 조회, 입출고 관리, 안전재고 알림 등'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('재고 관리 기능을 준비중입니다')),
                      ),
                      child: const Text('재고 현황 조회'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_basket, color: Colors.blue, size: 32),
                const SizedBox(width: 16),
                const Text('주문 처리 시스템', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('주문 처리 기능', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('주문 접수, 처리 상태 관리, 배송 추적 등'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('주문 처리 기능을 준비중입니다')),
                      ),
                      child: const Text('주문 현황 조회'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple, size: 32),
                const SizedBox(width: 16),
                const Text('고객 관리 시스템', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('고객 관리 기능', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('고객 정보 관리, 구매 이력, 고객 분석 등'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('고객 관리 기능을 준비중입니다')),
                      ),
                      child: const Text('고객 현황 조회'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.teal, size: 32),
                const SizedBox(width: 16),
                const Text('보고서 시스템', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assessment, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('보고서 기능', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('매출 보고서, 재고 보고서, 고객 분석 보고서 등'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('보고서 기능을 준비중입니다')),
                      ),
                      child: const Text('보고서 생성'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.grey, size: 32),
                const SizedBox(width: 16),
                const Text('시스템 설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('시스템 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('사용자 설정, 시스템 환경 설정, 권한 관리 등'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('설정 기능을 준비중입니다')),
                      ),
                      child: const Text('설정 관리'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.indigo, size: 32),
                const SizedBox(width: 16),
                const Text('템플릿 에디터', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_document, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('템플릿 편집 기능', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('문서 템플릿 생성 및 편집, 양식 관리 등'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('템플릿 에디터를 준비중입니다')),
                      ),
                      child: const Text('템플릿 편집'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('$_currentPage', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('해당 기능을 준비중입니다'),
        ],
      ),
    );
  }

  Widget _buildSystemCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
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