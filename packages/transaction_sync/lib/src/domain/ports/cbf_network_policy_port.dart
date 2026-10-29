import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../wallet_transaction_sync_failure.dart';

enum CbfNetworkPauseReason { offline, mobileData }

/// Network cost is a platform property, independent of the interface name.
/// A null cost is unknown; the explicit Wi-Fi-only policy treats it as costly.
final class CbfNetworkPolicyState {
  final bool initialized;
  final bool available;
  final bool? metered;
  final bool wifiOnly;
  final bool mobileDataOverride;

  const CbfNetworkPolicyState({
    this.initialized = false,
    this.available = false,
    this.metered,
    this.wifiOnly = false,
    this.mobileDataOverride = false,
  });

  CbfNetworkPauseReason? get pauseReason {
    if (!initialized) return null;
    if (!available) return CbfNetworkPauseReason.offline;
    if (wifiOnly && metered != false && !mobileDataOverride) {
      return CbfNetworkPauseReason.mobileData;
    }
    return null;
  }

  bool get canSync => initialized && pauseReason == null;

  @override
  bool operator ==(Object other) =>
      other is CbfNetworkPolicyState &&
      initialized == other.initialized &&
      available == other.available &&
      metered == other.metered &&
      wifiOnly == other.wifiOnly &&
      mobileDataOverride == other.mobileDataOverride;

  @override
  int get hashCode => Object.hash(
    initialized,
    available,
    metered,
    wifiOnly,
    mobileDataOverride,
  );
}

/// Platform-independent sync admission and user network-cost preferences.
abstract interface class CbfNetworkPolicyPort {
  CbfNetworkPolicyState get current;

  Stream<CbfNetworkPolicyState> watch();

  @useResult
  Future<Result<void, WalletTransactionSyncFailure>> setWifiOnly(bool enabled);

  /// Consent lasts for this process session; the persisted preference is intact.
  void continueOnMobileData();
}
