import 'package:bb_mobile/_pkg/wallet/testable_wallets.dart';
import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

import '../_flows/switchToTestnet.dart';
import '../_flows/utils.dart';
import '../_pages/home.dart';
import '../_pages/import.dart';

void main() {
  setupUITest();

  setUp(() {
    app.main(fromTest: true);
  });

  testWidgets('Import testnet wallet from xpub', (tester) async {
    final homePage = THomePage(tester: tester);
    final importPage = TImportPage(tester: tester);
    await Future.delayed(const Duration(seconds: 3));

    await switchToTestnetFromHomeAndReturnHome(tester);

    await homePage.tapPlusButton();
    await importPage.tapImportButton();
    await importPage.enterTextInXpubField(xpub1);
    await importPage.tapxPubConfirmButton();
    await importPage.waitForWalletsToSync();
    await importPage.tapWalletSelectionConfirmButton();
    await homePage.checkPageHasTestnetCard();
  });
}
