import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin_input_pair_model.freezed.dart';

@freezed
class PayjoinInputPairModel with _$PayjoinInputPairModel {
  const factory PayjoinInputPairModel({
    required String txId,
    required int vout,
    @Default([]) List<int> scriptSigRawOutputScript,
    @Default(0xFFFFFFFF) int sequence,
    @Default([]) List<Uint8List> witness,
    BigInt? value,
    required Uint8List scriptPubkey,
    @Default([]) List<int> redeemScriptRawOutputScript,
    @Default([]) List<int> witnessScriptRawOutputScript,
    required,
  }) = _PayjoinInputPairModel;
  const PayjoinInputPairModel._();

  factory PayjoinInputPairModel.fromUtxo(BitcoinTransactionOutput utxo) {
    return PayjoinInputPairModel(
      txId: utxo.txId,
      vout: utxo.vout,
      value: utxo.value,
      scriptPubkey: utxo.scriptPubkey,
    );
  }
}
