import '../../support/transaction_ui_actions.dart';

import 'package:preferences/preferences.dart' show Environment, SettingsEntity;
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:exchange/exchange.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:settings/testing.dart';
import 'package:settings/settings.dart';
import 'package:transactions/testing.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;

class _MockTransactionDetailsCubit extends Mock
    implements TransactionDetailsCubit {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

void main() {
  testWidgets('dates an order in the app language and clock format', (
    tester,
  ) async {
    await _pump(tester, Transaction(order: _buyOrder()));

    expect(find.text('17 nov. 2026 17:08'), findsOneWidget);
  });

  testWidgets('dates an order in Latin script for Hinglish', (tester) async {
    await _pump(
      tester,
      Transaction(order: _buyOrder()),
      locale: const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
    );

    expect(find.textContaining('Nov 17, 2026'), findsOneWidget);
  });

  testWidgets('names the order type and statuses in the app language', (
    tester,
  ) async {
    await _pump(tester, Transaction(order: _buyOrder()));

    expect(find.text('Acheter du Bitcoin'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
    expect(find.text('Non démarré'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Transaction transaction, {
  Locale locale = const Locale('fr'),
}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  addTearDown(tester.view.reset);
  final detailsCubit = _MockTransactionDetailsCubit();
  final settingsCubit = _MockSettingsCubit();
  when(() => detailsCubit.state)
      .thenReturn(TransactionDetailsState(transaction: transaction));
  when(() => detailsCubit.stream)
      .thenAnswer((_) => const Stream<TransactionDetailsState>.empty());
  when(() => settingsCubit.state).thenReturn(
    const SettingsState(
      storedSettings: SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    ),
  );
  when(() => settingsCubit.stream)
      .thenAnswer((_) => const Stream<SettingsState>.empty());

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      locale: locale,
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: const [
        bullUiLocalizationsDelegate,
        ...appLocalizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<TransactionDetailsCubit>.value(value: detailsCubit),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
        ],
        child: Settings.amountScope(
          navigatorKey: navigatorKey,
          child: Scaffold(
            body: SingleChildScrollView(
              child: TransactionDetailsTable(actions: transactionUiActions),
            ),
          ),
        ),
      ),
    ),
  );
}

Order _buyOrder() => Order.buy(
  orderId: 'order-1',
  orderType: OrderType.buy,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 42,
  payinAmount: 100,
  payinCurrency: 'CAD',
  payoutAmount: 0.001,
  payoutCurrency: 'BTC',
  payinMethod: OrderPaymentMethod.eTransfer,
  payoutMethod: OrderPaymentMethod.eTransfer,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.completed,
  payoutStatus: OrderPayoutStatus.notStarted,
  createdAt: DateTime(2026, 11, 17, 17, 8),
  isTestnet: false,
);
