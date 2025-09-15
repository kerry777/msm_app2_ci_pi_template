import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HospitalSafetyStockProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _safetyStocks = [];
  String? _selectedHospitalId;
  String? _selectedWarehouseId;
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get hospitals => _hospitals;
  List<Map<String, dynamic>> get warehouses => _warehouses;
  List<Map<String, dynamic>> get safetyStocks => _safetyStocks;
  String? get selectedHospitalId => _selectedHospitalId;
  String? get selectedWarehouseId => _selectedWarehouseId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setHospitals(List<Map<String, dynamic>> hospitals) {
    _hospitals = hospitals;
    notifyListeners();
  }

  void setWarehouses(List<Map<String, dynamic>> warehouses) {
    _warehouses = warehouses;
    notifyListeners();
  }

  void setSafetyStocks(List<Map<String, dynamic>> safetyStocks) {
    _safetyStocks = safetyStocks;
    notifyListeners();
  }

  void setSelectedHospitalId(String? id) {
    _selectedHospitalId = id;
    notifyListeners();
  }

  void setSelectedWarehouseId(String? id) {
    _selectedWarehouseId = id;
    notifyListeners();
  }

  void updateSafetyStockQty(int index, String value) {
    if (index >= 0 && index < _safetyStocks.length) {
      _safetyStocks[index]['safetyQt'] = value;
      notifyListeners();
    }
  }

  void updateSafetyStockRemark(int index, String value) {
    if (index >= 0 && index < _safetyStocks.length) {
      _safetyStocks[index]['remark'] = value;
      notifyListeners();
    }
  }

  Future<void> loadHospitals() async {
    final hospitals = await ApiService().getHospitals();
    setHospitals(hospitals);
  }

  Future<void> loadWarehouses(String hospitalId, String trCd) async {
    final warehouses = await ApiService().getHospitalCells(
      hospitalId: hospitalId,
      trCd: trCd,
    );
    setWarehouses(warehouses);
  }

  Future<void> loadSafetyStocks(String hospitalId, String cellId, String trCd) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final stocks = await ApiService().getHospitalSafeStocks(
        hospitalId: hospitalId, 
        cellId: cellId,
        trCd: trCd,
      );
      setSafetyStocks(stocks);
    } catch (e) {
      _error = '안전재고 목록을 불러오는데 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSafetyStocks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final safeStocks = _safetyStocks.map((stock) => {
        'hospitalId': stock['hospitalId'],
        'cellId': stock['cellId'],
        'itemCd': stock['itemCd'],
        'safeQt': stock['safeQt'],
        'trCd': stock['trCd'],
        'remark': stock['remark'],
      }).toList();
      await ApiService().saveHospitalSafeStocks(safeStocks: safeStocks);
    } catch (e) {
      _error = '안전재고 저장에 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 