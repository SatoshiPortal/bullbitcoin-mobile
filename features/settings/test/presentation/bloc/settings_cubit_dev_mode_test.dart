import 'package:settings/testing.dart';

import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettingsUsecase extends Mock implements Preferences {}

class _MockSetEnvironmentUsecase extends Mock
    implements SetEnvironmentUsecase {}

class _MockSetBitcoinUnitUsecase extends Mock
    implements SetBitcoinUnitUsecase {}

class _MockSetLanguageUsecase extends Mock implements SetLanguageUsecase {}

class _MockSetCurrencyUsecase extends Mock implements SetCurrencyUsecase {}

class _MockSyncExchangeCurrencyUsecase extends Mock
    implements SyncExchangeCurrencyUsecase {}

class _MockSetHideAmountsUsecase extends Mock
    implements SetHideAmountsUsecase {}

class _MockSetIsSuperuserUsecase extends Mock
    implements SetIsSuperuserUsecase {}

class _MockSetIsDevModeUsecase extends Mock implements SetIsDevModeUsecase {}

class _MockSetThemeModeUsecase extends Mock implements SetThemeModeUsecase {}

class _MockSetScreenCaptureProtectionUsecase extends Mock
    implements SetScreenCaptureProtectionUsecase {}

class _MockSetPayjoinEnabledUsecase extends Mock
    implements SetPayjoinEnabledUsecase {}

class _MockWatchPayjoinPolicyUsecase extends Mock
    implements WatchPayjoinPolicyUsecase {}

class _MockSetPayjoinMinAmountUsecase extends Mock
    implements SetPayjoinMinAmountUsecase {}

class _MockSetPayjoinExpireAfterSecUsecase extends Mock
    implements SetPayjoinExpireAfterSecUsecase {}

class _MockRevokeSpWalletUsecase extends Mock
    implements RevokeSpWalletForSettingsUsecase {}

class _MockCheckSpWalletSetupUsecase extends Mock
    implements CheckSpWalletSetupForSettingsUsecase {}

class _MockSetErrorReportingUsecase extends Mock
    implements SetErrorReportingUsecase {}

class _MockSetExchangeTestnetBasicAuthUsecase extends Mock
    implements SetExchangeTestnetBasicAuthUsecase {}

SettingsEntity _settings({bool isDevModeEnabled = true}) => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
  isSuperuser: true,
  isDevModeEnabled: isDevModeEnabled,
);

class _SetAmountMode extends Mock implements SetAmountInputModeUsecase {}

