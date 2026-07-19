class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8081/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
