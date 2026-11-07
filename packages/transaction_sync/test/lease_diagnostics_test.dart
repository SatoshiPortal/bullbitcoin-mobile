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
        expect(lines.join(), isNot(contains(key.id)));
        expect(lines.join(), isNot(contains(directory.path)));
      } finally {
        await log.flush();
        debugPrint = previous;
        directory.deleteSync(recursive: true);
      }
    },
  );

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
