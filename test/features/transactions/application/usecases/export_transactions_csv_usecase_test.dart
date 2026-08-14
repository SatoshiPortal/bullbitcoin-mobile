import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/adapters/csv_transaction_export_formatter.dart';
import 'package:bb_mobile/features/transactions/application/application_errors.dart';
import 'package:bb_mobile/features/transactions/application/usecases/export_transactions_csv_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Sats;

class _MockGetTransactionsUsecase extends Mock
    implements GetTransactionsUsecase {}

WalletTransaction _walletTx({
  required String txId,
  required int amountSat,
  Network network = Network.bitcoinMainnet,
  WalletTransactionDirection direction = WalletTransactionDirection.incoming,
  int feeSat = 0,
  DateTime? confirmationTime,
}) {
  return WalletTransaction(
    walletId: 'w1',
    network: network,
    direction: direction,
    status: WalletTransactionStatus.confirmed,
    txId: txId,
    amountSat: amountSat,
    feeSat: feeSat,
    vsize: 110,
    inputs: const [],
    outputs: const [],
    isRbf: false,
    confirmationTime: confirmationTime,
  );
}

Swap _lnReceive({String id = 'swap_ln_recv', String? receiveTxid}) =>
    Swap.lnReceive(
      id: id,
      keyIndex: 0,
      type: SwapType.lightningToBitcoin,
      status: SwapStatus.completed,
      environment: Environment.mainnet,
      creationTime: DateTime.utc(2026, 3, 1, 12),
      receiveWalletId: 'w1',
      invoice: 'lnbc_test_invoice_recv',
      receiveTxid: receiveTxid,
    );

Swap _lnSend({
  String id = 'swap_ln_send',
  String? sendTxid,
  String? preimage,
}) => Swap.lnSend(
  id: id,
  keyIndex: 0,
  type: SwapType.bitcoinToLightning,
  status: SwapStatus.completed,
  environment: Environment.mainnet,
  creationTime: DateTime.utc(2026, 3, 2, 14),
  sendWalletId: 'w1',
  invoice: 'lnbc_test_invoice_send',
  paymentAddress: 'bc1qpayaddr',
  paymentAmount: 50000,
  sendTxid: sendTxid,
  preimage: preimage,
);

Swap _chainSwap({
  String id = 'swap_chain',
  String? sendTxid,
  String? receiveTxid,
  String? receiveAddress,
  SwapType type = SwapType.bitcoinToLiquid,
  DateTime? completionTime,
  SwapFees? fees,
}) => Swap.chain(
  id: id,
  keyIndex: 0,
  type: type,
  status: SwapStatus.completed,
  environment: Environment.mainnet,
  creationTime: DateTime.utc(2026, 3, 3, 10),
  sendWalletId: 'w1',
  paymentAddress: 'bc1qsendaddr',
  paymentAmount: 100000,
  sendTxid: sendTxid,
  receiveWalletId: 'w2',
  receiveAddress: receiveAddress,
  receiveTxid: receiveTxid,
  completionTime: completionTime,
  fees: fees,
);

