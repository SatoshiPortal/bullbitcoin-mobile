import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:flutter_test/flutter_test.dart';

class THomePage {
  THomePage({required this.tester});

  final WidgetTester tester;

  Finder get mainnetCard => find.byKey(UIKeys.homeCardMainnet);
  Finder get testnetCard => find.byKey(UIKeys.homeCardTestnet);
  Finder get settingsButton => find.byKey(UIKeys.homeSettingsButton);
  Finder get plusButton => find.byKey(UIKeys.homeImportButton);

  Future tapPlusButton() async {
    await tester.tap(plusButton);
    await tester.pumpAndSettle();
  }

  Future checkPageHasTestnetCard() async {
    expect(testnetCard, findsNWidgets(1));
  }

  Future checkWalletCardWithName(String name) async {}
}
