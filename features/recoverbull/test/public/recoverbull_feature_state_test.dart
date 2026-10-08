import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_drive_discovery_port.dart';
import 'package:bull_recoverbull/src/ui/screens/recoverbull_unavailable_page.dart';
import 'package:bull_tor/tor.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../support/log_sink.dart';

class _Settings extends Mock implements RecoverBullSettingsPort {}

class _Wallets extends Mock implements RecoverBullWalletRepository {}

class _Seeds extends Mock implements RecoverBullSeedPort {}

class _Defaults extends Mock implements RecoverBullDefaultWalletsPort {}

class _Tor extends Mock implements Tor {}

class _EmbeddedTor extends Mock implements EmbeddedTor {}

class _Watcher extends Mock implements WatchTorConnectionUsecase {}

final class _CountingDriveDiscovery implements RecoverBullDriveDiscoveryPort {
  int sessions = 0;

  @override
  Future<T> withDiscoverySession<T>(
    Future<T> Function(RecoverBullDriveDiscoverySession? session) action,
  ) {
    sessions++;
    return action(null);
  }
}

Future<RecoverBullFeature> _createFeature(
  String path, {
  RecoverBullDriveDiscoveryPort? driveDiscovery,
}) {
  final tor = _Tor();
  final embedded = _EmbeddedTor();
  when(() => tor.embedded).thenReturn(embedded);
  final watcher = _Watcher();
  when(watcher.execute).thenAnswer((_) => const Stream.empty());
  when(() => embedded.watcher).thenReturn(watcher);
  return RecoverBullFeature.create(
    config: RecoverBullConfig(databasePath: path),
    wallets: _Wallets(),
    seeds: _Seeds(),
    defaultWallets: _Defaults(),
    settings: _Settings(),
    tor: tor,
    log: const TestLogSink(),
    driveDiscovery: driveDiscovery ?? _CountingDriveDiscovery(),
  );
}

void main() {
  late Directory directory;
  late String path;
  RecoverBullFeature? opened;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('recoverbull-feature-');
    path = '${directory.path}/state.sqlite';
  });

  tearDown(() async {
    await opened?.lifecycle.dispose();
    opened = null;
    await directory.delete(recursive: true);
  });

  test('a fresh database knows there is no encrypted backup yet', () async {
    final feature = opened = await _createFeature(path);

    final status = await feature.status();

    expect(status.isKnown, isTrue);
    expect(status.hasEncryptedBackup, isFalse);
  });

  test('status stays unknown after a corrupt database is archived until a '
      'backup is recorded again', () async {
    await File(path).writeAsString('not sqlite');

    var feature = opened = await _createFeature(path);
    expect((await feature.status()).isKnown, isFalse);

    await feature.lifecycle.dispose();
    feature = opened = await _createFeature(path);
    expect((await feature.status()).isKnown, isFalse);

    await feature.markBackupStored();
    final status = await feature.status();
    expect(status.isKnown, isTrue);
    expect(status.hasEncryptedBackup, isTrue);
  });

  test('setServer marks monitored backups for a silent rebaseline on the new '
      'server', () async {
    final feature = opened = await _createFeature(path);
    final database = await feature.lifecycle.openDatabase(path);
    await database
        .into(database.recoverbullMonitoredBackup)
        .insert(
          RecoverbullMonitoredBackupCompanion.insert(
            digest: Uint8List(32),
            expectedServerDistinctCandidateTotal: const Value(4),
            currentWindow: const Value(9),
            lastWarningWindow: const Value(7),
            rowRevision: const Value(3),
          ),
        );

    await feature.setServer(Uri.parse('http://newexample.onion'));

    final row = await database
        .select(database.recoverbullMonitoredBackup)
        .getSingle();
    expect(row.expectedServerDistinctCandidateTotal, 0);
    expect(row.currentWindow, 0);
    expect(row.lastWarningWindow, 0);
    expect(row.rowRevision, 0);
    final settings = await feature.serverSettings();
    expect(settings.server, Uri.parse('http://newexample.onion'));
    expect(settings.permissionGranted, isFalse);
  });

  test(
    'Drive discovery waits for an explicit start and an encrypted backup',
    () async {
      final drive = _CountingDriveDiscovery();
      final feature = opened = await _createFeature(
        path,
        driveDiscovery: drive,
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(drive.sessions, 0);

      await feature.discoverDriveBackups();
      expect(drive.sessions, 0);

      await feature.markBackupStored();
      await feature.discoverDriveBackups();
      expect(drive.sessions, 1);
    },
  );

  test(
    'flows trash the server key of a vault abandoned before any save',
    () async {
      final feature = opened = await _createFeature(path);

      final bloc = feature.newBlocForTesting(
        flow: RecoverBullFlow.secureVault,
      )!;
      addTearDown(bloc.close);

      expect(bloc.trashesAbandonedVaultKeys, isTrue);
    },
  );

  test('the unavailable feature builds no flow bloc', () {
    final feature = RecoverBullFeature.unavailable(log: const TestLogSink());

    expect(
      feature.newBlocForTesting(flow: RecoverBullFlow.secureVault),
      isNull,
    );
  });

  testWidgets('every route of the unavailable feature shows an error page', (
    tester,
  ) async {
    final feature = RecoverBullFeature.unavailable(log: const TestLogSink());
    final router = GoRouter(
      initialLocation: RecoverBullRoute.recoverbullSettings.path,
      routes: feature.routes,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecoverBullUnavailablePage), findsOneWidget);

    router.go(RecoverBullGoogleDriveRoute.recoverbullListDriveVaults.path);
    await tester.pumpAndSettle();
    expect(find.byType(RecoverBullUnavailablePage), findsOneWidget);
    expect(feature.isAvailable, isFalse);
    expect((await feature.status()).isKnown, isFalse);
  });
}
