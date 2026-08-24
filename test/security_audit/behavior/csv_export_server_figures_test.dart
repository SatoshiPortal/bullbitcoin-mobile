// Behavioral proof for the second half of the CSV export finding
// (issue #2625 fix).
//
// `fix(transactions)` neutralised spreadsheet formulas but kept preferring the
// swap provider's reported figures over the on-chain truth the wallet already
// holds, so an exported accounting file still carries server-controlled fees.
import 'dart:typed_data';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/adapters/csv_transaction_export_formatter.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports the on-chain fee, not the fee the swap server claims', () {
    const onChainFeeSat = 250;
    const serverClaimedLockupFeeSat = 999999;

    final walletTransaction = WalletTransaction(
      walletId: 'wallet-1',
      network: Network.bitcoinMainnet,
      direction: WalletTransactionDirection.outgoing,
      status: WalletTransactionStatus.confirmed,
      txId: 'lockup-txid',
      amountSat: 50000,
      feeSat: onChainFeeSat,
      vsize: 141,
      inputs: const [],
      outputs: [
        TransactionOutput.bitcoin(
          txId: 'lockup-txid',
          vout: 0,
          isOwn: false,
          scriptPubkey: Uint8List(0),
          address: 'bc1qswap-lockup-address',
        ),
      ],
      isRbf: false,
    );

    final transaction = Transaction(
      walletTransaction: walletTransaction,
      swap: Swap.chain(
        id: 'swap-1',
        keyIndex: 0,
        type: SwapType.bitcoinToLiquid,
        status: SwapStatus.pending,
        environment: Environment.mainnet,
        creationTime: DateTime.utc(2026, 7, 29, 12),
        sendWalletId: 'wallet-1',
        paymentAddress: 'bc1qswap-lockup-address',
        paymentAmount: 50000,
        sendTxid: 'lockup-txid',
        fees: const SwapFees(lockupFee: serverClaimedLockupFeeSat),
      ),
    );

    final csv = CsvTransactionExportFormatter().format([transaction]);
    final rows = csv.trim().split('\n');
    final headers = rows.first.split(',');
    final feeColumn = headers.indexOf('fee_sats');
    final exportedFee = rows[1].split(',')[feeColumn];

    expect(
      exportedFee,
      onChainFeeSat.toString(),
      reason: 'the wallet knows the real miner fee for its own transaction',
    );
  });
}
