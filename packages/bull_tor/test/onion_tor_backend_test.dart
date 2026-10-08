import 'dart:io';

import 'package:bull_sdk/onion.dart' as onion;
import 'package:bull_tor/src/data/onion_client_launcher.dart';
import 'package:bull_tor/src/data/onion_tor_backend.dart';
import 'package:bull_tor/src/data/tor_logger.dart';
import 'package:bull_tor/src/domain/ports/embedded_tor_port.dart';
import 'package:bull_tor/tor.dart';
import 'package:test/test.dart';

void main() {
  final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41001);

  onion.TorStatus blocked(onion.BlockageKind kind, String message) =>
      onion.TorStatus(
        fraction: 0.4,
        readyForTraffic: false,
        blockage: onion.Blockage(kind: kind, message: message),
        stage: '',
        transport: onion.TorTransport.direct,
      );

  group('OnionTorBackend.eventFor', () {
    test('keeps arti\'s blockage message as the bootstrap detail', () {
      final event = OnionTorBackend.eventFor(
        blocked(onion.BlockageKind.clockSkewed, 'Clock is skewed by 2 hours'),
        endpoint,
      );

      expect(event, isA<EmbeddedTorConnecting>());
      final connecting = event as EmbeddedTorConnecting;
      expect(connecting.diagnostic, TorDiagnostic.clockSkewed);
      expect(connecting.detail?.blockage, 'Clock is skewed by 2 hours');
      expect(connecting.detail?.stage, isNull);
    });

    // `notStarted` is arti describing our own manual bootstrap back to us.
    test('drops the message of a blockage that is not a fault', () {
      final event = OnionTorBackend.eventFor(
        blocked(
          onion.BlockageKind.notStarted,
          'Client is waiting to be told to bootstrap',
        ),
        endpoint,
      );

      expect((event as EmbeddedTorConnecting).detail, isNull);
    });

    test('carries arti\'s bootstrap stage next to the blockage', () {
      final event = OnionTorBackend.eventFor(
        const onion.TorStatus(
          fraction: 0.4,
          readyForTraffic: false,
          blockage: onion.Blockage(
            kind: onion.BlockageKind.clockSkewed,
            message: 'Clock is skewed by 2 hours',
          ),
          stage: 'Stuck at 40%: Clock is skewed by 2 hours',
          transport: onion.TorTransport.direct,
        ),
        endpoint,
      );

      final detail = (event as EmbeddedTorConnecting).detail;
      expect(detail?.stage, 'Stuck at 40%: Clock is skewed by 2 hours');
      expect(detail?.blockage, 'Clock is skewed by 2 hours');
    });

    test('reports the bootstrap stage when arti reports no blockage', () {
      final event = OnionTorBackend.eventFor(
        const onion.TorStatus(
          fraction: 0.4,
          readyForTraffic: false,
          stage: '40%: directory is fetching microdescriptors (120/300)',
          transport: onion.TorTransport.direct,
        ),
        endpoint,
      );

      final detail = (event as EmbeddedTorConnecting).detail;
      expect(
        detail?.stage,
        '40%: directory is fetching microdescriptors (120/300)',
      );
      expect(detail?.blockage, isNull);
    });

    test('carries no detail when arti reports no blockage', () {
      final event = OnionTorBackend.eventFor(
        const onion.TorStatus(
          fraction: 0.4,
          readyForTraffic: false,
          stage: '',
          transport: onion.TorTransport.direct,
        ),
        endpoint,
      );

      expect((event as EmbeddedTorConnecting).detail, isNull);
    });
  });

  test('a failed bootstrap keeps the last blockage detail', () {
    final failure = OnionTorBackend.failureFor(
      const onion.TorFailure(
        kind: onion.TorFailureKind.bootstrap,
        logMessage: 'bootstrap failed',
      ),
      TorDiagnostic.clockSkewed,
      const TorBootstrapDetail(blockage: 'Clock is skewed by 2 hours'),
    );

    expect(failure, isA<TorBootstrapFailure>());
    final bootstrap = failure as TorBootstrapFailure;
    expect(bootstrap.diagnostic, TorDiagnostic.clockSkewed);
    expect(bootstrap.detail?.blockage, 'Clock is skewed by 2 hours');
  });

  group('OnionTorBackend.start', () {
    late Directory root;
    late _RecordingLauncher launcher;
    late OnionTorBackend backend;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('bull_tor_backend_');
      launcher = _RecordingLauncher();
      final directories = torDirectoriesUnder('${root.path}/support');
      backend = OnionTorBackend(
        const TorLogger(),
        launcher: launcher,
        directories: (_) async => directories,
      );
    });

    tearDown(() async {
      await backend.close();
      await root.delete(recursive: true);
    });

    Future<OnionClientConfig> configFor(TorTransport transport) async {
      await expectLater(
        backend.start(transport),
        throwsA(isA<TorBackendException>()),
      );
      return launcher.configs.last;
    }

    // Arti refuses bridges to a client without the state-directory lock, and
    // the client stopped just before may still hold it.
    test('gives Snowflake a state directory of its own', () async {
      final direct = await configFor(TorTransport.direct);
      final snowflake = await configFor(TorTransport.snowflake);

      expect(snowflake.stateDir, isNot(direct.stateDir));
      expect(snowflake.snowflakePort, _RecordingLauncher.snowflakePort);
      expect(Directory(snowflake.stateDir).existsSync(), isTrue);
    });

    test('shares the directory cache between transports', () async {
      final direct = await configFor(TorTransport.direct);
      final snowflake = await configFor(TorTransport.snowflake);

      expect(snowflake.cacheDir, direct.cacheDir);
    });
  });

  // Android may purge an app's cache directory whenever storage runs low,
  // and a purged directory costs the next bootstrap its 30 to 45 s download.
  test('keeps the directory cache next to the Tor state', () {
    final directories = torDirectoriesUnder('/support');

    expect(directories.cache, '/support/tor_cache');
    expect({
      directories.directState,
      directories.snowflakeState,
      directories.cache,
    }, hasLength(3));
  });

  group('adoptLegacyTorCache', () {
    late Directory root;
    late String legacy;
    late String durable;
    final warnings = <Object?>[];
    final log = TorLogger(
      warningCallback: (message, {error, trace}) => warnings.add(message),
    );

    setUp(() async {
      root = await Directory.systemTemp.createTemp('bull_tor_cache_');
      legacy = '${root.path}/cache/tor';
      durable = '${root.path}/support/tor_cache';
      warnings.clear();
    });

    tearDown(() => root.delete(recursive: true));

    Future<void> adopt() =>
        adoptLegacyTorCache(legacy: legacy, durable: durable, log: log);

    test('moves an existing cache to the durable location', () async {
      await File('$legacy/dir.sqlite3').create(recursive: true);

      await adopt();

      expect(File('$durable/dir.sqlite3').existsSync(), isTrue);
      expect(Directory(legacy).existsSync(), isFalse);
    });

    test('keeps a durable cache and drops the legacy one', () async {
      await File('$legacy/dir.sqlite3').create(recursive: true);
      await File('$legacy/dir.sqlite3').writeAsString('legacy', flush: true);
      await File('$durable/dir.sqlite3').create(recursive: true);
      await File('$durable/dir.sqlite3').writeAsString('durable', flush: true);

      await adopt();

      expect(File('$durable/dir.sqlite3').readAsStringSync(), 'durable');
      expect(Directory(legacy).existsSync(), isFalse);
    });

    test('does nothing without a legacy cache', () async {
      await adopt();

      expect(Directory(durable).existsSync(), isFalse);
      expect(warnings, isEmpty);
    });

    // A cache is only worth a download: losing it must not stop Tor.
    test('gives up quietly when the move fails', () async {
      await File('$legacy/dir.sqlite3').create(recursive: true);
      // The durable location's parent is a file, so nothing can go there.
      await File('${root.path}/support').create(recursive: true);

      await expectLater(adopt(), completes);

      expect(warnings, isNotEmpty);
      expect(Directory(durable).existsSync(), isFalse);
    });
  });
}

final class _RecordingLauncher implements OnionClientLauncher {
  static const snowflakePort = 41999;

  final configs = <OnionClientConfig>[];

  @override
  Future<onion.TorService> startClient(
    OnionClientConfig config,
    onion.SocksPolicy policy,
  ) async {
    configs.add(config);
    throw StateError('no native Tor in tests');
  }

  @override
  Future<int> startSnowflakeProxy() async => snowflakePort;

  @override
  Future<void> stopSnowflakeProxy() async {}
}
