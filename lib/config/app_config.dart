
class AppConfig {
  // 기본 서버 주소 (API 버전 제외)
  static const String _serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://localhost/msm',
  );

  // API 버전
  static const String _apiVersion = 'v1';
  static const String _apiPrefix = 'api';

  // 기본 URL (서버 주소만)
  static String get serverUrl => _serverUrl;

  // API 기본 URL (서버 주소 + API 접두사 + 버전)
  static String get apiBaseUrl => '$_serverUrl/$_apiPrefix/$_apiVersion';

  // API 엔드포인트 생성 헬퍼 메서드
  static String getApiEndpoint(String path) {
    // path가 /로 시작하면 서버 주소에 바로 붙임
    if (path.startsWith('/')) {
      return '$_serverUrl$path';
    }
    // 그 외의 경우 서버 주소에 /를 추가하고 path 추가
    return '$_serverUrl/$path';
  }
  
  // 외부 서비스 URL들
  static const String openAiApiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String apkDownloadUrl = 'http://it.mek-ics.com:4100/msm/app-release.apk';
  
  // AI 분석 관련 설정
  static const String aiAnalysisSystemPrompt = 'ai_analysis_system_prompt';
  static const String aiAnalysisUserPromptTemplate = 'ai_analysis_user_prompt_template';
  
  static Map<String, dynamic> getEnvironmentConfig(String env) {
    switch (env) {
      case 'production':
        return {
          'serverUrl': _serverUrl,
          'apiVersion': _apiVersion,
        };
      case 'staging':
        return {
          'serverUrl': _serverUrl,
          'apiVersion': _apiVersion,
        };
      case 'development':
      default:
        return {
          'serverUrl': _serverUrl,
          'apiVersion': _apiVersion,
        };
    }
  }
} 