import 'package:bb_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

import '../../test/__flows/utils.dart';
import '../../test/receive/receive_address_test.dart';

void main() {
  group('Receive Tests', () {
    setupUITest();

    setUp(() async {
      app.main(fromTest: true);
    });

    testWidgets('Check receive qr and address is displayed', (tester) async {
      await receiveAddressSteps(tester);
    });
  });
}
