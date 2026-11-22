import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/coins/domain/wallet_utxo.dart';
import 'package:bb_mobile/features/send/public/coin_selection.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

WalletUtxo _coin(String pattern, int amount) => WalletUtxo.bitcoin(
  walletId: 'fixture',
  txId: pattern * 64,
  vout: 0,
  scriptPubkey: Uint8List(0),
  amountSat: BigInt.from(amount),
  address: 'bc1q${pattern * 36}',
);

void main() {
  testWidgets('only sends selectable outpoints once the amount is met', (
    tester,
  ) async {
    final first = _coin('a', 3000);
    final second = _coin('b', 2000);
    final unavailable = _coin('c', 9000);
    List<WalletUtxo>? submitted;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => BullBottomSheet.show<void>(
                context: context,
                child: WalletCoinSelectionBottomSheet(
                  bitcoinUnit: BitcoinUnit.sats,
                  exchangeRate: null,
                  fiatCurrency: 'CAD',
                  utxos: [first, second],
                  initialSelectedUtxos: [
                    first.copyWith(confirmations: 1),
                    unavailable,
                  ],
                  amountToSendSat: 5000,
                  onDone: (selection) => submitted = selection,
                ),
              ),
              child: const Text('Select coins'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        routerConfig: router,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.tap(find.text('Select coins'));
    await tester.pumpAndSettle();

    final done = find.byType(BullButton);
    expect(tester.widget<BullButton>(done).disabled, isTrue);
    expect(find.byType(Radio<bool>), findsNWidgets(2));

    await tester.tap(find.byType(Radio<bool>).last);
    await tester.pumpAndSettle();
    expect(tester.widget<BullButton>(done).disabled, isFalse);

    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(submitted, [first, second]);
    expect(done, findsNothing);
  });
}
