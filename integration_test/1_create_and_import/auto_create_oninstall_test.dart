import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../_flows/switchToTestnet.dart';
import '../_pages/home.dart';

void main() {
  group('First Time Launch Wallets Tests', () {
    late THomePage homepage;
    final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    setUp(() async {
      app.main(fromTest: true);
      homepage = THomePage();
    });

    testWidgets('Check mainnet exists and no testnet wallet cards exist', (tester) async {
      await Future.delayed(const Duration(seconds: 3));
      final mainnetCard = homepage.mainnetCard;
      expect(mainnetCard, findsOneWidget);

      await switchToTestnetFromHomeAndReturnHome(tester);

      final testnetCard = homepage.testnetCard;
      expect(testnetCard, findsNothing);
    });
  });
}
