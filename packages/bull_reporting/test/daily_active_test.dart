import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bull_reporting/src/metrics/daily_active.dart';

class MemoryDayStore implements ActiveDayStore {
  String? day;
  int writes = 0;
  bool fail = false;
  Completer<void>? writing;

  @override
  Future<String?> read() async {
    if (fail) throw const FileSystemException('read failed');
    return day;
  }

  @override
  Future<void> write(String value) async {
    if (fail) throw const FileSystemException('write failed');
    await writing?.future;
    day = value;
    writes++;
  }
}

void main() {
  late MemoryDayStore store;
  late DateTime now;
  late List<String> emitted;
  late DailyActiveInstallations active;

  setUp(() {
    store = MemoryDayStore();
    now = DateTime.utc(2026, 11, 25, 23);
    emitted = [];
    active = DailyActiveInstallations(store, (instant) {
      expect(store.day, instant.toUtc().toIso8601String().substring(0, 10));
      emitted.add('observed');
    }, clock: () => now);
  });

  test(
    'foreground and opt-in emit once per UTC day, including after restart',
    () async {
      active.setForeground(true);
      await active.idle;
      expect(emitted, isEmpty);
      active.setConsent(true);
      await active.idle;
      active.setForeground(false);
      active.setForeground(true);
      await active.idle;
      final restarted = DailyActiveInstallations(
        store,
        (_) => emitted.add('observed'),
        clock: () => now,
      );
      restarted.setConsent(true);
      restarted.setForeground(true);
      await restarted.idle;
      expect(emitted, ['observed']);
      expect(store.writes, 1);
      now = DateTime.utc(2026, 11, 26);
      await active.idle;
      expect(emitted, hasLength(1));
      active.setForeground(false);
      active.setForeground(true);
      await active.idle;
      expect(emitted, hasLength(2));
    },
  );

  test(
    'withdrawal while writing prevents emission and does not double count',
    () async {
      store.writing = Completer<void>();
      active.setConsent(true);
      active.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      active.setConsent(false);
      store.writing?.complete();
      await active.idle;
      active.setConsent(true);
      await active.idle;
      expect(emitted, isEmpty);
      expect(store.writes, 1);
    },
  );

  test('storage failure fails closed and a later entry can retry', () async {
    store.fail = true;
    active.setConsent(true);
    active.setForeground(true);
    await active.idle;
    expect(emitted, isEmpty);
    store.fail = false;
    active.setForeground(false);
    active.setForeground(true);
    await active.idle;
    expect(emitted, ['observed']);
  });

  test('file marker fails closed if malformed and persists the day', () async {
    final directory = await Directory.systemTemp.createTemp('active-day-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/marker');
    final fileStore = FileActiveDayStore(file);
    expect(await fileStore.read(), isNull);
    await file.writeAsString('invalid');
    await expectLater(fileStore.read(), throwsFormatException);
    await fileStore.write('2026-11-25');
    expect(await FileActiveDayStore(file).read(), '2026-11-25');
  });

  test(
    'day and observation use the same instant across UTC midnight',
    () async {
      store.writing = Completer<void>();
      now = DateTime.utc(2026, 11, 25, 23, 59, 59);
      final instants = <DateTime>[];
      active = DailyActiveInstallations(store, instants.add, clock: () => now);
      active.setConsent(true);
      active.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      now = DateTime.utc(2026, 11, 26);
      store.writing?.complete();
      await active.idle;
      expect(store.day, '2026-11-25');
      expect(instants.single, DateTime.utc(2026, 11, 25, 23, 59, 59));
    },
  );
}
