import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'switchToTestnet.dart';
import 'waitFor.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  app.main(fromTest: true);

  testWidgets('Import testnet wallet from xpub', (tester) async {
    await Future.delayed(const Duration(seconds: 3));

    await switchToTestnetFromHomeAndReturnHome(tester);

    final homeImportButton = find.byKey(UIKeys.homeImportButton);
    await tester.tap(homeImportButton);
    await tester.pumpAndSettle();

    final importImportButton = find.byKey(UIKeys.importImportButton);
    await tester.tap(importImportButton);
    await tester.pumpAndSettle();

    final importXpubField = find.byKey(UIKeys.importXpubField);
    await tester.enterText(
      importXpubField,
      'tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz',
    );

    final importXpubConfirmButton = find.byKey(UIKeys.importXpubConfirmButton);
    await tester.tap(importXpubConfirmButton);
    await tester.pumpAndSettle();

    final loader = find.byKey(UIKeys.importWalletSelectionSyncing);
    await waitForAllToDisappear(tester, loader);

    final importConfirmButton = find.byKey(UIKeys.importWalletSelectionConfirmButton);
    await tester.tap(importConfirmButton);
    await tester.pumpAndSettle();

    final homeCardTestnet = find.byKey(UIKeys.homeCardTestnet);
    expect(homeCardTestnet, findsNWidgets(2));
  });
}
