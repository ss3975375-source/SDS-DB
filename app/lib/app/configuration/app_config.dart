class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.googleWebClientId});

  final String apiBaseUrl;
  final String googleWebClientId;

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000'),
    googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
  );
}
