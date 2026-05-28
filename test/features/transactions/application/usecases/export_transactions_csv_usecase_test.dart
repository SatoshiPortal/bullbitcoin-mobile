import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/labels/label.dart';
import 'package:bb_mobile/features/transactions/adapters/csv_transaction_export_formatter.dart';
import 'package:bb_mobile/features/transactions/application/usecases/export_transactions_csv_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_transactions_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetTransactionsUsecase extends Mock
    implements GetTransactionsUsecase {}

WalletTransaction _walletTx({
  required String txId,
  required int amountSat,
  Network network = Network.bitcoinMainnet,
  WalletTransactionDirection direction =
      WalletTransactionDirection.incoming,
  int feeSat = 0,
  DateTime? confirmationTime,
  List<Label> labels = const [],
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
    labels: labels,
  );
}

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

  test('escapes labels containing a comma', () async {
    stub([
      Transaction(
        walletTransaction: _walletTx(
          txId: 'abc',
          amountSat: 100,
          confirmationTime: DateTime.utc(2026, 1, 1),
          labels: [Label.tx(id: 1, transactionId: 'abc', label: 'rent, may')],
        ),
      ),
    ]);

    final csv = await usecase.execute();
    expect(csv, contains('"rent, may"'));
  });

  test('throws when there are no transactions to export', () async {
    stub([]);
    expect(
      () => usecase.execute(),
      throwsA(isA<NoTransactionsToExportError>()),
    );
  });
}
