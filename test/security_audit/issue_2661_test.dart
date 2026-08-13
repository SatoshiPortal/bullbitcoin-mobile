// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2661
// Finding: non-canonical host spellings bypass the same-as-default guard.
// Regression test for the fix.

import 'package:bb_mobile/core/mempool/domain/value_objects/normalized_mempool_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2661 default server guard', () {
    test('trailing DNS dot compares as the same server', () {
      final defaultUrl = NormalizedMempoolUrl('mempool.space');
      final customUrl = NormalizedMempoolUrl('mempool.space.');

      expect(defaultUrl == customUrl, isTrue);
      expect(customUrl.value, 'mempool.space');
    });

    test('userinfo prefix is rejected by the hardened parser', () {
      final customUrl = NormalizedMempoolUrl('mempool.space@evil.example');

      expect(customUrl == NormalizedMempoolUrl('mempool.space'), isFalse);
    });
  });
}
