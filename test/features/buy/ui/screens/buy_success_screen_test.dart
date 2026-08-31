import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_success_screen.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuyBloc extends Mock implements BuyBloc {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBuyOrder extends Mock implements BuyOrder {}

void main() {
  testWidgets('view details opens the transaction order details route', (
    tester,
  ) async {
    final buyBloc = _MockBuyBloc();
    final settingsCubit = _MockSettingsCubit();
    final order = _MockBuyOrder();
    when(() => buyBloc.state).thenReturn(BuyState(buyOrder: order));
    when(
      () => buyBloc.stream,
    ).thenAnswer((_) => const Stream<BuyState>.empty());
    when(() => settingsCubit.state).thenReturn(
      const SettingsState(
        storedSettings: SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SettingsState>.empty());
    when(() => order.orderId).thenReturn('order-42');
    when(() => order.payoutAmount).thenReturn(0.001);
    when(() => order.payinAmount).thenReturn(100.0);
    when(() => order.payinCurrency).thenReturn('CAD');
    when(() => order.bitcoinAddress).thenReturn(null);
    when(() => order.transactionId).thenReturn(null);
    when(() => order.scheduledPayoutTime).thenReturn(null);
    when(() => order.payjoinOutcome).thenReturn(OrderPayjoinOutcome.none);

    final router = GoRouter(
      initialLocation: '/buy/success',
      routes: [
        GoRoute(
          path: '/buy/success',
          name: BuyRoute.buySuccess.name,
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<BuyBloc>.value(value: buyBloc),
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
            ],
            child: const BuySuccessScreen(),
          ),
        ),
        GoRoute(
          path: '/transaction/order/:orderId',
          name: TransactionsRoute.orderTransactionDetails.name,
          builder: (context, state) => Text(state.pathParameters['orderId']!),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();

    expect(find.text('order-42'), findsOneWidget);
  });
}
