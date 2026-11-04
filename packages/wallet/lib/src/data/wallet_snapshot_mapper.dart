import 'dart:typed_data';

import 'package:transaction_sync/transaction_sync.dart' as sync;
import 'package:wallet/wallet.dart';

/// Projects the source's explicit display evidence into the existing label mapper.
/// Missing evidence is an error, never an invented amount or an empty history.
abstract final class WalletSnapshotMapper {
  static Future<List<WalletTransactionDetails>> toModels(
    sync.WalletTransactionSnapshot snapshot, {
    String? toAddress,
  }) async {
    final liquid = snapshot.key.chain == 'liquid';
    final testnet = snapshot.key.network == 'testnet';
    final result = <WalletTransactionDetails>[];
    for (final transaction in snapshot.transactions) {
      if (toAddress != null && toAddress.isNotEmpty) {
        final matches = liquid
            ? transaction.outputs.any(
                (output) =>
                    output.standardAddress == toAddress ||
                    output.confidentialAddress == toAddress,
              )
            : await Future.any(
                transaction.outputs.map((output) async {
                  final address =
                      await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                        _bytes(_required(output.script)),
                        isTestnet: testnet,
                      );
                  return address != null && address == toAddress;
                }),
              ).catchError((_) => false);
        if (!matches) continue;
      }
      final time = switch (transaction.position) {
        sync.AnchoredPosition(:final time) => time,
        sync.SourceReportedConfirmedPosition(:final time) => time,
        sync.UnconfirmedPosition(:final firstSeen) when liquid => firstSeen,
        _ => null,
      };
      result.add(
        WalletTransactionDetails(
          txId: transaction.txid,
          isIncoming:
              transaction.direction == sync.TransactionDirection.incoming,
          amountSat: _required(transaction.displayAmountSats),
          feeSat: transaction.feeSats,
          vsize: _required(transaction.vsize),
          isRbf: _required(transaction.isRbf),
          isToSelf: _required(transaction.displaySelfTransfer),
          confirmationTimestamp: time == null
              ? null
              : time.millisecondsSinceEpoch ~/ 1000,
          isLiquid: liquid,
          isTestnet: testnet,
          inputs: [
            for (final (index, input) in transaction.inputs.indexed)
              if (liquid)
                TransactionInputDetails.liquid(
                  txId: transaction.txid,
                  vin: index,
                  isOwn: _required(input.isOwn),
                  value: BigInt.from(_required(input.value)),
                  scriptPubkey: _required(input.script),
                  previousTxId: input.txid,
                  previousTxVout: input.vout,
                )
              else
                TransactionInputDetails.bitcoin(
                  txId: transaction.txid,
                  vin: _required(input.originalIndex),
                  isOwn: _required(input.isOwn),
                  scriptSig: _bytes(_required(input.scriptSig)),
                  previousTxId: input.txid,
                  previousTxVout: input.vout,
                ),
          ],
          outputs: [
            for (final output in transaction.outputs)
              if (liquid)
                TransactionOutputDetails.liquid(
                  txId: transaction.txid,
                  vout: output.originalIndex,
                  isOwn: _required(output.isOwn),
                  value: BigInt.from(output.valueSats),
                  scriptPubkey: _required(output.script),
                  address: _required(output.confidentialAddress),
                )
              else
                TransactionOutputDetails.bitcoin(
                  txId: transaction.txid,
                  vout: output.originalIndex,
                  isOwn: _required(output.isOwn),
                  value: BigInt.from(output.valueSats),
                  scriptPubkey: _bytes(_required(output.script)),
                  address: output.standardAddress,
                  isChange: output.chain == sync.TransactionChain.internal,
                ),
          ],
        ),
      );
    }
    return result;
  }

  static T _required<T>(T? value) {
    if (value == null) {
      throw StateError('Wallet display evidence is unavailable');
    }
    return value;
  }

  static Uint8List _bytes(String hex) => Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}
