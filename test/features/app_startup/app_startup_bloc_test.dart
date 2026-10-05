import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_legacy_install_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/initialize_required_tor_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockResetAppDataUsecase extends Mock implements ResetAppDataUsecase {}

class _MockCheckPinCodeExistsUsecase extends Mock
    implements CheckPinCodeExistsUsecase {}

class _MockCheckForExistingDefaultWalletsUsecase extends Mock
    implements CheckForExistingDefaultWalletsUsecase {}

class _MockCheckLegacyInstallUsecase extends Mock
    implements CheckLegacyInstallUsecase {}

class _MockInitializeRequiredTorUsecase extends Mock
    implements InitializeRequiredTorUsecase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'Bull Bitcoin',
    packageName: 'com.bullbitcoin.mobile',
    version: '6.13.0',
    buildNumber: '200',
    buildSignature: '',
  );

  late _MockResetAppDataUsecase resetAppData;
  late _MockCheckPinCodeExistsUsecase checkPinCodeExists;
  late _MockCheckForExistingDefaultWalletsUsecase checkDefaultWallets;
  late _MockCheckLegacyInstallUsecase checkLegacyInstall;
  late _MockInitializeRequiredTorUsecase initializeRequiredTor;

  AppStartupBloc buildBloc() => AppStartupBloc(
    resetAppDataUsecase: resetAppData,
    checkPinCodeExistsUsecase: checkPinCodeExists,
    checkForExistingDefaultWalletsUsecase: checkDefaultWallets,
    checkLegacyInstallUsecase: checkLegacyInstall,
    initializeRequiredTorUsecase: initializeRequiredTor,
  );

  setUp(() {
    resetAppData = _MockResetAppDataUsecase();
    checkPinCodeExists = _MockCheckPinCodeExistsUsecase();
    checkDefaultWallets = _MockCheckForExistingDefaultWalletsUsecase();
    checkLegacyInstall = _MockCheckLegacyInstallUsecase();
    initializeRequiredTor = _MockInitializeRequiredTorUsecase();

    when(() => resetAppData.execute()).thenAnswer((_) async => const Ok(null));
    // No encrypted backup in these fixtures, so Tor is never warmed.
    when(() => initializeRequiredTor.execute()).thenAnswer((_) async => null);
  });

  test(
    'gates when the legacy marker is present and no default wallets exist',
    () async {
      when(
        () => checkDefaultWallets.execute(),
      ).thenAnswer((_) async => const Ok(false));
      when(
        () => checkLegacyInstall.execute(),
      ).thenAnswer((_) async => const Ok(true));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      unawaited(
        expectLater(
          bloc.stream,
          emitsInOrder([
            isA<AppStartupLoadingInProgress>(),
            isA<AppStartupLegacyBackupRequired>(),
          ]),
        ),
      );

      bloc.add(const AppStartupStarted());
    },
  );

  test(
    'skips the gate when default wallets exist despite a legacy marker',
    () async {
      when(
        () => checkDefaultWallets.execute(),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => checkPinCodeExists.execute(),
      ).thenAnswer((_) async => const Ok(true));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      unawaited(
        expectLater(
          bloc.stream,
          emitsInOrder([
            isA<AppStartupLoadingInProgress>(),
            isA<AppStartupSuccess>(),
          ]),
        ),
      );

      bloc.add(const AppStartupStarted());
      await bloc.stream.firstWhere((s) => s is AppStartupSuccess);

      // The legacy check must not even run: current seeds are not
      // legacy-format and would be missing from the backup screen.
      verifyNever(() => checkLegacyInstall.execute());
    },
  );

  test(
    'stays on splash when the keychain is locked before first unlock',
    () async {
      when(
        () => checkDefaultWallets.execute(),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => checkPinCodeExists.execute(),
      ).thenAnswer((_) async => const Err(AppUnlockKeychainLockedFailure()));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const AppStartupStarted());
      await bloc.stream.firstWhere(
        (state) => state is AppStartupLoadingInProgress,
      );
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<AppStartupLoadingInProgress>());
      verify(() => checkPinCodeExists.execute()).called(1);
    },
  );

  // The wallet check reads seeds, so it hits the locked keychain before the
  // PIN check does. It used to throw KeychainLockedException and be caught by
  // a bare `on KeychainLockedException` in the bloc; it now returns a typed
  // failure, and the splash-and-retry behaviour must survive that change.
  // Emitting failure here would strand the user on the error screen until a
  // cold launch, because the pre-warmed engine is reused.
  test(
    'stays on splash when the WALLET check hits a locked keychain',
    () async {
      when(
        () => checkDefaultWallets.execute(),
      ).thenAnswer((_) async => const Err(AppStartupKeychainLockedFailure()));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const AppStartupStarted());
      await bloc.stream.firstWhere((s) => s is AppStartupLoadingInProgress);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<AppStartupLoadingInProgress>());
      expect(bloc.state, isNot(isA<AppStartupFailureState>()));
      // Startup stopped there: nothing downstream may run on a locked keychain.
      verifyNever(() => checkLegacyInstall.execute());
      verifyNever(() => checkPinCodeExists.execute());
    },
  );

  test(
    'surfaces a typed failure when the wallet check fails for real',
    () async {
      when(() => checkDefaultWallets.execute()).thenAnswer(
        (_) async => const Err(AppStartupWalletCheckFailure('drift: locked')),
      );
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const AppStartupStarted());
      final state = await bloc.stream.firstWhere(
        (s) => s is AppStartupFailureState,
      );

      expect(
        (state as AppStartupFailureState).failure,
        isA<AppStartupWalletCheckFailure>(),
      );
    },
  );

  test('lifts a PIN failure into this feature\'s family rather than '
      'rethrowing it', () async {
    when(
      () => checkDefaultWallets.execute(),
    ).thenAnswer((_) async => const Ok(true));
    when(() => checkPinCodeExists.execute()).thenAnswer(
      (_) async => const Err(AppUnlockUnexpectedFailure('keychain read')),
    );
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const AppStartupStarted());
    final state = await bloc.stream.firstWhere(
      (s) => s is AppStartupFailureState,
    );

    // Not an AppUnlockFailure: this feature never holds another feature's type.
    expect(
      (state as AppStartupFailureState).failure,
      isA<AppStartupPinCheckFailure>(),
    );
  });

  // The reset runs on the fresh-install path. A stale PIN left behind is not
  // read this session, but IS read on the next launch once wallets exist —
  // locking the user out with a PIN they never set. So it must not be
  // silently swallowed, and a locked keychain must still take the retry path
  // rather than the terminal error screen.
  group('a failed data reset', () {
    setUp(() {
      when(
        () => checkDefaultWallets.execute(),
      ).thenAnswer((_) async => const Ok(false));
      when(
        () => checkLegacyInstall.execute(),
      ).thenAnswer((_) async => const Ok(false));
    });

    test('surfaces rather than being ignored', () async {
      when(
        () => resetAppData.execute(),
      ).thenAnswer((_) async => const Err(AppStartupResetFailure()));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const AppStartupStarted());
      final state = await bloc.stream.firstWhere(
        (s) => s is AppStartupFailureState,
      );

      expect(
        (state as AppStartupFailureState).failure,
        isA<AppStartupResetFailure>(),
      );
    });

    test('holds the splash when the keychain is the reason', () async {
      when(
        () => resetAppData.execute(),
      ).thenAnswer((_) async => const Err(AppStartupKeychainLockedFailure()));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const AppStartupStarted());
      await bloc.stream.firstWhere((s) => s is AppStartupLoadingInProgress);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<AppStartupLoadingInProgress>());
      expect(bloc.state, isNot(isA<AppStartupFailureState>()));
    });
  });

  test(
    'holds the splash when the LEGACY check hits a locked keychain',
    () async {
      when(
        () => checkDefaultWallets.execute(),
      ).thenAnswer((_) async => const Ok(false));
      when(
        () => checkLegacyInstall.execute(),
      ).thenAnswer((_) async => const Err(AppStartupKeychainLockedFailure()));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const AppStartupStarted());
      await bloc.stream.firstWhere((s) => s is AppStartupLoadingInProgress);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<AppStartupLoadingInProgress>());
      verifyNever(() => resetAppData.execute());
    },
  );

  test('does not gate a fresh install without a legacy marker', () async {
    when(
      () => checkDefaultWallets.execute(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => checkLegacyInstall.execute(),
    ).thenAnswer((_) async => const Ok(false));
    final bloc = buildBloc();
    addTearDown(bloc.close);

    unawaited(
      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AppStartupLoadingInProgress>(),
          isA<AppStartupSuccess>(),
        ]),
      ),
    );

    bloc.add(const AppStartupStarted());
  });
}
