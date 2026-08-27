import 'package:bb_mobile/core/wallet/data/models/bitcoin_policy_maturity_model.dart';

typedef BitcoinPsbtKeySourceRecord = ({
  String publicKey,
  String? fingerprint,
  String? derivationPath,
});

typedef BitcoinPsbtInputReviewRecord = ({
  BigInt amountSat,
  BitcoinPolicyKeychainModel? keychain,
  List<BitcoinPsbtKeySourceRecord> originKeySources,
  List<BitcoinPsbtKeySourceRecord> signedKeySources,
  String outpoint,
  int sequence,
});

typedef BitcoinPsbtOutputReviewRecord = ({
  String? address,
  BigInt amountSat,
  int index,
  bool isWalletOwned,
  String scriptHex,
});

final class BitcoinPsbtReviewModel {
  final String transactionId;
  final List<BitcoinPsbtInputReviewRecord> inputs;
  final List<BitcoinPsbtOutputReviewRecord> outputs;
  final BigInt feeSat;
  final int estimatedTransactionVsize;
  final int lockTime;
  final int version;

  BitcoinPsbtReviewModel({
    required this.transactionId,
    required List<BitcoinPsbtInputReviewRecord> inputs,
    required List<BitcoinPsbtOutputReviewRecord> outputs,
    required this.feeSat,
    required this.estimatedTransactionVsize,
    required this.lockTime,
    required this.version,
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs);
}
