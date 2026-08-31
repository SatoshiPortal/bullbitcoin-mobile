import 'dart:typed_data';

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/send/ui/widgets/coin_select_tile.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullCheckbox;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLabelsFacade extends Mock implements LabelsFacade {}

void main() {
  setUpAll(() {
    // LabelsWidget, nested in the tile, resolves the facade in its State
    // field initializer. Nothing here deletes a label, so an unstubbed mock
    // is enough to let the tile build.
    if (!locator.isRegistered<LabelsFacade>()) {
      locator.registerSingleton<LabelsFacade>(MockLabelsFacade());
    }
  });

  final utxo = WalletUtxo.bitcoin(
    walletId: 'wallet-1',
    txId: 'a' * 64,
    vout: 0,
    scriptPubkey: Uint8List.fromList([0, 1, 2]),
    amountSat: BigInt.from(100000),
    address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
  );

  Future<void> pumpTile(
    WidgetTester tester, {
    required bool selected,
    required VoidCallback onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CoinSelectTile(
            utxo: utxo,
            selected: selected,
            onTap: onTap,
            bitcoinUnit: BitcoinUnit.sats,
            exchangeRate: 100000,
            fiatCurrency: 'CAD',
          ),
        ),
      ),
    );
  }

  testWidgets('tapping the box of an unselected coin reports a tap', (
    tester,
  ) async {
    var taps = 0;
    await pumpTile(tester, selected: false, onTap: () => taps++);

    await tester.tap(find.byType(BullCheckbox));
    await tester.pump();

    expect(taps, 1);
  });

  // Regression: the box used to be a Radio, whose `toggleable` defaults to
  // false — RawRadio then swallows the tap that would clear an already
  // selected radio. Picking a coin worked, unpicking it silently did nothing.
  testWidgets('tapping the box of a selected coin reports a tap', (
    tester,
  ) async {
    var taps = 0;
    await pumpTile(tester, selected: true, onTap: () => taps++);

    await tester.tap(find.byType(BullCheckbox));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('tapping the tile body reports a tap when selected', (
    tester,
  ) async {
    var taps = 0;
    await pumpTile(tester, selected: true, onTap: () => taps++);

    await tester.tap(find.textContaining('sats'));
    await tester.pump();

    expect(taps, 1);
  });
}
