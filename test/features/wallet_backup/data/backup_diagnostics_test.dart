import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/backup_server_http_transport.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_diagnostics.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingLogger extends Fake implements Logger {
  final records = <({String level, String message, Object? error})>[];

  @override
  void fine(Object? message, {Object? error, StackTrace? trace}) =>
      records.add((level: 'fine', message: '$message', error: error));

  @override
  void info(Object? message, {Object? error, StackTrace? trace}) =>
      records.add((level: 'info', message: '$message', error: error));

  @override
  void warning(Object? message, {Object? error, StackTrace? trace}) =>
      records.add((level: 'warning', message: '$message', error: error));
}

class _Adapter implements HttpClientAdapter {
  FutureOr<ResponseBody> Function(RequestOptions) respond = (_) =>
      ResponseBody.fromString('{}', 200);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  late Logger original;
  late _CapturingLogger logger;
  late _Adapter adapter;
  late Dio dio;
  late BackupServerHttpTransport transport;
  setUp(() {
    original = log;
    logger = _CapturingLogger();
    log = logger;
    adapter = _Adapter();
    dio = Dio()..httpClientAdapter = adapter;
    transport = BackupServerHttpTransport(
      dio: dio,
      origin: Uri.parse('https://private-origin.invalid'),
    );
  });
  tearDown(() {
    log = original;
    dio.close(force: true);
  });

  test(
    'transport logs bounded facts without request or error content',
    () async {
      const forbidden = [
        'words-canary',
        'private-key-canary',
        'npub-canary',
        'ciphertext-canary',
        'hash-canary',
        'etag-canary',
        'label-canary',
        'address-canary',
        'outpoint-canary',
        'fingerprint-canary',
        'descriptor-canary',
        'private-origin.invalid',
      ];
      final body = {for (final value in forbidden) value: value};
      adapter.respond = (_) => ResponseBody.fromString(
        forbidden.join(','),
        429,
        headers: {
          'retry-after': ['30'],
        },
      );
      expect(
        await transport.send(
          method: 'POST',
          path: '/api/v1/wallet-backups/fetch',
          body: body,
        ),
        isA<Err<Map<String, dynamic>, WalletBackupFailure>>(),
      );
      expect(logger.records, hasLength(1));
      final record = logger.records.single;
      expect(record.level, 'warning');
      expect(record.message, contains('http_status=429'));
      expect(record.message, contains('WalletBackupRateLimitedFailure'));
      expect(record.message, contains('retry_after_seconds='));
      expect(record.message, contains('elapsed_ms='));
      expect(record.error, isNull);
      for (final text in forbidden) {
        expect(record.message, isNot(contains(text)));
      }
    },
  );

  test(
    'successful requests use fine; exception text is never logged',
    () async {
      final success = await transport.send(
        method: 'POST',
        path: '/api/v1/wallet-backups/fetch',
        body: {},
      );
      expect(success, isA<Ok>());
      expect(logger.records.single.level, 'fine');
      expect(logger.records.single.message, contains('http_status=200'));
      adapter.respond = (_) => throw const FormatException('secret-canary');
      await transport.send(
        method: 'POST',
        path: '/api/v1/wallet-backups/fetch',
        body: {},
      );
      expect(logger.records.last.level, 'warning');
      expect(logger.records.last.message, isNot(contains('secret-canary')));
      expect(logger.records.last.error, isNull);
    },
  );

  test('queue deadline records a warning without late success', () {
    fakeAsync((time) {
      final queue = WalletBackupOperationQueue();
      final pending = Completer<Result<void, WalletBackupFailure>>();
      unawaited(queue.run(() => pending.future));
      time.elapse(const Duration(minutes: 1));
      expect(logger.records, isNotEmpty);
      expect(
        logger.records.any(
          (r) => r.level == 'warning' && r.message.contains('deadline'),
        ),
        isTrue,
      );
      pending.complete(const Ok(null));
      time.flushMicrotasks();
      expect(logger.records.where((r) => r.level == 'info'), isEmpty);
    });
  });

  test(
    'completion does not stringify payloads or label partial recovery successful',
    () {
      const result = Ok<String, WalletBackupFailure>('payload-secret-canary');
      expect(
        logWalletBackupCompletion(WalletBackupOperation.export, result),
        same(result),
      );
      expect(
        logger.records.single.message,
        isNot(contains('payload-secret-canary')),
      );
      final partial = Ok<WalletBackupRecovery, WalletBackupFailure>(
        WalletBackupRecovery(
          wallets: WalletInventoryRecovery(
            walletReferences: {},
            failedReferences: ['descriptor-secret-canary'],
          ),
          publicRecordsRestored: true,
          metadataRestored: false,
        ),
      );
      expect(
        logWalletBackupCompletion(WalletBackupOperation.recover, partial),
        same(partial),
      );
      expect(logger.records.last.level, 'warning');
      expect(
        logger.records.last.message,
        contains('WalletBackupIncompleteFailure'),
      );
      expect(
        logger.records.last.message,
        isNot(contains('descriptor-secret-canary')),
      );
    },
  );

  test(
    'unexpected method and path strings are excluded from diagnostics',
    () async {
      final result = await transport.send(
        method: 'METHOD-secret-canary',
        path: '/secret-canary?key=secret',
        body: {},
      );
      expect(result, isA<Ok>());
      expect(
        logger.records.single.message,
        contains('method=unknown path=unknown'),
      );
      expect(logger.records.single.message, isNot(contains('secret')));
    },
  );
}
