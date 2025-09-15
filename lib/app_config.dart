enum Environment {
  development,
  staging,
  production,
}

class AppConfig {
  static const String developmentBaseUrl = String.fromEnvironment(
    'DEV_API_BASE_URL',
    defaultValue: 'http://localhost:4100',
  );
  
  static const String stagingBaseUrl = String.fromEnvironment(
    'STAGING_API_BASE_URL',
    defaultValue: 'http://staging-api.example.com',
  );
  
  static const String productionBaseUrl = String.fromEnvironment(
    'PROD_API_BASE_URL',
    defaultValue: 'http://api.example.com',
  );

  static Environment _environment = Environment.development;

  static bool get isDevelopment => _environment == Environment.development;
  static bool get isStaging => _environment == Environment.staging;
  static bool get isProduction => _environment == Environment.production;

  static void setEnvironment(Environment env) {
    _environment = env;
  }

  static String getBaseUrl() {
    switch (_environment) {
      case Environment.development:
        return developmentBaseUrl;
      case Environment.staging:
        return stagingBaseUrl;
      case Environment.production:
        return productionBaseUrl;
    }
  }

  static String getApiVersion() {
    return const String.fromEnvironment(
      'API_VERSION',
      defaultValue: 'v1',
    );
  }

  static String getApiBaseUrl() {
    return '${getBaseUrl()}/api/${getApiVersion()}';
  }
} 