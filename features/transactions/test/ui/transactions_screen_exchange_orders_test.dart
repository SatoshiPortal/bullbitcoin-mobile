import 'package:bull_ui/app_theme.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:transactions/generated/l10n/transactions_localizations.dart';
import 'package:transactions/src/ui/screens/transactions_screen.dart';
import 'package:transactions/testing.dart';

class _Read extends Mock implements GetTransactionsUsecase {}

class _Labels extends Mock implements RefreshTransactionLabelsUsecase {}

const _notice = 'Exchange orders could not be loaded.';

void main() {
  late _Read read;
  late TransactionsCubit cubit;
  late int reads;

  void answer(ExchangeOrdersInHistory exchangeOrders) {
    when(
      () => read.execute(
        walletId: any(named: 'walletId'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((_) async {
      reads++;
      return Ok(
        TransactionHistory(transactions: [], exchangeOrders: exchangeOrders),
      );
    });
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates:
            TransactionsLocalizations.localizationsDelegates,
        supportedLocales: TransactionsLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: TransactionsScreen(refreshWallets: (_) async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    reads = 0;
    read = _Read();
    cubit = TransactionsCubit(
      getTransactionsUsecase: read,
      refreshTransactionLabelsUsecase: _Labels(),
      watchStartedWalletSyncsUsecase: const Stream.empty(),
      watchFinishedWalletSyncsUsecase: const Stream.empty(),
    );
  });

  tearDown(() => cubit.close());

  testWidgets('a failed order read shows the notice, and Retry reloads', (
    tester,
  ) async {
    answer(const ExchangeOrdersUnavailable(ExchangeNetworkFailure()));
    await cubit.loadTxs();
    await pumpScreen(tester);

    expect(find.text(_notice), findsOneWidget);
    expect(reads, 1);

    answer(const ExchangeOrdersMerged());
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(reads, 2);
    expect(find.text(_notice), findsNothing);
  });

  for (final quiet in const <ExchangeOrdersInHistory>[
    ExchangeOrdersMerged(),
    ExchangeOrdersNoAccount(),
    ExchangeOrdersNotOffered(),
  ]) {
    testWidgets('${quiet.runtimeType} shows no notice', (tester) async {
      answer(quiet);
      await cubit.loadTxs();
      await pumpScreen(tester);

      expect(find.text(_notice), findsNothing);
    });
  }
}
