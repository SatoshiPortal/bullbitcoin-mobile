import 'enums/receive_network_type.dart';

enum ReceiveAdvancedSummaryPart { wallet, payjoin, message }

/// Applicability and active-option summary, independent of localized copy.
final class ReceiveAdvancedOptions {
  const ReceiveAdvancedOptions({
    required this.network,
    required this.walletCount,
    required this.payjoinEnabled,
    required this.hasMessage,
  });
  final ReceiveNetworkType? network;
  final int walletCount;
  final bool payjoinEnabled;
  final bool hasMessage;

  bool get showWalletPicker =>
      network == ReceiveNetworkType.bitcoin && walletCount > 1;
  List<ReceiveAdvancedSummaryPart> get summary => [
    if (showWalletPicker) ReceiveAdvancedSummaryPart.wallet,
    if (network == ReceiveNetworkType.bitcoin && payjoinEnabled)
      ReceiveAdvancedSummaryPart.payjoin,
    if (hasMessage) ReceiveAdvancedSummaryPart.message,
  ];
}
