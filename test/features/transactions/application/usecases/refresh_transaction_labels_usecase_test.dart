import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/transactions/application/usecases/refresh_transaction_labels_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsFacade extends Mock implements LabelsFacade {}

WalletTransaction _walletTransaction({
  required String txId,
  List<Label> labels = const [],
}) {
  return WalletTransaction(
    walletId: 'wallet-1',
    network: Network.bitcoinMainnet,
    direction: WalletTransactionDirection.incoming,
    status: WalletTransactionStatus.confirmed,
    txId: txId,
    amountSat: 100000,
    feeSat: 0,
    vsize: 141,
    inputs: const [],
    outputs: const [],
    labels: labels,
    isRbf: false,
  );
}

void main() {
  late _MockLabelsFacade labelsFacade;
  late RefreshTransactionLabelsUsecase usecase;

  setUp(() {
    labelsFacade = _MockLabelsFacade();
    usecase = RefreshTransactionLabelsUsecase(labelsFacade: labelsFacade);
  });

  void stubLabels(List<Label> labels) {
    when(labelsFacade.fetchAllOrFailure).thenAnswer((_) async => Ok(labels));
  }

  test('picks up a label added after the transactions were loaded', () async {
    final added = Label.tx(id: 1, transactionId: 'txid-1', label: 'rent');
    stubLabels([added]);

    final refreshed = await usecase.execute([
      Transaction(walletTransaction: _walletTransaction(txId: 'txid-1')),
    ]);

    expect(refreshed.single.labels, [added]);
  });

  test('drops a label that was deleted', () async {
    final removed = Label.tx(id: 1, transactionId: 'txid-1', label: 'rent');
    stubLabels([]);

    final refreshed = await usecase.execute([
      Transaction(
        walletTransaction: _walletTransaction(
          txId: 'txid-1',
          labels: [removed],
        ),
      ),
    ]);

    expect(refreshed.single.labels, isEmpty);
  });

  test('only touches the transaction the label belongs to', () async {
    final label = Label.tx(id: 1, transactionId: 'txid-2', label: 'rent');
    stubLabels([label]);

    final refreshed = await usecase.execute([
      Transaction(walletTransaction: _walletTransaction(txId: 'txid-1')),
      Transaction(walletTransaction: _walletTransaction(txId: 'txid-2')),
    ]);

    expect(refreshed.first.labels, isEmpty);
    expect(refreshed.last.labels, [label]);
  });

  test('ignores labels stored against an address, not a transaction', () async {
    stubLabels([Label.addr(id: 1, address: 'bc1q', label: 'x')]);

    final refreshed = await usecase.execute([
      Transaction(walletTransaction: _walletTransaction(txId: 'txid-1')),
    ]);

    expect(refreshed.single.labels, isEmpty);
  });

  test('keeps the labels it has when the read fails, instead of blanking '
      'every row', () async {
    final existing = Label.tx(id: 1, transactionId: 'txid-1', label: 'rent');
    when(labelsFacade.fetchAllOrFailure).thenAnswer(
      (_) async => const Err(LabelUnexpectedFailure('database is locked')),
    );

    final transactions = [
      Transaction(
        walletTransaction: _walletTransaction(
          txId: 'txid-1',
          labels: [existing],
        ),
      ),
    ];

    expect(
      identical(await usecase.execute(transactions), transactions),
      isTrue,
    );
  });

  test('returns the same list when no label changed, so the cubit can '
      'skip emitting', () async {
    final unchanged = Label.tx(id: 1, transactionId: 'txid-1', label: 'rent');
    stubLabels([unchanged]);

    final transactions = [
      Transaction(
        walletTransaction: _walletTransaction(
          txId: 'txid-1',
          labels: [unchanged],
        ),
      ),
    ];

    expect(
      identical(await usecase.execute(transactions), transactions),
      isTrue,
    );
  });

  test('does not read storage for a list with no wallet transaction, such '
      'as an exchange-only list', () async {
    final transactions = [const Transaction()];

    expect(
      identical(await usecase.execute(transactions), transactions),
      isTrue,
    );
    verifyNever(labelsFacade.fetchAllOrFailure);
  });

  test('does not read storage when there is nothing loaded yet', () async {
    expect(await usecase.execute(const []), isEmpty);

    verifyNever(labelsFacade.fetchAllOrFailure);
  });
}
