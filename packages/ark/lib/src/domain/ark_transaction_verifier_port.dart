import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

import 'ark_wallet_failure.dart';

/// Host decodes both the signed PSBT and extracted transaction using public
/// codecs. Input values/fee come from PSBT UTXOs, never raw transaction bytes.
/// It requires equality of the full final serialized PSBT transaction and raw
/// consensus bytes, including witnesses, and supplies both computed txids.
/// This is not a script/signature-validity proof. Ark separately compares
/// destination, input values, fee and committed authorization.
abstract interface class ArkTransactionVerifierPort {
  @useResult
  Future<Result<ArkTransactionFacts, ArkWalletFailure>> inspectTransaction({
    required String transactionHex,
    required String signedPsbt,
    required BitcoinNetwork network,
  });
  @useResult
  Future<Result<ArkBoardPsbtFacts, ArkWalletFailure>> inspectBoardPsbt({
    required String unfinalisedPsbt,
    required BitcoinNetwork network,
  });
}

final class ArkTransactionInput {
  final String outpoint;
  final Sats amount;
  final bool finalWitness;
  const ArkTransactionInput({
    required this.outpoint,
    required this.amount,
    required this.finalWitness,
  });
}

final class ArkTransactionOutput {
  final String scriptPubkey;
  final String? address;
  final Sats amount;
  const ArkTransactionOutput({
    required this.scriptPubkey,
    this.address,
    required this.amount,
  });
}

final class ArkTransactionFacts {
  final String txid;
  final String psbtTxid;
  final List<ArkTransactionInput> inputs;
  final List<ArkTransactionOutput> outputs;
  final Sats fee;
  ArkTransactionFacts({
    required this.txid,
    required this.psbtTxid,
    required List<ArkTransactionInput> inputs,
    required List<ArkTransactionOutput> outputs,
    required this.fee,
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs);
}

final class ArkBoardPsbtFacts {
  final String unsignedTxid;
  final bool finalised;
  final bool nativeSegwitInputs;
  final List<ArkTransactionOutput> outputs;
  ArkBoardPsbtFacts({
    required this.unsignedTxid,
    required this.finalised,
    required this.nativeSegwitInputs,
    required List<ArkTransactionOutput> outputs,
  }) : outputs = List.unmodifiable(outputs);
}
