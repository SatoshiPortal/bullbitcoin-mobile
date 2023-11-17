import 'package:bb_mobile/_pkg/wallet/testable_wallets.dart';
import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

import '../_flows/switchToTestnet.dart';
import '../_pages/_setup.dart';
import '../_pages/home.dart';
import '../_pages/import.dart';

void main() {
  group('Import - Recover tests', () {
    late THomePage homepage;
    late TImportPage importPage;
    setupUITest();

    setUp(() async {
      app.main(fromTest: true);
    });

    testWidgets('Import 12 words', (tester) async {
      homepage = THomePage(tester: tester);
      importPage = TImportPage(tester: tester);

      await Future.delayed(const Duration(seconds: 3));

      await switchToTestnetFromHomeAndReturnHome(tester);

      await homepage.tapPlusButton();
      await importPage.tapRecoverButton();
      await importPage.scrollToBottom();
      await importPage.enterWordsIntoFields(r2);
      await importPage.tapRecoverConfirmButton();
      await Future.delayed(const Duration(seconds: 3));
    });
  });
}
