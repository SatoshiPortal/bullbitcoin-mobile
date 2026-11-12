import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/device/driver.dart';

void main() {
  for (final report in <Map<String, dynamic>?>[
    null,
    {},
    {'completedProbes': 0, 'expectedProbes': 0, 'livePreprodEnabled': false},
    {'completedProbes': 6, 'expectedProbes': 7, 'livePreprodEnabled': true},
    {'completedProbes': 7, 'expectedProbes': 7, 'livePreprodEnabled': false},
    {'completedProbes': '7', 'expectedProbes': 7, 'livePreprodEnabled': true},
  ]) {
    test(
      'rejects unverified native completion ${report.runtimeType}: $report',
      () {
        expect(() => requireCompletedProbes(report), throwsStateError);
      },
    );
  }

  for (final live in [false, true]) {
    test(
      'accepts the exact completed ${live ? 'live' : 'synthetic'} suite',
      () {
        final count = live ? 7 : 6;
        expect(
          requireCompletedProbes({
            'completedProbes': count,
            'expectedProbes': count,
            'livePreprodEnabled': live,
          }),
          (completed: count, live: live),
        );
      },
    );
  }
}
