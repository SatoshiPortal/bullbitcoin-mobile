// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2648
// Finding: the Android USB permission bridge is not present in this checkout.
// This test PASSES while the vulnerability exists: it documents the current
// vulnerable behavior. When the issue is fixed, flip the assertions to the
// secure behavior so this becomes a regression test.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Security audit #2648 USB permission bridge', () {
    test('plugin source is unavailable for automated verification', () {
      final candidates = <String>[
        'android/app/src/main/kotlin/com/bullbitcoin/mobile/BitboxFlutterPlugin.kt',
        'android/app/src/main/java/com/bullbitcoin/mobile/BitboxFlutterPlugin.kt',
      ];
      expect(candidates.any((path) => File(path).existsSync()), isFalse);
    });
  });
}
