import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transactions/testing.dart';

class _Read extends Mock implements GetTransactionsUsecase {}

class _Labels extends Mock implements RefreshTransactionLabelsUsecase {}

void main() {
  late _Read read;
  late TransactionsCubit cubit;

  void answer(ExchangeOrdersInHistory exchangeOrders) {
    when(
      () => read.execute(
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer(
      (_) async => Ok(
        TransactionHistory(transactions: [], exchangeOrders: exchangeOrders),
      ),
    );
  }

  setUp(() {
    read = _Read();
    cubit = TransactionsCubit(
      getTransactionsUsecase: read,
      refreshTransactionLabelsUsecase: _Labels(),
      watchStartedWalletSyncsUsecase: const Stream.empty(),
      watchFinishedWalletSyncsUsecase: const Stream.empty(),
    );
  });

  tearDown(() => cubit.close());

  test('nothing is known about exchange orders before the first read', () {
    expect(cubit.state.exchangeOrders, isNull);
  });

  test('a failed order read is held as unavailable, with the list', () async {
    answer(const ExchangeOrdersUnavailable(ExchangeNetworkFailure()));

    await cubit.loadTxs();

    expect(cubit.state.exchangeOrders, isA<ExchangeOrdersUnavailable>());
    expect(cubit.state.transactions, isEmpty);
    expect(cubit.state.failure, isNull);
  });

  test('a retry that reads the orders clears the unavailable state', () async {
    answer(const ExchangeOrdersUnavailable(ExchangeNetworkFailure()));
    await cubit.loadTxs();

    answer(const ExchangeOrdersMerged());
    await cubit.loadTxs();

    expect(cubit.state.exchangeOrders, isA<ExchangeOrdersMerged>());
  });

  test('a failed whole read keeps the last known order state', () async {
    answer(const ExchangeOrdersUnavailable(ExchangeNetworkFailure()));
    await cubit.loadTxs();
    when(
      () => read.execute(
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((_) async => const Err(TransactionAggregationFailure()));

    await cubit.loadTxs();

    expect(cubit.state.failure, isA<TransactionAggregationFailure>());
    expect(cubit.state.exchangeOrders, isA<ExchangeOrdersUnavailable>());
  });

  group('ExchangeOrdersInHistory.ofFailure', () {
    test('no stored account is no account', () {
      expect(
        ExchangeOrdersInHistory.ofFailure(
          const ExchangeNotAuthenticatedFailure(),
        ),
        isA<ExchangeOrdersNoAccount>(),
      );
    });

    for (final failure in const <ExchangeFailure>[
      ExchangeNetworkFailure(),
      ExchangeSessionRejectedFailure(),
      ExchangeCredentialReadFailure(),
      ExchangeOrderLoadFailure(),
      ExchangeUnexpectedFailure(),
    ]) {
      test('${failure.runtimeType} is unavailable, never an empty list', () {
        expect(
          ExchangeOrdersInHistory.ofFailure(failure),
          isA<ExchangeOrdersUnavailable>().having(
            (read) => read.failure,
            'failure',
            same(failure),
          ),
        );
      });
    }
  });
}
