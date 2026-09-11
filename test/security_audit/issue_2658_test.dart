import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit regression for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2658
void main() {
  test('keeps fee routing behind the repository Tor policy', () {
    final source = File(
      'lib/core/fees/data/fees_repository_impl.dart',
    ).readAsStringSync();

    expect(source, contains('useTorProxy'));
    expect(source, contains('_tor.external.verify'));
    expect(source, contains('_tor.embedded.sessions.open'));
    expect(source, contains('proxyEndpoint: null'));
  });
}
