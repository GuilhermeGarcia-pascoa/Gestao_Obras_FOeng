const String _defaultApiUrl = 'http://localhost:6002/api';

class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: _defaultApiUrl,
  );
}
