import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_drive_discovery_port.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/log_sink.dart';
import '../support/monitoring_repository.dart';
import '../support/ui_labels.dart';

class _Wallets extends Mock implements RecoverBullWalletRepository {}

class _Seeds extends Mock implements RecoverBullSeedPort {}

class _Defaults extends Mock implements RecoverBullDefaultWalletsPort {}

class _Settings extends Mock implements RecoverBullSettingsPort {}

class _Tor extends Mock implements Tor {}

class _Embedded extends Mock implements EmbeddedTor {}

class _Watcher extends Mock implements WatchTorConnectionUsecase {}

class _Discovery implements RecoverBullDriveDiscoveryPort {
  @override
  Future<T> withDiscoverySession<T>(
    Future<T> Function(RecoverBullDriveDiscoverySession?) action,
  ) => action(null);
}

Future<RecoverBullFeature> _create(String? path) {
  final tor = _Tor();
  final embedded = _Embedded();
  final watcher = _Watcher();
  when(() => tor.embedded).thenReturn(embedded);
  when(() => embedded.watcher).thenReturn(watcher);
  when(watcher.execute).thenAnswer((_) => const Stream.empty());
  return RecoverBullFeature.create(
    config: RecoverBullConfig(
      databasePath: path,
      initialPermissionGranted: true,
      initialServerUrlOverride: Uri.parse('http://legacy.onion'),
    ),
    uiLabels: testUiLabels,
    navigation: RecoverBullNavigationCallbacks(
      onOpenTorSettings: () {},
      onOpenWalletHome: () {},
    ),
    wallets: _Wallets(),
    seeds: _Seeds(),
    defaultWallets: _Defaults(),
    settings: _Settings(),
    tor: tor,
    log: const TestLogSink(),
    driveDiscovery: _Discovery(),
  );
}

Future<void> _expectTemporary(RecoverBullFeature feature) async {
  expect(feature.storageMode, RecoverBullStorageMode.temporary);
  final settings = (await feature.serverSettings().requireOk());
  expect(settings.permissionGranted, isFalse);
  expect(settings.server.toString(), recoverBullDefaultServerUrl);
  expect((await feature.attemptMonitoring.status()).enabled, isFalse);
  expect((await feature.attemptMonitoring.status()).enabledAllowed, isFalse);
  await feature.attemptMonitoring.setEnabled(true);
  expect(feature.attemptMonitoring.enabled, isFalse);
  expect((await feature.status(RecoverBullNetwork.mainnet)).isKnown, isFalse);
  await feature.setPermission(true).requireOk();
  await feature.setServer(Uri.parse('http://chosen.onion')).requireOk();
  expect(
    (await feature.serverSettings().requireOk()).permissionGranted,
    isFalse,
  );
  await feature.setPermission(true).requireOk();
  expect(
    (await feature.serverSettings().requireOk()).permissionGranted,
    isTrue,
  );
  await feature.markBackupStored(RecoverBullNetwork.mainnet).requireOk();
  await feature.markBackupVerified(RecoverBullNetwork.mainnet).requireOk();
  expect((await feature.status(RecoverBullNetwork.mainnet)).isKnown, isFalse);
}

void main() {
  test(
    'missing application documents directory still permits a fresh recovery session',
    () async {
      final feature = await _create(null);
      addTearDown(feature.lifecycle.dispose);
      await _expectTemporary(feature);
      await feature.lifecycle.dispose();
      // Only this session has consent; a new session must confirm again.
      final reopened = await _create(null);
      addTearDown(reopened.lifecycle.dispose);
      expect(
        (await reopened.serverSettings().requireOk()).permissionGranted,
        isFalse,
      );
    },
  );

  test(
    'a non-corrupt storage failure preserves the original file and recovery settings work',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-storage-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final blocker = File('${directory.path}/blocked')
        ..writeAsStringSync('user data');
      final feature = await _create('${blocker.path}/recoverbull.sqlite');
      addTearDown(feature.lifecycle.dispose);
      await _expectTemporary(feature);
      expect(blocker.readAsStringSync(), 'user data');
      expect(directory.listSync().map((f) => f.path), [blocker.path]);
    },
  );

  test(
    'a newer schema is preserved and recovery uses isolated temporary storage',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-future-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/recoverbull.sqlite';
      final db = sqlite3.open(path);
      db.execute('CREATE TABLE future_private_data (value TEXT)');
      db.execute("INSERT INTO future_private_data VALUES ('preserve')");
      db.execute('PRAGMA user_version = 100');
      db.dispose();
      final feature = await _create(path);
      addTearDown(feature.lifecycle.dispose);
      await _expectTemporary(feature);
      final original = sqlite3.open(path);
      addTearDown(original.dispose);
      expect(original.select('PRAGMA user_version').single.values.single, 100);
      expect(
        original
            .select('SELECT value FROM future_private_data')
            .single['value'],
        'preserve',
      );
      expect(
        directory.listSync().where((f) => f.path.contains('.corrupt')),
        isEmpty,
      );
    },
  );
}
