import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_table.dart';
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
    await _pumpInFrench(tester, Transaction(order: _buyOrder()));

    expect(find.text('17 nov. 2026 17:08'), findsOneWidget);
  });
}

Future<void> _pumpInFrench(WidgetTester tester, Transaction transaction) async {
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
      locale: const Locale('fr'),
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
        child: SettingsFacade.amountScope(
          navigatorKey: navigatorKey,
          child: const Scaffold(
            body: SingleChildScrollView(child: TransactionDetailsTable()),
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
