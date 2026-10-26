import 'dart:async';

import 'package:bull_sdk/onion.dart' as onion;
import 'package:bull_tor/src/data/tor_log_bridge.dart';
import 'package:bull_tor/src/data/tor_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<onion.TorLogRecord> source;
  late List<String> info;
  late List<String> fine;
  late List<String> warning;
  late TorLogger logger;

  onion.TorLogRecord record(
    String message, {
    onion.TorLogLevel level = onion.TorLogLevel.info,
    String target = 'onion',
  }) => onion.TorLogRecord(level: level, target: target, message: message);

  setUp(() {
    source = StreamController(sync: true);
    info = [];
    fine = [];
    warning = [];
    logger = TorLogger(
      infoCallback: (message, {error, trace}) => info.add('$message'),
      fineCallback: (message, {error, trace}) => fine.add('$message'),
      warningCallback: (message, {error, trace}) => warning.add('$message'),
    );
  });

  test(
    'persists relevant milestones and warnings, keeps debug console-only',
    () async {
      final bridge = TorLogBridge(logger)..start(source.stream);
      source
        ..add(record('failure', level: onion.TorLogLevel.error))
        ..add(record('degraded', level: onion.TorLogLevel.warn))
        ..add(record('descriptor', target: 'tor_hsclient::connect'))
        ..add(record('circuit', target: 'tor_circmgr'))
        ..add(record('session', target: 'onion::api::session'))
        ..add(record('directory', target: 'tor_dirmgr'))
        ..add(record('similar-prefix', target: 'tor_hsclient_other'))
        ..add(
          record(
            'development',
            level: onion.TorLogLevel.debug,
            target: 'tor_hsclient',
          ),
        );
      expect(warning, ['[onion] failure', '[onion] degraded']);
      expect(fine, [
        '[tor_hsclient::connect] descriptor',
        '[tor_circmgr] circuit',
        '[onion::api::session] session',
      ]);
      expect(info, [
        '[tor_dirmgr] directory',
        '[tor_hsclient_other] similar-prefix',
        '[tor_hsclient] development',
      ]);
      await bridge.close();
      await source.close();
    },
  );

  test(
    'suppresses consecutive duplicates without hiding severity changes',
    () async {
      final bridge = TorLogBridge(logger)..start(source.stream);
      source
        ..add(record('same'))
        ..add(record('same'))
        ..add(record('same', level: onion.TorLogLevel.warn));
      await bridge.close();
      await source.close();
      expect(fine, ['[onion] same', 'tor_native summary dropped=0 repeated=1']);
      expect(warning, ['[onion] same']);
    },
  );

  test(
    'reserves capacity for warnings and reports every omitted record',
    () async {
      final bridge = TorLogBridge(logger, maxRecords: 4)..start(source.stream);
      for (var index = 0; index < 4; index++) {
        source.add(record('milestone=$index'));
      }
      source
        ..add(record('important', level: onion.TorLogLevel.warn))
        ..add(record('overflow', level: onion.TorLogLevel.error));
      await bridge.close();
      await source.close();
      expect(fine.take(3), [
        '[onion] milestone=0',
        '[onion] milestone=1',
        '[onion] milestone=2',
      ]);
      expect(warning, ['[onion] important']);
      expect(fine.last, 'tor_native summary dropped=2 repeated=0');
    },
  );

  test(
    'budget renews by monotonic elapsed time without a background timer',
    () async {
      var elapsed = Duration.zero;
      final bridge = TorLogBridge(logger, maxRecords: 1, elapsed: () => elapsed)
        ..start(source.stream);
      source
        ..add(record('first'))
        ..add(record('second'));
      elapsed = const Duration(seconds: 59);
      source.add(record('third'));
      elapsed = const Duration(minutes: 1);
      source.add(record('first'));
      expect(fine, [
        '[onion] first',
        'tor_native summary dropped=2 repeated=0',
        '[onion] first',
      ]);
      await bridge.close();
      await source.close();
    },
  );

  test('byte budget counts UTF-8 bytes, including the target prefix', () async {
    final bridge = TorLogBridge(logger, maxBytes: 12)..start(source.stream);
    source
      ..add(record('éé', level: onion.TorLogLevel.warn))
      ..add(record('x', level: onion.TorLogLevel.warn));
    await bridge.close();
    await source.close();
    expect(warning, ['[onion] éé']);
    expect(fine, ['tor_native summary dropped=1 repeated=0']);
  });

  test(
    'stream exceptions use fixed metadata and follow the same budget',
    () async {
      final bridge = TorLogBridge(logger)..start(source.stream);
      source
        ..addError(Exception('foreign-sensitive-text'))
        ..addError(Exception('different-sensitive-text'));
      await bridge.close();
      await source.close();
      expect(warning, ['[onion::capture] stream_failed']);
      expect(fine, ['tor_native summary dropped=0 repeated=1']);
    },
  );

  test(
    'closing cancels capture and cannot start a replacement subscription',
    () async {
      var cancelled = false;
      source.onCancel = () => cancelled = true;
      final bridge = TorLogBridge(logger)..start(source.stream);
      expect(() => bridge.start(source.stream), throwsStateError);
      await bridge.close();
      await bridge.close();
      expect(cancelled, isTrue);
      expect(() => bridge.start(source.stream), throwsStateError);
      await source.close();
    },
  );
}
