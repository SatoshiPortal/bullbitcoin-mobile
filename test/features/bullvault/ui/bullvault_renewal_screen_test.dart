import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/cancel_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/renew_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_registration_name_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/watch_bullvault_migration_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_renewal_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_renewal_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';

class _MockLoadBullVaultRenewalUsecase extends Mock
    implements LoadBullVaultRenewalUsecase {}

class _MockRenewBullVaultUsecase extends Mock
    implements RenewBullVaultUsecase {}

class _MockActivateBullVaultRenewalUsecase extends Mock
    implements ActivateBullVaultRenewalUsecase {}

class _MockCancelBullVaultRenewalUsecase extends Mock
    implements CancelBullVaultRenewalUsecase {}

class _MockUpdateBullVaultSetupUsecase extends Mock
    implements UpdateBullVaultSetupUsecase {}

class _MockUpdateBullVaultRegistrationNameUsecase extends Mock
    implements UpdateBullVaultRegistrationNameUsecase {}

class _MockWatchBullVaultMigrationUsecase extends Mock
    implements WatchBullVaultMigrationUsecase {}

class _MockEncodeBullVaultRecoveryPackageUsecase extends Mock
    implements EncodeBullVaultRecoveryPackageUsecase {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      BullVaultRenewRequest(
        walletId: 'fallback-wallet',
        label: 'Fallback',
        schedule: const BullVaultSchedule(),
        timeReference: BullVaultTimeReference(
          deviceTime: DateTime.utc(2027),
          chainHeight: 3_000_000,
          medianTimePast: DateTime.utc(2027).millisecondsSinceEpoch ~/ 1000,
        ),
      ),
    );
  });

  testWidgets('shows incomplete setup without preparing renewal dates', (
    tester,
  ) async {
    final details = testBullVaultDetails();
    final load = _MockLoadBullVaultRenewalUsecase();
    when(() => load.execute(details.record.walletId)).thenAnswer(
      (_) async =>
          Ok(BullVaultRenewalLoad(details: details, needsInitialSetup: true)),
    );
    final cubit = BullVaultRenewalCubit(
      load,
      _MockRenewBullVaultUsecase(),
      _MockActivateBullVaultRenewalUsecase(),
      _MockCancelBullVaultRenewalUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      _MockUpdateBullVaultRegistrationNameUsecase(),
      _MockWatchBullVaultMigrationUsecase(),
      _MockEncodeBullVaultRecoveryPackageUsecase(),
      walletId: details.record.walletId,
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      BlocProvider<BullVaultRenewalCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BullVaultRenewalScreen(walletLabel: 'Vault'),
        ),
      ),
    );

    expect(find.text('Finish setup'), findsOneWidget);
    expect(find.text('New recovery dates'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('can leave incomplete hardware setup for later', (tester) async {
    final details = testBullVaultDetails();
    final created = testBullVaultCreateResult(
      walletId: 'replacement-wallet',
      previousVaultId: details.record.walletId,
      lineageId: details.record.lineageId,
      generation: 1,
    );
    final coldKey = created.policy.coldKey;
    final renewal = BullVaultRenewResult(
      previous: details.record,
      replacement: BullVaultCreateResult(
        wallet: created.wallet.copyWith(
          signers: [
            WalletSigner.single(
              id: 'cold',
              masterFingerprint: coldKey.accountKey.masterFingerprint,
              xpubFingerprint: coldKey.accountKey.xpubFingerprint,
              xpub: coldKey.accountKey.xpub,
              derivationPath: coldKey.accountKey.derivationPath,
              descriptorPath: coldKey.accountKey.descriptorPath,
              signer: coldKey.signer,
              signerDevice: coldKey.signerDevice,
            ),
          ],
        ),
        record: created.record.copyWith(recoveryPackageConfirmed: true),
      ),
    );
    final load = _MockLoadBullVaultRenewalUsecase();
    final encode = _MockEncodeBullVaultRecoveryPackageUsecase();
    when(() => load.execute(details.record.walletId)).thenAnswer(
      (_) async => Ok(BullVaultRenewalLoad(details: details, renewal: renewal)),
    );
    when(() => encode.execute(created.recoveryPackage)).thenReturn('{}');
    final cubit = BullVaultRenewalCubit(
      load,
      _MockRenewBullVaultUsecase(),
      _MockActivateBullVaultRenewalUsecase(),
      _MockCancelBullVaultRenewalUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      _MockUpdateBullVaultRegistrationNameUsecase(),
      _MockWatchBullVaultMigrationUsecase(),
      encode,
      walletId: details.record.walletId,
    );
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Wallet home')),
        GoRoute(
          path: '/settings',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const BullVaultRenewalScreen(walletLabel: 'Vault'),
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
    router.push('/settings');
    await tester.pumpAndSettle();

    expect(find.text('Do this later'), findsOneWidget);
    await tester.tap(find.text('Do this later'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet home'), findsOneWidget);
  });

  testWidgets('blocks Back while a renewal is being created', (tester) async {
    final details = testBullVaultDetails();
    final reference = BullVaultTimeReference(
      deviceTime: DateTime.utc(2027, 1, 1),
      chainHeight: 3_000_000,
      medianTimePast:
          DateTime.utc(2027, 1, 1).millisecondsSinceEpoch ~/ 1000 - 3600,
    );
    final load = _MockLoadBullVaultRenewalUsecase();
    final renew = _MockRenewBullVaultUsecase();
    final delayed = Completer<void>();
    when(() => load.execute(details.record.walletId)).thenAnswer(
      (_) async =>
          Ok(BullVaultRenewalLoad(details: details, timeReference: reference)),
    );
    when(() => renew.execute(any())).thenAnswer((_) async {
      await delayed.future;
      return const Err(BullVaultRenewalFailure());
    });
    final cubit = BullVaultRenewalCubit(
      load,
      renew,
      _MockActivateBullVaultRenewalUsecase(),
      _MockCancelBullVaultRenewalUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      _MockUpdateBullVaultRegistrationNameUsecase(),
      _MockWatchBullVaultMigrationUsecase(),
      _MockEncodeBullVaultRecoveryPackageUsecase(),
      walletId: details.record.walletId,
    );
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Previous screen')),
        GoRoute(
          path: '/settings',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const BullVaultRenewalScreen(walletLabel: 'Vault'),
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
    router.push('/settings');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Renew vault'));
    await tester.pumpAndSettle();
    expect(find.text('Renew this BullVault?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Renew vault'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(cubit.state.isRenewing, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Previous screen'), findsNothing);
    expect(find.text('BullVault settings'), findsOneWidget);

    delayed.complete();
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('blocks Back while a renewal is being activated', (tester) async {
    final details = testBullVaultDetails();
    final created = testBullVaultCreateResult(
      walletId: 'replacement-wallet',
      previousVaultId: details.record.walletId,
      lineageId: details.record.lineageId,
      generation: 1,
    );
    final replacement = BullVaultCreateResult(
      wallet: created.wallet,
      record: created.record.copyWith(recoveryPackageConfirmed: true),
    );
    final renewal = BullVaultRenewResult(
      previous: details.record,
      replacement: replacement,
    );
    final load = _MockLoadBullVaultRenewalUsecase();
    final activate = _MockActivateBullVaultRenewalUsecase();
    final encode = _MockEncodeBullVaultRecoveryPackageUsecase();
    final delayed = Completer<void>();
    when(() => load.execute(details.record.walletId)).thenAnswer(
      (_) async => Ok(BullVaultRenewalLoad(details: details, renewal: renewal)),
    );
    when(() => encode.execute(created.recoveryPackage)).thenReturn('{}');
    when(
      () => activate.execute(
        previousWalletId: details.record.walletId,
        replacementWalletId: created.wallet.id,
      ),
    ).thenAnswer((_) async {
      await delayed.future;
      return const Ok(null);
    });
    final cubit = BullVaultRenewalCubit(
      load,
      _MockRenewBullVaultUsecase(),
      activate,
      _MockCancelBullVaultRenewalUsecase(),
      _MockUpdateBullVaultSetupUsecase(),
      _MockUpdateBullVaultRegistrationNameUsecase(),
      _MockWatchBullVaultMigrationUsecase(),
      encode,
      walletId: details.record.walletId,
    );
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Previous screen')),
        GoRoute(
          path: '/settings',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const BullVaultRenewalScreen(walletLabel: 'Vault'),
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
    router.push('/settings');
    await tester.pumpAndSettle();

    final activationFuture = cubit.activate();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(cubit.state.isActivating, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Previous screen'), findsNothing);
    expect(find.text('BullVault settings'), findsOneWidget);

    delayed.complete();
    await activationFuture;
    await tester.pumpAndSettle();
  });
}
