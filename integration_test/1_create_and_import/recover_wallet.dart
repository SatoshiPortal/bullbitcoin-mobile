import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

import '../../test/__flows/utils.dart';
import '../../test/import/recover_widget_test.dart';

void main() {
  group('Import - Recover tests', () {
    setupUITest();

    setUp(() async {
      app.main(fromTest: true);
    });

    testWidgets('Recover testnet wallet with 12 word mnemonic', recoverWalletSteps);
  });
}
