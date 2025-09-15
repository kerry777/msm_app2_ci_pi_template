class Cell {
  final int id;
  final String name;
  final String code;
  final String hospitalCode;

  Cell({
    required this.id,
    required this.name,
    required this.code,
    required this.hospitalCode,
  });

  factory Cell.fromJson(Map<String, dynamic> json) {
    return Cell(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      hospitalCode: json['hospitalCode'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'hospitalCode': hospitalCode,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cell &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          hospitalCode == other.hospitalCode;

  @override
  int get hashCode => code.hashCode ^ hospitalCode.hashCode;
} 