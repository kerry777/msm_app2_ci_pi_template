class ApiConfig {
  static const String baseUrl = 'http://it.mek-ics.com:4100';  // 실제 서버 URL (포트 4100)
  // static const String baseUrl = 'https://api.example.com';  // 프로덕션 서버 URL

  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // API 엔드포인트 메서드들
  static String getApiEndpoint(String endpoint) {
    return '$baseUrl$endpoint';
  }

  static String get getHospitalCellItems => '$baseUrl/api/v1/hospital-cell-items';
  static String get getHospitals => '$baseUrl/api/v1/hospitals';
  static String get getHospitalCells => '$baseUrl/api/v1/hospital-cells';
  static String get getItems => '$baseUrl/api/v1/items';
  
  // 대리점 관련 엔드포인트
  static String get getAgencies => '$baseUrl/api/v1/agencies';
  
  // 병원매출 관련 엔드포인트
  static String get getAgencySales => '$baseUrl/api/v1/agency-sales/data';
} 