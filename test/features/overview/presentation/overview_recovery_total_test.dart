import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';

import '../support/overview_home_harness.dart';

void main() {
  for (final status in [
    OverviewCatalogueStatus.partial,
    OverviewCatalogueStatus.unreadable,
  ]) {
    test(
      '$status keeps the total unknown and backup warning conservative',
      () async {
        final h = OverviewHomeHarness();
        addTearDown(h.close);
        await h.mount();
        h.source.publish(
          snapshot(status, [
            if (status == OverviewCatalogueStatus.partial)
              homeWallet('readable', balanceSat: 125),
          ]),
        );
        await flushEvents();
        expect(h.controller.current.totalSat, isNull);
        expect(h.controller.current.backupCard, isTrue);
        expect(h.controller.current.backupWarning, isTrue);
        h.controller.dismissBackupWarning();
        expect(h.controller.current.backupCard, isTrue);
        expect(h.controller.current.backupWarning, isFalse);
      },
    );
  }
}
