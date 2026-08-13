import 'dart:async';

import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_legacy_install_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
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

class _MockCheckBackupUsecase extends Mock implements CheckBackupUsecase {}

class _MockIsTorRequiredUsecase extends Mock implements IsTorRequiredUsecase {}

class _MockInitTorUsecase extends Mock implements InitTorUsecase {}

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
  late _MockIsTorRequiredUsecase isTorRequired;

  AppStartupBloc buildBloc() => AppStartupBloc(
    resetAppDataUsecase: resetAppData,
    checkPinCodeExistsUsecase: checkPinCodeExists,
    checkForExistingDefaultWalletsUsecase: checkDefaultWallets,
    checkLegacyInstallUsecase: checkLegacyInstall,
    checkBackupUsecase: _MockCheckBackupUsecase(),
    isTorRequiredUsecase: isTorRequired,
    initTorUsecase: _MockInitTorUsecase(),
  );

  setUp(() {
    resetAppData = _MockResetAppDataUsecase();
    checkPinCodeExists = _MockCheckPinCodeExistsUsecase();
    checkDefaultWallets = _MockCheckForExistingDefaultWalletsUsecase();
    checkLegacyInstall = _MockCheckLegacyInstallUsecase();
    isTorRequired = _MockIsTorRequiredUsecase();

    when(() => resetAppData.execute()).thenAnswer((_) async {});
    when(() => isTorRequired.execute()).thenAnswer((_) async => false);
  });

  test(
    'gates when the legacy marker is present and no default wallets exist',
    () async {
      when(() => checkDefaultWallets.execute()).thenAnswer((_) async => false);
      when(() => checkLegacyInstall.execute()).thenAnswer((_) async => true);
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
      when(() => checkDefaultWallets.execute()).thenAnswer((_) async => true);
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
      when(() => checkDefaultWallets.execute()).thenAnswer((_) async => true);
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

  test('does not gate a fresh install without a legacy marker', () async {
    when(() => checkDefaultWallets.execute()).thenAnswer((_) async => false);
    when(() => checkLegacyInstall.execute()).thenAnswer((_) async => false);
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
