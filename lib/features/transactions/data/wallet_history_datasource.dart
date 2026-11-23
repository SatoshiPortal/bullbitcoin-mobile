import 'dart:typed_data';

import 'package:bb_mobile/features/transactions/data/models/transaction_input_model.dart';
import 'package:bb_mobile/features/transactions/data/models/transaction_output_model.dart';
import 'package:bb_mobile/features/transactions/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Network;
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, Outpoint;
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' as sync;

class WalletHistoryDatasource {
  final Future<sync.Wallet> Function(sync.WalletKey) _load;

  WalletHistoryDatasource({required this._load});

  Future<List<WalletTransactionModel>> getTransactions({
    required sync.WalletKey key,
    String? toAddress,
  }) async {
    final handle = await _load(key);
    // Both values come from one frame: no await between the two reads.
    final transactions = WalletCatalogPortImpl.value(handle.history.now.latest);
    final book = WalletCatalogPortImpl.value(handle.addresses.book.now.latest);
    final network = Network.fromEnvironment(
      environment: key.network.env,
      isLiquid: key.network is LiquidNetwork,
    );
    final filter = toAddress != null && toAddress.isNotEmpty ? toAddress : null;
    final result = switch (key.network) {
      BitcoinNetwork() => _bitcoinHistory(
        transactions.whereType<sync.BitcoinTransaction>().toList(),
        network: network,
        toAddress: filter,
      ),
      LiquidNetwork() => _liquidHistory(
        transactions.whereType<sync.LiquidTransaction>().toList(),
        book,
        network: network,
        toAddress: filter,
      ),
    };
    return result;
  }

  /// The wallet cannot price a transaction whose previous outputs it does not
  /// know; its history fails as a whole, as it did before sync published it.
  static int _feeOf(sync.ChainTransaction tx) =>
      tx.feeSat ??
      (throw const WalletSnapshotException(sync.SyncNeedsRepairFailure()));

  static List<WalletTransactionModel> _bitcoinHistory(
    List<sync.BitcoinTransaction> transactions, {
    required Network network,
    String? toAddress,
  }) {
    final allOutputs = <Outpoint, bool>{
      for (final tx in transactions)
        for (final output in tx.outputs)
          (txId: tx.txid, vout: output.vout): output.isOwn,
    };
    return [
      for (final tx in transactions)
        if (toAddress == null ||
            tx.outputs.any((output) => output.address == toAddress))
          _bitcoinTransaction(tx, allOutputs, network),
    ];
  }

  static WalletTransactionModel _bitcoinTransaction(
    sync.BitcoinTransaction tx,
    Map<Outpoint, bool> allOutputs,
    Network network,
  ) {
    final inputs = [
      for (var vin = 0; vin < tx.inputs.length; vin++)
        TransactionInputModel.bitcoin(
          txId: tx.txid,
          vin: vin,
          isOwn: allOutputs[tx.inputs[vin].previousOutput] ?? false,
          scriptSig: Uint8List.fromList(tx.inputs[vin].scriptSig),
          previousTxId: tx.inputs[vin].previousOutput.txId,
          previousTxVout: tx.inputs[vin].previousOutput.vout,
        ),
    ];
    final outputs = [
      for (final output in tx.outputs)
        TransactionOutputModel.bitcoin(
          txId: tx.txid,
          vout: output.vout,
          isOwn: output.isOwn,
          value: output.valueSat,
          scriptPubkey: Uint8List.fromList(output.scriptPubkey),
          address: output.address,
          isChange: output.isChange,
        ) as BitcoinTransactionOutputModel,
    ];
    final isToSelf =
        inputs.every((input) => input.isOwn) &&
        outputs.every((output) => output.isOwn);
    final isIncoming = tx.receivedSat > tx.sentSat;
    return WalletTransactionModel(
      txId: tx.txid,
      isIncoming: isIncoming,
      amountSat: bitcoinNetAmountSat(
        isToSelf: isToSelf,
        isIncoming: isIncoming,
        outputs: outputs,
        sent: tx.sentSat,
        received: tx.receivedSat,
        fee: _feeOf(tx),
      ),
      feeSat: _feeOf(tx),
      vsize: tx.vsize,
      confirmationTimestamp: tx.confirmationTime,
      isToSelf: isToSelf,
      inputs: inputs,
      outputs: outputs,
      network: network,
      isRbf: tx.isExplicitlyRbf,
    );
  }

