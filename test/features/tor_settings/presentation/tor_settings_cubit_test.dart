import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/update_tor_settings_usecase.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/tor_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockUpdateTorSettingsUsecase extends Mock
    implements UpdateTorSettingsUsecase {}

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

  // The port sheet validates 1-65535 but the repository does not, so a corrupted
  // or legacy stored value used to throw *after* Connecting was emitted, leaving
  // the card spinning forever with the error unhandled.
  test(
    'an out-of-range stored port reports unavailable, not a spinner',
    () async {
      final getSettings = _MockGetSettingsUsecase();
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          useTorProxy: true,
          torProxyPort: 0,
        ),
      );

      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorSettingsUsecase: _MockUpdateTorSettingsUsecase(),
        verifyExternalTorUsecase: VerifyExternalTorUsecase(
          _FakeExternalTorPort(),
        ),
      );
      addTearDown(cubit.close);

      await cubit.init();

      expect(cubit.state.connection, isA<TorUnavailable>());
    },
  );
}
