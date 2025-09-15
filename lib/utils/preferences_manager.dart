import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class PreferencesManager {
  // 날짜 관련
  static const String _lastSelectedDateKey = 'last_selected_date';
  static const String _lastSelectedRegionKey = 'last_selected_region';
  static const String _lastSelectedCategoryKey = 'last_selected_category';
  static const String _lastSearchQueryKey = 'last_search_query';
  
  // 주문 관련
  static const String _lastOrderTypeKey = 'last_order_type';
  static const String _lastOrderDateKey = 'last_order_date';
  static const String _lastOrderNoteKey = 'last_order_note';
  
  // 장바구니 관련
  static const String _cartItemsKey = 'cart_items';
  
  // 재고 관련
  static const String _lastInventoryDateKey = 'last_inventory_date';
  static const String _lastInventoryRegionKey = 'last_inventory_region';
  static const String _lastInventoryCategoryKey = 'last_inventory_category';

  // 카테고리 관련
  static const String _lastCategoryAKey = 'last_category_a';
  static const String _lastCategoryBKey = 'last_category_b';
  static const String _lastCategoryCKey = 'last_category_c';

  // 지역 관련
  static const String _lastLocationKey = 'last_location';

  // 거래처 관련
  static const String _lastTrCdKey = 'last_tr_cd';
  static const String _lastTradeNameKey = 'last_trade_name';

  // 최근 검색어 관련
  static const String _recentSearchesKey = 'recent_searches';
  
  // 즐겨찾기 병원 관련
  static const String _favoriteHospitalsKey = 'favorite_hospitals';

  // 날짜 범위 저장/복원
  static Future<void> saveDateRange(DateTime startDate, DateTime endDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSelectedDateKey, 
      '${startDate.toIso8601String()},${endDate.toIso8601String()}');
  }

  static Future<DateTimeRange?> getLastDateRange() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastSelectedDateKey);
    if (dateString != null) {
      final dates = dateString.split(',');
      if (dates.length == 2) {
        return DateTimeRange(
          start: DateTime.parse(dates[0]),
          end: DateTime.parse(dates[1]),
        );
      }
    }
    return null;
  }

  // 지역 저장/복원
  static Future<void> saveSelectedRegion(String region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSelectedRegionKey, region);
  }

  static Future<String?> getLastSelectedRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSelectedRegionKey);
  }

  // 카테고리 저장/복원
  static Future<void> saveSelectedCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSelectedCategoryKey, category);
  }

  static Future<String?> getLastSelectedCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSelectedCategoryKey);
  }

  // 검색어 저장/복원
  static Future<void> saveSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSearchQueryKey, query);
  }

  static Future<String?> getLastSearchQuery() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSearchQueryKey);
  }

  // 주문 유형 저장/복원
  static Future<void> saveOrderType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOrderTypeKey, type);
  }

  static Future<String?> getLastOrderType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOrderTypeKey);
  }

  // 주문 날짜 저장/복원
  static Future<void> saveOrderDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOrderDateKey, date.toIso8601String());
  }

  static Future<DateTime?> getLastOrderDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastOrderDateKey);
    return dateString != null ? DateTime.parse(dateString) : null;
  }

  // 주문 비고 저장/복원
  static Future<void> saveOrderNote(String note) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOrderNoteKey, note);
  }

  static Future<String?> getLastOrderNote() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOrderNoteKey);
  }

  // 장바구니 저장/복원
  static Future<void> saveCartItems(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = items
        .map((item) => json.encode(item))
        .toList();
    await prefs.setStringList(_cartItemsKey, itemsJson);
  }

  static Future<List<Map<String, dynamic>>> getCartItems() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getStringList(_cartItemsKey) ?? [];
    return itemsJson
        .map((item) => Map<String, dynamic>.from(json.decode(item)))
        .toList();
  }

  // 재고 관련 저장/복원
  static Future<void> saveInventoryDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastInventoryDateKey, date.toIso8601String());
  }

  static Future<DateTime?> getLastInventoryDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastInventoryDateKey);
    return dateString != null ? DateTime.parse(dateString) : null;
  }

  static Future<void> saveInventoryRegion(String region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastInventoryRegionKey, region);
  }

  static Future<String?> getLastInventoryRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastInventoryRegionKey);
  }

  static Future<void> saveInventoryCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastInventoryCategoryKey, category);
  }

  static Future<String?> getLastInventoryCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastInventoryCategoryKey);
  }

  // 카테고리 A 저장/복원
  static Future<void> saveCategoryA(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCategoryAKey, category);
  }

  static Future<String?> getLastCategoryA() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCategoryAKey);
  }

  // 카테고리 B 저장/복원
  static Future<void> saveCategoryB(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCategoryBKey, category);
  }

  static Future<String?> getLastCategoryB() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCategoryBKey);
  }

  // 카테고리 C 저장/복원
  static Future<void> saveCategoryC(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCategoryCKey, category);
  }

  static Future<String?> getLastCategoryC() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCategoryCKey);
  }

  // 지역 저장/복원
  static Future<void> saveLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastLocationKey, location);
  }

  static Future<String?> getLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastLocationKey);
  }

  // 거래처 코드 저장/복원
  static Future<void> saveTradeCode(String tradeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastTrCdKey, tradeCode);
  }

  static Future<String?> getLastTradeCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastTrCdKey);
  }

  // 거래처명 저장/복원
  static Future<void> saveTradeName(String tradeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastTradeNameKey, tradeName);
  }

  static Future<String?> getLastTradeName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastTradeNameKey);
  }

  // 최근 검색어 저장/복원
  static Future<void> saveRecentSearches(List<String> searches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, searches);
  }

  static Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSearchesKey) ?? [];
  }

  // 즐겨찾기 병원 저장/복원
  static Future<void> saveFavoriteHospitals(List<String> hospitals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteHospitalsKey, hospitals);
  }

  static Future<List<String>> getFavoriteHospitals() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoriteHospitalsKey) ?? [];
  }

  // 범용 메소드들 추가
  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<List<String>?> getStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }

  static Future<void> setStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  // 모든 설정 초기화
  static Future<void> clearAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
} 