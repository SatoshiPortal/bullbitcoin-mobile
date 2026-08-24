// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2623
// Finding: userinfo can make a trusted-looking prefix hide the actual host.
// Regression test for the fix.

import 'package:bb_mobile/core/utils/mempool_url_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2623 deceptive mempool URLs', () {
    test('rejects a deceptive userinfo URL', () {
      final parsed = MempoolUrlParser.tryParse('mempool.space@evil.example');

      expect(parsed, isNull);
    });
  });
}
