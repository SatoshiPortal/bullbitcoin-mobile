import 'package:primitives/primitives.dart';

import 'payjoin_failure.dart';

/// Write-ahead admission for an original signed from a reviewed spend.
/// The caller must hold the wallet's admission through [persist].
typedef PayjoinOriginalAdmission =
    Future<Result<void, PayjoinFailure>> Function({
      required String sessionId,
      required Future<void> Function() persist,
    });

final class PreparedPayjoinOriginal {
  final String signedPsbt;
  final PayjoinOriginalAdmission admit;

  const PreparedPayjoinOriginal({
    required this.signedPsbt,
    required this.admit,
  });
}

final class StartPayjoinSender {
  final String walletId;
  final BitcoinNetwork network;
  final String bip21Uri;
  final String unsignedOriginalPsbt;
  final Sats amount;
  final FeeRate feeRate;
  final DateTime? expiresAt;
  final PreparedPayjoinOriginal? preparedOriginal;

  StartPayjoinSender({
    required this.walletId,
    required this.network,
    required this.bip21Uri,
    required this.unsignedOriginalPsbt,
    required this.amount,
    required this.feeRate,
    this.expiresAt,
    this.preparedOriginal,
  }) {
    _requireNotBlank(walletId, 'walletId');
    _requireSupportedNetwork(network);
    _requireNotBlank(bip21Uri, 'bip21Uri');
    _requireNotBlank(unsignedOriginalPsbt, 'unsignedOriginalPsbt');
    if (amount == Sats.zero) {
      throw ArgumentError.value(amount, 'amount', 'must be greater than zero');
    }
  }
}

final class StartPayjoinReceiver {
  final String walletId;
  final BitcoinNetwork network;
  final String address;
  final Sats? amount;
  final DateTime? expiresAt;

  /// The payout of a Bull Bitcoin exchange buy order: gated by the buy switch
  /// instead of the receive switch.
  final bool isTrade;

  StartPayjoinReceiver({
    required this.walletId,
    required this.network,
    required this.address,
    this.amount,
    this.expiresAt,
    this.isTrade = false,
  }) {
    _requireNotBlank(walletId, 'walletId');
    _requireSupportedNetwork(network);
    _requireNotBlank(address, 'address');
    if (amount == Sats.zero) {
      throw ArgumentError.value(amount, 'amount', 'must be greater than zero');
    }
  }
}

final class PayjoinSessionFilter {
  final String? walletId;
  final BitcoinNetwork? network;
  final bool ongoingOnly;

  PayjoinSessionFilter({
    this.walletId,
    this.network,
    this.ongoingOnly = false,
  }) {
    final walletId = this.walletId;
    if (walletId != null) _requireNotBlank(walletId, 'walletId');
    final network = this.network;
    if (network != null) _requireSupportedNetwork(network);
  }
}

void _requireSupportedNetwork(BitcoinNetwork network) {
  if (!NetworkCapabilities.supports(network, NetworkCapability.payjoin)) {
    throw ArgumentError.value(
      network,
      'network',
      'Unsupported Payjoin network',
    );
  }
}

void _requireNotBlank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
}
