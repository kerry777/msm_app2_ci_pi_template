import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider with ChangeNotifier {
  Set<String> _hospitalFavorites = {};
  Set<String> _itemFavorites = {};
  Set<String> _warehouseFavorites = {};

  // Getter
  Set<String> get hospitalFavorites => _hospitalFavorites;
  Set<String> get itemFavorites => _itemFavorites;
  Set<String> get warehouseFavorites => _warehouseFavorites;

  // 초기화 - 앱 시작 시 호출
  Future<void> initialize() async {
    await _loadAllFavorites();
  }

  // 모든 즐겨찾기 로드
  Future<void> _loadAllFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 병원 즐겨찾기
      final hospitalList = prefs.getStringList('hospital_favorites') ?? [];
      _hospitalFavorites = hospitalList.toSet();
      
      // 품목 즐겨찾기
      final itemList = prefs.getStringList('item_favorites') ?? [];
      _itemFavorites = itemList.toSet();
      
      // 창고 즐겨찾기
      final warehouseList = prefs.getStringList('warehouse_favorites') ?? [];
      _warehouseFavorites = warehouseList.toSet();
      
      print('[즐겨찾기] 로드 완료 - 병원: ${_hospitalFavorites.length}개, 품목: ${_itemFavorites.length}개, 창고: ${_warehouseFavorites.length}개');
      notifyListeners();
    } catch (e) {
      print('[즐겨찾기] 로드 실패: $e');
    }
  }

  // 병원 즐겨찾기 토글
  Future<void> toggleHospitalFavorite(String hospitalId) async {
    if (_hospitalFavorites.contains(hospitalId)) {
      _hospitalFavorites.remove(hospitalId);
    } else {
      _hospitalFavorites.add(hospitalId);
    }
    
    await _saveHospitalFavorites();
    notifyListeners();
  }

  // 품목 즐겨찾기 토글
  Future<void> toggleItemFavorite(String itemId) async {
    print('[FavoritesProvider] toggleItemFavorite 호출: $itemId');
    print('[FavoritesProvider] 토글 전 상태: ${_itemFavorites.contains(itemId)}');
    print('[FavoritesProvider] 현재 즐겨찾기 개수: ${_itemFavorites.length}');
    
    if (_itemFavorites.contains(itemId)) {
      _itemFavorites.remove(itemId);
      print('[FavoritesProvider] 즐겨찾기에서 제거: $itemId');
    } else {
      _itemFavorites.add(itemId);
      print('[FavoritesProvider] 즐겨찾기에 추가: $itemId');
    }
    
    print('[FavoritesProvider] 토글 후 개수: ${_itemFavorites.length}');
    await _saveItemFavorites();
    notifyListeners();
    print('[FavoritesProvider] notifyListeners() 호출 완료');
  }

  // 창고 즐겨찾기 토글
  Future<void> toggleWarehouseFavorite(String warehouseId) async {
    if (_warehouseFavorites.contains(warehouseId)) {
      _warehouseFavorites.remove(warehouseId);
    } else {
      _warehouseFavorites.add(warehouseId);
    }
    
    await _saveWarehouseFavorites();
    notifyListeners();
  }

  // 병원 즐겨찾기 저장
  Future<void> _saveHospitalFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('hospital_favorites', _hospitalFavorites.toList());
      print('[즐겨찾기] 병원 즐겨찾기 저장: ${_hospitalFavorites.length}개');
    } catch (e) {
      print('[즐겨찾기] 병원 즐겨찾기 저장 실패: $e');
    }
  }

  // 품목 즐겨찾기 저장
  Future<void> _saveItemFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('item_favorites', _itemFavorites.toList());
      print('[즐겨찾기] 품목 즐겨찾기 저장: ${_itemFavorites.length}개');
    } catch (e) {
      print('[즐겨찾기] 품목 즐겨찾기 저장 실패: $e');
    }
  }

  // 창고 즐겨찾기 저장
  Future<void> _saveWarehouseFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('warehouse_favorites', _warehouseFavorites.toList());
      print('[즐겨찾기] 창고 즐겨찾기 저장: ${_warehouseFavorites.length}개');
    } catch (e) {
      print('[즐겨찾기] 창고 즐겨찾기 저장 실패: $e');
    }
  }

  // 즐겨찾기 확인 메서드들
  bool isHospitalFavorite(String hospitalId) => _hospitalFavorites.contains(hospitalId);
  bool isItemFavorite(String itemId) => _itemFavorites.contains(itemId);
  bool isWarehouseFavorite(String warehouseId) => _warehouseFavorites.contains(warehouseId);

  // 모든 즐겨찾기 초기화 (로그아웃 시 사용)
  Future<void> clearAllFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('hospital_favorites');
      await prefs.remove('item_favorites');
      await prefs.remove('warehouse_favorites');
      
      _hospitalFavorites.clear();
      _itemFavorites.clear();
      _warehouseFavorites.clear();
      
      print('[즐겨찾기] 모든 즐겨찾기 초기화 완료');
      notifyListeners();
    } catch (e) {
      print('[즐겨찾기] 즐겨찾기 초기화 실패: $e');
    }
  }
} 