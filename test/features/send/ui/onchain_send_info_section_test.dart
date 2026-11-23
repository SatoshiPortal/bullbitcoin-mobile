import 'package:bull_ui/app_theme.dart';
import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bb_mobile/localization/onchain_send_labels_l10n.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('names confirmation controls and gives them 48 dp targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var feeOpened = false;
    bool? payjoin;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BullOnchainSendInfoSection(
            labels: lookupAppLocalizations(const Locale('en'))
                .onchainSendLabels,
            sendWalletLabel: 'Cold storage',
            addressBuilder: (style, color) =>
                AddressViewer('Savings', style: style, color: color),
            formattedBitcoinAmount: '0.01234567 BTC',
            formattedFiatEquivalent: '1,234.56 CAD',
            absoluteFees: '550 sats',
            selectedFeeOptionTitle: 'Fast',
            onFeePriorityTap: () => feeOpened = true,
            payjoinToggleValue: true,
            onPayjoinToggleChanged: (value) => payjoin = value,
          ),
        ),
      ),
    );

    final address = find.byType(AddressViewer);
    final toggle = find.byType(BullSwitch);
    final fee = find.widgetWithText(InkWell, 'Fast');
    for (final control in [address, toggle, fee]) {
      expect(tester.getSize(control).shortestSide, greaterThanOrEqualTo(48));
    }
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      tester.getCenter(find.text('Savings')).dy,
      closeTo(tester.getCenter(find.text(l10n.coreScreensToLabel)).dy, 1),
    );
    expect(
      find.bySemanticsLabel(RegExp(l10n.coreScreensFeePriorityLabel)),
      findsWidgets,
    );
    await tester.tap(fee);
    await tester.tap(toggle);
    expect(feeOpened, isTrue);
    expect(payjoin, isFalse);
  });
}
