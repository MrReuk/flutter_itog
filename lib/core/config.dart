const apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

const String kLocalApi = 'http://127.0.0.1:8090/api';

String resolveApiBaseUrl(String define) {
  final value = define.trim();
  if (value.isEmpty) return kLocalApi;
  return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

final String apiBaseUrl = resolveApiBaseUrl(apiBaseUrlDefine);

const inactivitySeconds = int.fromEnvironment('INACTIVITY_SECONDS', defaultValue: 900);

const inactivityWarningSeconds = int.fromEnvironment(
  'INACTIVITY_WARNING_SECONDS',
  defaultValue: 30,
);

const maxSessionMinutes = int.fromEnvironment('SESSION_MAX_MINUTES', defaultValue: 480);

const tokenRefreshMarginSeconds = 120;
