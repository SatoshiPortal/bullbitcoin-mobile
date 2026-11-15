import 'package:bull_sdk/lwk.dart' as lwk;

/// The native store does not exist where the catalog expects it.
final class NativeStoreMissing implements Exception {
  const NativeStoreMissing();
}

/// The store, or the requested network, is not one this SDK pin supports.
final class NativeNetworkUnsupported implements Exception {
  const NativeNetworkUnsupported();
}

/// LWK's update conflict, the only error that permits an explicit repair.
bool isLiquidStatusConflict(Object error) =>
    error is lwk.LwkError && error.msg.contains('UpdateOnDifferentStatus');
