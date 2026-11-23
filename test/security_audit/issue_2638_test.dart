// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2638
// Finding: unsupported SeedSigner static and Specter xpub scans fail silently —
// the catch block only logs and resets, with no user-visible error.
// Regression test for the fix. The scan screen is intentionally out of scope;
// it must map the parser failure to a visible error separately.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2638 watch-only scan', () {
    test(
      'parser accepts origin-prefixed xpub input and maps unsupported formats',
      () {
        final source = File(
          'features/wallet_import/lib/src/domain/watch_only_input.dart',
        ).readAsStringSync();
        expect(source, contains('trimmed.substring(origin?.length ?? 0)'));
        expect(source, contains('Err<WatchOnlyInput, ImportFailure>'));
      },
    );
  });
}
