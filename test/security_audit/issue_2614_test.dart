// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2614
// Finding: the BIP85 route does not apply the application's screen-capture protection.
// Regression test for route-wide screen-capture protection.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2614 screen capture protection', () {
    test('BIP85 home page uses PrivacyScreen', () {
      final source = File(
        'lib/features/bip85_entropy/bip85_home_page.dart',
      ).readAsStringSync();

      expect(source, contains('PrivacyScreen'));
      expect(source, contains('package:screen_privacy/screen_privacy.dart'));
    });
  });
}
