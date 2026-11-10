/// Build-time settings, passed with --dart-define.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'AVA_API_URL',
    defaultValue: 'http://localhost:8080',
  );
}
