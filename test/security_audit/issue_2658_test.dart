import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit regression for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2658
void main() {
  test('keeps fees independent from the configured Tor proxy', () {
    final source = File(
      'lib/core/fees/data/fees_datasource.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("package:bull_tor")));
    expect(source, isNot(contains('SocksTCPClient')));
    expect(
      source,
      isNot(contains('core/settings/domain/repositories/settings_repository.dart')),
    );
    expect(source, isNot(contains('useTorProxy')));
    expect(source, isNot(contains('torProxyPort')));
  });
}
