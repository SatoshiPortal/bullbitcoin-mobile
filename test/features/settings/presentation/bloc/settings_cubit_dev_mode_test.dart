import 'package:bb_mobile/core/ark/usecases/revoke_ark_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/domain/usecases/revoke_sp_wallet_for_settings_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_error_reporting_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_exchange_testnet_basic_auth_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_dev_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockSetEnvironmentUsecase extends Mock
    implements SetEnvironmentUsecase {}

class _MockSetBitcoinUnitUsecase extends Mock
    implements SetBitcoinUnitUsecase {}

class _MockSetLanguageUsecase extends Mock implements SetLanguageUsecase {}

class _MockSetCurrencyUsecase extends Mock implements SetCurrencyUsecase {}

class _MockSetHideAmountsUsecase extends Mock
    implements SetHideAmountsUsecase {}

class _MockSetIsSuperuserUsecase extends Mock
    implements SetIsSuperuserUsecase {}

class _MockSetIsDevModeUsecase extends Mock implements SetIsDevModeUsecase {}

class _MockSetThemeModeUsecase extends Mock implements SetThemeModeUsecase {}

class _MockGetOldSeedsUsecase extends Mock implements GetOldSeedsUsecase {}

class _MockRevokeArkUsecase extends Mock implements RevokeArkUsecase {}

class _MockRevokeSpWalletUsecase extends Mock
    implements RevokeSpWalletForSettingsUsecase {}

class _MockSetErrorReportingUsecase extends Mock
    implements SetErrorReportingUsecase {}

class _MockSetExchangeTestnetBasicAuthUsecase extends Mock
    implements SetExchangeTestnetBasicAuthUsecase {}

class _MockWalletBloc extends Mock implements WalletBloc {}

class _FakeRefreshSpWallet extends Fake implements RefreshSpWallet {}

class _FakeRefreshArkBalance extends Fake implements RefreshArkWalletBalance {}

SettingsEntity _settings({bool isDevModeEnabled = true}) => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
  isSuperuser: true,
  isDevModeEnabled: isDevModeEnabled,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRefreshSpWallet());
    registerFallbackValue(_FakeRefreshArkBalance());
  });

  late _MockSetIsDevModeUsecase setIsDevModeUsecase;
  late _MockRevokeSpWalletUsecase revokeSpWalletUsecase;
  late _MockRevokeArkUsecase revokeArkUsecase;
  late _MockWalletBloc walletBloc;
  late SettingsCubit cubit;

  setUp(() {
    setIsDevModeUsecase = _MockSetIsDevModeUsecase();
    revokeSpWalletUsecase = _MockRevokeSpWalletUsecase();
    revokeArkUsecase = _MockRevokeArkUsecase();
    walletBloc = _MockWalletBloc();

    when(() => setIsDevModeUsecase.execute(any())).thenAnswer((_) async {});
    when(
      () => revokeSpWalletUsecase.execute(),
    ).thenAnswer((_) async => const Ok(null));
    when(() => revokeArkUsecase.execute()).thenAnswer((_) async {});
    when(() => walletBloc.add(any())).thenReturn(null);

    cubit = SettingsCubit(
      getSettingsUsecase: _MockGetSettingsUsecase(),
      setEnvironmentUsecase: _MockSetEnvironmentUsecase(),
      setBitcoinUnitUsecase: _MockSetBitcoinUnitUsecase(),
      setLanguageUsecase: _MockSetLanguageUsecase(),
      setCurrencyUsecase: _MockSetCurrencyUsecase(),
      setHideAmountsUsecase: _MockSetHideAmountsUsecase(),
      setIsSuperuserUsecase: _MockSetIsSuperuserUsecase(),
      setIsDevModeUsecase: setIsDevModeUsecase,
      setThemeModeUsecase: _MockSetThemeModeUsecase(),
      getOldSeedsUsecase: _MockGetOldSeedsUsecase(),
      revokeArkUsecase: revokeArkUsecase,
      revokeSpWalletUsecase: revokeSpWalletUsecase,
      setErrorReportingUsecase: _MockSetErrorReportingUsecase(),
      setExchangeTestnetBasicAuthUsecase:
          _MockSetExchangeTestnetBasicAuthUsecase(),
    );
  });

  tearDown(() => cubit.close());

  group('toggleDevMode', () {
    test(
      'dev-mode true -> false triggers RevokeSpWalletUsecase and does NOT '
      'drive the wallet for SP (the wallet observes SpSetupChanged itself)',
      () async {
        // Seed cubit state with dev mode currently enabled.
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings(isDevModeEnabled: true),
          ),
        );

        await cubit.toggleDevMode(false, walletBloc: walletBloc);

        verify(() => revokeSpWalletUsecase.execute()).called(1);
        // Settings no longer pokes the WalletBloc for SP; revoke emits
        // SpSetupChanged and the wallet refreshes via its own watcher.
        verifyNever(
          () => walletBloc.add(any(that: isA<RefreshSpWallet>())),
        );
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

        await cubit.toggleDevMode(true, walletBloc: walletBloc);

        verifyNever(() => revokeSpWalletUsecase.execute());
        verify(() => setIsDevModeUsecase.execute(true)).called(1);
        expect(cubit.state.storedSettings?.isDevModeEnabled, true);
      },
    );

    test(
      'dev-mode toggle-off without walletBloc still revokes SP wallet',
      () async {
        cubit.emit(
          cubit.state.copyWith(
            storedSettings: _settings(isDevModeEnabled: true),
          ),
        );

        await cubit.toggleDevMode(false);

        verify(() => revokeSpWalletUsecase.execute()).called(1);
        // No walletBloc was passed; refresh add must not crash and must not
        // be invoked.
        verifyNever(() => walletBloc.add(any()));
      },
    );

    test('dev-mode toggle-off still flips devmode AND surfaces revoke error in '
        'state when RevokeSpWalletUsecase returns Err', () async {
      // The sentinel written by RevokeSpWalletUsecase BEFORE its delete
      // attempt makes it safe to flip dev mode off even when delete fails:
      // GetSpWalletUsecase keys off that sentinel and will refuse to load.
      // So the cubit must NOT refuse the toggle, but it MUST surface the
      // error so the UI can warn the user.
      when(
        () => revokeSpWalletUsecase.execute(),
      ).thenAnswer((_) async => const Err(SpUnexpected('file locked')));
      cubit.emit(
        cubit.state.copyWith(storedSettings: _settings(isDevModeEnabled: true)),
      );

      await cubit.toggleDevMode(false, walletBloc: walletBloc);

      verify(() => revokeSpWalletUsecase.execute()).called(1);
      // Dev mode still flips off (sentinel makes this safe).
      verify(() => setIsDevModeUsecase.execute(false)).called(1);
      expect(cubit.state.storedSettings?.isDevModeEnabled, false);
      // The failure is flagged in state so the UI can show a generic message;
      // the raw cause is logged at the boundary only, never stored.
      expect(cubit.state.revokeSpFailed, isTrue);
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

        await cubit.toggleDevMode(false, walletBloc: walletBloc);

        verify(() => revokeSpWalletUsecase.execute()).called(1);
        expect(cubit.state.storedSettings?.isDevModeEnabled, false);
        expect(cubit.state.revokeSpFailed, isFalse);
      },
    );
  });
}
