import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class ItemIOProvider extends ChangeNotifier {
  // final String baseUrl = 'http://localhost:8080';  // API 서버 URL (삭제)
  // 상태 변수
  String? _ioType;  // RELEASE, RETURN
  String? _ioPurpose;  // SALES, SALES_RETURN
  String? _selectedItemCode;
  String? _selectedItemName;
  int _quantity = 0;
  DateTime _selectedDate = DateTime.now();
  String? _selectedWarehouseCode;
  String? _selectedWarehouseName;
  String? _selectedEmployeeCode;
  String? _selectedEmployeeName;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  // Getters
  String? get ioType => _ioType;
  String? get ioPurpose => _ioPurpose;
  String? get selectedItemCode => _selectedItemCode;
  String? get selectedItemName => _selectedItemName;
  int get quantity => _quantity;
  DateTime get selectedDate => _selectedDate;
  String? get selectedWarehouseCode => _selectedWarehouseCode;
  String? get selectedWarehouseName => _selectedWarehouseName;
  String? get selectedEmployeeCode => _selectedEmployeeCode;
  String? get selectedEmployeeName => _selectedEmployeeName;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get items => _items;

  // Setters
  void setIOType(String type) {
    _ioType = type;
    notifyListeners();
  }

  void setIOPurpose(String purpose) {
    _ioPurpose = purpose;
    notifyListeners();
  }

  void setSelectedItem(String code, String name) {
    _selectedItemCode = code;
    _selectedItemName = name;
    notifyListeners();
  }

  void setQuantity(int value) {
    _quantity = value;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setSelectedWarehouse(String code, String name) {
    _selectedWarehouseCode = code;
    _selectedWarehouseName = name;
    notifyListeners();
  }

  void setSelectedEmployee(String code, String name) {
    _selectedEmployeeCode = code;
    _selectedEmployeeName = name;
    notifyListeners();
  }

  // API 호출
  Future<void> saveItemIO() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/item-io'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'io_type': _ioType,
          'io_purpose': _ioPurpose,
          'item_code': _selectedItemCode,
          'io_date': _selectedDate.toIso8601String(),
          'cell_id': _selectedWarehouseCode,
          'io_qt': _quantity,
          'tr_cd': _selectedEmployeeCode,
        }),
      );

      if (response.statusCode == 200) {
        // 성공 처리
      } else {
        _error = '저장 중 오류가 발생했습니다.';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 초기화
  void reset() {
    _ioType = null;
    _ioPurpose = null;
    _selectedItemCode = null;
    _selectedItemName = null;
    _quantity = 0;
    _selectedDate = DateTime.now();
    _selectedWarehouseCode = null;
    _selectedWarehouseName = null;
    _selectedEmployeeCode = null;
    _selectedEmployeeName = null;
    _error = null;
    notifyListeners();
  }

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/items'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _items = data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load items');
      }
    } catch (e) {
      print('Error loading items: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveItem(Map<String, dynamic> item) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/items'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(item),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save item');
      }

      await loadItems();  // 목록 새로고침
    } catch (e) {
      print('Error saving item: $e');
      rethrow;
    }
  }
} 