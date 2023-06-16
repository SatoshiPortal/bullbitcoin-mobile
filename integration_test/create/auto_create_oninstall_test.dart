import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../_flows/switchToTestnet.dart';

void main() {
  group('First Time Launch Wallets Tests', () {
    final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    setUp(() async {
      app.main(fromTest: true);
    });

    testWidgets('Check mainnet and testnet wallet cards exist', (tester) async {
      await Future.delayed(const Duration(seconds: 3));
      final mainnetCard = find.byKey(UIKeys.homeCardMainnet);
      expect(mainnetCard, findsOneWidget);

      await switchToTestnetFromHomeAndReturnHome(tester);

      final testnetCard = find.byKey(UIKeys.homeCardTestnet);
      expect(testnetCard, findsOneWidget);
    });
  });
}
