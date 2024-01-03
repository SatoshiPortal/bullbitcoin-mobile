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

    testWidgets('Create invoice and check qr and address is updated', (tester) async {
      await receiveRequestPayment(tester);
    });
  });
}
