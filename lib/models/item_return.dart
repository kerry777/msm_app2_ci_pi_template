class ItemReturn {
  final int id;
  final String itemCode;
  final String itemName;
  final int quantity;
  final String returnType; // 'EXPORT' or 'RETURN'
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final String? reason;
  final String warehouseCode;
  final String warehouseName;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? approvedAt;
  final String? approvedBy;

  ItemReturn({
    required this.id,
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    required this.returnType,
    required this.status,
    this.reason,
    required this.warehouseCode,
    required this.warehouseName,
    required this.createdAt,
    required this.createdBy,
    this.approvedAt,
    this.approvedBy,
  });

  factory ItemReturn.fromJson(Map<String, dynamic> json) {
    return ItemReturn(
      id: json['id'] as int,
      itemCode: json['itemCode'] as String,
      itemName: json['itemName'] as String,
      quantity: json['quantity'] as int,
      returnType: json['returnType'] as String,
      status: json['status'] as String,
      reason: json['reason'] as String?,
      warehouseCode: json['warehouseCode'] as String,
      warehouseName: json['warehouseName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String,
      approvedAt: json['approvedAt'] != null ? DateTime.parse(json['approvedAt'] as String) : null,
      approvedBy: json['approvedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemCode': itemCode,
      'itemName': itemName,
      'quantity': quantity,
      'returnType': returnType,
      'status': status,
      'reason': reason,
      'warehouseCode': warehouseCode,
      'warehouseName': warehouseName,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'approvedAt': approvedAt?.toIso8601String(),
      'approvedBy': approvedBy,
    };
  }
}

// 품목반출/반납 화면용 모델
class ItemExportReturn {
  final String itemCode;
  final String itemName;
  String quantity;
  String note;
  String exporter;
  String employee;
  String warehouseCode;

  ItemExportReturn({
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    required this.note,
    required this.exporter,
    required this.employee,
    required this.warehouseCode,
  });

  factory ItemExportReturn.fromJson(Map<String, dynamic> json) {
    return ItemExportReturn(
      itemCode: json['itemCode'] as String,
      itemName: json['itemName'] as String,
      quantity: json['quantity']?.toString() ?? '0',
      note: json['note']?.toString() ?? '',
      exporter: json['exporter']?.toString() ?? '',
      employee: json['employee']?.toString() ?? '',
      warehouseCode: json['warehouseCode'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemCode': itemCode,
      'itemName': itemName,
      'quantity': quantity,
      'note': note,
      'exporter': exporter,
      'employee': employee,
      'warehouseCode': warehouseCode,
    };
  }
} 