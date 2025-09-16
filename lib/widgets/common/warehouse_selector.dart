import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';

class WarehouseSelector extends StatefulWidget {
  final Function(String code, String name) onSelected;

  const WarehouseSelector({
    super.key,
    required this.onSelected,
  });

  @override
  State<WarehouseSelector> createState() => _WarehouseSelectorState();
}

class _WarehouseSelectorState extends State<WarehouseSelector> {
  List<Map<String, dynamic>> _warehouses = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedWarehouseCode;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/warehouses'),
      );

      if (response.statusCode == 200) {
        final apiService = ApiService();
        final warehouses = await apiService.getHospitalCells(hospitalId: '', trCd: ''); // 실제 파라미터에 맞게 호출
        // warehouses는 이미 방어코드 적용된 List<Map<String, dynamic>>
        setState(() {
          _warehouses = warehouses;
        });
      } else {
        setState(() {
          _error = '창고 목록을 불러오는데 실패했습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).get('warehouse'),
        border: const OutlineInputBorder(),
      ),
      initialValue: _warehouses.isNotEmpty ? _selectedWarehouseCode : null,
      items: _warehouses.isNotEmpty
          ? _warehouses.map((warehouse) => DropdownMenuItem<String>(
              value: warehouse['code'],
              child: Text(AppLocalizations.of(context).get('warehouse_name_code') ?? '${warehouse['name']} (${warehouse['code']})'),
            )).toList()
          : [],
      onChanged: _warehouses.isNotEmpty ? (value) {
        if (value != null) {
          setState(() {
            _selectedWarehouseCode = value;
          });
          final warehouse = _warehouses.firstWhere((w) => w['code'] == value);
          widget.onSelected(warehouse['code'], warehouse['name']);
        }
      } : null,
      hint: _warehouses.isNotEmpty ? null : Text(AppLocalizations.of(context).get('no_warehouse') ?? '선택 가능한 창고 없음'),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '창고를 선택해주세요';
        }
        return null;
      },
    );
  }
} 