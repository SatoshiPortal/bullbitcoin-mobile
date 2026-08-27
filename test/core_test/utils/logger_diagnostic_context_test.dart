import 'dart:io';
import 'dart:convert';

import 'package:bb_mobile/core/utils/diagnostic_context.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes diagnostic context on creation and after deletion', () async {
    final directory = await Directory.systemTemp.createTemp('logger-context-');
    addTearDown(() async {
      await log.flush();
      await directory.delete(recursive: true);
    });
    const context = DiagnosticContext(
      version: '6.13.0',
      build: '214',
      system: {
        'platform': 'android',
        'os_version': 'Android 14 (API 34)',
        'manufacturer': 'Google',
        'model': 'Pixel 5',
      },
      resources: {'battery_percent': 73},
      network: {
        'transports': ['wifi'],
        'vpn': 'inactive',
      },
      tor: {
        'source': null,
        'state': 'uninitialized',
        'transport': null,
        'socks_proxy_configured': false,
      },
    );

    log = Logger.replace(
      directory: directory,
      diagnosticContextLoader: () async => context,
    );
    await log.ensureLogsExist();

    var contents = await log.logsFile.readAsString();
    final firstContext = contents
        .split('\n')
        .firstWhere((line) => line.contains('"context_version":1'))
        .split('\t')[2];
    expect(jsonDecode(firstContext)['context_version'], 1);

    await log.ensureLogsExist();
    contents = await log.logsFile.readAsString();
    expect(
      contents
          .split('\t')
          .where((line) => line.contains('"context_version":1'))
          .length,
      2,
    );

    await log.deleteLogs();
    contents = await log.logsFile.readAsString();
    expect(contents, contains('Logs deleted'));
    expect(contents, contains('"context_version":1'));
    expect(contents, contains('"version":"6.13.0"'));
    expect(contents, isNot(contains('"event"')));
    expect(
      contents
          .split('\n')
          .where((line) => line.contains('"context_version":1')),
      hasLength(1),
    );
  });
}
