import 'package:bb_mobile/features/bullvault/presentation/bullvault_inheritance_mnemonic_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/generate_bullvault_inheritance_mnemonic_usecase.dart';
import 'package:secrets/secrets.dart';
import '../bullvault_secrets_fixture.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullIcons, BullSecretTextInput;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_key_source.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/derive_bullvault_mnemonic_key_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_onboarding_snapshot.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_initial_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_registration_name_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_onboarding_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';

class _MockDeriveInheritance extends Mock
    implements DeriveBullVaultMnemonicKeyUsecase {}

class _MockGenerateInheritance extends Mock
    implements GenerateBullVaultInheritanceMnemonicUsecase {}

class _MockCreateBullVaultOnboardingUsecase extends Mock
    implements CreateBullVaultOnboardingUsecase {}

class _MockPrepareBullVaultTimeReferenceUsecase extends Mock
    implements PrepareBullVaultTimeReferenceUsecase {}

class _MockLoadBullVaultOnboardingUsecase extends Mock
    implements LoadBullVaultOnboardingUsecase {}

class _MockCheckBullVaultMobileBackupsUsecase extends Mock
    implements CheckBullVaultMobileBackupsUsecase {}

class _MockUpdateBullVaultSetupUsecase extends Mock
    implements UpdateBullVaultSetupUsecase {}

class _MockActivateInitialBullVaultUsecase extends Mock
    implements ActivateInitialBullVaultUsecase {}

class _MockEncodeBullVaultRecoveryPackageUsecase extends Mock
    implements EncodeBullVaultRecoveryPackageUsecase {}

class _MockUpdateBullVaultRegistrationNameUsecase extends Mock
    implements UpdateBullVaultRegistrationNameUsecase {}

