const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5080',
);
const enableDevelopmentLogin = bool.fromEnvironment(
  'ENABLE_DEV_LOGIN',
  defaultValue: false,
);
