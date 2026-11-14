class AppConfig {
  static const String appName = 'Etaprise HRMS';
  static const String apiBaseUrl = 'https://hrms.etaprise.ai/api';
  static const int requestTimeoutSeconds = 30;
  static const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');
}
