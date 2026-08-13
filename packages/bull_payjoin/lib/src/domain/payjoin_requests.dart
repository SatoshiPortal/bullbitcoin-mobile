import 'package:primitives/primitives.dart';

final class StartPayjoinSender {
  final String walletId;
  final BitcoinNetwork network;
  final String bip21Uri;
  final String unsignedOriginalPsbt;
  final Sats amount;
  final FeeRate feeRate;
  final DateTime? expiresAt;
  final bool isExchange;

  StartPayjoinSender({
    required this.walletId,
    required this.network,
    required this.bip21Uri,
    required this.unsignedOriginalPsbt,
    required this.amount,
    required this.feeRate,
    this.expiresAt,
    this.isExchange = false,
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
  final bool isExchange;

  StartPayjoinReceiver({
    required this.walletId,
    required this.network,
    required this.address,
    this.amount,
    this.expiresAt,
    this.isExchange = false,
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
  if (network != BitcoinNetwork.mainnet && network != BitcoinNetwork.testnet) {
    throw ArgumentError.value(
      network,
      'network',
      'Payjoin supports only mainnet and testnet',
    );
  }
}

void _requireNotBlank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
}
