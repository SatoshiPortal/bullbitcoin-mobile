/// Public configuration surface for the Bullnym feature.
///
/// Other features must reach Bullnym only through `public/`; this dependency-
/// free config file is the sanctioned way to share the base URL (e.g. POS
/// building its terminal URL client-side) without importing `bullnym/data`.
const bullnymBaseUrlEnvironmentKey = 'BULLNYM_BASE_URL';

const bullnymDefaultBaseUrl = String.fromEnvironment(
  bullnymBaseUrlEnvironmentKey,
  defaultValue: 'https://bullpay.ca',
);
