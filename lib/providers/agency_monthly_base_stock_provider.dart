import 'package:flutter/material.dart';

class AgencyMonthlyBaseStockProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _items = [];
  final List<Map<String, dynamic>> _customRows = [];
  String? _year;
  String? _month;
  String? _warehouseId;

  List<Map<String, dynamic>> get warehouses => _warehouses;
  List<Map<String, dynamic>> get items => _items;
  List<Map<String, dynamic>> get customRows => _customRows;
  String? get year => _year;
  String? get month => _month;
  String? get warehouseId => _warehouseId;

  void setWarehouses(List<Map<String, dynamic>> warehouses) {
    _warehouses = warehouses;
    notifyListeners();
  }

  void setItems(List<Map<String, dynamic>> items) {
    _items = items;
    notifyListeners();
  }

  void setYear(String year) {
    _year = year;
    notifyListeners();
  }

  void setMonth(String month) {
    _month = month;
    notifyListeners();
  }

  void setWarehouseId(String warehouseId) {
    _warehouseId = warehouseId;
    notifyListeners();
  }

  void updateItemQuantity(String itemCd, String value) {
    final item = _items.firstWhere(
      (item) => item['itemCd'] == itemCd,
      orElse: () => {'itemCd': itemCd, 'qty': '0'},
    );
    item['qty'] = value;
    notifyListeners();
  }

  void updateItemRemark(String itemCd, String value) {
    final item = _items.firstWhere(
      (item) => item['itemCd'] == itemCd,
      orElse: () => {'itemCd': itemCd, 'remark': ''},
    );
    item['remark'] = value;
    notifyListeners();
  }

  void addCustomRow() {
    _customRows.add({
      'itemCd': '',
      'itemName': '',
      'qty': '0',
      'remark': '',
    });
    notifyListeners();
  }

  void removeCustomRow(int index) {
    if (index >= 0 && index < _customRows.length) {
      _customRows.removeAt(index);
      notifyListeners();
    }
  }
} 