import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/initialize_required_tor_usecase.dart';
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

class _MockCheckBackupUsecase extends Mock implements CheckBackupUsecase {}

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
  late _MockInitializeRequiredTorUsecase initializeRequiredTor;

  AppStartupBloc buildBloc() => AppStartupBloc(
    resetAppDataUsecase: resetAppData,
    checkPinCodeExistsUsecase: checkPinCodeExists,
    checkForExistingDefaultWalletsUsecase: checkDefaultWallets,
    checkBackupUsecase: _MockCheckBackupUsecase(),
    initializeRequiredTorUsecase: initializeRequiredTor,
  );

  setUp(() {
    resetAppData = _MockResetAppDataUsecase();
    checkPinCodeExists = _MockCheckPinCodeExistsUsecase();
    checkDefaultWallets = _MockCheckForExistingDefaultWalletsUsecase();
    initializeRequiredTor = _MockInitializeRequiredTorUsecase();

    when(() => resetAppData.execute()).thenAnswer((_) async {});
    // No encrypted backup in these fixtures, so Tor is never warmed.
    when(() => initializeRequiredTor.execute()).thenAnswer((_) async => null);
  });

  test('starts up when default wallets exist', () async {
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
  });

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

  test('a fresh install with no default wallets starts up', () async {
    when(() => checkDefaultWallets.execute()).thenAnswer((_) async => false);
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
