import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_transport_mode_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tor/tor.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockEmbeddedTor extends Mock implements EmbeddedTor {}

void main() {
  test('persists the preference before reconfiguring embedded Tor', () async {
    final settingsRepository = _MockSettingsRepository();
    final embeddedTor = _MockEmbeddedTor();
    final ready = TorReady(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.snowflake,
      ),
    );
    when(
      () => settingsRepository.setTorTransportMode(TorTransportMode.snowflake),
    ).thenAnswer((_) async {});
    when(
      () => embeddedTor.setMode(TorTransportMode.snowflake),
    ).thenAnswer((_) async => ready);
    final usecase = UpdateTorTransportModeUsecase(
      settingsRepository,
      embeddedTor,
    );

    final result = await usecase.execute(TorTransportMode.snowflake);

    expect(result, same(ready));
    verifyInOrder([
      () => settingsRepository.setTorTransportMode(TorTransportMode.snowflake),
      () => embeddedTor.setMode(TorTransportMode.snowflake),
    ]);
  });
}
