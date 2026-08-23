import 'package:bb_mobile/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/can_access_bip85_entropy_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/derive_next_unreserved_bip85_mnemonic_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/fetch_unreserved_bip85_derivations_with_entropy_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _GetSettings extends Mock implements GetSettingsUsecase {}

class _DeriveMnemonic extends Mock
    implements DeriveNextBip85MnemonicFromDefaultWalletUsecase {}

class _FetchDerivations extends Mock
    implements FetchAllBip85DerivationsWithEntropyUsecase {}

void main() {
  const registry = Bip85RegistryFacade();

  setUpAll(() {
    registerFallbackValue(<int>{});
    registerFallbackValue(<String>{});
  });

  test('entropy access requires both privileged settings', () async {
    final settings = _GetSettings();
    final usecase = CanAccessBip85EntropyUsecase(settings);

    for (final flags in [
      (superuser: true, devMode: true, allowed: true),
      (superuser: true, devMode: false, allowed: false),
      (superuser: false, devMode: true, allowed: false),
      (superuser: false, devMode: false, allowed: false),
    ]) {
      reset(settings);
      when(settings.execute).thenAnswer(
        (_) async => SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          isSuperuser: flags.superuser,
          isDevModeEnabled: flags.devMode,
        ),
      );
      expect(await usecase.execute(), flags.allowed);
    }
  });

  test('entropy access fails closed when settings cannot load', () async {
    final settings = _GetSettings();
    when(settings.execute).thenThrow(StateError('unavailable'));

    expect(await CanAccessBip85EntropyUsecase(settings).execute(), isFalse);
  });

  test('manual derivation skips every reserved wallet index', () async {
    final derive = _DeriveMnemonic();
    when(
      () => derive.execute(excludedIndices: any(named: 'excludedIndices')),
    ).thenAnswer((_) async => const Err(Bip85NoDefaultWalletFailure()));

    final result = await DeriveNextUnreservedBip85MnemonicUsecase(
      derive,
      registry,
    ).execute();
    expect(result, isA<Err>());

    final excluded =
        verify(
              () => derive.execute(
                excludedIndices: captureAny(named: 'excludedIndices'),
              ),
            ).captured.single
            as Set<int>;
    expect(excluded, registry.reservedWalletSeedIndices);
  });

  test('entropy listing hides every reserved wallet path', () async {
    final fetch = _FetchDerivations();
    when(
      () => fetch.execute(excludedPaths: any(named: 'excludedPaths')),
    ).thenAnswer((_) async => const Ok([]));

    final result = await FetchUnreservedBip85DerivationsWithEntropyUsecase(
      fetch,
      registry,
    ).execute();
    expect(result, isA<Ok>());

    final excluded =
        verify(
              () => fetch.execute(
                excludedPaths: captureAny(named: 'excludedPaths'),
              ),
            ).captured.single
            as Set<String>;
    expect(excluded, registry.reservedWalletSeedPaths);
  });
}
