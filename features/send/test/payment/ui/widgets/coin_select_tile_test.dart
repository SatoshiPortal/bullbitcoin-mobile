import '../../testing/send_test_localizations.dart';

import 'package:send/setup.dart' show SendLocalizations;

import 'dart:typed_data';

import 'package:address_view/address_view.dart';
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/ui/widgets/coin_selection_bottom_sheet.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:coins/coins.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _SendCubit extends Mock implements SendCubit {}

void main() {
  final utxo = WalletUtxo.bitcoin(
    walletId: 'wallet-1',
    txId: 'a' * 64,
    vout: 0,
    scriptPubkey: Uint8List.fromList([0, 1, 2]),
    amountSat: BigInt.from(100000),
    address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
  );

  Future<_SendCubit> pumpSheet(
    WidgetTester tester, {
    required WalletUtxo coin,
    required bool selected,
    bool building = false,
  }) async {
    final cubit = _SendCubit();
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.state).thenReturn(
      SendState(
        bitcoinUnit: BitcoinUnit.sats,
        utxos: [coin],
        selectedUtxos: selected ? [coin] : [],
        buildingTransaction: building,
        confirmedAmountSat: 2000,
        exchangeRate: 100000,
      ),
    );
    when(() => cubit.utxoSelected(coin)).thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: sendTestLocalizationsDelegates,
        supportedLocales: SendLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<SendCubit>.value(
            value: cubit,
            child: const CoinSelectionBottomSheet(),
          ),
        ),
      ),
    );
    return cubit;
  }

  testWidgets('tapping an unselected checkbox reports the coin', (
    tester,
  ) async {
    final cubit = await pumpSheet(tester, coin: utxo, selected: false);
    await tester.tap(find.byType(BullCheckbox));
    await tester.pump();
    verify(() => cubit.utxoSelected(utxo)).called(1);
  });

  testWidgets('tapping a selected checkbox clears the coin', (tester) async {
    final cubit = await pumpSheet(tester, coin: utxo, selected: true);
    await tester.tap(find.byType(BullCheckbox));
    await tester.pump();
    verify(() => cubit.utxoSelected(utxo)).called(1);
  });

  testWidgets('tapping the amount toggles a selected coin', (tester) async {
    final cubit = await pumpSheet(tester, coin: utxo, selected: true);
    await tester.tap(find.byKey(ValueKey(utxo.outpoint)));
    await tester.pump();
    verify(() => cubit.utxoSelected(utxo)).called(1);
  });

  testWidgets('shows the coin confirmation count', (tester) async {
    await pumpSheet(
      tester,
      coin: utxo.copyWith(confirmations: 6),
      selected: false,
    );
    expect(find.text('6 confirmations'), findsOneWidget);
  });

  testWidgets('keeps a gap between the address and type label', (tester) async {
    await pumpSheet(tester, coin: utxo, selected: false);
    final addressEnd = tester.getTopRight(find.byType(AddressViewer)).dx;
    final typeStart = tester.getTopLeft(find.text('Type: ')).dx;
    expect(typeStart - addressEnd, greaterThanOrEqualTo(8));
  });

  testWidgets('shows Liquid confirmation status without a keychain label', (
    tester,
  ) async {
    final liquid = LiquidWalletUtxo(
      walletId: 'liquid',
      txId: 'tx',
      vout: 0,
      scriptPubkey: '',
      amountSat: BigInt.from(10000),
      standardAddress: 'tex1own',
      confidentialAddress: 'tlq1own',
      blockHeight: 100,
    );
    await pumpSheet(tester, coin: liquid, selected: true);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Receive'), findsNothing);
    await pumpSheet(
      tester,
      coin: liquid.copyWith(blockHeight: null),
      selected: true,
    );
    expect(find.text('Unconfirmed'), findsOneWidget);
  });

  testWidgets('allows automatic selection and waits for a selected build', (
    tester,
  ) async {
    await pumpSheet(tester, coin: utxo, selected: false, building: true);
    expect(
      tester.widget<BullButton>(find.byType(BullButton)).disabled,
      isFalse,
    );
    await pumpSheet(tester, coin: utxo, selected: true, building: true);
    expect(tester.widget<BullButton>(find.byType(BullButton)).disabled, isTrue);
  });

  testWidgets('does not offer frozen coins', (tester) async {
    await pumpSheet(
      tester,
      coin: utxo.copyWith(isFrozen: true),
      selected: false,
    );
    expect(find.byType(BullCheckbox), findsNothing);
  });
}
