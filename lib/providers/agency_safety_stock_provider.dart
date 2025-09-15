import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AgencySafetyStockProvider with ChangeNotifier {
  String? _warehouseId;
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _safetyStocks = [];
  bool _isLoading = false;
  String? _error;

  String? get warehouseId => _warehouseId;
  List<Map<String, dynamic>> get warehouses => _warehouses;
  List<Map<String, dynamic>> get safetyStocks => _safetyStocks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setWarehouseId(String value) {
    _warehouseId = value;
    notifyListeners();
  }

  void setWarehouses(List<Map<String, dynamic>> warehouses) {
    _warehouses = warehouses;
    notifyListeners();
  }

  Future<void> loadWarehouses(String trCd) async {
    print('[안전재고] 창고 목록 로드 시작: trCd=$trCd');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final warehouses = await ApiService().getAgencyCells(trCd: trCd);
      print('[안전재고] 창고 목록 로드 성공: ${warehouses.length}개');
      _warehouses = warehouses;
    } catch (e) {
      print('[안전재고] 창고 목록 로드 실패: $e');
      _error = '창고 목록을 불러오는데 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSafetyStocks(String trCd) async {
    if (_warehouseId == null) {
      print('[안전재고] 창고가 선택되지 않음');
      return;
    }

    print('[안전재고] 안전재고 목록 로드 시작: trCd=$trCd, warehouseId=$_warehouseId');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final safetyStocks = await ApiService().getAgencySafeStocks(
        trCd: trCd,
        cellId: _warehouseId!,
      );
      print('[안전재고] 안전재고 목록 로드 성공: ${safetyStocks.length}개');
      if (safetyStocks.isEmpty) {
        print('[안전재고] 데이터가 없어 빈 목록으로 초기화');
        _safetyStocks = [];
      } else {
        _safetyStocks = safetyStocks;
      }
    } catch (e) {
      print('[안전재고] 안전재고 목록 로드 실패: $e');
      _error = '안전재고 목록을 불러오는데 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSafetyStocks(String trCd, List<Map<String, dynamic>> safetyStocks) async {
    if (_warehouseId == null) {
      print('[안전재고] 필수 파라미터 누락: warehouseId');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('[안전재고] 저장 시작: trCd=$trCd, warehouseId=$_warehouseId');
      final saveData = safetyStocks.map((stock) {
        return {
          'itemCd': stock['itemCd'],
          'safetyQt': int.tryParse(stock['safetyQt']?.toString() ?? '0') ?? 0,
          'cellId': _warehouseId,
          'remark': stock['remark'] ?? '',
        };
      }).toList();
      print('[안전재고] 저장할 데이터: $saveData');
      
      await ApiService().saveAgencySafetyStocks(
        safeStocks: saveData,
      );
      print('[안전재고] 저장 완료');
      
      // 저장 후 목록 새로고침
      await loadSafetyStocks(trCd);
    } catch (e) {
      print('[안전재고] 저장 실패: $e');
      _error = '안전재고 저장에 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateSafetyStock(int index, String value) {
    if (index >= 0 && index < _safetyStocks.length) {
      _safetyStocks[index]['safetyQt'] = value;
      notifyListeners();
    }
  }

  void updateRemark(int index, String value) {
    if (index >= 0 && index < _safetyStocks.length) {
      _safetyStocks[index]['remark'] = value;
      notifyListeners();
    }
  }
} 