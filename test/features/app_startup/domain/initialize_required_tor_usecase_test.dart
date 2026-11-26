import 'package:bull_recoverbull/bull_recoverbull.dart'
    show RecoverBullFailure, VaultStorageFailure;
import 'package:startup/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

class _MockEmbeddedTor extends Mock implements EmbeddedTor {}

class _MockTor extends Mock implements Tor {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockExternalTor extends Mock implements ExternalTor {}

SettingsEntity _settings({required bool useTorProxy, int port = 9050}) =>
    SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
      useTorProxy: useTorProxy,
      torProxyPort: port,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 9050));
  });
  late Result<bool, RecoverBullFailure> backup;
  late _MockEmbeddedTor embedded;
  late _MockSettingsRepository settingsRepository;
  late _MockExternalTor externalTor;
  late InitializeRequiredTorUsecase usecase;

  setUp(() {
    backup = const Ok(false);
    embedded = _MockEmbeddedTor();
    settingsRepository = _MockSettingsRepository();
    externalTor = _MockExternalTor();
    final tor = _MockTor();
    when(() => tor.embedded).thenReturn(embedded);
    when(() => tor.external).thenReturn(externalTor);
    usecase = InitializeRequiredTorUsecase(
      () async => backup,
      settingsRepository,
      tor,
    );
  });

  test('does not start embedded Tor without an encrypted backup', () async {
    backup = const Ok(false);

    expect(await usecase.execute(), isNull);
    verifyNever(() => settingsRepository.fetch());
    verifyNever(() => embedded.ensureReady());
  });

  test('uses external Tor when it is ready', () async {
    final route = TorRoute(
      source: TorSource.external,
      endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
      evidence: TorReadinessEvidence.externalSocksHandshake,
    );
    backup = const Ok(true);
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => Ok(_settings(useTorProxy: true)));
    when(() => externalTor.verify(any()))
        .thenAnswer((_) async => TorReady(route));

    final state = await usecase.execute();
    expect(state, isA<TorReady>());
    expect((state! as TorReady).route, same(route));
    verifyNever(() => embedded.ensureReady());
  });

  test(
    'does not fall back to embedded Tor when external Tor is unavailable',
    () async {
      final failure = TorExternalProxyUnavailableFailure('offline');
      backup = const Ok(true);
      when(() => settingsRepository.fetch())
          .thenAnswer((_) async => Ok(_settings(useTorProxy: true)));
      when(() => externalTor.verify(any())).thenAnswer(
        (_) async =>
            TorUnavailable(source: TorSource.external, failure: failure),
      );

      final state = await usecase.execute();
      expect(state, isA<TorUnavailable>());
      expect((state! as TorUnavailable).source, TorSource.external);
      verifyNever(() => embedded.ensureReady());
    },
  );

  test('starts embedded Tor when external Tor is disabled', () async {
    final ready = const TorUninitialized();
    backup = const Ok(true);
    when(() => settingsRepository.fetch())
        .thenAnswer((_) async => Ok(_settings(useTorProxy: false)));
    when(() => embedded.ensureReady()).thenAnswer((_) async => ready);

    expect(await usecase.execute(), same(ready));
    verify(() => embedded.ensureReady()).called(1);
  });

  test('skips Tor when the backup check fails, as before', () async {
    backup = const Err(VaultStorageFailure());

    expect(await usecase.execute(), isNull);
    verifyNever(() => embedded.ensureReady());
    verifyNever(() => settingsRepository.fetch());
  });
}
