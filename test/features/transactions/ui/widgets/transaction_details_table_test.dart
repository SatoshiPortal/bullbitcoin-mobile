import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_table.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransactionDetailsCubit extends Mock
    implements TransactionDetailsCubit {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

void main() {
  testWidgets('copies the exact order swap order number', (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final detailsCubit = _MockTransactionDetailsCubit();
    final settingsCubit = _MockSettingsCubit();
    when(() => detailsCubit.state).thenReturn(
      TransactionDetailsState(
        transaction: Transaction(orderSwap: _orderSwap()),
      ),
    );
    when(
      () => detailsCubit.stream,
    ).thenAnswer((_) => const Stream<TransactionDetailsState>.empty());
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<TransactionDetailsCubit>.value(value: detailsCubit),
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
          ],
          child: const Scaffold(body: TransactionDetailsTable()),
        ),
      ),
    );

    final orderNumberItem = find.ancestor(
      of: find.text('123456'),
      matching: find.byType(DetailsTableItem),
    );
    await tester.tap(
      find.descendant(
        of: orderNumberItem,
        matching: find.byIcon(Icons.copy_outlined),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(copiedText, '123456');
  });
}

OrderSwapRecord _orderSwap() => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.receiveLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.lightning,
  outNetwork: OrderSwapNetwork.liquid,
  isInAmountFixed: true,
  requestedAmountSat: BigInt.from(1000),
  destinationWalletId: 'wallet-1',
  destination: 'tlq1destination',
  fallback: 'tlq1destination',
  order: OrderSwap(
    orderId: 'order-1',
    orderNumber: 123456,
    inNetwork: OrderSwapNetwork.lightning,
    outNetwork: OrderSwapNetwork.liquid,
    payinAmountSat: BigInt.from(1000),
    payoutAmountSat: BigInt.from(900),
    payinCurrency: 'BTCLN',
    payoutCurrency: 'LBTC',
    payinMethod: 'Lightning',
    payoutMethod: 'Liquid',
    orderType: 'Swap',
    orderStatus: 'In_pending',
    payinStatus: 'Awaiting payment',
    payoutStatus: 'Not started',
    messageCode: 'PAYMENT_NOT_DETECTED',
    lightningInvoice: 'invoice',
    liquidAddress: 'tlq1destination',
    createdAt: DateTime.utc(2026),
    confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
  ),
  createdAt: DateTime.utc(2026),
  localStatus: OrderSwapLocalStatus.awaitingUserConfirmation,
);
