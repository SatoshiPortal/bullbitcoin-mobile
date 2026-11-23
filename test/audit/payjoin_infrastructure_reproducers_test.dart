import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Payjoin setup uses the production and regtest cutovers from the composition root', () {
    final init = File('lib/init.dart').readAsStringSync();
    final setup = File('lib/features/wallet/public/payjoin_setup.dart')
        .readAsStringSync();

    expect(
      init,
      allOf(
        contains('final payjoin = payjoinStore(regtest: false);'),
        contains('final regtestPayjoin = payjoinStore(regtest: true);'),
        contains('locator.registerSingleton(payjoin);'),
        contains(
          "locator.registerSingleton(regtestPayjoin, instanceName: 'regtest');",
        ),
      ),
    );
    expect(
      setup,
      allOf(
        contains('productionCutover: locator<PayjoinCutover>()'),
        contains(
          "regtestCutover: locator<PayjoinCutover>(instanceName: 'regtest')",
        ),
      ),
    );
  });

  test('the canonical Drift target includes the Payjoin package schema', () {
    final makefile = File('makefile').readAsStringSync();
    final start = makefile.indexOf('drift-migrations:');
    final end = makefile.indexOf('\nios-simulator:', start);
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
      'features/bull_exchange/lib/src/buy/domain/create_buy_order_usecase.dart',
      'features/transactions/lib/src/domain/usecases/get_transactions_usecase.dart',
      'features/transactions/lib/src/domain/usecases/get_transactions_by_tx_id_usecase.dart',
      'lib/features/send/domain/usecases/prepare_bitcoin_send_usecase.dart',
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
