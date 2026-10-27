import 'dart:io';

import 'package:bb_mobile/init.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'writes foreground and background logs to the supplied directory',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bull-init-logs-',
      );
      final previousLog = log;
      addTearDown(() async {
        await log.flush();
        log = Logger.replace(
          directory: previousLog.dir,
          background: previousLog.filename == 'bull_background_logs.tsv',
        );
        await directory.delete(recursive: true);
      });

      final foreground = File(p.join(directory.path, 'bull_logs.tsv'));
      final background = File(
        p.join(directory.path, 'bull_background_logs.tsv'),
      );

      await Bull.initLogs(logDirectory: directory);
      expect(log.logsFile.path, foreground.path);
      expect(await foreground.exists(), isTrue);
      expect(await background.exists(), isFalse);

      log.fine('foreground initialization marker');
      await log.flush();
      expect(
        await foreground.readAsString(),
        contains('foreground initialization marker'),
      );

      await Bull.initLogs(logDirectory: directory, background: true);
      expect(log.logsFile.path, background.path);
      expect(await background.exists(), isTrue);

      log.fine('background initialization marker');
      await log.flush();
      expect(
        await background.readAsString(),
        contains('background initialization marker'),
      );
      expect(
        await foreground.readAsString(),
        isNot(contains('background initialization marker')),
      );
      expect(
        await background.readAsString(),
        isNot(contains('foreground initialization marker')),
      );
    },
  );
}
