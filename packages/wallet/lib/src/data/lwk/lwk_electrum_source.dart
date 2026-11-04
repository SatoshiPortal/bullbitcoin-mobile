import 'package:bull_sdk/lwk.dart' as lwk;

/// LWK has one native scan capability, shared by foreground and headless.
/// Recovery and fallback stay with the owning coordinated operation.
Future<void> synchronizeLwkElectrum({
  required lwk.Wallet wallet,
  required String electrumUrl,
  required bool validateDomain,
  int? stopAtIndex,
  int? timeout,
}) => wallet.sync_(
  electrumUrl: electrumUrl,
  validateDomain: validateDomain,
  stopAtIndex: stopAtIndex,
  timeout: timeout,
);
