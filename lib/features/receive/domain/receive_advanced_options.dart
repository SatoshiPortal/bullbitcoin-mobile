import 'enums/receive_network_type.dart';

enum ReceiveAdvancedSummaryPart { wallet, payjoin, message }

enum ReceivePayjoinExplanation { global, awaitingFunds, belowMinimum }

/// Applicability and active-option summary, independent of localized copy.
final class ReceiveAdvancedOptions {
  const ReceiveAdvancedOptions({
    required this.network,
    required this.walletCount,
    required this.payjoinEnabled,
    required this.hasMessage,
    this.hasLocalSigner = false,
    this.supportsDeviceVerification = false,
    this.hasFunds = false,
    this.payjoinSuppressedForAmount = false,
  });
  final ReceiveNetworkType? network;
  final int walletCount;
  final bool payjoinEnabled;
  final bool hasMessage;
  final bool hasLocalSigner;
  final bool supportsDeviceVerification;
  final bool hasFunds;
  final bool payjoinSuppressedForAmount;

  bool get showWalletPicker =>
      network == ReceiveNetworkType.bitcoin && walletCount > 1;
  bool get showPayjoin =>
      network == ReceiveNetworkType.bitcoin && hasLocalSigner;
  bool get showNewAddress =>
      network == ReceiveNetworkType.bitcoin ||
      network == ReceiveNetworkType.liquid;
  bool get showHardwareVerification =>
      network == ReceiveNetworkType.bitcoin && supportsDeviceVerification;
  ReceivePayjoinExplanation get payjoinExplanation => !hasFunds
      ? ReceivePayjoinExplanation.awaitingFunds
      : payjoinSuppressedForAmount
      ? ReceivePayjoinExplanation.belowMinimum
      : ReceivePayjoinExplanation.global;

  List<ReceiveAdvancedSummaryPart> get summary => [
    if (showWalletPicker) ReceiveAdvancedSummaryPart.wallet,
    if (showPayjoin && payjoinEnabled) ReceiveAdvancedSummaryPart.payjoin,
    if (hasMessage) ReceiveAdvancedSummaryPart.message,
  ];
}
