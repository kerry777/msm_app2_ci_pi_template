class Hospital {
  final int id;
  final String name;
  final String code;

  Hospital({
    required this.id,
    required this.name,
    required this.code,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
    };
  }
} 