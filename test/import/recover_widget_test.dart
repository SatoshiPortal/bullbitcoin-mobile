import 'package:bb_mobile/_pkg/wallet/testable_wallets.dart';
import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../__flows/path_mock.dart';
import '../__flows/switchToTestnet.dart';
import '../__pages/home.dart';
import '../__pages/import.dart';

void main() {
  setUp(() async {
    PathProviderPlatform.instance = FakePathProviderPlatform();
    app.main(fromTest: true);
  });

  group('Import - Recover tests', () {
    testWidgets('Recover testnet wallet with 12 word mnemonic', recoverWalletSteps);
  });
}

Future recoverWalletSteps(WidgetTester tester) async {
  final homePage = THomePage(tester: tester);
  final importPage = TImportPage(tester: tester);
  await Future.delayed(const Duration(seconds: 3));

  await switchToTestnetFromHomeAndReturnHome(tester);

  await homePage.tapPlusButton();
  await importPage.tapRecoverButton();
  await importPage.scrollToBottomOfRecoverWords();
  await importPage.enterWordsIntoFields(r2);
  await importPage.tapRecoverConfirmButton();
  await importPage.waitForWalletsToSync();
  await importPage.tapSegwitWallet();
  await importPage.tapWalletSelectionConfirmButton();
  await homePage.checkPageHasTestnetCard();
}
