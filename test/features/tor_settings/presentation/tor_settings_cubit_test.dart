import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/update_tor_settings_usecase.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_transport_mode_usecase.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tor/tor.dart';
import 'package:tor/tor_adapter.dart';

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockUpdateTorSettingsUsecase extends Mock
    implements UpdateTorSettingsUsecase {}

class _MockUpdateTorTransportModeUsecase extends Mock
    implements UpdateTorTransportModeUsecase {}

class _MockEnsureTorReadyUsecase extends Mock
    implements EnsureTorReadyUsecase {}

class _MockWatchTorConnectionUsecase extends Mock
    implements WatchTorConnectionUsecase {}

class _FakeExternalTorPort implements ExternalTorPort {
  @override
  Future<void> verify(TorProxyEndpoint endpoint) async {}
}

void main() {
  test('does not emit when settings finish loading after close', () async {
    final getSettings = _MockGetSettingsUsecase();
    final settings = Completer<SettingsEntity>();
    when(() => getSettings.execute()).thenAnswer((_) => settings.future);

    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorSettingsUsecase: _MockUpdateTorSettingsUsecase(),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
      watchTorConnectionUsecase: _MockWatchTorConnectionUsecase(),
      verifyExternalTorUsecase: VerifyExternalTorUsecase(
        _FakeExternalTorPort(),
      ),
    );

    final initialization = cubit.init();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    settings.complete(
      const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );

    await expectLater(initialization, completes);
  });
}
