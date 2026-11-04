import '../domain/wallet_transaction_details.dart';
import '../domain/transaction_input_details.dart';
import '../domain/transaction_output_details.dart';
import 'models/wallet_transaction_model.dart';
import 'models/transaction_input_model.dart';
import 'models/transaction_output_model.dart';

abstract final class WalletTransactionDetailsMapper {
  static WalletTransactionDetails fromModel(WalletTransactionModel model) =>
      WalletTransactionDetails(
        txId: model.txId,
        isIncoming: model.isIncoming,
        amountSat: model.amountSat,
        feeSat: model.feeSat,
        vsize: model.vsize,
        isLiquid: model.isLiquid,
        isTestnet: model.isTestnet,
        isRbf: model.isRbf,
        isToSelf: model.isToSelf,
        confirmationTimestamp: model.confirmationTimestamp,
        unblindedUrl: model.unblindedUrl,
        inputs: model.inputs.map(_input).toList(),
        outputs: model.outputs.map(_output).toList(),
      );

  static TransactionInputDetails _input(TransactionInputModel input) =>
      switch (input) {
        BitcoinTransactionInputModel() => TransactionInputDetails.bitcoin(
          txId: input.txId,
          vin: input.vin,
          isOwn: input.isOwn,
          value: input.value,
          scriptSig: input.scriptSig,
          previousTxId: input.previousTxId,
          previousTxVout: input.previousTxVout,
        ),
        LiquidTransactionInputModel() => TransactionInputDetails.liquid(
          txId: input.txId,
          vin: input.vin,
          isOwn: input.isOwn,
          value: input.value,
          scriptPubkey: input.scriptPubkey,
          previousTxId: input.previousTxId,
          previousTxVout: input.previousTxVout,
        ),
      };

  static TransactionOutputDetails _output(TransactionOutputModel output) =>
      switch (output) {
        BitcoinTransactionOutputModel() => TransactionOutputDetails.bitcoin(
          txId: output.txId,
          vout: output.vout,
          isOwn: output.isOwn,
          value: output.value,
          scriptPubkey: output.scriptPubkey,
          address: output.address,
          isChange: output.isChange,
        ),
        LiquidTransactionOutputModel() => TransactionOutputDetails.liquid(
          txId: output.txId,
          vout: output.vout,
          isOwn: output.isOwn,
          value: output.value,
          scriptPubkey: output.scriptPubkey,
          address: output.address,
          isChange: output.isChange,
        ),
      };
}
