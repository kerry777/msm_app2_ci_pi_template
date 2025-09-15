class Warehouse {
  final String code;
  final String name;

  Warehouse({
    required this.code,
    required this.name,
  });

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
    };
  }
} 