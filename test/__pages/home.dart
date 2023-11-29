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
    print('tapPlusButton');
    await tester.tap(plusButton);
    await tester.pumpAndSettle();
  }

  Future checkPageHasMainnetCard() async {
    print('checkPageHasMainnetCard');
    expect(mainnetCard, findsNWidgets(1));
  }

  Future checkPageHasTestnetCard() async {
    print('checkPageHasTestnetCard');
    expect(testnetCard, findsNWidgets(1));
  }

  Future checkPageHasNoTestnetCard() async {
    print('checkPageHasNoTestnetCard');
    expect(testnetCard, findsNWidgets(0));
  }

  Future checkWalletCardWithName(String name) async {}
}
