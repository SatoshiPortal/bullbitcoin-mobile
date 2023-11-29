import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

import '../../test/__flows/switchToTestnet.dart';
import '../../test/__flows/utils.dart';
import '../../test/__pages/home.dart';

void main() {
  group('First Time Launch Wallets Tests', () {
    setupUITest();

    setUp(() async {
      app.main(fromTest: true);
    });

    testWidgets('Check mainnet exists and no testnet wallet cards exist', (tester) async {
      final homepage = THomePage(tester: tester);
      await Future.delayed(const Duration(seconds: 3));

      await homepage.checkPageHasMainnetCard();
      await switchToTestnetFromHomeAndReturnHome(tester);
      await homepage.checkPageHasNoTestnetCard();
    });
  });
}
