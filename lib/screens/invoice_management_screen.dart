import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/invoice_service.dart';
import 'package:intl/intl.dart';

class InvoiceManagementScreen extends StatefulWidget {
  const InvoiceManagementScreen({super.key});

  @override
  State<InvoiceManagementScreen> createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends State<InvoiceManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerContactController = TextEditingController();
  final _remarksController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _shippingTermsController = TextEditingController();
  
  final List<Map<String, dynamic>> _invoiceItems = [];
  DateTime _invoiceDate = DateTime.now();
  DateTime _validUntilDate = DateTime.now().add(const Duration(days: 30));
  String _selectedInvoiceType = 'proforma';

  @override
  void initState() {
    super.initState();
    _addSampleItem();
  }

  void _addSampleItem() {
    _invoiceItems.add({
      'ERPCODE': 'SAMPLE001',
      'itemName': 'Sample Product',
      'specification': 'Standard specification',
      'quantity': 1,
      'unitPrice': 100.0,
    });
  }

  void _addInvoiceItem() {
    showDialog(
      context: context,
      builder: (context) => _ItemAddDialog(
        onItemAdded: (item) {
          setState(() {
            _invoiceItems.add(item);
          });
        },
      ),
    );
  }

  void _removeInvoiceItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
    });
  }

  double get _subtotal {
    return _invoiceItems.fold(0.0, (sum, item) => 
      sum + (item['quantity'] * item['unitPrice']));
  }

  double get _taxAmount {
    return _subtotal * 0.1; // 10% VAT
  }

  double get _total {
    return _subtotal + _taxAmount;
  }

  Future<void> _generateInvoice() async {
    if (_formKey.currentState!.validate()) {
      if (_invoiceItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('no_items_added'))),
        );
        return;
      }

      try {
        final invoiceNumber = InvoiceService.generateInvoiceNumber(
          isProforma: _selectedInvoiceType == 'proforma'
        );

        // Excel 패키지 제거로 인한 Invoice 생성 비활성화
        // TODO: Syncfusion으로 교체 예정
        /*
        if (_selectedInvoiceType == 'proforma') {
          await InvoiceService.generateProformaInvoice(
            customerName: _customerNameController.text,
            customerAddress: _customerAddressController.text,
            customerContact: _customerContactController.text,
            items: _invoiceItems,
            invoiceNumber: invoiceNumber,
            invoiceDate: _invoiceDate,
            validUntil: _validUntilDate,
            remarks: _remarksController.text.isNotEmpty ? _remarksController.text : null,
          );
        } else {
          await InvoiceService.generateCommercialInvoice(
            customerName: _customerNameController.text,
            customerAddress: _customerAddressController.text,
            customerContact: _customerContactController.text,
            items: _invoiceItems,
            invoiceNumber: invoiceNumber,
            invoiceDate: _invoiceDate,
            dueDate: _validUntilDate,
            paymentTerms: _paymentTermsController.text.isNotEmpty ? _paymentTermsController.text : null,
            shippingTerms: _shippingTermsController.text.isNotEmpty ? _shippingTermsController.text : null,
            remarks: _remarksController.text.isNotEmpty ? _remarksController.text : null,
          );
        }
        */

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice 기능이 임시로 비활성화되었습니다. Syncfusion으로 교체 예정입니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice generation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('invoice_management')),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice Type Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.translate('invoice_type'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text(localizations.translate('proforma_invoice')),
                              value: 'proforma',
                              groupValue: _selectedInvoiceType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedInvoiceType = value!;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text(localizations.translate('commercial_invoice')),
                              value: 'commercial',
                              groupValue: _selectedInvoiceType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedInvoiceType = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Customer Information
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.translate('customer_information'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customerNameController,
                        decoration: InputDecoration(
                          labelText: localizations.translate('customer_name'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return localizations.translate('customer_name_required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customerAddressController,
                        decoration: InputDecoration(
                          labelText: localizations.translate('customer_address'),
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return localizations.translate('customer_address_required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customerContactController,
                        decoration: InputDecoration(
                          labelText: localizations.translate('customer_contact'),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return localizations.translate('customer_contact_required');
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Date Information
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.translate('date_information'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _invoiceDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setState(() {
                                    _invoiceDate = date;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: localizations.translate('invoice_date'),
                                  border: const OutlineInputBorder(),
                                ),
                                child: Text(DateFormat('yyyy-MM-dd').format(_invoiceDate)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _validUntilDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                );
                                if (date != null) {
                                  setState(() {
                                    _validUntilDate = date;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: _selectedInvoiceType == 'proforma'
                                    ? localizations.translate('valid_until')
                                    : localizations.translate('due_date'),
                                  border: const OutlineInputBorder(),
                                ),
                                child: Text(DateFormat('yyyy-MM-dd').format(_validUntilDate)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Items List
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            localizations.translate('invoice_items'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: _addInvoiceItem,
                            icon: const Icon(Icons.add),
                            label: Text(localizations.translate('add_item')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_invoiceItems.isNotEmpty) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              DataColumn(label: Text(localizations.translate('item_code'))),
                              DataColumn(label: Text(localizations.translate('item_name'))),
                              DataColumn(label: Text(localizations.translate('quantity'))),
                              DataColumn(label: Text(localizations.translate('unit_price'))),
                              DataColumn(label: Text(localizations.translate('amount'))),
                              DataColumn(label: Text(localizations.translate('action'))),
                            ],
                            rows: _invoiceItems.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final amount = item['quantity'] * item['unitPrice'];
                              return DataRow(cells: [
                                DataCell(Text(item['ERPCODE'] ?? '')),
                                DataCell(Text(item['itemName'] ?? '')),
                                DataCell(Text(item['quantity'].toString())),
                                DataCell(Text('\$${item['unitPrice'].toStringAsFixed(2)}')),
                                DataCell(Text('\$${amount.toStringAsFixed(2)}')),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeInvoiceItem(index),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Totals
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${localizations.translate('subtotal')}: \$${_subtotal.toStringAsFixed(2)}'),
                                Text('${localizations.translate('vat')} (10%): \$${_taxAmount.toStringAsFixed(2)}'),
                                Text(
                                  '${localizations.translate('total')}: \$${_total.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else ...[
                        Center(
                          child: Text(
                            localizations.translate('no_items_added'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Additional Information
              if (_selectedInvoiceType == 'commercial') ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.translate('additional_terms'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _paymentTermsController,
                          decoration: InputDecoration(
                            labelText: localizations.translate('payment_terms'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _shippingTermsController,
                          decoration: InputDecoration(
                            labelText: localizations.translate('shipping_terms'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Remarks
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.translate('remarks'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarksController,
                        decoration: InputDecoration(
                          labelText: localizations.translate('remarks'),
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Generate Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _generateInvoice,
                  icon: const Icon(Icons.file_download),
                  label: Text(
                    localizations.translate('generate_invoice'),
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerContactController.dispose();
    _remarksController.dispose();
    _paymentTermsController.dispose();
    _shippingTermsController.dispose();
    super.dispose();
  }
}

class _ItemAddDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onItemAdded;

  const _ItemAddDialog({required this.onItemAdded});

  @override
  State<_ItemAddDialog> createState() => _ItemAddDialogState();
}

class _ItemAddDialogState extends State<_ItemAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _erpCodeController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _specificationController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController(text: '0.00');

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    
    return AlertDialog(
      title: Text(localizations.translate('add_item')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _erpCodeController,
                decoration: InputDecoration(
                  labelText: localizations.translate('item_code'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizations.translate('item_code_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _itemNameController,
                decoration: InputDecoration(
                  labelText: localizations.translate('item_name'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizations.translate('item_name_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specificationController,
                decoration: InputDecoration(
                  labelText: localizations.translate('specification'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: localizations.translate('quantity'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizations.translate('quantity_required');
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return localizations.translate('quantity_invalid');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitPriceController,
                decoration: InputDecoration(
                  labelText: localizations.translate('unit_price'),
                  border: const OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizations.translate('unit_price_required');
                  }
                  final price = double.tryParse(value);
                  if (price == null || price < 0) {
                    return localizations.translate('unit_price_invalid');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.translate('cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onItemAdded({
                'ERPCODE': _erpCodeController.text,
                'itemName': _itemNameController.text,
                'specification': _specificationController.text,
                'quantity': int.parse(_quantityController.text),
                'unitPrice': double.parse(_unitPriceController.text),
              });
              Navigator.pop(context);
            }
          },
          child: Text(localizations.translate('add')),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _erpCodeController.dispose();
    _itemNameController.dispose();
    _specificationController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }
}