import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

final class _Logger implements RecoverBullLogger {
  @override
  void fine(String message, {Object? error, StackTrace? trace}) {}

  @override
  void info(String message, {Object? error, StackTrace? trace}) {}

  @override
  void error(String code, {Object? error, StackTrace? trace}) {}

  @override
  void warning(String message, {Object? error, StackTrace? trace}) {}
}

final class _Settings extends Mock implements RecoverBullSettingsPort {}

final class _Wallets extends Mock implements RecoverBullWalletRepository {}

final class _Seeds extends Mock implements RecoverBullSeedPort {}

final class _Defaults extends Mock implements RecoverBullDefaultWalletsPort {}

final class _Tor extends Mock implements Tor {}

final class _EmbeddedTor extends Mock implements EmbeddedTor {}

final class _TorSessions extends Mock implements TorSessions {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('public route enum covers every flow, including test vault', () {
    expect(
      RecoverBullRoute.values.map((route) => route.name),
      containsAll([
        'recoverbullSecureVault',
        'recoverbullRecoverVault',
        'recoverbullTestVault',
        'recoverbullViewVaultKey',
        'recoverbullSettings',
      ]),
    );
  });

  test('public route names are unique across RecoverBull route enums', () {
    final names = [
      ...RecoverBullRoute.values.map((route) => route.name),
      ...RecoverBullGoogleDriveRoute.values.map((route) => route.name),
    ];
    expect(names.toSet(), hasLength(names.length));
  });

  test('package localizations expose every supported locale', () {
    expect(RecoverBullLocalizations.supportedLocales.length, 27);
    expect(
      RecoverBullLocalizations.supportedLocales,
      contains(const Locale('fr')),
    );
  });

  test(
    'package delegate resolves a non-English locale and assets are bundled',
    () async {
      final localizations = await RecoverBullLocalizations.delegate.load(
        const Locale('fr'),
      );
      expect(localizations.localeName, 'fr');
      expect(
        (await rootBundle.load(
          'packages/bull_recoverbull/assets/animations/tor_bull_ready.png',
        )).lengthInBytes,
        greaterThan(0),
      );
    },
  );

  test('test vault remains reachable before any backup exists', () async {
    const status = RecoverBullStatus.initial();
    expect(status.hasEncryptedBackup, isFalse);
    expect(status.hasVerifiedEncryptedBackup, isFalse);

    final verifiedStatus = RecoverBullStatus(
      lastVerifiedEncryptedBackupAt: DateTime(2026),
    );
    expect(verifiedStatus.hasEncryptedBackup, isTrue);
    expect(verifiedStatus.hasVerifiedEncryptedBackup, isTrue);

    final tor = _Tor();
    final embedded = _EmbeddedTor();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'recoverbull-ui-contract-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    when(() => tor.embedded).thenReturn(embedded);
    when(() => embedded.watcher).thenReturn(_MockWatchTorConnection());
    final recoverBull = await RecoverBullFeature.create(
      config: RecoverBullConfig(
        databasePath: '${tempDirectory.path}/recoverbull.sqlite',
      ),
      wallets: _Wallets(),
      seeds: _Seeds(),
      defaultWallets: _Defaults(),
      settings: _Settings(),
      tor: tor,
      logger: _Logger(),
    );
    await recoverBull.lifecycle.dispose();
  });

  test('composition forwards timing events from Tor acquisition', () async {
    final tor = _Tor();
    final embedded = _EmbeddedTor();
    final sessions = _TorSessions();
    final settings = _Settings();
    final timings =
        <({String phase, int durationMilliseconds, String outcome})>[];
    final tempDirectory = await Directory.systemTemp.createTemp(
      'recoverbull-timing-contract-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    var closeCount = 0;
    final readyRoute = TorRoute(
      source: TorSource.embedded,
      endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
      evidence: TorReadinessEvidence.embeddedBootstrap,
      transport: TorTransport.direct,
    );
    final session = TorSession(
      TorProxyEndpoint(host: '127.0.0.1', port: 19051),
      TorTransport.direct,
      () async => closeCount++,
    );
    when(() => tor.embedded).thenReturn(embedded);
    when(() => embedded.watcher).thenReturn(_MockWatchTorConnection());
    when(() => embedded.sessions).thenReturn(sessions);
    when(
      () => embedded.ensureReady(),
    ).thenAnswer((_) async => TorReady(readyRoute));
    when(() => sessions.open()).thenAnswer((_) async => session);
    when(() => settings.fetch()).thenAnswer(
      (_) async =>
          const RecoverBullTorSettings(useTorProxy: false, torProxyPort: 9050),
    );

    final recoverBull = await RecoverBullFeature.create(
      config: RecoverBullConfig(
        databasePath: '${tempDirectory.path}/recoverbull.sqlite',
      ),
      wallets: _Wallets(),
      seeds: _Seeds(),
      defaultWallets: _Defaults(),
      settings: settings,
      tor: tor,
      logger: _Logger(),
      timing: (phase, durationMilliseconds, outcome) => timings.add((
        phase: phase,
        durationMilliseconds: durationMilliseconds,
        outcome: outcome,
      )),
    );

    expect(await recoverBull.ensureTorReady(), isTrue);
    expect(timings, hasLength(1));
    expect(timings.single.phase, 'tor_route_acquire');
    expect(timings.single.durationMilliseconds, isNonNegative);
    expect(timings.single.outcome, 'success');
    expect(closeCount, 1);
    await recoverBull.lifecycle.dispose();
  });
}

final class _MockWatchTorConnection extends Mock
    implements WatchTorConnectionUsecase {}
