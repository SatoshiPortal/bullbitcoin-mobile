import 'package:bb_mobile/core/electrum/adapters/electrum_tor_session_adapter.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_tor_session_port.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/di/electrum_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
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

  test('can be resolved before the Tor facade is registered', () {
    final locator = GetIt.asNewInstance();
    ElectrumLocator.registerPorts(locator);

    expect(locator<ElectrumTorSessionPort>(), isA<ElectrumTorSessionAdapter>());
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
