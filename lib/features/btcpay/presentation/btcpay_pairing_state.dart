import 'package:bb_mobile/core/wallet/domain/wallet_behavior_rule.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';

enum BtcpayPairingStatus {
  loading,
  idle,
  submitting,
  success,
  failure,
  unavailable,
}

enum BtcpayWalletBehaviorStatus { loading, loaded, unavailable }

enum BtcpayPairingRail { bitcoin, liquid, lightning }

enum BtcpayPairingWallet { bitcoin, liquid }

class BtcpayPairingState {
  final BtcpayPairingStatus status;
  final BtcpayFailure? failure;
  final BtcpayConnectionViewModel? connection;
  final List<BtcpayWalletBehaviorViewModel> walletBehaviors;
  final BtcpayWalletBehaviorStatus walletBehaviorsStatus;
  final bool walletSettingsSaving;
  final bool showPairingForm;

  const BtcpayPairingState({
    this.status = BtcpayPairingStatus.loading,
    this.failure,
    this.connection,
    this.walletBehaviors = const [],
    this.walletBehaviorsStatus = BtcpayWalletBehaviorStatus.loading,
    this.walletSettingsSaving = false,
    this.showPairingForm = false,
  });

  bool get isLoading => status == BtcpayPairingStatus.loading;
  bool get isSubmitting => status == BtcpayPairingStatus.submitting;
  bool get isSuccess => status == BtcpayPairingStatus.success;
  bool get isFailure => status == BtcpayPairingStatus.failure;
  bool get isUnavailable => status == BtcpayPairingStatus.unavailable;
  bool get shouldShowConnection =>
      connection != null && !showPairingForm && !isSuccess;

  BtcpayPairingState copyWith({
    BtcpayPairingStatus? status,
    BtcpayFailure? failure,
    BtcpayConnectionViewModel? connection,
    List<BtcpayWalletBehaviorViewModel>? walletBehaviors,
    BtcpayWalletBehaviorStatus? walletBehaviorsStatus,
    bool? walletSettingsSaving,
    bool clearFailure = false,
    bool clearConnection = false,
    bool? showPairingForm,
  }) {
    return BtcpayPairingState(
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      connection: clearConnection ? null : connection ?? this.connection,
      walletBehaviors: walletBehaviors ?? this.walletBehaviors,
      walletBehaviorsStatus:
          walletBehaviorsStatus ?? this.walletBehaviorsStatus,
      walletSettingsSaving: walletSettingsSaving ?? this.walletSettingsSaving,
      showPairingForm: showPairingForm ?? this.showPairingForm,
    );
  }
}

class BtcpayWalletBehaviorViewModel {
  final String walletId;
  final BtcpayPairingWallet wallet;
  final bool hideOnHome;
  final bool autoSweepEnabled;

  const BtcpayWalletBehaviorViewModel({
    required this.walletId,
    required this.wallet,
    required this.hideOnHome,
    required this.autoSweepEnabled,
  });

  BtcpayWalletBehaviorViewModel copyWith({
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) {
    return BtcpayWalletBehaviorViewModel(
      walletId: walletId,
      wallet: wallet,
      hideOnHome: hideOnHome ?? this.hideOnHome,
      autoSweepEnabled: autoSweepEnabled ?? this.autoSweepEnabled,
    );
  }

  /// The behavior a requested toggle actually produces, with the auto-sweep /
  /// hide-on-home rule applied — what the write will persist, so an optimistic
  /// UI update shows the truth instead of a combination the store will refuse.
  BtcpayWalletBehaviorViewModel withRequestedChange({
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) {
    final resolved = resolveWalletBehaviorChange(
      hideOnHome: this.hideOnHome,
      autoSweepEnabled: this.autoSweepEnabled,
      requestedHideOnHome: hideOnHome,
      requestedAutoSweepEnabled: autoSweepEnabled,
    );
    return copyWith(
      hideOnHome: resolved.hideOnHome,
      autoSweepEnabled: resolved.autoSweepEnabled,
    );
  }

  /// Hiding this wallet from home is only offered while auto-sweep empties it.
  bool get canHideOnHome => autoSweepEnabled;
}

class BtcpayConnectionViewModel {
  final String serverUrl;
  final String storeId;
  final List<BtcpayPairingRail> rails;
  final List<BtcpayPairingWallet> wallets;
  final bool isUncertain;
  final bool isPaired;
  final DateTime displayDate;

  const BtcpayConnectionViewModel({
    required this.serverUrl,
    required this.storeId,
    required this.rails,
    required this.wallets,
    required this.isUncertain,
    required this.isPaired,
    required this.displayDate,
  });
}

class BtcpayPairingPreview {
  final String serverUrl;
  final bool supportsBitcoinChain;
  final bool supportsLiquidChain;
  final bool supportsLightning;

  const BtcpayPairingPreview({
    required this.serverUrl,
    required this.supportsBitcoinChain,
    required this.supportsLiquidChain,
    required this.supportsLightning,
  });
}
