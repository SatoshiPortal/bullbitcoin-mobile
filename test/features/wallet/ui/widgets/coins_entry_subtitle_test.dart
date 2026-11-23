import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/coins_entry_subtitle.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

Future<void> _pump(WidgetTester tester, BitcoinUnit unit, int frozen) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: [
        ...appLocalizationsDelegates,
        ...bullUiLocalizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: BullAmountScope(
        snapshot: BullAmountSnapshot(
          unit: unit,
          hideAmounts: false,
          isReady: true,
        ),
        writeUnit: (_) async => true,
        child: CoinsEntrySubtitle(utxoCount: 3, frozenSat: BigInt.from(frozen)),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the frozen amount in sats', (tester) async {
    await _pump(tester, BitcoinUnit.sats, 12345);
    expect(find.textContaining('12,345 sats'), findsOneWidget);
  });

  testWidgets('shows the frozen amount in BTC', (tester) async {
    await _pump(tester, BitcoinUnit.btc, 12345);
    expect(find.textContaining('0.00012345 BTC'), findsOneWidget);
  });

  testWidgets('omits the frozen clause when nothing is frozen', (tester) async {
    await _pump(tester, BitcoinUnit.sats, 0);
    expect(find.textContaining('frozen'), findsNothing);
  });
}