  /// The amount to show for a transaction, from this wallet's point of view.
  static int bitcoinNetAmountSat({
    required bool isToSelf,
    required bool isIncoming,
    required List<BitcoinTransactionOutputModel> outputs,
    required int sent,
    required int received,
    required int fee,
  }) {
    if (isToSelf) {
      // `sent` is the whole utxo we spent, not what we paid: coin selection
      // spends whole utxos and hands the rest back as change.
      final toDestination = outputs
          .where((output) => !output.isChange)
          .fold(0, (sum, output) => sum + (output.value?.toInt() ?? 0));
      // Nothing paid out — a consolidation. The fee is the only balance change.
      return toDestination > 0 ? toDestination : fee;
    }

    // The sender paid the fee, so it never left this balance.
    if (isIncoming) return received - sent;

    // We paid the fee, so take it off to leave what reached the recipient.
    return sent - received - fee;
  }

  static List<WalletTransactionModel> _liquidHistory(
    List<sync.LiquidTransaction> transactions,
    sync.AddressBook book, {
    required Network network,
    String? toAddress,
  }) {
    final used = <String>{
      for (final address in book.receive) ...[
        address.address,
        ?address.standardAddress,
      ],
    };
    bool isWallet(sync.LiquidTxOut out) =>
        used.contains(out.standardAddress) ||
        used.contains(out.confidentialAddress);
    final result = <WalletTransactionModel>[];
    for (final tx in transactions) {
      if (toAddress != null &&
          !tx.outputs.any(
            (output) =>
                output.standardAddress == toAddress ||
                output.confidentialAddress == toAddress,
          )) {
        continue;
      }
      final isIncoming = tx.kind == 'incoming';
      final finalBalance = tx.policyBalanceSat;
      final isToSelf =
          tx.kind == 'redeposit' || finalBalance.abs() == _feeOf(tx);
      var changeAmountInToSelf = 0;
      final inputs = [
        for (var vin = 0; vin < tx.inputs.length; vin++)
          TransactionInputModel.liquid(
            txId: tx.txid,
            vin: vin,
            isOwn: isToSelf || isWallet(tx.inputs[vin]),
            value: tx.inputs[vin].valueSat,
            scriptPubkey: tx.inputs[vin].scriptPubkey,
            previousTxId: tx.inputs[vin].outpoint.txId,
            previousTxVout: tx.inputs[vin].outpoint.vout,
          ),
      ];
      final outputs = <TransactionOutputModel>[];
      for (var vout = 0; vout < tx.outputs.length; vout++) {
        final output = tx.outputs[vout];
        final owned = isWallet(output);
        if (isToSelf && !owned) {
          changeAmountInToSelf += output.valueSat.toInt();
        }
        outputs.add(
          TransactionOutputModel.liquid(
            txId: tx.txid,
            vout: vout,
            isOwn: isToSelf || owned,
            value: output.valueSat,
            scriptPubkey: output.scriptPubkey,
            address: output.confidentialAddress,
          ),
        );
      }
      final sumOutputs = outputs
          .map((output) => output.value?.toInt() ?? 0)
          .fold(0, (int a, b) => a + b);
      final toDestination = sumOutputs - changeAmountInToSelf;
      // LWK lists only this wallet's outputs and cannot list change
      // addresses, so a redeposit to an unlisted address of the wallet has
      // no recognised destination. With a single L-BTC output, that output
      // is the destination; any other ambiguous case stays unresolved.
      final sole = tx.outputs.length == 1 ? tx.outputs.first : null;
      final soleRedepositSat =
          tx.kind == 'redeposit' && sole != null && sole.isPolicyAsset
          ? sole.valueSat.toInt()
          : null;
      final netAmountSat = isToSelf
          ? toDestination == 0
                ? soleRedepositSat ?? 0
                : toDestination
          : isIncoming
          ? finalBalance
          : finalBalance.abs() - _feeOf(tx);
      result.add(
        WalletTransactionModel(
          txId: tx.txid,
          isIncoming: isIncoming,
          amountSat: netAmountSat,
          feeSat: _feeOf(tx),
          vsize: tx.vsize,
          confirmationTimestamp: tx.confirmationTime,
          isToSelf: isToSelf,
          inputs: inputs,
          outputs: outputs,
          network: network,
          unblindedUrl: tx.unblindedUrl,
          isRbf: false,
        ),
      );
    }
    return result;
  }
}
