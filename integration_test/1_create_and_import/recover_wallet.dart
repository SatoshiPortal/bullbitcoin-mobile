import 'package:bb_mobile/_pkg/wallet/testable_wallets.dart';
import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

import '../_flows/switchToTestnet.dart';
import '../_pages/_utils.dart';
import '../_pages/home.dart';
import '../_pages/import.dart';

void main() {
  group('Import - Recover tests', () {
    setupUITest();

    setUp(() async {
      app.main(fromTest: true);
    });

    testWidgets('Recover testnet wallet with 12 word mnemonic', (tester) async {
      final homePage = THomePage(tester: tester);
      final importPage = TImportPage(tester: tester);
      await Future.delayed(const Duration(seconds: 3));

      await switchToTestnetFromHomeAndReturnHome(tester);

      await homePage.tapPlusButton();
      await importPage.tapRecoverButton();
      await importPage.scrollToBottom();
      await importPage.enterWordsIntoFields(r2);
      await importPage.tapRecoverConfirmButton();

      await importPage.waitForWalletsToSync();
      await importPage.selectWalletWithMostTxs();
      await importPage.tapWalletSelectionConfirmButton();

      await homePage.checkPageHasTestnetCard();
    });
  });
}
