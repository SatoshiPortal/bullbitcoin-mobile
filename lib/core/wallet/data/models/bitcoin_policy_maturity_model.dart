enum BitcoinPolicyKeychainModel { external, internal }

final class BitcoinPolicyUtxoMaturityModel {
  final String outpoint;
  final BitcoinPolicyKeychainModel keychain;
  final BigInt amountSat;
  final int confirmations;
  final int? confirmationMedianTimePast;

  const BitcoinPolicyUtxoMaturityModel({
    required this.outpoint,
    required this.keychain,
    required this.amountSat,
    required this.confirmations,
    this.confirmationMedianTimePast,
  });
}

final class BitcoinPolicyMaturityModel {
  final int tipHeight;
  final int? medianTimePast;
  final List<BitcoinPolicyUtxoMaturityModel> utxos;

  BitcoinPolicyMaturityModel({
    required this.tipHeight,
    required this.medianTimePast,
    required List<BitcoinPolicyUtxoMaturityModel> utxos,
  }) : utxos = List.unmodifiable(utxos);
}
