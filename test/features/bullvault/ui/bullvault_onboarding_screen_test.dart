import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_key_source.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/generate_bullvault_inheritance_mnemonic_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/derive_bullvault_mnemonic_key_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_onboarding_snapshot.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
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

class _MockGenerateInheritanceMnemonicUsecase extends Mock
    implements GenerateBullVaultInheritanceMnemonicUsecase {}

void main() {
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
      final words = [...List.filled(11, 'abandon'), 'about'];
      final generate = _MockGenerateInheritanceMnemonicUsecase();
      when(generate.execute).thenReturn(Ok(words));
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
        generate,
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
          BBButton,
          loc.bullVaultInheritanceGenerateMnemonic,
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(ShowMnemonicScreen), findsOneWidget);
        expect(find.text('abandon'), findsNWidgets(11));
        await tester.tap(find.text(loc.testBackupNext));
        await tester.pumpAndSettle();
        expect(find.byType(VerifyMnemonicScreen), findsOneWidget);
      }

      await openMnemonic();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ShowMnemonicScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(cubit.state.inheritanceInput, isEmpty);

      await openMnemonic();
      Future<void> selectWord(String word) async {
        final tile = find
            .widgetWithText(InkWell, word)
            .evaluate()
            .firstWhere((element) => (element.widget as InkWell).onTap != null);
        final finder = find.byWidget(tile.widget);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await selectWord('about');
      expect(cubit.state.inheritanceInput, isEmpty);
      for (final word in words) {
        await selectWord(word);
      }
      final expected =
          const DeriveBullVaultMnemonicKeyUsecase().execute(
                words: words,
                network: Network.bitcoinMainnet,
              )
              as Ok<String, BullVaultFailure>;
      expect(cubit.state.inheritanceInput, expected.value);
      expect(cubit.state.seedBackupVerified, isFalse);
      expect(find.byType(BullVaultOnboardingScreen), findsOneWidget);
    },
  );

  testWidgets('keeps setup and completion on one progress scale', (
    tester,
  ) async {
    final load = _MockLoadBullVaultOnboardingUsecase();
    final prepare = _MockPrepareBullVaultTimeReferenceUsecase();
    when(load.execute).thenAnswer(
      (_) async =>
          const Ok(BullVaultOnboardingLoad(network: Network.bitcoinMainnet)),
    );
    when(
      () => prepare.execute(isTestnet: false),
    ).thenAnswer((_) async => Ok(_timeReference()));
    final reviewCubit = BullVaultOnboardingCubit(
      _MockCreateBullVaultOnboardingUsecase(),
      prepare,
      load,
      _MockCheckBullVaultMobileBackupsUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      _MockActivateInitialBullVaultUsecase(),
      _MockEncodeBullVaultRecoveryPackageUsecase(),
      _MockUpdateBullVaultRegistrationNameUsecase(),
    );
    addTearDown(reviewCubit.close);
    await reviewCubit.load();
    await reviewCubit.next();
    reviewCubit.setInheritance(false);
    await reviewCubit.next();
    await reviewCubit.next();
    reviewCubit.useGenericColdSigner();
    reviewCubit.setColdInput('account-key');
    await reviewCubit.next();

    final reviewRouter = _completionRouter(reviewCubit);
    addTearDown(reviewRouter.dispose);
    await tester.pumpWidget(_app(reviewRouter));
    await tester.pumpAndSettle();
    final reviewProgress = tester
        .widget<LinearProgressIndicator>(
          find.byKey(const Key('bullvault-onboarding-progress')),
        )
        .value!;
    expect(reviewProgress, inInclusiveRange(0, 1));

    final result = testBullVaultCreateResult();
    final completionLoad = _MockLoadBullVaultOnboardingUsecase();
    final encode = _MockEncodeBullVaultRecoveryPackageUsecase();
    when(completionLoad.execute).thenAnswer(
      (_) async => Ok(
        BullVaultOnboardingLoad(
          network: Network.bitcoinMainnet,
          snapshot: BullVaultOnboardingSnapshot(
            result: result,
            mobileBackupStatus: const Ok((physical: false, recoverBull: false)),
          ),
        ),
      ),
    );
    when(() => encode.execute(result.recoveryPackage)).thenReturn('{}');
    final completionCubit = BullVaultOnboardingCubit(
      _MockCreateBullVaultOnboardingUsecase(),
      _MockPrepareBullVaultTimeReferenceUsecase(),
      completionLoad,
      _MockCheckBullVaultMobileBackupsUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      _MockActivateInitialBullVaultUsecase(),
      encode,
      _MockUpdateBullVaultRegistrationNameUsecase(),
    );
    addTearDown(completionCubit.close);
    await completionCubit.load();
    final completionRouter = _completionRouter(completionCubit);
    addTearDown(completionRouter.dispose);
    await tester.pumpWidget(_app(completionRouter));
    await tester.pumpAndSettle();
    final completionProgress = tester
        .widget<LinearProgressIndicator>(
          find.byKey(const Key('bullvault-onboarding-progress')),
        )
        .value!;
    expect(completionProgress, greaterThan(reviewProgress));
    expect(completionProgress, lessThanOrEqualTo(1));
  });

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

BullVaultTimeReference _timeReference() => BullVaultTimeReference(
  deviceTime: DateTime.utc(2027, 1, 15, 12),
  chainHeight: 900000,
  medianTimePast: DateTime.utc(2027, 1, 15, 11).millisecondsSinceEpoch ~/ 1000,
);
