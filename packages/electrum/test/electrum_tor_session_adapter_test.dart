import 'package:electrum/testing.dart';
import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'electrum_test_database.dart';

import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

class _MockTor extends Mock implements Tor {}

class _MockEmbeddedTor extends Mock implements EmbeddedTor {}

class _MockTorSessions extends Mock implements TorSessions {}

class _MockExternalTor extends Mock implements ExternalTor {}

void main() {
  late _MockTor tor;
  late _MockEmbeddedTor embedded;
  late _MockTorSessions sessions;
  late _MockExternalTor external;
  late ElectrumTorSessionAdapter adapter;

  setUp(() {
    tor = _MockTor();
    embedded = _MockEmbeddedTor();
    sessions = _MockTorSessions();
    external = _MockExternalTor();
    when(() => tor.embedded).thenReturn(embedded);
    when(() => tor.external).thenReturn(external);
    when(() => embedded.sessions).thenReturn(sessions);
    adapter = ElectrumTorSessionAdapter(() => tor);
  });

  setUpAll(() {
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 9050));
  });

  test('opens and exposes the sync connection policy before Tor is ready', () {
    final database = ElectrumTestDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final electrum = createElectrumForTesting(
      database: database,
      readPreferences: () async => throw StateError('Settings are not ready'),
      tor: () => throw StateError('Tor is not ready'),
    );

    expect(electrum.walletConnections, isA<WalletConnectionPolicyImpl>());
  });

  test('opens an embedded session for Bitcoin onion servers', () async {
    var closed = false;
    final session = TorSession(
      TorProxyEndpoint(host: '127.0.0.1', port: 41001),
      TorTransport.snowflake,
      () async => closed = true,
    );
    when(() => sessions.open()).thenAnswer((_) async => session);

    final route = await adapter.open(
      network: ElectrumServerNetwork.bitcoinMainnet,
      serverUrl: 'ssl://hidden.onion:50002',
      isCustom: true,
      externalProxyEnabled: false,
      externalProxyPort: 9150,
    );

    expect(route?.endpoint, session.endpoint);
    await route?.close();
    expect(closed, isTrue);
  });

  test('verifies external SOCKS5 for a custom Bitcoin onion server', () async {
    when(() => external.verify(any())).thenAnswer(
      (_) async => TorReady(
        TorRoute(
          source: TorSource.external,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 9150),
          evidence: TorReadinessEvidence.externalSocksHandshake,
        ),
      ),
    );
    final route = await adapter.open(
      network: ElectrumServerNetwork.bitcoinMainnet,
      serverUrl: 'ssl://hidden.onion:50002',
      isCustom: true,
      externalProxyEnabled: true,
      externalProxyPort: 9150,
    );

    expect(route?.endpoint.authority, '127.0.0.1:9150');
    verifyNever(() => sessions.open());
  });

  test('keeps Bitcoin clearnet servers direct', () async {
    final route = await adapter.open(
      network: ElectrumServerNetwork.bitcoinMainnet,
      serverUrl: 'ssl://electrum.example:50002',
      isCustom: true,
      externalProxyEnabled: true,
      externalProxyPort: 9150,
    );

    expect(route, isNull);
    verifyNever(() => sessions.open());
  });

  test('leaves clearnet and Liquid servers direct', () async {
    final clearnet = await adapter.open(
      network: ElectrumServerNetwork.bitcoinMainnet,
      serverUrl: 'ssl://electrum.example:50002',
      isCustom: true,
      externalProxyEnabled: false,
      externalProxyPort: 9150,
    );
    final liquid = await adapter.open(
      network: ElectrumServerNetwork.liquidMainnet,
      serverUrl: 'ssl://hidden.onion:50002',
      isCustom: false,
      externalProxyEnabled: true,
      externalProxyPort: 9150,
    );

    expect(clearnet, isNull);
    expect(liquid, isNull);
    verifyNever(() => sessions.open());
  });

  test('fails closed for an external port below the valid range', () async {
    expect(
      () => adapter.open(
        network: ElectrumServerNetwork.bitcoinMainnet,
        serverUrl: 'ssl://hidden.onion:50002',
        isCustom: true,
        externalProxyEnabled: true,
        externalProxyPort: 0,
      ),
      throwsA(isA<OnionServerWithoutTorException>()),
    );
    verifyNever(() => external.verify(any()));
    verifyNever(() => sessions.open());
  });

  test('fails closed for an external port above the valid range', () async {
    expect(
      () => adapter.open(
        network: ElectrumServerNetwork.bitcoinMainnet,
        serverUrl: 'ssl://hidden.onion:50002',
        isCustom: true,
        externalProxyEnabled: true,
        externalProxyPort: 65536,
      ),
      throwsA(isA<OnionServerWithoutTorException>()),
    );
    verifyNever(() => external.verify(any()));
    verifyNever(() => sessions.open());
  });
}
