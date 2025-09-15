import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class BaseStockHeader extends StatelessWidget {
  final String? year;
  final String? month;
  final String? warehouseId;
  final List<Map<String, dynamic>> warehouses;
  final Function(String) onYearChanged;
  final Function(String) onMonthChanged;
  final Function(String) onWarehouseChanged;
  final VoidCallback onSearch;
  final VoidCallback onLoadItems;
  final VoidCallback onSave;
  final bool isLoading;

  const BaseStockHeader({
    super.key,
    required this.year,
    required this.month,
    required this.warehouseId,
    required this.warehouses,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onWarehouseChanged,
    required this.onSearch,
    required this.onLoadItems,
    required this.onSave,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        // 연도, 월 선택
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 8,
            children: [
              SizedBox(
                width: 80,
                child: DropdownButton<String>(
                  value: year,
                  hint: Text(AppLocalizations.of(context).get('year') ?? '년도'),
                  isExpanded: true,
                  items: List.generate(5, (index) => now.year - 2 + index)
                      .map((year) => DropdownMenuItem(
                            value: year.toString(),
                            child: Text(
                              year.toString(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onYearChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: DropdownButton<String>(
                  value: month,
                  hint: Text(AppLocalizations.of(context).get('month') ?? '월'),
                  isExpanded: true,
                  items: List.generate(12, (index) => (index + 1).toString().padLeft(2, '0'))
                      .map((month) => DropdownMenuItem(
                            value: month,
                            child: Text(
                              month,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onMonthChanged(value);
                  },
                ),
              ),
            ],
          ),
        ),

        // 창고 선택
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: DropdownButton<String>(
            value: warehouseId,
            hint: Text(AppLocalizations.of(context).get('warehouse') ?? '창고'),
            isExpanded: true,
            items: warehouses.map((warehouse) => DropdownMenuItem(
              value: warehouse['cellId']?.toString(),
              child: Text(
                warehouse['cellName']?.toString() ?? '',
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            )).toList(),
            onChanged: (value) {
              if (value != null) onWarehouseChanged(value);
            },
          ),
        ),

        // 버튼들
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 8,
            children: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: isLoading ? null : onSearch,
                tooltip: AppLocalizations.of(context).get('search_warehouse') ?? '창고조회',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.list),
                onPressed: isLoading ? null : onLoadItems,
                tooltip: AppLocalizations.of(context).get('load_items') ?? '소모품 조회',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: isLoading ? null : onSave,
                tooltip: AppLocalizations.of(context).get('save') ?? '저장',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 