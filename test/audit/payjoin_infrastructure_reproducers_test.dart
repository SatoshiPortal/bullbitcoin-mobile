import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Payjoin setup lets integration tests inject an isolated database path',
    () {
      final source = File('lib/payjoin_setup.dart').readAsStringSync();

      expect(
        source,
        contains('String? databasePath'),
        reason:
            'without path injection the funded integration test reuses persisted '
            'sessions from previous runs',
      );
    },
  );

  test('the canonical Drift target includes the Payjoin package schema', () {
    final makefile = File('makefile').readAsStringSync();
    final start = makefile.indexOf('drift-migrations:');
    final end = makefile.indexOf('\nios-pod-update:', start);
    final target = makefile.substring(start, end);

    expect(
      target,
      contains('packages/bull_payjoin'),
      reason: 'make drift-migrations currently updates only the root database',
    );
    expect(
      File('packages/bull_payjoin/build.yaml').existsSync(),
      isTrue,
      reason: 'the package needs a committed schema baseline configuration',
    );
  });

  test('touched domain usecases do not import concrete data repositories', () {
    final paths = [
      'lib/features/buy/domain/create_buy_order_usecase.dart',
      'lib/features/transactions/application/usecases/get_transactions_usecase.dart',
      'lib/features/transactions/application/usecases/get_transactions_by_tx_id_usecase.dart',
      'lib/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart',
    ];
    final violations = <String>[];

    for (final path in paths) {
      final imports = File(path).readAsLinesSync().where(
        (line) =>
            line.startsWith('import ') &&
            (line.contains('/data/') || line.contains('/datasources/')),
      );
      for (final import in imports) {
        violations.add('$path: $import');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'domain/application usecases must depend on domain contracts',
    );
  });
}
