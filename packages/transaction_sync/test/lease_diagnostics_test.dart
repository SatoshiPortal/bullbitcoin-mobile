import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/src/write/lease_diagnostics.dart';
import 'package:transaction_sync/src/write/writer_lock.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  test(
    'real logger keeps lease pairs on console and persists only busy',
    () async {
      final directory = Directory.systemTemp.createTempSync('lease-log-');
      final console = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) console.add(message);
      };
      log = Logger.replace(directory: directory);
      final key = WalletKey(
        id: 'must-not-be-logged',
        network: BitcoinNetwork.testnet,
      );
      try {
        final trace = LeaseDiagnostics(
          role: LeaseRole.reader,
          intent: LeaseIntent.snapshot,
          source: LeaseSource.syncStarted,
        );
        final acquired =
            WriterLock.acquire(directory.path, key, diagnostics: trace) as Ok;
        final lock = acquired.value as WriterLock;
        try {
          trace.read = LeaseRead.cache;
          expect(WriterLock.acquire(directory.path, key), isA<Err>());
        } finally {
          lock.release();
          lock.release();
        }
        await log.flush();
        await pumpEventQueue();
        final lines = console
            .where((line) => line.contains('event=lease_'))
            .toList();
        expect(
          lines.where((line) => line.contains('event=lease_acquire')),
          hasLength(1),
        );
        expect(
          lines.where((line) => line.contains('event=lease_release')),
          hasLength(1),
        );
        expect(
          lines.where((line) => line.contains('event=lease_busy')),
          hasLength(1),
        );
        expect(
          lines.join(),
          contains(
            'role=reader intent=snapshot scope=foreground source=sync_started',
          ),
        );
        expect(lines.last, contains('read=cache'));
        expect(lines.last, matches(r'held_ms=\d+'));
        expect(lines.last, contains('owner_at='));
        final persisted = (await log.readLogs())
            .where((line) => line.contains('event=lease_'))
            .toList();
        expect(persisted, hasLength(1));
        expect(persisted.single, contains('FINE'));
        expect(persisted.single, contains('busy_source=lease_begin'));
        expect(persisted.single, contains('waited_ms=0'));
        expect(persisted.join(), isNot(contains('event=lease_long_hold')));
        expect(lines.join(), isNot(contains(key.id)));
        expect(lines.join(), isNot(contains(directory.path)));
      } finally {
        await log.flush();
        debugPrint = previous;
        directory.deleteSync(recursive: true);
      }
    },
  );

  test(
    'reader refusals stay on console while writer refusals persist',
    () async {
      final directory = Directory.systemTemp.createTempSync('lease-refusal-');
      final console = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) console.add(message);
      };
      log = Logger.replace(directory: directory);
      try {
        for (final role in LeaseRole.values) {
          final trace = LeaseDiagnostics(
            role: role,
            intent: role == LeaseRole.reader
                ? LeaseIntent.snapshot
                : LeaseIntent.sync,
          );
          for (final source in LeaseBusySource.values) {
            trace.busy(source);
          }
        }
        await log.flush();
        await pumpEventQueue();
        expect(
          console.where(
            (line) => line.contains('event=lease_busy role=reader'),
          ),
          hasLength(LeaseBusySource.values.length),
        );
        final persisted = (await log.readLogs())
            .where((line) => line.contains('event=lease_busy'))
            .toList();
        expect(persisted, hasLength(LeaseBusySource.values.length));
        for (final line in persisted) {
          expect(line, contains('FINE'));
          expect(line, contains('role=writer'));
          expect(line, contains('waited_ms=0'));
        }
      } finally {
        await log.flush();
        debugPrint = previous;
        directory.deleteSync(recursive: true);
      }
    },
  );

  test('only holds of at least 1000 ms are persisted', () async {
    final directory = Directory.systemTemp.createTempSync('lease-threshold-');
    log = Logger.replace(directory: directory);
    try {
      final trace = LeaseDiagnostics(
        role: LeaseRole.writer,
        intent: LeaseIntent.sync,
        scope: LeaseScope.compute,
        source: LeaseSource.syncStarted,
      );
      trace.release(999);
      await log.flush();
      expect(
        await log.readLogs(),
        isNot(contains(contains('lease_long_hold'))),
      );
      trace.release(1000);
      await log.flush();
      final lines = (await log.readLogs())
          .where((line) => line.contains('event=lease_long_hold'))
          .toList();
      expect(lines, hasLength(1));
      expect(lines.single, contains('FINE'));
      expect(lines.single, contains('role=writer intent=sync scope=compute'));
      expect(
        lines.single,
        contains('source=sync_started read=hydrate held_ms=1000'),
      );
    } finally {
      await log.flush();
      directory.deleteSync(recursive: true);
    }
  });

  for (final role in LeaseRole.values) {
    test('real ${role.name} long hold is persisted once on release', () async {
      final directory = Directory.systemTemp.createTempSync('lease-long-');
      log = Logger.replace(directory: directory);
      final key = WalletKey(
        id: 'never-log-this-id',
        network: BitcoinNetwork.testnet,
      );
      final trace = LeaseDiagnostics(
        role: role,
        intent: role == LeaseRole.reader
            ? LeaseIntent.snapshot
            : LeaseIntent.sync,
        scope: LeaseScope.headless,
        source: LeaseSource.balance,
      );
      final acquired =
          WriterLock.acquire(directory.path, key, diagnostics: trace) as Ok;
      final lock = acquired.value as WriterLock;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 1050));
        await log.flush();
        expect(
          await log.readLogs(),
          isNot(contains(contains('lease_long_hold'))),
        );
        lock.release();
        lock.release();
        await log.flush();
        final lines = (await log.readLogs())
            .where((line) => line.contains('event=lease_'))
            .toList();
        expect(lines, hasLength(1));
        expect(lines.single, contains('FINE'));
        expect(
          lines.single,
          contains('event=lease_long_hold role=${role.name}'),
        );
        expect(
          lines.single,
          contains('scope=headless source=balance read=hydrate'),
        );
        final held = RegExp(r'held_ms=(\d+)')
            .firstMatch(lines.single)
            ?.group(1);
        expect(held, isNotNull);
        expect(int.tryParse(held ?? ''), greaterThanOrEqualTo(1000));
        expect(lines.single, isNot(contains(key.id)));
        expect(lines.single, isNot(contains(directory.path)));
      } finally {
        lock.release();
        await log.flush();
        directory.deleteSync(recursive: true);
      }
    });
  }

  test('throwing diagnostic cannot retain an acquired lease', () {
    final directory = Directory.systemTemp.createTempSync('lease-callback-');
    final key = WalletKey(id: 'test', network: BitcoinNetwork.testnet);
    final trace = LeaseDiagnostics(
      role: LeaseRole.writer,
      intent: LeaseIntent.create,
      sink: (_, _) => throw StateError('diagnostic'),
    );
    try {
      final first =
          WriterLock.acquire(directory.path, key, diagnostics: trace) as Ok;
      (first.value as WriterLock).release();
      final second =
          WriterLock.acquire(directory.path, key, diagnostics: trace) as Ok;
      (second.value as WriterLock).release();
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
