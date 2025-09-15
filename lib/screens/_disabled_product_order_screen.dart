import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../utils/order_report_generator.dart';
import '../services/invoice_service.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class ProductOrderScreen extends StatefulWidget {
  final String initialView;

  const ProductOrderScreen({super.key, this.initialView = 'search'});

  @override
  ProductOrderScreenState createState() => ProductOrderScreenState();
}

class ProductOrderScreenState extends State<ProductOrderScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategoryA = '';
  String _selectedCategoryB = '';
  String _selectedCategoryC = '';
  String _selectedLocation = '';
  String _selectedOption = '';
  String? _selectedTradeCode;
  List<dynamic> _items = [];
  final List<Map<String, dynamic>> _cart = [];
  String _deliveryDate = '';
  String _orderType = 'ORDER'; // ORDER or FUNNEL
  late Box _tradeFavoritesBox;
  Set<String> _favoriteTradeCodes = {}; // 메모리 캐시
  bool _showOnlyFavoriteTrades = false;
  final TextEditingController _tradeSearchController = TextEditingController();
  List<Map<String, dynamic>> _trades = [];
  Set<int> _selectedCartItems = {}; // 장바구니 선택된 아이템들
  final Map<String, bool> _expansionStates = {}; // 각 카테고리별 확장 상태
  int _expansionUpdateKey = 0; // ExpansionTile 재구성을 위한 키
  bool _isLoading = false;
  bool _isTradeLoading = false;
  int _page = 1;
  final int _pageSize = 50;
  bool _hasMore = true;
  bool _isMultiSelectMode = false;
  final List<String> _selectedItems = [];
  final ScrollController _scrollController = ScrollController();
  late Box _favoritesBox;
  List<dynamic> _recentOrders = [];
  List<dynamic> _orderHistory = [];
  String? _errorMessage;
  bool _isInitialized = false;

  // Provider references stored safely
  AuthProvider? _authProvider;
  String? _userToken;
  Map<String, dynamic>? _userInfo;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    debugPrint('ProductOrderScreen initState 시작');

    // 기본 출고요청일을 7일 후로 설정
    _deliveryDate = DateTime.now().add(const Duration(days: 7)).toIso8601String().split('T')[0];

    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Provider 참조를 안전하게 저장
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _userToken = _authProvider?.token;
    _userInfo = _authProvider?.userInfo;

    // ScaffoldMessenger 참조도 안전하게 저장
    try {
      _scaffoldMessenger = ScaffoldMessenger.of(context);
    } catch (e) {
      debugPrint('ScaffoldMessenger 접근 실패: $e');
      _scaffoldMessenger = null;
    }

    // 초기화가 아직 되지 않았다면 시작
    if (!_isInitialized && _authProvider != null) {
      _initializeAsync();
    }
  }

  Future<void> _initializeAsync() async {
    try {
      debugPrint('비동기 초기화 시작');
      setState(() {
        _errorMessage = null;
        _isInitialized = false;
      });
      
      // 1. Hive 초기화 먼저
      await _initHive();
      debugPrint('Hive 초기화 완료');
      
      // 2. 거래처 데이터 로드
      await _fetchTrades();
      debugPrint('거래처 데이터 로드 완료');
      
      // 3. 품목 데이터 로드
      await _fetchItems();
      debugPrint('품목 데이터 로드 완료');
      
      // 4. 초기 뷰에 따른 추가 데이터 로드
      if (widget.initialView == 'recent') {
        await _fetchRecentOrders();
        debugPrint('최근 주문 데이터 로드 완료');
      } else if (widget.initialView == 'history') {
        await _fetchOrderHistory();
        debugPrint('주문 내역 데이터 로드 완료');
      }
      
      setState(() {
        _isInitialized = true;
      });
      debugPrint('모든 비동기 초기화 완료');
    } catch (e) {
      debugPrint('비동기 초기화 오류: $e');
      setState(() {
        _errorMessage = '초기화 오류: $e';
        _isInitialized = true; // 에러가 있어도 UI는 표시
      });
      if (mounted && _scaffoldMessenger != null) {
        try {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: Text('초기화 오류: $e'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (snackBarError) {
          debugPrint('SnackBar 표시 실패: $snackBarError');
        }
      }
    }
  }

  Future<void> _initHive() async {
    _favoritesBox = await Hive.openBox('favorites');
    _tradeFavoritesBox = await Hive.openBox('trade_favorites');

    // 즐겨찾기를 메모리로 캐시
    _favoriteTradeCodes = Set<String>.from(_tradeFavoritesBox.keys.cast<String>());
  }

  // 안전한 SnackBar 표시 헬퍼 메서드
  void _showSafeSnackBar(SnackBar snackBar) {
    if (!mounted) return;

    try {
      if (_scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(snackBar);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    } catch (e) {
      debugPrint('SnackBar 표시 실패: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tradeSearchController.dispose();
    // Close Hive boxes safely
    if (_favoritesBox.isOpen) {
      _favoritesBox.close();
    }
    if (_tradeFavoritesBox.isOpen) {
      _tradeFavoritesBox.close();
    }
    super.dispose();
  }

  Future<void> _fetchTrades() async {
    if (!mounted || _userInfo == null) return;

    if (_userInfo?['MEK_TR_CD'] != 'MEK') {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isTradeLoading = true;
    });

    final url = Uri.parse('${AppConfig.apiBaseUrl}/trades');
    try {
      // 30초 타임아웃 설정 (느린 서버 대응)
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${_userToken}'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('거래처 조회 시간이 초과되었습니다. 서버가 느려서 시간이 오래 걸릴 수 있습니다.');
        },
      );
      
      debugPrint('fetchTrades: Status ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _trades = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        }
        
        // 성공 시 간단한 피드백
        if (mounted && _trades.isNotEmpty && _scaffoldMessenger != null) {
          try {
            _scaffoldMessenger!.showSnackBar(
              SnackBar(
                content: Text('거래처 ${_trades.length}개를 불러왔습니다.'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          } catch (snackBarError) {
            debugPrint('SnackBar 표시 실패: $snackBarError');
          }
        }
      } else {
        if (mounted && _scaffoldMessenger != null) {
          try {
            _scaffoldMessenger!.showSnackBar(
              const SnackBar(
                content: Text('거래처 조회 실패: 서버와 연결할 수 없습니다.'),
                backgroundColor: Colors.red,
              ),
            );
          } catch (snackBarError) {
            debugPrint('SnackBar 표시 실패: $snackBarError');
          }
        }
      }
    } catch (e) {
      debugPrint('fetchTrades: Error $e');
      if (mounted && _scaffoldMessenger != null) {
        try {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: Text('거래처 조회 오류: ${e.toString().contains('초과') ? e.toString() : '네트워크를 확인해주세요.'}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        } catch (snackBarError) {
          debugPrint('SnackBar 표시 실패: $snackBarError');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTradeLoading = false;
        });
      }
    }
  }

  Future<void> _fetchItems({bool reset = false}) async {
    debugPrint('_fetchItems 호출 - reset: $reset, isLoading: $_isLoading, hasMore: $_hasMore');
    
    if (_isLoading || !_hasMore) {
      debugPrint('_fetchItems 건너뜀 - 로딩 중이거나 더 이상 데이터 없음');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final trCd = _userInfo?['MEK_TR_CD'];
    debugPrint('_fetchItems - trCd: $trCd, userInfo: $_userInfo');

    if (trCd == null) {
      debugPrint('Error: MEK_TR_CD missing in userInfo: $_userInfo');
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('사용자 정보가 없습니다. 다시 로그인해주세요.')),
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/products?page=$_page&size=$_pageSize'
          '${_searchController.text.isNotEmpty ? '&search=${Uri.encodeComponent(_searchController.text.toUpperCase())}' : ''}'
          '${_selectedCategoryA.isNotEmpty ? '&categoryA=${Uri.encodeComponent(_selectedCategoryA.toUpperCase())}' : ''}'
          '${_selectedCategoryB.isNotEmpty ? '&categoryB=${Uri.encodeComponent(_selectedCategoryB.toUpperCase())}' : ''}'
          '${_selectedCategoryC.isNotEmpty ? '&categoryC=${Uri.encodeComponent(_selectedCategoryC.toUpperCase())}' : ''}'
          '${_selectedLocation.isNotEmpty ? '&location=${Uri.encodeComponent(_selectedLocation.toUpperCase())}' : ''}'
          '${_selectedOption.isNotEmpty ? '&option=${Uri.encodeComponent(_selectedOption.toUpperCase())}' : ''}',
    );

    try {
      debugPrint('_fetchItems - API 호출 시작: $url');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${_userToken}'},
      );
      debugPrint('_fetchItems - 응답 상태: ${response.statusCode}');
      debugPrint('_fetchItems - 응답 본문 길이: ${response.body.length}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final newItems = data['data'] ?? [];
        debugPrint('_fetchItems - 받은 아이템 수: ${newItems.length}');
        debugPrint('_fetchItems - 첫 번째 아이템: ${newItems.isNotEmpty ? newItems[0] : 'None'}');
        
        final categoryADistribution = newItems.map((item) => item['품목_대분류']).toSet().toList();
        debugPrint('_fetchItems - 대분류 분포: $categoryADistribution');

        if (mounted) {
          setState(() {
            if (reset) {
              _items = newItems;
              debugPrint('_fetchItems - 아이템 리셋: ${_items.length}개');
            } else {
              _items.addAll(newItems);
              debugPrint('_fetchItems - 아이템 추가: 총 ${_items.length}개');
            }
            _hasMore = newItems.length == _pageSize;
            _page = reset ? 2 : _page + 1;
          });
        }
        
        debugPrint('_fetchItems - 상태 업데이트 완료: hasMore=$_hasMore, page=$_page');
      } else {
        debugPrint('_fetchItems - API 오류: ${response.statusCode} - ${response.body}');
        if (mounted) {
          if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
            const SnackBar(content: Text('품목 조회 실패: 서버와 연결할 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      debugPrint('_fetchItems - 예외 발생: $e');
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('품목 조회 오류: 네트워크를 확인해주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('_fetchItems - 로딩 완료');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchItems();
    }
  }

  Future<void> _fetchRecentOrders() async {
    if (!mounted || _authProvider == null) return;
    final trCd = _authProvider!.userInfo?['MEK_TR_CD'];
    if (trCd == null) {
      debugPrint('Error: MEK_TR_CD missing in userInfo: ${_authProvider!.userInfo}');
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('사용자 정보가 없습니다. 다시 로그인해주세요.')),
        );
      }
      return;
    }

    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/product-order/history'
          '?startDate=${DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String()}'
          '&endDate=${DateTime.now().toIso8601String()}',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${_userToken}'},
      );
      debugPrint('fetchRecentOrders: Status ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _recentOrders = data['data']?.take(50).toList() ?? [];
          });
        }
      } else {
        if (mounted) {
          if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
            const SnackBar(content: Text('최근 주문 조회 실패: 서버와 연결할 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      debugPrint('fetchRecentOrders: Error $e');
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('최근 주문 조회 오류: 네트워크를 확인해주세요.')),
        );
      }
    }
  }

  Future<void> _fetchOrderHistory() async {
    if (!mounted || _authProvider == null) return;
    if (_authProvider!.userInfo?['MEK_TR_CD'] == null) {
      debugPrint('Error: trCd missing in userInfo');
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('사용자 정보가 없습니다. 다시 로그인해주세요.')),
        );
      }
      return;
    }

    final url = Uri.parse('${AppConfig.apiBaseUrl}/product-order/history');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${_userToken}'},
      );
      debugPrint('fetchOrderHistory: Status ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _orderHistory = data['data'] ?? [];
          });
        }
      } else {
        if (mounted) {
          if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
            const SnackBar(content: Text('주문 내역 조회 실패: 서버와 연결할 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      debugPrint('fetchOrderHistory: Error $e');
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('주문 내역 조회 오류: 네트워크를 확인해주세요.')),
        );
      }
    }
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('장바구니가 비어 있습니다.')),
        );
      }
      return;
    }

    if (_userInfo?['MEK_TR_CD'] == null) {
      debugPrint('Error: trCd missing in userInfo');
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('사용자 정보가 없습니다. 다시 로그인해주세요.')),
        );
      }
      return;
    }

    final effectiveTrCd = _selectedTradeCode ?? _userInfo!['trCd'];
    if (_userInfo!['MEK_TR_CD'] == 'MEK' && _selectedTradeCode == null) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('거래처를 선택해주세요.')),
        );
      }
      return;
    }

    // Validate cart items
    final validCart = _cart.where((item) {
      final isValid = item.containsKey('ERPCODE') &&
          item['quantity'] != null &&
          item['quantity'] > 0 &&
          item['unitPrice'] != null;
      if (!isValid) {
        debugPrint('Invalid cart item skipped: $item');
      }
      return isValid;
    }).toList();

    if (validCart.isEmpty) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('유효한 주문 항목이 없습니다. 품번과 수량이 올바른 항목을 추가해주세요.')),
        );
      }
      return;
    }

    final url = Uri.parse('${AppConfig.apiBaseUrl}/product-order');
    final orderData = {
      'SO_NB': 'SO_${DateTime.now().millisecondsSinceEpoch}',
      'SO_NB_SEQ': 1,
      'TR_CD': effectiveTrCd,
      'EXP_DT': DateTime.parse('$_deliveryDate 00:00:00Z').toIso8601String(),
      'SO_DT': DateTime.now().toIso8601String(),
      'EXCH_CD': 'KRW',
      'MEK_DELIVER_PLACE': 'Default',
      'MEK_STATUS': _orderType,
      'items': validCart.map((item) {
        return {
          'ITEM_CD': item['ERPCODE'],
          'SO_QT': item['quantity'],
          'SO_UM': item['unitPrice'],
          'SOG_AM': item['quantity'] * item['unitPrice'],
          'REMARK_DC': '',
        };
      }).toList(),
    };

    debugPrint('Submitting order: ${jsonEncode(orderData)}');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${_userToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(orderData),
      );
      debugPrint('submitOrder: Status ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        if (mounted) {
          if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
            const SnackBar(content: Text('주문이 완료되었습니다.')),
          );
          setState(() {
            _cart.clear();
            _selectedItems.clear();
            _selectedCartItems.clear();
          });
        }
      } else {
        String errorMessage = '주문 실패';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          errorMessage = errorData['message'] ?? '서버 오류: ${response.statusCode}';
        } catch (_) {
          errorMessage = '서버 응답 파싱 실패: ${response.statusCode}';
        }
        if (mounted) {
          if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      debugPrint('submitOrder: Error $e');
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('주문 오류: $e')),
        );
      }
    }
  }

  void _addToCart(Map<String, dynamic> item, int quantity) {
    print('=== _addToCart 호출 ===');
    print('전체 아이템 데이터: $item');
    
    // 실제 API 필드명 사용 (UI에서 동일하게 사용되는 필드들)
    String? erpCode = item['ERPCODE'];
    String? itemName = item['품명'];
    String? spec = item['규격'];
    double? unitPrice = item['대리점가_DIAMOND_KRW']?.toDouble();
    
    print('추출된 데이터:');
    print('- ERPCODE: $erpCode');
    print('- 품명: $itemName');
    print('- 규격: $spec');
    print('- 단가: $unitPrice');
    print('현재 장바구니 크기: ${_cart.length}');
    
    if (erpCode == null || itemName == null) {
      print('⚠️ 필수 데이터 누락 - ERPCODE: $erpCode, 품명: $itemName');
      return;
    }
    
    setState(() {
      final existing = _cart.firstWhere(
            (cartItem) => cartItem['ERPCODE'] == erpCode,
        orElse: () => {},
      );
      if (existing.isNotEmpty) {
        print('기존 항목 발견 - 수량 증가: ${existing['quantity']} -> ${existing['quantity'] + quantity}');
        existing['quantity'] += quantity;
      } else {
        print('새 항목 추가');
        _cart.add({
          'ERPCODE': erpCode,
          '품명': itemName,
          '규격': spec ?? 'N/A',
          'unitPrice': unitPrice ?? 0.0,
          'quantity': quantity,
        });
      }
      print('업데이트 후 장바구니 크기: ${_cart.length}');
      print('장바구니 내용: $_cart');
    });
  }

  void _addToCartDirectly(Map<String, dynamic> item) {
    _addToCart(item, 1);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item['품명']}이(가) 장바구니에 추가되었습니다.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showQuantityDialog(Map<String, dynamic> item) {
    TextEditingController quantityController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['품명'] ?? '품명 없음'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('품번: ${item['ERPCODE'] ?? 'N/A'}'),
            Text('규격: ${item['규격'] ?? 'N/A'}'),
            Text('단가: ${NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(item['대리점가_DIAMOND_KRW'] ?? 0)}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '수량',
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
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0) {
                _addToCart(item, quantity);
                Navigator.pop(context);
                if (mounted) {
                  if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
                    SnackBar(
                      content: Text('${item['품명']} $quantity개가 장바구니에 추가되었습니다.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
                    const SnackBar(content: Text('수량을 올바르게 입력해주세요.')),
                  );
                }
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite(String itemCode) {
    print('=== _toggleFavorite 호출 ===');
    print('아이템 코드: $itemCode');
    
    if (itemCode.isEmpty || itemCode == 'N/A') {
      print('⚠️ 유효하지 않은 아이템 코드: $itemCode');
      return;
    }
    
    if (!mounted) return;
    final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
    print('토글 전 즐겨찾기 상태: ${favoritesProvider.isItemFavorite(itemCode)}');
    favoritesProvider.toggleItemFavorite(itemCode);
    print('토글 후 즐겨찾기 상태: ${favoritesProvider.isItemFavorite(itemCode)}');
    // setState 제거 - FavoritesProvider가 notifyListeners() 자동 호출
  }

  void _toggleTradeFavorite(String tradeCode) {
    if (_favoriteTradeCodes.contains(tradeCode)) {
      _favoriteTradeCodes.remove(tradeCode);
      _tradeFavoritesBox.delete(tradeCode);
    } else {
      _favoriteTradeCodes.add(tradeCode);
      _tradeFavoritesBox.put(tradeCode, true);
    }
    setState(() {});
  }

  List<Map<String, dynamic>> _getFilteredTrades() {
    var filteredTrades = _trades.where((trade) {
      final tradeName = trade['TR_NM']?.toString().toLowerCase() ?? '';
      final tradeCode = trade['TR_CD']?.toString().toLowerCase() ?? '';
      final searchQuery = _tradeSearchController.text.toLowerCase();
      
      // 검색 필터
      final matchesSearch = searchQuery.isEmpty || 
                          tradeName.contains(searchQuery) || 
                          tradeCode.contains(searchQuery);
      
      // 즐겨찾기 필터 (메모리 캐시 사용)
      final matchesFavorite = !_showOnlyFavoriteTrades || 
                            _favoriteTradeCodes.contains(trade['TR_CD']);
      
      return matchesSearch && matchesFavorite;
    }).toList();
    
    return filteredTrades;
  }

  void _toggleMultiSelect(String itemCode) {
    setState(() {
      if (_selectedItems.contains(itemCode)) {
        _selectedItems.remove(itemCode);
      } else {
        _selectedItems.add(itemCode);
      }
    });
  }

  void _addSelectedToCart() {
    setState(() {
      for (var itemCode in _selectedItems) {
        final item = _items.firstWhere((i) => i['ERPCODE'] == itemCode);
        final existing = _cart.firstWhere(
              (cartItem) => cartItem['ERPCODE'] == itemCode,
          orElse: () => {},
        );
        if (existing.isNotEmpty) {
          existing['quantity'] += 1;
        } else {
          _cart.add({
            'ERPCODE': item['ERPCODE'],
            '품명': item['품명'] ?? '품명 없음',
            '규격': item['규격'] ?? 'N/A',
            'unitPrice': item['대리점가_DIAMOND_KRW'] ?? 0.0,
            'quantity': 1,
          });
        }
      }
      _selectedItems.clear();
    });
  }

  void _showCartDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('장바구니'),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedCartItems.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              // 선택된 아이템들을 역순으로 삭제 (인덱스 변화 방지)
                              final sortedIndices = _selectedCartItems.toList()..sort((a, b) => b.compareTo(a));
                              for (final index in sortedIndices) {
                                _cart.removeAt(index);
                              }
                              _selectedCartItems.clear();
                            });
                            setState(() {});
                            // 모든 항목이 삭제되어 장바구니가 비었으면 모달 닫기
                            if (_cart.isEmpty) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text('선택삭제 (${_selectedCartItems.length})'),
                        ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 출고요청일 선택
                    Row(
                      children: [
                        const Text('출고요청일: '),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'YYYY-MM-DD',
                            ),
                            initialValue: _deliveryDate,
                            onChanged: (value) {
                              _deliveryDate = value;
                            },
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  _deliveryDate = picked.toIso8601String().split('T')[0];
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 주문/펀넬 구분
                    Row(
                      children: [
                        const Text('구분: '),
                        Radio<String>(
                          value: 'ORDER',
                          groupValue: _orderType,
                          onChanged: (value) {
                            setDialogState(() {
                              _orderType = value!;
                            });
                          },
                        ),
                        const Text('주문'),
                        Radio<String>(
                          value: 'FUNNEL',
                          groupValue: _orderType,
                          onChanged: (value) {
                            setDialogState(() {
                              _orderType = value!;
                            });
                          },
                        ),
                        const Text('펀넬'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 전체 선택 체크박스
                    if (_cart.isNotEmpty)
                      Row(
                        children: [
                          Checkbox(
                            value: _selectedCartItems.length == _cart.length && _cart.isNotEmpty,
                            tristate: true,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true || (_selectedCartItems.isNotEmpty && _selectedCartItems.length != _cart.length)) {
                                  // 전체 선택
                                  _selectedCartItems = Set<int>.from(List.generate(_cart.length, (index) => index));
                                } else {
                                  // 전체 해제
                                  _selectedCartItems.clear();
                                }
                              });
                            },
                          ),
                          const Text('전체 선택'),
                          const Spacer(),
                          if (_selectedCartItems.isNotEmpty)
                            Text('${_selectedCartItems.length}개 선택됨', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    // 장바구니 내역
                    Expanded(
                      child: _cart.isEmpty
                          ? const Center(child: Text('장바구니가 비어 있습니다.'))
                          : ListView.builder(
                              itemCount: _cart.length,
                              itemBuilder: (context, index) {
                                final item = _cart[index];
                                final isSelected = _selectedCartItems.contains(index);
                                return Card(
                                  child: ListTile(
                                    leading: Checkbox(
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        setDialogState(() {
                                          if (value == true) {
                                            _selectedCartItems.add(index);
                                          } else {
                                            _selectedCartItems.remove(index);
                                          }
                                        });
                                      },
                                    ),
                                    title: Text(item['품명']),
                                    subtitle: Text('품번: ${item['ERPCODE']} | 규격: ${item['규격']}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          onPressed: () {
                                            final originalLength = _cart.length;
                                            setDialogState(() {
                                              if (item['quantity'] > 1) {
                                                item['quantity']--;
                                              } else {
                                                _cart.removeAt(index);
                                                _selectedCartItems.remove(index);
                                                // 인덱스 재정렬
                                                _selectedCartItems = _selectedCartItems.where((i) => i < index).toSet()
                                                  ..addAll(_selectedCartItems.where((i) => i > index).map((i) => i - 1));
                                              }
                                            });
                                            setState(() {});
                                            // 1개였는데 삭제되어 0개가 되면 모달 닫기
                                            if (originalLength == 1 && _cart.isEmpty) {
                                              Navigator.of(context).pop();
                                            }
                                          },
                                        ),
                                        Text('${item['quantity']}'),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: () {
                                            setDialogState(() {
                                              item['quantity']++;
                                            });
                                            setState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () {
                                            final originalLength = _cart.length;
                                            setDialogState(() {
                                              _cart.removeAt(index);
                                              _selectedCartItems.remove(index);
                                              // 인덱스 재정렬
                                              _selectedCartItems = _selectedCartItems.where((i) => i < index).toSet()
                                                ..addAll(_selectedCartItems.where((i) => i > index).map((i) => i - 1));
                                            });
                                            setState(() {});
                                            // 1개였는데 삭제되어 0개가 되면 모달 닫기
                                            if (originalLength == 1 && _cart.isEmpty) {
                                              Navigator.of(context).pop();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    // 총액
                    Text(
                      '총액: ${NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(
                        _cart.fold(0.0, (sum, item) => sum + item['quantity'] * item['unitPrice']),
                      )}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _cart.clear();
                      _selectedCartItems.clear();
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('비우기'),
                ),
                TextButton(
                  onPressed: () async {
                    await _previewOrderDocument();
                  },
                  child: const Text('인쇄미리보기'),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'pdf') {
                      await _exportToPDF();
                    } else if (value == 'excel') {
                      await _exportToExcel();
                    } else if (value == 'quote') {
                      await _generateQuote();
                    } else if (value == 'proforma_invoice') {
                      await _generateProformaInvoice();
                    } else if (value == 'commercial_invoice') {
                      await _generateCommercialInvoice();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, color: Colors.red),
                          SizedBox(width: 8),
                          Text('PDF 출력'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'excel',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Excel 출력'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'quote',
                      child: Row(
                        children: [
                          Icon(Icons.description, color: Colors.purple),
                          SizedBox(width: 8),
                          Text('견적서 생성'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'proforma_invoice',
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Proforma Invoice'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'commercial_invoice',
                      child: Row(
                        children: [
                          Icon(Icons.business_center, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text('Commercial Invoice'),
                        ],
                      ),
                    ),
                  ],
                  child: const Text('출력'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _submitOrder();
                  },
                  child: const Text('주문 제출'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _previewOrderDocument() async {
    if (_cart.isEmpty) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('장바구니가 비어 있습니다.')),
        );
      }
      return;
    }

    if (!mounted || _authProvider == null) return;
    final effectiveTrCd = _selectedTradeCode ?? _authProvider!.userInfo!['trCd'];
    final tradeName = _trades.isNotEmpty 
        ? _trades.firstWhere((t) => t['TR_CD'] == effectiveTrCd, orElse: () => {'TR_NM': '미지정'})['TR_NM']
        : '미지정';

    try {
      final pdfData = await OrderReportGenerator.generatePDF(
        orderNumber: 'SO_${DateTime.now().millisecondsSinceEpoch}',
        customerName: tradeName,
        customerCode: effectiveTrCd,
        deliveryDate: _deliveryDate,
        orderType: _orderType == 'ORDER' ? '주문' : '펀넬',
        items: _cart,
      );

      await OrderReportGenerator.previewPDF(pdfData);
    } catch (e) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('미리보기 오류: $e')),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    if (_cart.isEmpty) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('장바구니가 비어 있습니다.')),
        );
      }
      return;
    }

    if (!mounted || _authProvider == null) return;
    final effectiveTrCd = _selectedTradeCode ?? _authProvider!.userInfo!['trCd'];
    final tradeName = _trades.isNotEmpty 
        ? _trades.firstWhere((t) => t['TR_CD'] == effectiveTrCd, orElse: () => {'TR_NM': '미지정'})['TR_NM']
        : '미지정';

    try {
      final orderNumber = 'SO_${DateTime.now().millisecondsSinceEpoch}';
      final pdfData = await OrderReportGenerator.generatePDF(
        orderNumber: orderNumber,
        customerName: tradeName,
        customerCode: effectiveTrCd,
        deliveryDate: _deliveryDate,
        orderType: _orderType == 'ORDER' ? '주문' : '펀넬',
        items: _cart,
      );

      await OrderReportGenerator.sharePDF(
        pdfData, 
        '주문서_${orderNumber}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );

      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('PDF 주문서가 생성되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('PDF 생성 오류: $e')),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_cart.isEmpty) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('장바구니가 비어 있습니다.')),
        );
      }
      return;
    }

    if (!mounted || _authProvider == null) return;
    final effectiveTrCd = _selectedTradeCode ?? _authProvider!.userInfo!['trCd'];
    final tradeName = _trades.isNotEmpty 
        ? _trades.firstWhere((t) => t['TR_CD'] == effectiveTrCd, orElse: () => {'TR_NM': '미지정'})['TR_NM']
        : '미지정';

    try {
      final filePath = await OrderReportGenerator.generateExcel(
        orderNumber: 'SO_${DateTime.now().millisecondsSinceEpoch}',
        customerName: tradeName,
        customerCode: effectiveTrCd,
        deliveryDate: _deliveryDate,
        orderType: _orderType == 'ORDER' ? '주문' : '펀넬',
        items: _cart,
      );

      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('Excel 주문서가 생성되었습니다: $filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('Excel 생성 오류: $e')),
        );
      }
    }
  }

  Future<void> _generateQuote() async {
    if (_cart.isEmpty) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('장바구니가 비어 있습니다.')),
        );
      }
      return;
    }

    String? selectedFormat = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('견적서 형식 선택'),
          content: const Text('어떤 형식의 견적서를 생성하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop('pdf'),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              label: const Text('PDF'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop('excel'),
              icon: const Icon(Icons.table_chart, color: Colors.green),
              label: const Text('Excel'),
            ),
          ],
        );
      },
    );

    if (selectedFormat == null) return;

    if (!mounted || _authProvider == null) return;
    final effectiveTrCd = _selectedTradeCode ?? _authProvider!.userInfo!['trCd'];
    final tradeName = _trades.isNotEmpty 
        ? _trades.firstWhere((t) => t['TR_CD'] == effectiveTrCd, orElse: () => {'TR_NM': '미지정'})['TR_NM']
        : '미지정';

    try {
      final quoteNumber = 'QT_${DateTime.now().millisecondsSinceEpoch}';
      final validDate = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));

      if (selectedFormat == 'pdf') {
        final pdfData = await OrderReportGenerator.generateQuotePDF(
          quoteNumber: quoteNumber,
          customerName: tradeName,
          customerCode: effectiveTrCd,
          validDate: validDate,
          quoteType: _orderType == 'ORDER' ? '정식견적' : '간이견적',
          items: _cart,
        );

        await OrderReportGenerator.previewPDF(pdfData);

        if (mounted) {
          if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
            const SnackBar(content: Text('PDF 견적서가 생성되었습니다.')),
          );
        }
      } else if (selectedFormat == 'excel') {
        final filePath = await OrderReportGenerator.generateQuoteExcel(
          quoteNumber: quoteNumber,
          customerName: tradeName,
          customerCode: effectiveTrCd,
          validDate: validDate,
          quoteType: _orderType == 'ORDER' ? '정식견적' : '간이견적',
          items: _cart,
        );

        if (mounted) {
          if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
            SnackBar(content: Text('Excel 견적서가 생성되었습니다: $filePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('견적서 생성 오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ProductOrderScreen build 호출 - 초기화됨: $_isInitialized, 에러: $_errorMessage');
    
    // 초기화가 완료되지 않은 경우 로딩 화면 표시
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('주문실행'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('데이터를 불러오는 중...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // 에러가 발생한 경우 에러 화면 표시
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('주문실행'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isInitialized = false;
                  });
                  _initializeAsync();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final isHeadOffice = _userInfo?['MEK_TR_CD'] == 'MEK';
    final uniqueCategoryA = _items.map((e) => e['품목_대분류']?.toString() ?? '').toSet().toList();
    final uniqueCategoryB = _items
        .where((e) => _selectedCategoryA.isEmpty || e['품목_대분류'].toUpperCase() == _selectedCategoryA.toUpperCase())
        .map((e) => e['품목_중분류']?.toString() ?? '')
        .toSet()
        .toList();
    final uniqueCategoryC = _items
        .where((e) =>
    (_selectedCategoryA.isEmpty || e['품목_대분류'].toUpperCase() == _selectedCategoryA.toUpperCase()) &&
        (_selectedCategoryB.isEmpty || e['품목_중분류'].toUpperCase() == _selectedCategoryB.toUpperCase()))
        .map((e) => e['품목_소분류']?.toString() ?? '')
        .toSet()
        .toList();
    final uniqueLocations = _items.map((e) => e['품목_국내외구분']?.toString() ?? '').toSet().toList();
    final uniqueOptions = _items.map((e) => e['옵션분류']?.toString() ?? '').toSet().toList();

    debugPrint('build: uniqueCategoryA: $uniqueCategoryA');
    debugPrint('build: cart length: ${_cart.length}');
    debugPrint('build: cart contents: $_cart');

    return Scaffold(
      appBar: AppBar(
        title: const Text('주문실행'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  _showCartDialog();
                },
              ),
              if (_cart.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${_cart.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (isHeadOffice) ...[
            // 거래처 검색 및 필터 바
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tradeSearchController,
                      decoration: const InputDecoration(
                        labelText: '거래처 검색',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _showOnlyFavoriteTrades ? Colors.orange : Colors.white,
                      border: Border.all(color: _showOnlyFavoriteTrades ? Colors.orange : Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.star,
                        color: _showOnlyFavoriteTrades ? Colors.white : Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _showOnlyFavoriteTrades = !_showOnlyFavoriteTrades;
                        });
                      },
                      tooltip: '즐겨찾기만 보기',
                    ),
                  ),
                ],
              ),
            ),
            // 거래처 드롭다운
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _isTradeLoading
                  ? Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text(
                            '거래처 정보를 불러오는 중...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          key: UniqueKey(), // 리스트를 닫기 위해 필요
                          iconColor: Colors.blue, // 화살표 아이콘 색상 설정
                          collapsedIconColor: Colors.blue, // 접힌 상태 아이콘 색상
                          textColor: Colors.black, // 텍스트 색상
                          collapsedTextColor: Colors.black, // 접힌 상태 텍스트 색상
                          backgroundColor: Colors.white, // 펼쳐진 상태 배경색
                          collapsedBackgroundColor: Colors.grey[50], // 접힌 상태 배경색
                          title: Text(
                            _selectedTradeCode == null 
                                ? '거래처 선택 (총 ${_trades.length}개 - 클릭하여 펼치기)' 
                                : _trades.isNotEmpty 
                                    ? '${_trades.firstWhere((t) => t['TR_CD'] == _selectedTradeCode, orElse: () => {'TR_NM': '선택된 거래처', 'TR_CD': _selectedTradeCode})['TR_NM']} ($_selectedTradeCode)'
                                    : '거래처 선택 (총 ${_trades.length}개 - 클릭하여 펼치기)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          children: [
                            Container(
                              constraints: const BoxConstraints(
                                maxHeight: 300, // 최대 높이 제한
                              ),
                              child: Scrollbar(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: _getFilteredTrades().map((trade) {
                                      final isFavorite = _favoriteTradeCodes.contains(trade['TR_CD']);
                                      return Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: Colors.grey[300]!, width: 0.5),
                                          ),
                                        ),
                                        child: ListTile(
                                          leading: IconButton(
                                            icon: Icon(
                                              isFavorite ? Icons.star : Icons.star_border,
                                              color: isFavorite ? Colors.orange : Colors.grey,
                                            ),
                                            onPressed: () => _toggleTradeFavorite(trade['TR_CD']),
                                          ),
                                          title: Text(
                                            '${trade['TR_NM']}',
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          subtitle: Text(
                                            '${trade['TR_CD']}',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _selectedTradeCode = trade['TR_CD'];
                                              // ExpansionTile을 닫기 위해 새로운 key 생성
                                            });
                                            // 거래처 선택 완료 메시지
                                            if (mounted) {
                                              if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
                                                SnackBar(
                                                  content: Text('${trade['TR_NM']} 거래처가 선택되었습니다.'),
                                                  duration: const Duration(seconds: 1),
                                                ),
                                              );
                                            }
                                          },
                                          selected: _selectedTradeCode == trade['TR_CD'],
                                          selectedTileColor: Colors.blue.withOpacity(0.1),
                                          tileColor: Colors.white,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TypeAheadField<Map<String, dynamic>>(
                    suggestionsCallback: (pattern) async {
                      if (_userInfo?['MEK_TR_CD'] == null) {
                        debugPrint('Error: trCd missing in userInfo');
                        return [];
                      }
                      final url = Uri.parse(
                        '${AppConfig.apiBaseUrl}/products?search=${Uri.encodeComponent(pattern.toUpperCase())}&size=10',
                      );
                      try {
                        final response = await http.get(
                          url,
                          headers: {'Authorization': 'Bearer ${_userToken}'},
                        );
                        debugPrint('suggestionsCallback: Status ${response.statusCode} - ${response.body}');
                        if (response.statusCode == 200) {
                          final data = jsonDecode(utf8.decode(response.bodyBytes));
                          return List<Map<String, dynamic>>.from(data['data'] ?? []);
                        }
                        return [];
                      } catch (e) {
                        debugPrint('suggestionsCallback: Error $e');
                        return [];
                      }
                    },
                    itemBuilder: (context, Map<String, dynamic> suggestion) {
                      return ListTile(
                        title: Text(suggestion['품명'] ?? '품명 없음'),
                        subtitle: Text('품번: ${suggestion['ERPCODE'] ?? 'N/A'} | 규격: ${suggestion['규격'] ?? 'N/A'}'),
                      );
                    },
                    onSelected: (Map<String, dynamic> suggestion) {
                      _searchController.text = suggestion['ERPCODE'] ?? '';
                      _fetchItems(reset: true);
                    },
                    builder: (context, controller, focusNode) {
                      return TextField(
                        controller: _searchController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: '품번/품명/규격/분류 검색',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _fetchItems(reset: true);
                  },
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Text('선택 모드: '),
                Radio<bool>(
                  value: false,
                  groupValue: _isMultiSelectMode,
                  onChanged: (value) {
                    setState(() {
                      _isMultiSelectMode = value!;
                      _selectedItems.clear();
                    });
                  },
                ),
                const Text('팝업'),
                Radio<bool>(
                  value: true,
                  groupValue: _isMultiSelectMode,
                  onChanged: (value) {
                    setState(() {
                      _isMultiSelectMode = value!;
                      _selectedItems.clear();
                    });
                  },
                ),
                const Text('다중 선택'),
                if (_isMultiSelectMode && _selectedItems.isNotEmpty) ...[
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _addSelectedToCart,
                    child: const Text('선택 항목 추가'),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        DropdownButton<String>(
                          hint: const Text('대분류'),
                          value: _selectedCategoryA.isEmpty ? null : _selectedCategoryA,
                          items: uniqueCategoryA
                              .where((e) => e.isNotEmpty)
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryA = value ?? '';
                              _selectedCategoryB = '';
                              _selectedCategoryC = '';
                              _page = 1;
                              _items.clear();
                              _hasMore = true;
                            });
                            _fetchItems(reset: true);
                          },
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          hint: const Text('중분류'),
                          value: _selectedCategoryB.isEmpty ? null : _selectedCategoryB,
                          items: uniqueCategoryB
                              .where((e) => e.isNotEmpty)
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryB = value ?? '';
                              _selectedCategoryC = '';
                              _page = 1;
                              _items.clear();
                              _hasMore = true;
                            });
                            _fetchItems(reset: true);
                          },
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          hint: const Text('소분류'),
                          value: _selectedCategoryC.isEmpty ? null : _selectedCategoryC,
                          items: uniqueCategoryC
                              .where((e) => e.isNotEmpty)
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryC = value ?? '';
                              _page = 1;
                              _items.clear();
                              _hasMore = true;
                            });
                            _fetchItems(reset: true);
                          },
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          hint: const Text('국내외'),
                          value: _selectedLocation.isEmpty ? null : _selectedLocation,
                          items: uniqueLocations
                              .where((e) => e.isNotEmpty)
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedLocation = value ?? '';
                              _page = 1;
                              _items.clear();
                              _hasMore = true;
                            });
                            _fetchItems(reset: true);
                          },
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          hint: const Text('옵션분류'),
                          value: _selectedOption.isEmpty ? null : _selectedOption,
                          items: uniqueOptions
                              .where((e) => e.isNotEmpty)
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedOption = value ?? '';
                              _page = 1;
                              _items.clear();
                              _hasMore = true;
                            });
                            _fetchItems(reset: true);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryA = '';
                      _selectedCategoryB = '';
                      _selectedCategoryC = '';
                      _selectedLocation = '';
                      _selectedOption = '';
                      _searchController.clear();
                      _page = 1;
                      _items.clear();
                      _hasMore = true;
                    });
                    _fetchItems(reset: true);
                  },
                  child: const Icon(Icons.clear_all, size: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    debugPrint('_buildMainContent 호출 - initialView: ${widget.initialView}');
    
    switch (widget.initialView) {
      case 'recent':
        return _buildRecentOrders();
      case 'history':
        return _buildOrderHistory();
      default:
        return _buildItemList();
    }
  }

  Widget _buildItemList() {
    final groupedItems = <String, List<dynamic>>{};
    for (var item in _items) {
      final key = '${item['품목_대분류']} > ${item['품목_중분류']}';
      groupedItems.putIfAbsent(key, () => []).add(item);
    }

    return Column(
      children: [
        // 모두 펼치기/접기 버튼
        if (groupedItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '카테고리별 품목 (${groupedItems.length}개 카테고리)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          for (var key in groupedItems.keys) {
                            _expansionStates[key] = true;
                          }
                          _expansionUpdateKey++; // 키를 증가시켜 ExpansionTile 재구성
                        });
                        print('모두 펼치기: 상태 업데이트됨 - $_expansionStates');
                      },
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: const Text('모두 펼치기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          for (var key in groupedItems.keys) {
                            _expansionStates[key] = false;
                          }
                          _expansionUpdateKey++; // 키를 증가시켜 ExpansionTile 재구성
                        });
                        print('모두 접기: 상태 업데이트됨 - $_expansionStates');
                      },
                      icon: const Icon(Icons.expand_less, size: 18),
                      label: const Text('모두 접기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // 품목 리스트
        Expanded(
          child: ListView.builder(
      controller: _scrollController,
      itemCount: groupedItems.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == groupedItems.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final key = groupedItems.keys.elementAt(index);
        final items = groupedItems[key]!;

        // 확장 상태 초기화 (한 번만)
        if (!_expansionStates.containsKey(key)) {
          _expansionStates[key] = true;
        }

        return ExpansionTile(
          key: Key('expansion_${key}_$_expansionUpdateKey'),
          title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: _expansionStates[key] ?? true,
          onExpansionChanged: (bool expanded) {
            setState(() {
              _expansionStates[key] = expanded;
            });
            print('ExpansionTile 상태 변경: $key = $expanded');
          },
          children: items.map((item) {
            final isSelected = _selectedItems.contains(item['ERPCODE']);
            return Consumer<FavoritesProvider>(
              builder: (context, favoritesProvider, child) {
                final isFavorite = favoritesProvider.isItemFavorite(item['ERPCODE']);
                return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: _isMultiSelectMode
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          _toggleMultiSelect(item['ERPCODE']);
                        },
                      )
                    : null,
                title: Text(item['품명'] ?? '품명 없음'),
                subtitle: Text(
                  '품번: ${item['ERPCODE'] ?? 'N/A'}\n규격: ${item['규격'] ?? 'N/A'} | 국내외: ${item['품목_국내외구분'] ?? 'N/A'}\n단가: ${NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(item['대리점가_DIAMOND_KRW'] ?? 0)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: isFavorite ? Colors.orange : Colors.grey,
                      ),
                      onPressed: () => _toggleFavorite(item['ERPCODE']),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () {
                          _addToCartDirectly(item);
                        },
                      ),
                    ),
                  ],
                ),
                onTap: _isMultiSelectMode
                    ? () => _toggleMultiSelect(item['ERPCODE'])
                    : () {
                      // 수량 입력 다이얼로그 표시
                      _showQuantityDialog(item);
                    },
                onLongPress: _isMultiSelectMode
                    ? null
                    : () {
                        setState(() {
                          _isMultiSelectMode = true;
                          _selectedItems.add(item['ERPCODE']);
                        });
                      },
              ),
                );
              },
            );
          }).toList(),
        );
      },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrders() {
    return ListView.builder(
      itemCount: _recentOrders.length,
      itemBuilder: (context, index) {
        final order = _recentOrders[index];
        return ListTile(
          title: Text('품번: ${order['ITEM_CD'] ?? 'N/A'}'),
          subtitle: Text(
            '수량: ${order['SO_QT'] ?? '0'} | 금액: ${NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(order['SOG_AM'] ?? 0)} | 주문일: ${order['SO_DT'] ?? 'N/A'}',
          ),
          onTap: () {
            _searchController.text = order['ITEM_CD'] ?? '';
            _fetchItems(reset: true);
          },
        );
      },
    );
  }

  Widget _buildOrderHistory() {
    return ListView.builder(
      itemCount: _orderHistory.length,
      itemBuilder: (context, index) {
        final order = _orderHistory[index];
        return ExpansionTile(
          title: Text('주문번호: ${order['SO_NB'] ?? 'N/A'}'),
          subtitle: Text('주문일: ${order['SO_DT'] ?? 'N/A'}'),
          children: (order['items'] as List<dynamic>?)?.map((item) {
            return ListTile(
              title: Text('품번: ${item['ITEM_CD'] ?? 'N/A'}'),
              subtitle: Text(
                '수량: ${item['SO_QT'] ?? '0'} | 금액: ${NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(item['SOG_AM'] ?? 0)}',
              ),
              onTap: () {
                _searchController.text = item['ITEM_CD'] ?? '';
                _fetchItems(reset: true);
              },
            );
          }).toList() ??
              [],
        );
      },
    );
  }

  /// Proforma Invoice 생성
  Future<void> _generateProformaInvoice() async {
    if (_cart.isEmpty) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('장바구니가 비어 있습니다.')),
        );
      }
      return;
    }

    try {
      // Invoice 아이템 변환
      InvoiceService.convertCartToInvoiceItems(_cart);

      // Invoice 번호 생성
      InvoiceService.generateInvoiceNumber(isProforma: true);

      // Excel 패키지 제거로 인한 Proforma Invoice 생성 비활성화
      // TODO: Syncfusion으로 교체 예정
      /*
      await InvoiceService.generateProformaInvoice(
        customerName: customerName,
        customerAddress: customerAddress,
        customerContact: customerContact,
        items: invoiceItems,
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(days: 30)),
        remarks: 'This proforma invoice is valid for 30 days.',
      );
      */

      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('Invoice 기능이 임시로 비활성화되었습니다. Syncfusion으로 교체 예정입니다.')),
        );
      }
    } catch (e) {
      debugPrint('Proforma Invoice 생성 오류: $e');
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('Proforma Invoice 생성 오류: $e')),
        );
      }
    }
  }

  /// Commercial Invoice 생성
  Future<void> _generateCommercialInvoice() async {
    if (_cart.isEmpty) {
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          const SnackBar(content: Text('장바구니가 비어 있습니다.')),
        );
      }
      return;
    }

    try {
      // Invoice 아이템 변환
      InvoiceService.convertCartToInvoiceItems(_cart);

      // Invoice 번호 생성
      InvoiceService.generateInvoiceNumber(isProforma: false);

      // Excel 패키지 제거로 인한 Commercial Invoice 생성 비활성화
      // TODO: Syncfusion으로 교체 예정
      /*
      await InvoiceService.generateCommercialInvoice(
        customerName: customerName,
        customerAddress: customerAddress,
        customerContact: customerContact,
        items: invoiceItems,
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        paymentTerms: '30 days net',
        shippingTerms: 'FOB Seoul',
        remarks: 'Payment due within 30 days of invoice date.',
      );
      */

      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('Invoice 기능이 임시로 비활성화되었습니다. Syncfusion으로 교체 예정입니다.')),
        );
      }
    } catch (e) {
      debugPrint('Commercial Invoice 생성 오류: $e');
      if (mounted) {
        if (_scaffoldMessenger != null) {\n          try {\n            _scaffoldMessenger!.showSnackBar(
          SnackBar(content: Text('Commercial Invoice 생성 오류: $e')),
        );
      }
    }
  }
}