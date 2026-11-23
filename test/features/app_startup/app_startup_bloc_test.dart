import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/initialize_required_tor_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/restore_missing_default_secret_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/start_swap_engine_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:access/access.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/get_startup_pin_status_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _MockAccess extends Mock implements Access {}

class _MockCheckForExistingDefaultWalletsUsecase extends Mock
    implements CheckForExistingDefaultWalletsUsecase {}

class _MockInitializeRequiredTorUsecase extends Mock
    implements InitializeRequiredTorUsecase {}

class _MockRestoreMissingDefaultSecretUsecase extends Mock
    implements RestoreMissingDefaultSecretUsecase {}

class _MockStartSwapEngineUsecase extends Mock
    implements StartSwapEngineUsecase {}

void main() {
  setUpAll(() => registerFallbackValue(Language.english));
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'Bull Bitcoin',
    packageName: 'com.bullbitcoin.mobile',
    version: '6.13.0',
    buildNumber: '200',
    buildSignature: '',
  );

  late _MockAccess checkPinCodeExists;
  late _MockCheckForExistingDefaultWalletsUsecase checkDefaultWallets;
  late _MockInitializeRequiredTorUsecase initializeRequiredTor;
  late _MockRestoreMissingDefaultSecretUsecase restoreSecret;
  late _MockStartSwapEngineUsecase startSwapEngine;

  AppStartupBloc buildBloc() => AppStartupBloc(
    getStartupPinStatusUsecase: GetStartupPinStatusUsecase(checkPinCodeExists),
    checkForExistingDefaultWalletsUsecase: checkDefaultWallets,
    initializeRequiredTorUsecase: initializeRequiredTor,
    restoreMissingDefaultSecretUsecase: restoreSecret,
    startSwapEngineUsecase: startSwapEngine,
  );

  setUp(() {
    checkPinCodeExists = _MockAccess();
    checkDefaultWallets = _MockCheckForExistingDefaultWalletsUsecase();
    initializeRequiredTor = _MockInitializeRequiredTorUsecase();
    restoreSecret = _MockRestoreMissingDefaultSecretUsecase();
    startSwapEngine = _MockStartSwapEngineUsecase();

    when(() => checkPinCodeExists.checkPinCodeExists())
        .thenAnswer((_) async => const Ok(false));
    // No encrypted backup in these fixtures, so Tor is never warmed.
    when(() => initializeRequiredTor.execute()).thenAnswer((_) async => null);
    when(() => startSwapEngine.execute()).thenAnswer((_) async {});
  });

  test('starts up when default wallets exist', () async {
    when(() => checkDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(true));
    when(() => checkPinCodeExists.checkPinCodeExists())
        .thenAnswer((_) async => const Ok(false));
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
    verify(() => startSwapEngine.execute()).called(1);
  });

  test(
    'stays on splash when the keychain is locked before first unlock',
    () async {
      when(() => checkDefaultWallets.execute())
          .thenAnswer((_) async => const Ok(true));
      when(
        () => checkPinCodeExists.checkPinCodeExists(),
      ).thenAnswer((_) async => const Err(AccessUnlockKeychainLockedFailure()));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const AppStartupStarted());
      await bloc.stream.firstWhere(
        (state) => state is AppStartupLoadingInProgress,
      );
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<AppStartupLoadingInProgress>());
      verify(() => checkPinCodeExists.checkPinCodeExists()).called(1);
      verifyNever(() => startSwapEngine.execute());
    },
  );

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
      verify(() => checkPinCodeExists.checkPinCodeExists()).called(1);
      verifyNever(() => startSwapEngine.execute());
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
    when(() => checkDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(true));
    when(() => checkPinCodeExists.checkPinCodeExists()).thenAnswer(
      (_) async => const Err(AccessUnlockUnexpectedFailure('keychain read')),
    );
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const AppStartupStarted());
    final state = await bloc.stream.firstWhere(
      (s) => s is AppStartupFailureState,
    );

    // Not an AccessFailure: this feature never holds another feature's type.
    expect(
      (state as AppStartupFailureState).failure,
      isA<AppStartupPinCheckFailure>(),
    );
  });

  test(
    'requires the PIN before inspecting wallets, even without a default',
    () async {
      when(() => checkPinCodeExists.checkPinCodeExists())
          .thenAnswer((_) async => const Ok(true));
      when(() => checkDefaultWallets.execute())
          .thenAnswer((_) async => const Ok(false));
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const AppStartupStarted());
      final initial = await bloc.stream.firstWhere(
        (s) => s is AppStartupSuccess,
      ) as AppStartupSuccess;
      expect(initial.isPinCodeSet, isTrue);
      verifyNever(() => checkDefaultWallets.execute());
      verifyNever(() => startSwapEngine.execute());

      bloc.add(const AppStartupUnlocked());
      final unlocked = await bloc.stream.firstWhere(
        (s) => s is AppStartupSuccess,
      ) as AppStartupSuccess;
      expect(unlocked.isPinCodeSet, isFalse);
      expect(unlocked.hasDefaultWallets, isFalse);
      verify(() => checkDefaultWallets.execute()).called(1);
    },
  );

  test('starts a fresh install', () async {
    when(() => checkDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(false));
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

  group('restoring a missing default secret', () {
    const words = ['abandon', 'about'];

    Future<AppStartupBloc> missingSecret() async {
      when(() => checkDefaultWallets.execute()).thenAnswer(
        (_) async => const Err(
          AppStartupMissingDefaultSecretFailure(
            '73c5da0a',
            walletId: 'wallet-id',
          ),
        ),
      );
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const AppStartupStarted());
      await bloc.stream.firstWhere((s) => s is AppStartupFailureState);
      return bloc;
    }

    test(
      'checks the words against the missing wallet, then starts again',
      () async {
        final bloc = await missingSecret();
        when(
          () => restoreSecret.execute(
            expectedFingerprint: '73c5da0a',
            expectedWalletId: 'wallet-id',
            words: words,
            language: Language.french,
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(() => checkDefaultWallets.execute())
            .thenAnswer((_) async => const Ok(true));
        final result = await bloc.restoreDefaultSecret(
          words,
          language: Language.french,
        );
        await bloc.stream.firstWhere((s) => s is AppStartupSuccess);

        expect(result, isA<Ok<void, AppStartupFailure>>());
      },
    );

    test('reports a refused phrase and stays on the failure', () async {
      final bloc = await missingSecret();
      when(
        () => restoreSecret.execute(
          expectedFingerprint: any(named: 'expectedFingerprint'),
          expectedWalletId: any(named: 'expectedWalletId'),
          words: any(named: 'words'),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => const Err(AppStartupRestoreMismatchFailure()));

      final result = await bloc.restoreDefaultSecret(
        words,
        language: Language.english,
      );

      expect((result as Err).failure, isA<AppStartupRestoreMismatchFailure>());
      expect(bloc.state, isA<AppStartupFailureState>());
    });

    test('refuses when no secret is missing', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      final result = await bloc.restoreDefaultSecret(
        words,
        language: Language.english,
      );

      expect((result as Err).failure, isA<AppStartupRestoreFailure>());
      verifyNever(
        () => restoreSecret.execute(
          expectedFingerprint: any(named: 'expectedFingerprint'),
          expectedWalletId: any(named: 'expectedWalletId'),
          words: any(named: 'words'),
          language: any(named: 'language'),
        ),
      );
    });
  });
}
