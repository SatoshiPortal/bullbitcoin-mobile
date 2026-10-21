import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// An empty suite must never be accepted as a successful physical-device run.
({int completed, bool live}) requireCompletedProbes(
  Map<String, dynamic>? data,
) => switch (data) {
  {
    'completedProbes': final int completed,
    'expectedProbes': final int expected,
    'livePreprodEnabled': final bool live,
  }
      when completed == expected && expected == (live ? 7 : 6) =>
    (completed: completed, live: live),
  _ => throw StateError('Native credential probe completion was not verified'),
};

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final result = requireCompletedProbes(data);
    await writeResponseData(data);
    stdout.writeln(
      'Verified ${result.completed} native credential probes '
      '(live preprod: ${result.live})',
    );
  },
);
