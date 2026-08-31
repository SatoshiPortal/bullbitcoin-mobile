import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bitbox/public/bitbox_facade.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_onboarding_snapshot.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_initial_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_onboarding_screen.dart';
import 'package:bb_mobile/features/import_qr_device/public/import_qr_device_facade.dart';
import 'package:bb_mobile/features/ledger/public/ledger_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
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

void main() {
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
    );
    addTearDown(reviewCubit.close);
    await reviewCubit.load();
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

  for (final device in [
    SignerDeviceEntity.ledgerNanoX,
    SignerDeviceEntity.bitbox02,
    SignerDeviceEntity.krux,
  ]) {
    testWidgets(
      'continues after ${device.name} returns a key and Back restores the signer step',
      (tester) async {
        final load = _MockLoadBullVaultOnboardingUsecase();
        final prepare = _MockPrepareBullVaultTimeReferenceUsecase();
        when(load.execute).thenAnswer(
          (_) async => const Ok(
            BullVaultOnboardingLoad(network: Network.bitcoinMainnet),
          ),
        );
        when(
          () => prepare.execute(isTestnet: false),
        ).thenAnswer((_) async => Ok(_timeReference()));
        final cubit = BullVaultOnboardingCubit(
          _MockCreateBullVaultOnboardingUsecase(),
          prepare,
          load,
          _MockCheckBullVaultMobileBackupsUsecase(),
          _MockUpdateBullVaultSetupUsecase(),
          _MockActivateInitialBullVaultUsecase(),
          _MockEncodeBullVaultRecoveryPackageUsecase(),
        );
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.next();
        await cubit.next();
        cubit.selectColdDevice(device);

        final routeName = switch (device) {
          SignerDeviceEntity.ledgerNanoX =>
            const LedgerFacade().readAccountKeyRouteName,
          SignerDeviceEntity.bitbox02 =>
            const BitBoxFacade().readAccountKeyRouteName,
          SignerDeviceEntity.krux =>
            const ImportQrDeviceFacade().accountKeyRouteName(device),
          _ => throw StateError('Unsupported test device'),
        };
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => BlocProvider.value(
                value: cubit,
                child: const BullVaultOnboardingScreen(),
              ),
            ),
            GoRoute(
              name: routeName,
              path: '/acquire',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop('account-key'),
                  child: const Text('Return key'),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );

        await tester.tap(find.text('Continue with ${device.displayName}'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Return key'));
        await tester.pumpAndSettle();

        expect(find.text('Review your BullVault'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Connect your cold key'), findsOneWidget);
        expect(
          find.text('Public account key received from ${device.displayName}.'),
          findsOneWidget,
        );
      },
    );
  }

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
    policy: result.policy,
    record: result.record.copyWith(recoveryPackageConfirmed: true),
    recoveryPackage: result.recoveryPackage,
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
