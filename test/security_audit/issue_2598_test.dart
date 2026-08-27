// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2598
// Finding: logger writes exception.toString() containing secret material to TSV logs.
// Regression test for the fix.

import 'dart:io';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2598 secret material in logs', () {
    test(
      'redacts a mnemonic embedded in an exception from the TSV row',
      () async {
        final directory = await Directory.systemTemp.createTemp('issue-2598-');
        addTearDown(() async {
          await log.flush();
          await directory.delete(recursive: true);
        });

        log = Logger.replace(directory: directory);
        await log.ensureLogsExist();
        const mnemonic =
            'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

        log.severe(
          error: FormatException('Invalid mnemonic: $mnemonic'),
          trace: StackTrace.current,
        );
        await log.flush();

        final contents = await File(
          '${directory.path}/bull_logs.tsv',
        ).readAsString();
        expect(contents, isNot(contains(mnemonic)));
      },
    );
  });
}
