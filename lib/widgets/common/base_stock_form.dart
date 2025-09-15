import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class BaseStockForm extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> customRows;
  final List<FocusNode> focusNodes;
  final Function(String, String) onQuantityChanged;
  final Function(String, String) onRemarkChanged;
  final Function(int) onAddCustomRow;
  final Function(int) onRemoveCustomRow;
  final bool isLoading;

  const BaseStockForm({
    super.key,
    required this.title,
    required this.items,
    required this.customRows,
    required this.focusNodes,
    required this.onQuantityChanged,
    required this.onRemarkChanged,
    required this.onAddCustomRow,
    required this.onRemoveCustomRow,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[200],
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(AppLocalizations.of(context).get('item_code') ?? '품목코드'),
              ),
              Expanded(
                flex: 3,
                child: Text(AppLocalizations.of(context).get('item_name') ?? '품목명'),
              ),
              Expanded(
                flex: 2,
                child: Text(AppLocalizations.of(context).get('quantity') ?? '수량'),
              ),
              Expanded(
                flex: 2,
                child: Text(AppLocalizations.of(context).get('remark') ?? '비고'),
              ),
              SizedBox(width: 40),
            ],
          ),
        ),
        
        // 아이템 리스트
        Expanded(
          child: ListView.builder(
            itemCount: items.length + customRows.length,
            itemBuilder: (context, index) {
              final isCustomRow = index >= items.length;
              final item = isCustomRow 
                ? customRows[index - items.length] 
                : items[index];
              
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    // 품목코드
                    Expanded(
                      flex: 2,
                      child: Text(
                        item['itemCd']?.toString() ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    // 품목명
                    Expanded(
                      flex: 3,
                      child: Text(
                        item['itemName']?.toString() ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    // 수량
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        focusNode: focusNodes[index],
                        initialValue: item['qty']?.toString() ?? '0',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) => onQuantityChanged(
                          item['itemCd']?.toString() ?? '',
                          value,
                        ),
                      ),
                    ),
                    // 비고
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: item['remark']?.toString() ?? '',
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) => onRemarkChanged(
                          item['itemCd']?.toString() ?? '',
                          value,
                        ),
                      ),
                    ),
                    // 커스텀 행 삭제 버튼
                    if (isCustomRow)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => onRemoveCustomRow(index - items.length),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // 하단 버튼
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: isLoading ? null : () => onAddCustomRow(items.length),
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context).get('add_row') ?? '행 추가'),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 