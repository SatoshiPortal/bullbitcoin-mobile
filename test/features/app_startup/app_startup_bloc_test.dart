import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:access/setup.dart';
import 'package:access/testing.dart' show PinCodeUnlockInputScreen;
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:secrets/secrets.dart' show DatabaseOpenFailure;
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

import '../../support/inventory_fixture.dart';

class _MockAccess extends Mock implements Access {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

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

  AppStartupBloc buildBloc([Access? access]) => AppStartupBloc(
    getStartupPinStatusUsecase: GetStartupPinStatusUsecase(
      access ?? checkPinCodeExists,
    ),
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

  testWidgets('a PIN set before cold start gates the first router frame', (
    tester,
  ) async {
    final services = GetIt.asNewInstance();
    addTearDown(services.reset);
    final bloc = buildBloc(const Access());
    addTearDown(bloc.close);
    when(() => checkDefaultWallets.execute())
        .thenAnswer((_) async => const Ok(true));
    late final String pin;
    await tester.runAsync(() async {
      FakeSecureStoragePlatform().install();
      final directory = await Directory.systemTemp.createTemp('cold-pin-');
      addTearDown(() => directory.delete(recursive: true));
      final installation = await InventoryFixture.open(directory);
      addTearDown(installation.close);
      pin = Random.secure().nextInt(10000).toString().padLeft(4, '0');
      expect(
        await installation.inventory.setCredential(
          pin,
          backupVerification: installation.backup,
        ),
        isA<Ok>(),
      );
      await installation.inventory.close();
      final opened = await SecretsInventory.open(
        file: File('${directory.path}/test-secrets.sqlite'),
        admission: installation.admission,
      );
      final inventory =
          (opened as Ok<SecretsInventory, DatabaseOpenFailure>).value;
      final feature = AccessFeature.mount(
        services: services,
        inventory: inventory,
        backupVerification: installation.backup,
        hasVerifiedBackup: () async => true,
        onUnlocked: (_) {},
        onBackUp: (_) async {},
      );
      services.registerSingleton(feature);
    });
    bloc.add(const AppStartupStarted());
    await pumpUntilInventoryReady(
      tester,
      () => bloc.state is AppStartupSuccess,
    );
    expect(
      bloc.state,
      isA<AppStartupSuccess>().having(
        (state) => state.isPinCodeSet,
        'PIN required',
        true,
      ),
    );

    var homeBuilds = 0;
    final settings = _MockSettingsCubit();
    when(() => settings.state).thenReturn(const SettingsState());
    when(() => settings.stream)
        .thenAnswer((_) => const Stream<SettingsState>.empty());
    var unlocks = 0;
    final walletRuntime = Completer<void>();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) {
            homeBuilds++;
            return const SizedBox.shrink();
          },
        ),
        ...services<AccessFeature>().routes.root,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: bloc),
          BlocProvider.value(value: settings),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: const [
            ...appLocalizationsDelegates,
            bullUiLocalizationsDelegate,
          ],
          builder: (_, child) => AppStartupWidget(
            app: child ?? const SizedBox.shrink(),
            loadingSplash: (_) => const SizedBox.shrink(),
            onMissingWallets: () => fail('Unexpected onboarding navigation'),
            onUnlocked: () {
              unlocks++;
              return walletRuntime.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PinCodeUnlockInputScreen), findsOneWidget);
    expect(homeBuilds, 0);
    verifyNever(() => checkDefaultWallets.execute());

    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    final loc = AccessLocalizations.of(
      tester.element(find.byType(PinCodeUnlockInputScreen)),
    );
    await tester.tap(find.text(loc.appUnlockButton));
    await pumpUntilInventoryReady(tester, () => unlocks == 1);
    expect(homeBuilds, 0);
    verifyNever(() => checkDefaultWallets.execute());

    walletRuntime.complete();
    await tester.pumpAndSettle();
    expect(homeBuilds, greaterThan(0));
    expect(find.byType(PinCodeUnlockInputScreen), findsNothing);
    verify(() => checkDefaultWallets.execute()).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
