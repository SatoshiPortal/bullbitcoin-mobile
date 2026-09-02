import 'package:bb_mobile/core/exchange/domain/entity/historical_rate_series.dart';
import 'package:bb_mobile/core/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/historical_value/historical_value_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_historical_value.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends Mock implements HistoricalValueCubit {}

Transaction _incomingLiquid() => Transaction(
  walletTransaction: WalletTransaction(
    walletId: 'w1',
    network: Network.liquidMainnet,
    direction: WalletTransactionDirection.incoming,
    status: WalletTransactionStatus.confirmed,
    txId: 'tx1',
    amountSat: 1000000,
    feeSat: 100,
    vsize: 100,
    inputs: const [],
    outputs: const [],
    isRbf: false,
    confirmationTime: DateTime.utc(2026, 9, 1, 12),
  ),
);

HistoricalRateSeries _series() => HistoricalRateSeries.from(
  currency: 'USD',
  rates: [
    Rate(
      fromCurrency: 'BTC',
      toCurrency: 'USD',
      interval: RateTimelineInterval.fifteen,
      createdAt: DateTime.utc(2026, 9, 1, 12),
      indexPrice: 100000,
    ),
  ],
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders nothing, and does not throw, with no cubit in scope', (
    tester,
  ) async {
    // TransactionsByDayList lives in core/widgets and OngoingSwaps mounts its
    // own rows, so a list row can be built where nothing provides the cubit.
    // That must degrade to no value, never to a crash.
    await _pump(tester, TransactionHistoricalValue(tx: _incomingLiquid()));

    expect(tester.takeException(), isNull);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders the value when the cubit is in scope', (tester) async {
    final cubit = _MockCubit();
    when(
      () => cubit.state,
    ).thenReturn(HistoricalValueState(currencyCode: 'USD', series: _series()));
    when(
      () => cubit.stream,
    ).thenAnswer((_) => const Stream<HistoricalValueState>.empty());

    await _pump(
      tester,
      BlocProvider<HistoricalValueCubit>.value(
        value: cubit,
        child: TransactionHistoricalValue(tx: _incomingLiquid()),
      ),
    );

    // 1,000,000 sats at 100,000 USD/BTC is 1,000 USD.
    expect(find.textContaining('1,000'), findsOneWidget);
    expect(find.textContaining('when it confirmed'), findsOneWidget);
  });

  testWidgets('shows nothing before the cubit has loaded a currency', (
    tester,
  ) async {
    final cubit = _MockCubit();
    when(() => cubit.state).thenReturn(const HistoricalValueState());
    when(
      () => cubit.stream,
    ).thenAnswer((_) => const Stream<HistoricalValueState>.empty());

    await _pump(
      tester,
      BlocProvider<HistoricalValueCubit>.value(
        value: cubit,
        child: TransactionHistoricalValue(tx: _incomingLiquid()),
      ),
    );
    expect(find.byType(Text), findsNothing);
  });
}
