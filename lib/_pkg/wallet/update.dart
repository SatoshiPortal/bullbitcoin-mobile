import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletUpdate {
  // sync bdk wallet, import state from wallet into new native type
  // if native type exists, only update
  // for every new tx:
  // check collect vins and vouts
  // check for related addresses and inherit labels
  Future<(Wallet?, Err?)> syncWalletTxsAndAddresses({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      // sync bdk wallet, import state from wallet into new native type
      // if native type exists, only update
      // for every new tx:
      // check collect vins and vouts
      // check for related addresses and inherit labels

      final storedTxs = wallet.transactions ?? [];
      final storedAddrs = wallet.addresses ?? [];
      final storedToAddrs = wallet.toAddresses ?? [];
      print('storedAddrs: $storedAddrs');
      print('storedToAddrs: $storedToAddrs');
      final txs = await bdkWallet.listTransactions(true);
      // final x = bdk.TxBuilderResult();
      if (txs.isEmpty) throw 'No bdk transactions found';

      if (txs.length > storedTxs.length) {
        print('${txs.length - storedTxs.length} NEW TXS');
        // only for these transactions, also update addresses linked
      }
      if (txs.length == storedTxs.length) {
        print('NO NEW TXS');
      }
      if (storedTxs.length > txs.length) {
        print(
          '!!!${storedTxs.length - txs.length} extra transaction in Wallet compared to bdkWallet.',
        );
      }
      final List<Transaction> transactions = [];
      for (final tx in txs) {
        final idx = storedTxs.indexWhere((t) => t.txid == tx.txid);
        Transaction? storedTx;
        if (idx != -1) storedTx = storedTxs.elementAtOrNull(idx);
        if (storedTx != null) {
          print('Tx already exists, update');
        } else {
          print('Tx does not exist, must be added.');
          print('Addresses related to tx must be added and label inherited.');
          // send txs will have the address we send to and our change both to inherit the same label
          // recieve tx will have our deposit address
        }

        final txObj = Transaction(
          txid: tx.txid,
          received: tx.received,
          sent: tx.sent,
          fee: tx.fee ?? 0,
          height: tx.confirmationTime?.height ?? 0,
          timestamp: tx.confirmationTime?.timestamp ?? 0,
          bdkTx: tx,
          rbfEnabled: storedTx?.rbfEnabled ?? false,
          // label: label,
        );
        const label = '';
        final outputs = await tx.transaction?.output();
        print('recd: ${tx.received}');
        print('sent: ${tx.sent}');

        for (final out in outputs!) {
          late Address? linkedAddress;

          final addresss = await bdk.Address.fromScript(
            out.scriptPubkey,
            wallet.getBdkNetwork(),
          );
          final addressStr = addresss.toString();
          if (txObj.isReceived()) {
            if (out.value == tx.received) {
              print('DEPOSIT');
              linkedAddress = Address(
                address: addressStr,
                index: -1,
                isReceive: true,
              );
            } else {
              print('SENDERS CHANGE');
              linkedAddress = Address(
                address: addressStr,
                index: -1,
                isReceive: true,
                isMine: false,
              );
            }
          } else {
            if (out.value == (tx.received)) {
              // this is change
              linkedAddress = Address(
                address: addressStr,
                label: 'inherit-tx-label',
                index: -1,
                isReceive: false,
              );
              print('CHANGE');
            } else {
              linkedAddress = Address(
                address: addressStr,
                index: -1,
                isReceive: false,
                isMine: false,
              );
              print('TO');
            }
          }
          print('$linkedAddress');
        }
        print('Check to match address with transaction');

        transactions.add(txObj.copyWith(label: label));
      }

      final w = wallet.copyWith(transactions: transactions);

      return (w, null);
    } catch (e) {
      return (null, Err(e.toString(), expected: e.toString() == 'No bdk transactions found'));
    }
  }
}
