import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'dart:convert';

class AgencyMonthlyBaseStockEditProvider with ChangeNotifier {
  String? _trCd;
  String? _warehouseId;
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _baseStocks = [];
  bool _isLoading = false;
  String? _error;
  String? _year;
  String? _month;

  String? get trCd => _trCd;
  String? get warehouseId => _warehouseId;
  List<Map<String, dynamic>> get warehouses => _warehouses;
  List<Map<String, dynamic>> get baseStocks => _baseStocks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get year => _year;
  String? get month => _month;

  void setTrCd(String value) {
    _trCd = value;
    notifyListeners();
  }

  void setYear(String value) {
    _year = value;
    notifyListeners();
  }

  void setMonth(String value) {
    _month = value;
    notifyListeners();
  }

  void setWarehouseId(String value) {
    if (_warehouseId != value) {
      _warehouseId = value;
      notifyListeners();
      // 창고가 변경되면 자동으로 기초재고 조회
      if (_year != null && _month != null && _trCd != null) {
        loadBaseStocks(_trCd!);
      }
    }
  }

  void setWarehouses(List<Map<String, dynamic>> warehouses) {
    _warehouses = warehouses;
    notifyListeners();
  }

  void setBaseStocks(List<Map<String, dynamic>> baseStocks) {
    _baseStocks = baseStocks;
    notifyListeners();
  }

  Future<void> loadWarehouses(String trCd) async {
    print('loadWarehouses 시작: trCd=$trCd');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final warehouses = await ApiService().getAgencyCells(trCd: trCd);
      print('창고 목록 로드 성공: ${warehouses.length}개');
      print('창고 목록: $warehouses');
      
      if (warehouses.isEmpty) {
        print('창고 목록이 비어있음');
        _warehouses = [];
      } else {
        _warehouses = warehouses;
        // 첫 번째 창고를 기본값으로 설정
        if (_warehouseId == null && warehouses.isNotEmpty) {
          _warehouseId = warehouses[0]['cellId']?.toString();
          print('기본 창고 설정: $_warehouseId');
        }
      }
    } catch (e) {
      print('창고 목록 로드 실패: $e');
      _error = '창고 목록을 불러오는데 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBaseStocks(String trCd) async {
    print('loadBaseStocks 시작: trCd=$trCd, warehouseId=$_warehouseId, year=$_year, month=$_month');
    if (_warehouseId == null || _year == null || _month == null) {
      print('필수 파라미터 누락');
      return;
    }

    // 조회 시작 시 기존 데이터 초기화
    _baseStocks = [];
    notifyListeners();

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final baseStocks = await ApiService().getAgencyBaseStocks(
        trCd: trCd,
        year: _year!.toString(),
        month: _month!.toString(),
        cellId: _warehouseId!,
      );
      print('기초재고 목록 로드 성공: [38;5;2m${baseStocks.length}[0m개');
      print('기초재고 데이터: $baseStocks');
      if (baseStocks.isEmpty) {
        print('기초재고 데이터가 없어 빈 목록으로 초기화');
        _baseStocks = [];
      } else {
        _baseStocks = baseStocks.map((stock) {
          // stockHistory가 문자열로 오는 경우 처리
          if (stock['stockHistory'] is String) {
            try {
              stock['stockHistory'] = jsonDecode(stock['stockHistory']);
            } catch (e) {
              print('stockHistory 파싱 실패: $e');
              stock['stockHistory'] = [];
            }
          }
          return stock;
        }).toList();
      }
    } catch (e) {
      print('기초재고 목록 로드 실패: $e');
      _error = '기초재고 목록을 불러오는데 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveBaseStocks(String trCd, List<Map<String, dynamic>> baseStocks) async {
    if (_warehouseId == null || _year == null || _month == null) {
      print('필수 파라미터 누락');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('기초재고 저장 시작: trCd=$trCd, warehouseId=$_warehouseId, year=$_year, month=$_month');
      // body 전체를 배열로, 각 원소에 itemCd, year, month, baseQt, cellId, remark만 포함
      final saveData = baseStocks.map((stock) {
        return {
          'itemCd': stock['itemCd'],
          'year': _year!.toString(),
          'month': _month!.toString(),
          'baseQt': int.tryParse(stock['baseQt']?.toString() ?? '0') ?? 0,
          'cellId': _warehouseId,
          'remark': stock['remark'] ?? '',
        };
      }).toList();
      print('저장할 데이터(배열): $saveData');
      await ApiService().saveAgencyBaseStocks(
        baseStocks: saveData,
      );
      print('기초재고 저장 완료');
      // 저장 후 목록 새로고침
      await loadBaseStocks(trCd);
    } catch (e) {
      print('기초재고 저장 실패: $e');
      _error = '기초재고 저장에 실패했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateBaseStock(int index, String value) {
    if (index >= 0 && index < _baseStocks.length) {
      _baseStocks[index]['baseQt'] = value;
      notifyListeners();
    }
  }

  void updateRemark(int index, String value) {
    if (index >= 0 && index < _baseStocks.length) {
      _baseStocks[index]['remark'] = value;
      notifyListeners();
    }
  }
} 