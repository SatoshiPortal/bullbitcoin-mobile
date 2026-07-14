/// Public configuration surface for the Bullnym feature.
///
/// Other features must reach Bullnym only through `public/`; this dependency-
/// free config file is the sanctioned way to configure API and public trust
/// origins without importing `bullnym/data`.
const bullnymBaseUrlEnvironmentKey = 'BULLNYM_BASE_URL';
const bullnymPublicBaseUrlEnvironmentKey = 'BULLNYM_PUBLIC_BASE_URL';

const bullnymDefaultBaseUrl = String.fromEnvironment(
  bullnymBaseUrlEnvironmentKey,
  defaultValue: 'https://bullpay.ca',
);

/// Explicit trust origin for server-returned Payment Page and POS URLs. It may
/// differ from the API origin in split deployments; arbitrary response origins
/// are never accepted.
const bullnymDefaultPublicBaseUrl = String.fromEnvironment(
  bullnymPublicBaseUrlEnvironmentKey,
  defaultValue: bullnymDefaultBaseUrl,
);
