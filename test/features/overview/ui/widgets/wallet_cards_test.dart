import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

import '../../../overview/support/overview_home_harness.dart';

void main() {
  for (final enabled in [false, true]) {
    for (final configured in [false, true]) {
      test(
        'Silent Home card gate: enabled=$enabled configured=$configured',
        () async {
          final h = OverviewHomeHarness();
          addTearDown(h.close);
          h.silent
            ..enabled = enabled
            ..setUp = configured
            ..wallet = silentWallet(1, network: BitcoinNetwork.mainnet);
          h.source.publish(
            snapshot(OverviewCatalogueStatus.ready, [
              homeWallet('default', network: BitcoinNetwork.mainnet),
            ]),
          );
          await flushEvents();
          expect(h.controller.current.showSilentCard, enabled && configured);
        },
      );
    }
  }
}