void main() {
  late _MockGetTransactionsUsecase getTransactions;
  late ExportTransactionsCsvUsecase usecase;

  setUp(() {
    getTransactions = _MockGetTransactionsUsecase();
    usecase = ExportTransactionsCsvUsecase(
      getTransactionsUsecase: getTransactions,
      formatter: CsvTransactionExportFormatter(),
    );
  });

  void stub(List<Transaction> txs) {
    when(() => getTransactions.execute()).thenAnswer((_) async => txs);
  }

  test('emits a header and one row per transaction', () async {
    stub([
      Transaction(
        walletTransaction: _walletTx(
          txId: 'abc',
          amountSat: 500000,
          confirmationTime: DateTime.utc(2026, 1, 15, 10, 30),
        ),
      ),
    ]);

    final csv = await usecase.execute();
    final lines = csv.trim().split('\n');

    expect(lines.length, 2);
    expect(lines.first, startsWith('date,type,direction,amount_sats'));
    final row = lines[1].split(',');
    expect(row[0], '2026-01-15T10:30:00Z');
    expect(row[1], 'onchain');
    expect(row[2], 'incoming');
    expect(row[3], '500000');
    expect(row[4], '0.00500000');
    expect(row[7], 'abc');
    expect(row[8], 'bitcoin');
  });

  test('marks liquid transactions with the liquid network and type', () async {
    stub([
      Transaction(
        walletTransaction: _walletTx(
          txId: 'lq',
          amountSat: 200000,
          network: Network.liquidMainnet,
          direction: WalletTransactionDirection.outgoing,
          feeSat: 350,
          confirmationTime: DateTime.utc(2026, 2, 1, 8),
        ),
      ),
    ]);

    final row = (await usecase.execute()).trim().split('\n')[1].split(',');
    expect(row[1], 'liquid');
    expect(row[2], 'outgoing');
    expect(row[5], '350');
    expect(row[8], 'liquid');
  });

  test('filters by inclusive date range, end rounds to end of day', () async {
    stub([
      Transaction(
        walletTransaction: _walletTx(
          txId: 'before',
          amountSat: 1,
          confirmationTime: DateTime.utc(2025, 12, 31, 23, 59),
        ),
      ),
      Transaction(
        walletTransaction: _walletTx(
          txId: 'inside',
          amountSat: 2,
          confirmationTime: DateTime.utc(2026, 1, 15, 18),
        ),
      ),
      Transaction(
        walletTransaction: _walletTx(
          txId: 'after',
          amountSat: 3,
          confirmationTime: DateTime.utc(2026, 1, 16, 0, 1),
        ),
      ),
    ]);

    final csv = await usecase.execute(
      start: DateTime.utc(2026, 1, 1),
      end: DateTime.utc(2026, 1, 15),
    );

    expect(csv, contains('inside'));
    expect(csv, isNot(contains('before')));
    expect(csv, isNot(contains('after')));
  });

  test('null-timestamp tx is excluded when a date range is set', () async {
    stub([
      Transaction(
        walletTransaction: _walletTx(
          txId: 'has_time',
          amountSat: 1000,
          confirmationTime: DateTime.utc(2026, 1, 10),
        ),
      ),
      Transaction(
        walletTransaction: _walletTx(
          txId: 'no_time',
          amountSat: 2000,
          confirmationTime: null,
        ),
      ),
    ]);

    final csv = await usecase.execute(
      start: DateTime.utc(2026, 1, 1),
      end: DateTime.utc(2026, 1, 31),
    );

    expect(csv, contains('has_time'));
    expect(csv, isNot(contains('no_time')));
  });

  test(
    'swap status takes precedence over confirmed wallet tx status',
    () async {
      final swap = _lnReceive(receiveTxid: 'recv_txid');
      stub([
        Transaction(
          swap: swap.copyWith(status: SwapStatus.claimable),
          walletTransaction: _walletTx(
            txId: 'recv_txid',
            amountSat: 80000,
            confirmationTime: DateTime.utc(2026, 3, 1, 12),
          ),
        ),
      ]);

      final row = (await usecase.execute()).trim().split('\n')[1].split(',');
      expect(row[6], 'pending');
    },
  );

  test('throws NoTransactionsToExportError when list is empty', () async {
    stub([]);
    expect(
      () => usecase.execute(),
      throwsA(isA<NoTransactionsToExportError>()),
    );
  });

  test('throws InvalidDateRangeError when start is after end', () async {
    stub([]);
    expect(
      () => usecase.execute(
        start: DateTime.utc(2026, 2, 1),
        end: DateTime.utc(2026, 1, 1),
      ),
      throwsA(isA<InvalidDateRangeError>()),
    );
  });

  test('sorts newest-first', () async {
    stub([
      Transaction(
        walletTransaction: _walletTx(
          txId: 'old',
          amountSat: 1,
          confirmationTime: DateTime.utc(2026, 1, 1),
        ),
      ),
      Transaction(
        walletTransaction: _walletTx(
          txId: 'new',
          amountSat: 2,
          confirmationTime: DateTime.utc(2026, 6, 1),
        ),
      ),
    ]);

    final lines = (await usecase.execute()).trim().split('\n');
    expect(lines[1], contains('new'));
    expect(lines[2], contains('old'));
  });

  test(
    'LN receive swap row has empty network and address, correct type',
    () async {
      final swap = _lnReceive(receiveTxid: 'recv_txid');
      stub([
        Transaction(
          swap: swap,
          walletTransaction: _walletTx(
            txId: 'recv_txid',
            amountSat: 80000,
            confirmationTime: DateTime.utc(2026, 3, 1, 12),
          ),
        ),
      ]);

      final row = (await usecase.execute()).trim().split('\n')[1].split(',');
      expect(row[1], 'lightning_receive');
      expect(row[2], 'incoming');
      expect(row[8], 'lightning'); // network
      expect(row[9], ''); // address
      expect(row[10], 'swap_ln_recv'); // swap_id
      expect(row[11], ''); // preimage (none for receive)
    },
  );

  test('LN send swap row has preimage, empty network and address', () async {
    final swap = _lnSend(sendTxid: 'send_txid', preimage: 'abc123preimage');
    stub([
      Transaction(
        swap: swap,
        walletTransaction: _walletTx(
          txId: 'send_txid',
          amountSat: 50000,
          direction: WalletTransactionDirection.outgoing,
          feeSat: 120,
          confirmationTime: DateTime.utc(2026, 3, 2, 14),
        ),
      ),
    ]);

    final row = (await usecase.execute()).trim().split('\n')[1].split(',');
    expect(row[1], 'lightning_send');
    expect(row[2], 'outgoing');
    expect(row[8], 'lightning'); // network
    expect(row[9], ''); // address
    expect(row[10], 'swap_ln_send'); // swap_id
    expect(row[11], 'abc123preimage'); // preimage
  });

  test(
    'chain swap: both legs exported with direction-specific network',
    () async {
      final swap = _chainSwap(
        sendTxid: 'chain_send_txid',
        receiveTxid: 'chain_recv_txid',
        receiveAddress: 'VJLCbLBTCksDqx1',
        type: SwapType.bitcoinToLiquid,
        completionTime: DateTime.utc(2026, 3, 3, 12),
        fees: const SwapFees(lockupFee: 500, claimFee: 200),
      );
      stub([
        Transaction(
          swap: swap,
          walletTransaction: _walletTx(
            txId: 'chain_send_txid',
            amountSat: 100000,
            direction: WalletTransactionDirection.outgoing,
            confirmationTime: DateTime.utc(2026, 3, 3, 10),
          ),
        ),
        Transaction(
          swap: swap,
          walletTransaction: _walletTx(
            txId: 'chain_recv_txid',
            amountSat: 99000,
            network: Network.liquidMainnet,
            direction: WalletTransactionDirection.incoming,
            confirmationTime: DateTime.utc(2026, 3, 3, 11),
          ),
        ),
      ]);

      final lines = (await usecase.execute()).trim().split('\n');
      expect(lines.length, 3, reason: 'both legs are exported');

      final rowsByTxid = {
        for (final line in lines.skip(1)) line.split(',')[7]: line.split(','),
      };
      final sendRow = rowsByTxid['chain_send_txid']!;
      final receiveRow = rowsByTxid['chain_recv_txid']!;

      expect(sendRow[1], 'chain_swap');
      expect(sendRow[2], 'outgoing');
      expect(sendRow[5], '500'); // fee_sats = lockup fee
      expect(sendRow[8], 'bitcoin'); // network = send network for outgoing leg
      expect(
        sendRow[0],
        '2026-03-03T10:00:00Z',
      ); // date = outgoing leg's block time
      expect(sendRow[13], 'bitcoin'); // send_network
      expect(sendRow[14], 'liquid'); // receive_network

      expect(receiveRow[1], 'chain_swap');
      expect(receiveRow[2], 'incoming');
      expect(receiveRow[5], '200'); // fee_sats = claim fee
      expect(
        receiveRow[8],
        'liquid',
      ); // network = receive network for incoming leg
      expect(
        receiveRow[0],
        '2026-03-03T11:00:00Z',
      ); // date = incoming leg's block time
      expect(receiveRow[9], 'VJLCbLBTCksDqx1'); // address = receiveAddress
      expect(receiveRow[13], 'bitcoin');
      expect(receiveRow[14], 'liquid');
    },
  );

  test(
    'incoming leg without confirmationTime falls back to swap.completionTime',
    () async {
      final swap = _chainSwap(
        sendTxid: 'chain_send_a',
        receiveTxid: 'chain_recv_a',
        type: SwapType.bitcoinToLiquid,
        completionTime: DateTime.utc(2026, 4, 1, 9, 30),
      );
      stub([
        Transaction(
          swap: swap,
          walletTransaction: _walletTx(
            txId: 'chain_send_a',
            amountSat: 100000,
            direction: WalletTransactionDirection.outgoing,
            confirmationTime: DateTime.utc(2026, 4, 1, 8),
          ),
        ),
        Transaction(
          swap: swap,
          walletTransaction: _walletTx(
            txId: 'chain_recv_a',
            amountSat: 99000,
            network: Network.liquidMainnet,
            direction: WalletTransactionDirection.incoming,
            confirmationTime: null, // claim tx not yet seen confirmed
          ),
        ),
      ]);

      final lines = (await usecase.execute()).trim().split('\n');
      final rowsByTxid = {
        for (final line in lines.skip(1)) line.split(',')[7]: line.split(','),
      };
      // outgoing leg: its own block time
      expect(rowsByTxid['chain_send_a']![0], '2026-04-01T08:00:00Z');
      // incoming leg: falls back to swap.completionTime
      expect(rowsByTxid['chain_recv_a']![0], '2026-04-01T09:30:00Z');
    },
  );

  test(
    'incoming leg with neither confirmationTime nor completionTime falls back to outgoing leg time',
    () async {
      final swap = _chainSwap(
        sendTxid: 'chain_send_b',
        receiveTxid: 'chain_recv_b',
        type: SwapType.bitcoinToLiquid,
      );
      stub([
        Transaction(
          swap: swap,
          walletTransaction: _walletTx(
            txId: 'chain_send_b',
            amountSat: 100000,
            direction: WalletTransactionDirection.outgoing,
            confirmationTime: DateTime.utc(2026, 4, 2, 8),
          ),
        ),
        Transaction(
          swap: swap,
          walletTransaction: _walletTx(
            txId: 'chain_recv_b',
            amountSat: 99000,
            network: Network.liquidMainnet,
            direction: WalletTransactionDirection.incoming,
            confirmationTime: null,
          ),
        ),
      ]);

      final lines = (await usecase.execute()).trim().split('\n');
      final rowsByTxid = {
        for (final line in lines.skip(1)) line.split(',')[7]: line.split(','),
      };
      expect(rowsByTxid['chain_send_b']![0], '2026-04-02T08:00:00Z');
      // incoming leg has no own confirmation and no completion → outgoing leg's time
      expect(rowsByTxid['chain_recv_b']![0], '2026-04-02T08:00:00Z');
    },
  );

  test('chain swap with only send leg (no receive yet) is kept', () async {
    final swap = _chainSwap(sendTxid: 'chain_send_only', receiveTxid: null);
    stub([
      Transaction(
        swap: swap,
        walletTransaction: _walletTx(
          txId: 'chain_send_only',
          amountSat: 100000,
          direction: WalletTransactionDirection.outgoing,
          confirmationTime: DateTime.utc(2026, 3, 3, 10),
        ),
      ),
    ]);

    final lines = (await usecase.execute()).trim().split('\n');
    expect(lines.length, 2);
    final row = lines[1].split(',');
    expect(row, contains('chain_send_only'));
    expect(row[8], 'bitcoin'); // network = send network (the kept leg)
  });

  test('expired swaps are excluded from the export', () async {
    stub([
      Transaction(
        swap: _lnSend(
          id: 'expired_swap',
          sendTxid: 'expired_tx',
        ).copyWith(status: SwapStatus.expired),
        walletTransaction: _walletTx(
          txId: 'expired_tx',
          amountSat: 50000,
          direction: WalletTransactionDirection.outgoing,
          confirmationTime: DateTime.utc(2026, 3, 2, 14),
        ),
      ),
      Transaction(
        walletTransaction: _walletTx(
          txId: 'non_swap_tx',
          amountSat: 30000,
          confirmationTime: DateTime.utc(2026, 3, 4, 10),
        ),
      ),
    ]);

    final csv = await usecase.execute();
    expect(csv, isNot(contains('expired_swap')));
    expect(csv, isNot(contains('expired_tx')));
    expect(csv, contains('non_swap_tx'));
  });

  test('payjoin send row has correct type and bitcoin network', () async {
    final payjoin = PayjoinSenderSession(
      status: PayjoinStatus.requested,
      uri: 'pj://test',
      network: BitcoinNetwork.mainnet,
      walletId: 'w1',
      originalTransactionId: 'pj_orig_txid',
      amount: Sats.fromInt(75000),
      createdAt: DateTime.utc(2026, 4, 1, 9),
      expiresAt: DateTime.utc(2026, 4, 1, 10),
    );
    stub([Transaction(payjoin: payjoin)]);

    final row = (await usecase.execute()).trim().split('\n')[1].split(',');
    expect(row[1], 'payjoin_send');
    expect(row[2], 'outgoing');
    expect(row[8], 'bitcoin');
  });

  test('payjoin receive row has correct type', () async {
    final payjoin = PayjoinReceiverSession(
      status: PayjoinStatus.started,
      id: 'pj_recv_id',
      network: BitcoinNetwork.mainnet,
      walletId: 'w1',
      payjoinUri: 'pj://recv',
      createdAt: DateTime.utc(2026, 4, 2, 11),
      expiresAt: DateTime.utc(2026, 4, 2, 12),
      amount: Sats.fromInt(60000),
    );
    stub([Transaction(payjoin: payjoin)]);

    final row = (await usecase.execute()).trim().split('\n')[1].split(',');
    expect(row[1], 'payjoin_receive');
    expect(row[2], 'incoming');
    expect(row[8], 'bitcoin');
  });
}