void main() {
  testWidgets('requires matching passphrases before completing mobile setup', (
    tester,
  ) async {
    const privacyChannel = MethodChannel(
      'com.flutterplaza.no_screenshot_methods',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      privacyChannel,
      (_) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        privacyChannel,
        null,
      ),
    );
    final load = _MockLoadBullVaultOnboardingUsecase();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    final cubit = BullVaultOnboardingCubit(
      _MockCreateBullVaultOnboardingUsecase(),
      _MockPrepareBullVaultTimeReferenceUsecase(),
      load,
      _MockCheckBullVaultMobileBackupsUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      _MockActivateInitialBullVaultUsecase(),
      _MockEncodeBullVaultRecoveryPackageUsecase(),
      _MockUpdateBullVaultRegistrationNameUsecase(),
    );
    addTearDown(cubit.close);
    await cubit.load();
    cubit.setMobilePassphraseProtection(enabled: true);
    await cubit.next();
    cubit.setInheritance(false);
    await cubit.next();
    cubit.useGenericColdSigner();
    cubit.setColdInput('cold-account-key');
    await cubit.next();
    final router = _completionRouter(cubit);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(BullSecretTextInput),
      matching: find.byType(TextField),
    );
    const passphrase = '  café vault  ';
    await tester.enterText(fields.first, passphrase);
    await tester.enterText(fields.last, passphrase.trim());
    expect(cubit.state.mobilePassphraseReady, isFalse);
    await tester.enterText(fields.last, passphrase);
    expect(cubit.state.mobilePassphraseReady, isTrue);
    await tester.enterText(fields.first, 'changed');
    expect(cubit.state.mobilePassphraseReady, isFalse);
  });

  testWidgets('fits the setup illustration on a narrow screen', (tester) async {
    const screenSize = Size(320, 740);
    Device.screen = screenSize;
    addTearDown(() => Device.screen = const Size(800, 600));
    await tester.binding.setSurfaceSize(screenSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = BullVaultOnboardingCubit(
      _MockCreateBullVaultOnboardingUsecase(),
      _MockPrepareBullVaultTimeReferenceUsecase(),
      _MockLoadBullVaultOnboardingUsecase(),
      _MockCheckBullVaultMobileBackupsUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      _MockActivateInitialBullVaultUsecase(),
      _MockEncodeBullVaultRecoveryPackageUsecase(),
      _MockUpdateBullVaultRegistrationNameUsecase(),
    );
    addTearDown(cubit.close);
    final router = _completionRouter(cubit);
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.phone_iphone_outlined), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customizes last-resort recovery without adding another signer', (
    tester,
  ) async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    final cubit = BullVaultOnboardingCubit(
      _MockCreateBullVaultOnboardingUsecase(),
      _MockPrepareBullVaultTimeReferenceUsecase(),
      load,
      _MockCheckBullVaultMobileBackupsUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      _MockActivateInitialBullVaultUsecase(),
      _MockEncodeBullVaultRecoveryPackageUsecase(),
      _MockUpdateBullVaultRegistrationNameUsecase(),
    );
    addTearDown(cubit.close);
    await cubit.load();
    cubit.setEverydayKeySource(BullVaultEverydayKeySource.hardware);
    final router = _completionRouter(cubit);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(
      tester.element(find.byType(BullVaultOnboardingScreen)),
    );
    await tester.tap(find.text(loc.continueButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.bullVaultAddInheritance));
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.bullVaultCustomizeSetup));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(loc.bullVaultLastResortRecovery));
    await tester.pumpAndSettle();
    expect(find.text(loc.bullVaultLastResortDescription), findsOneWidget);
    await tester.tap(find.text(loc.bullVaultLastResortRecovery));
    await tester.pumpAndSettle();
    expect(cubit.state.schedule.lastResortDelay, isNull);
    await tester.tap(find.text(loc.bullVaultLastResortRecovery));
    await tester.pumpAndSettle();
    expect(cubit.state.schedule.lastResortDelay, 7);
    expect(cubit.state.everydayKeySource, BullVaultEverydayKeySource.hardware);
    await tester.ensureVisible(find.text(loc.bullVaultScheduleTitle));
    await tester.tap(find.text(loc.bullVaultScheduleTitle));
    await tester.pumpAndSettle();
    expect(find.text(loc.bullVaultLastResortDelay), findsOneWidget);
    expect(find.text(loc.bullVaultYears(7)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accepts a generated inheritance key only after mnemonic verification',
    (tester) async {
      const privacyChannel = MethodChannel(
        'com.flutterplaza.no_screenshot_methods',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        privacyChannel,
        (_) async => true,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          privacyChannel,
          null,
        ),
      );
      final fixture = BullVaultSecretsFixture();
      final first = await tester.runAsync(
        () async =>
            (await fixture.secrets.generateEphemeral()
                    as Ok<EphemeralMnemonic, SecretFailure>)
                .value,
      );
      final second = await tester.runAsync(
        () async =>
            (await fixture.secrets.generateEphemeral()
                    as Ok<EphemeralMnemonic, SecretFailure>)
                .value,
      );
      if (first == null || second == null) fail('Generation did not finish');
      final derive = DeriveBullVaultMnemonicKeyUsecase(fixture.secrets);
      final expected = await tester.runAsync(
        () => derive.fromGenerated(
          mnemonic: second,
          network: Network.bitcoinMainnet,
        ),
      );
      final deriveFlow = _MockDeriveInheritance();
      when(
        () => deriveFlow.fromGenerated(
          mnemonic: second,
          network: Network.bitcoinMainnet,
        ),
      ).thenAnswer(
        (_) async => expected ?? const Err(BullVaultCreationFailure()),
      );
      final generated = [first, second].iterator;
      final generate = _MockGenerateInheritance();
      when(generate.execute).thenAnswer((_) async {
        generated.moveNext();
        return Ok(generated.current);
      });
      locator.registerSingleton<GenerateBullVaultInheritanceMnemonicUsecase>(
        generate,
      );
      locator.registerSingleton<DeriveBullVaultMnemonicKeyUsecase>(deriveFlow);
      locator.registerFactory<BullVaultInheritanceMnemonicCubit>(
        () => BullVaultInheritanceMnemonicCubit(generate, deriveFlow),
      );
      addTearDown(() {
        locator.unregister<BullVaultInheritanceMnemonicCubit>();
        locator.unregister<GenerateBullVaultInheritanceMnemonicUsecase>();
        locator.unregister<DeriveBullVaultMnemonicKeyUsecase>();
      });
      final load = _MockLoadBullVaultOnboardingUsecase();
      when(load.execute).thenAnswer(
        (_) async =>
            const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
      );
      final cubit = BullVaultOnboardingCubit(
        _MockCreateBullVaultOnboardingUsecase(),
        _MockPrepareBullVaultTimeReferenceUsecase(),
        load,
        _MockCheckBullVaultMobileBackupsUsecase(),
        _MockUpdateBullVaultSetupUsecase(),
        _MockActivateInitialBullVaultUsecase(),
        _MockEncodeBullVaultRecoveryPackageUsecase(),
        _MockUpdateBullVaultRegistrationNameUsecase(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.next();
      cubit.setInheritance(true);
      await cubit.next();
      cubit.useGenericColdSigner();
      cubit.setColdInput('cold-account-key');
      await cubit.next();
      cubit.setInheritanceSource(
        BullVaultInheritanceKeySource.generatedMnemonic,
      );
      Device.screen = const Size(800, 600);
      final router = _completionRouter(cubit);
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(BullVaultOnboardingScreen));
      final loc = AppLocalizations.of(context);

      Future<void> openMnemonic() async {
        final button = find.widgetWithText(
          BullButton,
          loc.bullVaultInheritanceGenerateMnemonic,
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(ShowMnemonicScreen), findsOneWidget);
        expect(find.byType(MnemonicView), findsOneWidget);
        await tester.tap(find.text(loc.testBackupNext));
        await tester.pumpAndSettle();
        expect(find.byType(VerifyMnemonicScreen), findsOneWidget);
      }

      await openMnemonic();
      await tester.tap(find.byIcon(BullIcons.arrowBack));
      await tester.pumpAndSettle();
      expect(find.byType(ShowMnemonicScreen), findsOneWidget);
      await tester.tap(find.byIcon(BullIcons.arrowBack));
      await tester.pumpAndSettle();
      expect(cubit.state.inheritanceInput, isEmpty);

      await openMnemonic();
      final challenge = tester.widget<MnemonicChallenge>(
        find.byType(MnemonicChallenge),
      );
      challenge.onMistake();
      expect(cubit.state.inheritanceInput, isEmpty);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      challenge.onSolved();
      await tester.pumpAndSettle();
      expect(
        cubit.state.inheritanceInput,
        (expected as Ok<String, BullVaultFailure>).value,
      );
      expect(fixture.storage.entries, isEmpty);
      expect(cubit.state.seedBackupVerified, isFalse);
      expect(find.byType(BullVaultOnboardingScreen), findsOneWidget);
    },
  );

  testWidgets('activates the vault before opening its wallet', (tester) async {
    final result = _readyResult();
    final load = _MockLoadBullVaultOnboardingUsecase();
    final activate = _MockActivateInitialBullVaultUsecase();
    final encode = _MockEncodeBullVaultRecoveryPackageUsecase();
    when(load.execute).thenAnswer(
      (_) async => Ok(
        BullVaultOnboardingLoad(
          network: Network.bitcoinMainnet,
          snapshot: BullVaultOnboardingSnapshot(
            result: result,
            mobileBackupStatus: const Ok((physical: true, recoverBull: false)),
          ),
        ),
      ),
    );
    when(() => encode.execute(result.recoveryPackage)).thenReturn('{}');
    when(
      () => activate.execute(
        walletId: result.wallet.id,
        hardwareSetupDeferred: false,
        hasMobileBackup: true,
        mobileBackupDeferred: false,
      ),
    ).thenAnswer((_) async => const Ok(null));
    final cubit = BullVaultOnboardingCubit(
      _MockCreateBullVaultOnboardingUsecase(),
      _MockPrepareBullVaultTimeReferenceUsecase(),
      load,
      _MockCheckBullVaultMobileBackupsUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      activate,
      encode,
      _MockUpdateBullVaultRegistrationNameUsecase(),
    );
    addTearDown(cubit.close);
    await cubit.load();

    final router = _completionRouter(cubit);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open wallet list'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet home'), findsOneWidget);
    verify(
      () => activate.execute(
        walletId: result.wallet.id,
        hardwareSetupDeferred: false,
        hasMobileBackup: true,
        mobileBackupDeferred: false,
      ),
    ).called(1);
  });

  testWidgets('keeps the completion screen open when activation fails', (
    tester,
  ) async {
    final result = _readyResult();
    final load = _MockLoadBullVaultOnboardingUsecase();
    final activate = _MockActivateInitialBullVaultUsecase();
    final encode = _MockEncodeBullVaultRecoveryPackageUsecase();
    when(load.execute).thenAnswer(
      (_) async => Ok(
        BullVaultOnboardingLoad(
          network: Network.bitcoinMainnet,
          snapshot: BullVaultOnboardingSnapshot(
            result: result,
            mobileBackupStatus: const Ok((physical: true, recoverBull: false)),
          ),
        ),
      ),
    );
    when(() => encode.execute(result.recoveryPackage)).thenReturn('{}');
    when(
      () => activate.execute(
        walletId: result.wallet.id,
        hardwareSetupDeferred: false,
        hasMobileBackup: true,
        mobileBackupDeferred: false,
      ),
    ).thenAnswer((_) async => const Err(BullVaultCreationFailure()));
    final cubit = BullVaultOnboardingCubit(
      _MockCreateBullVaultOnboardingUsecase(),
      _MockPrepareBullVaultTimeReferenceUsecase(),
      load,
      _MockCheckBullVaultMobileBackupsUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      activate,
      encode,
      _MockUpdateBullVaultRegistrationNameUsecase(),
    );
    addTearDown(cubit.close);
    await cubit.load();

    final router = _completionRouter(cubit);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open wallet list'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet home'), findsNothing);
    expect(find.text('BullVault created'), findsOneWidget);
    expect(find.text('Open wallet list'), findsOneWidget);
  });
}

BullVaultCreateResult _readyResult() {
  final result = testBullVaultCreateResult();
  return BullVaultCreateResult(
    wallet: result.wallet,
    record: result.record.copyWith(recoveryPackageConfirmed: true),
  );
}

GoRouter _completionRouter(BullVaultOnboardingCubit cubit) => GoRouter(
  initialLocation: '/setup',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const Text('Wallet home')),
    GoRoute(
      path: '/setup',
      builder: (_, _) => BlocProvider.value(
        value: cubit,
        child: const BullVaultOnboardingScreen(),
      ),
    ),
  ],
);

Widget _app(GoRouter router) => MaterialApp.router(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);
