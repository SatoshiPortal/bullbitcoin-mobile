import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';

enum BtcpayPairingStatus { loading, idle, submitting, success, failure }

enum BtcpayPairingRail { bitcoin, liquid, lightning }

enum BtcpayPairingWallet { bitcoin, liquid }

class BtcpayPairingState {
  final BtcpayPairingStatus status;
  final BtcpayFailure? failure;
  final BtcpayConnectionViewModel? connection;
  final bool showPairingForm;

  const BtcpayPairingState({
    this.status = BtcpayPairingStatus.loading,
    this.failure,
    this.connection,
    this.showPairingForm = false,
  });

  bool get isLoading => status == BtcpayPairingStatus.loading;
  bool get isSubmitting => status == BtcpayPairingStatus.submitting;
  bool get isSuccess => status == BtcpayPairingStatus.success;
  bool get isFailure => status == BtcpayPairingStatus.failure;
  bool get shouldShowConnection =>
      connection != null && !showPairingForm && !isSuccess;

  BtcpayPairingState copyWith({
    BtcpayPairingStatus? status,
    BtcpayFailure? failure,
    BtcpayConnectionViewModel? connection,
    bool clearFailure = false,
    bool clearConnection = false,
    bool? showPairingForm,
  }) {
    return BtcpayPairingState(
      status: status ?? this.status,
      failure: clearFailure ? null : failure ?? this.failure,
      connection: clearConnection ? null : connection ?? this.connection,
      showPairingForm: showPairingForm ?? this.showPairingForm,
    );
  }
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