void main() {
  late _MockSetIsDevModeUsecase setIsDevModeUsecase;
  late _MockRevokeSpWalletUsecase revokeSpWalletUsecase;
  late _MockCheckSpWalletSetupUsecase checkSpWalletSetupUsecase;
  late SettingsCubit cubit;
  late _SetAmountMode setAmountMode;
  late _MockSetCurrencyUsecase setCurrency;
  late _MockSyncExchangeCurrencyUsecase syncCurrency;

  setUp(() {
    setAmountMode = _SetAmountMode();
    setCurrency = _MockSetCurrencyUsecase();
    syncCurrency = _MockSyncExchangeCurrencyUsecase();
    setIsDevModeUsecase = _MockSetIsDevModeUsecase();
    revokeSpWalletUsecase = _MockRevokeSpWalletUsecase();
    checkSpWalletSetupUsecase = _MockCheckSpWalletSetupUsecase();

    when(() => setIsDevModeUsecase.execute(any()))
        .thenAnswer((_) async => const Ok(null));
    when(() => revokeSpWalletUsecase.execute())
        .thenAnswer((_) async => const Ok(null));
    when(() => checkSpWalletSetupUsecase.execute())
        .thenAnswer((_) async => Ok(false));

    final watchPayjoinPolicyUsecase = _MockWatchPayjoinPolicyUsecase();
    when(() => watchPayjoinPolicyUsecase.execute())
        .thenAnswer((_) => const Stream<PayjoinPolicy>.empty());

    cubit = SettingsCubit(
      loadPreferencesUsecase: LoadSettingsUsecase(_MockGetSettingsUsecase()),
      setEnvironmentUsecase: _MockSetEnvironmentUsecase(),
      setBitcoinUnitUsecase: _MockSetBitcoinUnitUsecase(),
      setAmountInputModeUsecase: setAmountMode,
      setLanguageUsecase: _MockSetLanguageUsecase(),
      setCurrencyUsecase: setCurrency,
      syncExchangeCurrencyUsecase: syncCurrency,
      setHideAmountsUsecase: _MockSetHideAmountsUsecase(),
      setIsSuperuserUsecase: _MockSetIsSuperuserUsecase(),
      setIsDevModeUsecase: setIsDevModeUsecase,
      setThemeModeUsecase: _MockSetThemeModeUsecase(),
      revokeSpWalletUsecase: revokeSpWalletUsecase,
      checkSpWalletSetupUsecase: checkSpWalletSetupUsecase,
      setErrorReportingUsecase: _MockSetErrorReportingUsecase(),
      setScreenCaptureProtectionUsecase:
          _MockSetScreenCaptureProtectionUsecase(),
      setExchangeTestnetBasicAuthUsecase:
          _MockSetExchangeTestnetBasicAuthUsecase(),
      setPayjoinEnabledUsecase: _MockSetPayjoinEnabledUsecase(),
      watchPayjoinPolicyUsecase: watchPayjoinPolicyUsecase,
      setPayjoinMinAmountUsecase: _MockSetPayjoinMinAmountUsecase(),
      setPayjoinExpireAfterSecUsecase: _MockSetPayjoinExpireAfterSecUsecase(),
    );
  });

  tearDown(() => cubit.close());

  test('currency completion preserves the persisted input mode and Undo preserves currency', () async {
    cubit.emit(cubit.state.copyWith(storedSettings: _settings()));
    final currency = Completer<Result<void, SettingsFailure>>();
    when(() => setCurrency.execute('CAD')).thenAnswer((_) => currency.future);
    when(() => syncCurrency.execute('CAD'))
        .thenAnswer((_) async => const Ok(null));
    when(() => setAmountMode.execute(fiat: true))
        .thenAnswer((_) async => const Ok(null));
    when(() => setAmountMode.execute(fiat: false))
        .thenAnswer((_) async => const Ok(null));
    final changingCurrency = cubit.changeCurrency('CAD');
    await cubit.setStartAmountsInFiat(true);
    currency.complete(const Ok(null));
    await changingCurrency;
    expect(cubit.state.storedSettings?.startAmountsInFiat, isTrue);
    expect(cubit.state.currencyCode, 'CAD');
    await cubit.setStartAmountsInFiat(false);
    expect(cubit.state.storedSettings?.startAmountsInFiat, isFalse);
    expect(cubit.state.currencyCode, 'CAD');
  });

  test('input mode completion preserves a newer currency', () async {
    cubit.emit(cubit.state.copyWith(storedSettings: _settings()));
    final mode = Completer<Result<void, SettingsFailure>>();
    when(() => setAmountMode.execute(fiat: true))
        .thenAnswer((_) => mode.future);
    when(() => setCurrency.execute('CAD'))
        .thenAnswer((_) async => const Ok(null));
    when(() => syncCurrency.execute('CAD'))
        .thenAnswer((_) async => const Ok(null));
    final changingMode = cubit.setStartAmountsInFiat(true);
    await cubit.changeCurrency('CAD');
    mode.complete(const Ok(null));
    await changingMode;
    expect(cubit.state.currencyCode, 'CAD');
    expect(cubit.state.storedSettings?.startAmountsInFiat, isTrue);
  });

  test('a failed input mode write keeps the stored preference', () async {
    cubit.emit(cubit.state.copyWith(storedSettings: _settings()));
    when(() => setAmountMode.execute(fiat: true))
        .thenAnswer((_) async => const Err(SettingsStorageFailure()));
    await cubit.setStartAmountsInFiat(true);
    expect(cubit.state.storedSettings?.startAmountsInFiat, isFalse);
    expect(cubit.state.failure, isA<SettingsStorageFailure>());
  });

  group('toggleDevMode', () {
    test(
      'disabling developer mode publishes the committed mainnet selection',
      () async {
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings().copyWith(
              environment: Environment.testnet,
            ),
          ),
        );
        await cubit.toggleDevMode(false);
        expect(cubit.state.environment, Environment.mainnet);
        expect(cubit.state.storedSettings?.isDevModeEnabled, isFalse);
        verify(() => setIsDevModeUsecase.execute(false)).called(1);
      },
    );

    test(
      'dev-mode true -> false revokes the SP wallet; the wallet feature picks '
      'the change up from SilentSetupChanged, settings never drives it',
      () async {
        // Seed cubit state with dev mode currently enabled.
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings(isDevModeEnabled: true),
          ),
        );

        await cubit.toggleDevMode(false);

        verify(() => revokeSpWalletUsecase.execute()).called(1);
        verify(() => setIsDevModeUsecase.execute(false)).called(1);
        expect(cubit.state.storedSettings?.isDevModeEnabled, false);
      },
    );

    test(
      'dev-mode false -> true does NOT call RevokeSpWalletUsecase',
      () async {
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings(isDevModeEnabled: false),
          ),
        );

        await cubit.toggleDevMode(true);

        verifyNever(() => revokeSpWalletUsecase.execute());
        verify(() => setIsDevModeUsecase.execute(true)).called(1);
        expect(cubit.state.storedSettings?.isDevModeEnabled, true);
      },
    );

    test(
      'dev-mode toggle-off keeps dev mode enabled when revoke fails',
      () async {
        when(() => revokeSpWalletUsecase.execute()).thenAnswer(
          (_) async => const Err(SettingsStorageFailure('file locked')),
        );
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings(isDevModeEnabled: true),
          ),
        );

        await cubit.toggleDevMode(false);

        verify(() => revokeSpWalletUsecase.execute()).called(1);
        verifyNever(() => setIsDevModeUsecase.execute(false));
        expect(cubit.state.storedSettings?.isDevModeEnabled, true);
        expect(cubit.state.revokeSpFailed, isTrue);
      },
    );

    test('a failed dev-mode write after a successful revoke still re-reads the '
        'SP setup flag', () async {
      when(() => setIsDevModeUsecase.execute(any())).thenAnswer(
        (_) async => const Err(SettingsStorageFailure('write failed')),
      );
      cubit.emit(
        cubit.state.copyWith(
          storedSettings: _settings(isDevModeEnabled: true),
          isSpWalletSetup: true,
        ),
      );

      await cubit.toggleDevMode(false);

      // The revoke already dropped the wallet, so the flag must not keep
      // claiming it is set up just because the dev-mode write failed.
      verify(() => revokeSpWalletUsecase.execute()).called(1);
      verify(() => checkSpWalletSetupUsecase.execute()).called(1);
      expect(cubit.state.isSpWalletSetup, isFalse);
      expect(cubit.state.failure, isA<SettingsStorageFailure>());
      expect(cubit.state.storedSettings?.isDevModeEnabled, true);
    });

    test(
      'successful toggle-off clears any previously-set revokeSpFailed',
      () async {
        // Seed state with a stale failure flag from a previous attempt.
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings(isDevModeEnabled: true),
            revokeSpFailed: true,
          ),
        );

        await cubit.toggleDevMode(false);

        verify(() => revokeSpWalletUsecase.execute()).called(1);
        expect(cubit.state.storedSettings?.isDevModeEnabled, false);
        expect(cubit.state.revokeSpFailed, isFalse);
      },
    );
  });
}
