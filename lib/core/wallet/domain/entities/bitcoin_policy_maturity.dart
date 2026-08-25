import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_node.dart';

final class BitcoinPolicyUtxoMaturity {
  final String outpoint;
  final BitcoinPolicyKeychain keychain;
  final BigInt amountSat;
  final int confirmations;
  final int? confirmationMedianTimePast;

  BitcoinPolicyUtxoMaturity({
    required this.outpoint,
    required this.keychain,
    required this.amountSat,
    required this.confirmations,
    this.confirmationMedianTimePast,
  }) {
    if (outpoint.isEmpty) throw ArgumentError.value(outpoint, 'outpoint');
    if (amountSat < BigInt.zero) {
      throw ArgumentError.value(amountSat, 'amountSat');
    }
    if (confirmations < 0) {
      throw ArgumentError.value(confirmations, 'confirmations');
    }
  }
}

final class BitcoinPolicyMaturity {
  final bool isKnown;
  final int tipHeight;
  final int? medianTimePast;
  final List<BitcoinPolicyUtxoMaturity> utxos;

  const BitcoinPolicyMaturity.empty()
    : isKnown = false,
      tipHeight = 0,
      medianTimePast = null,
      utxos = const [];

  BitcoinPolicyMaturity({
    required this.tipHeight,
    required this.medianTimePast,
    required List<BitcoinPolicyUtxoMaturity> utxos,
  }) : isKnown = true,
       utxos = List.unmodifiable(utxos) {
    if (tipHeight < 0) throw ArgumentError.value(tipHeight, 'tipHeight');
  }
}

enum BitcoinPolicyActivationType {
  absoluteBlock,
  absoluteTime,
  relativeBlocks,
  relativeTime,
}

final class BitcoinPolicyActivation {
  final BitcoinPolicyActivationType type;
  final int value;
  final int estimatedSecondsFromNow;

  BitcoinPolicyActivation({
    required this.type,
    required this.value,
    required this.estimatedSecondsFromNow,
  }) {
    if (value < 0) throw ArgumentError.value(value, 'value');
    if (estimatedSecondsFromNow < 0) {
      throw ArgumentError.value(
        estimatedSecondsFromNow,
        'estimatedSecondsFromNow',
      );
    }
  }
}

final class BitcoinPolicyOptionStatus {
  final bool available;
  final BigInt availableAmountSat;
  final BigInt activatingAmountSat;
  final BitcoinPolicyActivation? activation;

  const BitcoinPolicyOptionStatus({
    required this.available,
    required this.availableAmountSat,
    required this.activatingAmountSat,
    this.activation,
  });
}
