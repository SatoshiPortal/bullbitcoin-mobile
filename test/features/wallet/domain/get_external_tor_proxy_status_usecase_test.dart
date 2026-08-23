import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_external_tor_proxy_status_usecase.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/src/domain/ports/external_tor_port.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _FakeExternalTorPort implements ExternalTorPort {
  _FakeExternalTorPort(this.available);

  final bool available;
  int verificationCount = 0;

  @override
  Future<void> verify(TorProxyEndpoint endpoint) async {
    verificationCount++;
    if (!available) throw StateError('proxy unavailable');
  }
}

SettingsEntity settings({required bool useTorProxy, int port = 9050}) =>
    SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
      useTorProxy: useTorProxy,
      torProxyPort: port,
    );

void main() {
  test('returns unavailable when the enabled proxy handshake fails', () async {
    final repository = _MockSettingsRepository();
    when(repository.fetch).thenAnswer((_) async => settings(useTorProxy: true));
    final port = _FakeExternalTorPort(false);

    final status = await GetExternalTorProxyStatusUsecase(
      repository,
      VerifyExternalTorUsecase(port),
    ).execute();

    expect(status, ExternalTorProxyStatus.unavailable);
  });

  test('returns available when the enabled proxy handshake succeeds', () async {
    final repository = _MockSettingsRepository();
    when(repository.fetch).thenAnswer((_) async => settings(useTorProxy: true));
    final port = _FakeExternalTorPort(true);

    final status = await GetExternalTorProxyStatusUsecase(
      repository,
      VerifyExternalTorUsecase(port),
    ).execute();

    expect(status, ExternalTorProxyStatus.available);
  });

  test('returns disabled without checking a disabled proxy', () async {
    final repository = _MockSettingsRepository();
    when(
      repository.fetch,
    ).thenAnswer((_) async => settings(useTorProxy: false));
    final port = _FakeExternalTorPort(true);

    final status = await GetExternalTorProxyStatusUsecase(
      repository,
      VerifyExternalTorUsecase(port),
    ).execute();

    expect(status, ExternalTorProxyStatus.disabled);
    expect(port.verificationCount, 0);
  });

  test('returns unavailable for an invalid enabled port', () async {
    final repository = _MockSettingsRepository();
    when(
      repository.fetch,
    ).thenAnswer((_) async => settings(useTorProxy: true, port: 0));
    final port = _FakeExternalTorPort(true);

    final status = await GetExternalTorProxyStatusUsecase(
      repository,
      VerifyExternalTorUsecase(port),
    ).execute();

    expect(status, ExternalTorProxyStatus.unavailable);
    expect(port.verificationCount, 0);
  });
}
