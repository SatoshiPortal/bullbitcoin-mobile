import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_restore_screen.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_router.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_scanner_screen.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_policy_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/update_wallet_signer_device_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_policy_view.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';

class _Vaults extends Mock implements BullVaultRepository {}

class _Wallets extends Mock implements GetWalletUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

class _Seeds extends Mock implements SeedVerificationPort {}

class _MockRestoreBullVaultUsecase extends Mock
    implements RestoreBullVaultUsecase {}

class _MockGetWalletPolicyUsecase extends Mock
    implements GetWalletPolicyUsecase {}

class _MockUpdateSignerUsecase extends Mock
    implements UpdateWalletSignerDeviceUsecase {}

void main() {
  testWidgets('fills the descriptor field from a QR scan', (tester) async {
    const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    const descriptor = 'tr(test-descriptor)';
    final cubit = BullVaultRestoreCubit(_MockRestoreBullVaultUsecase());
    addTearDown(cubit.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider.value(
            value: cubit,
            child: const BullVaultRestoreScreen(),
          ),
        ),
        GoRoute(
          name: BullVaultRouter.scannerRouteName,
          path: '/scan',
          builder: (context, state) {
            expect(state.extra, BullVaultScannerPurpose.descriptor);
            return Scaffold(
              body: TextButton(
                onPressed: () => context.pop(descriptor),
                child: const Text('Return descriptor'),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.qr_code_scanner));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return descriptor'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller?.text),
      contains(descriptor),
    );
  });

  testWidgets(
    'successful watch-only restore shows the existing policy viewer',
    (tester) async {
      const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => true,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      locator.pushNewScope();
      addTearDown(locator.popScope);
      final created = testBullVaultCreateResult(
        status: .active,
        usesBullMobile: false,
      );
      final vaults = _Vaults(), wallets = _Wallets();
      when(
        () => vaults.getByWalletId(created.wallet.id),
      ).thenAnswer((_) async => Ok(created.record));
      when(
        () => wallets.execute(created.wallet.id),
      ).thenAnswer((_) async => created.wallet);
      locator.registerFactory<BullVaultSettingsCubit>(
        () => BullVaultSettingsCubit(
          InspectBullVaultUsecase(vaults, wallets, _Settings(), _Seeds()),
        ),
      );
      final usecase = _MockRestoreBullVaultUsecase();
      final getPolicy = _MockGetWalletPolicyUsecase();
      final spending = BitcoinSpendingPolicy(
        root: BitcoinSignaturePolicyNode(
          id: 'inheritance',
          key: BitcoinPolicyKey(
            kind: BitcoinPolicyKeyKind.fingerprint,
            value: '12345678',
          ),
        ),
        requiresPath: false,
      );
      final policy = BitcoinWalletPolicy(
        external: spending,
        internal: spending,
      );
      when(
        () => getPolicy.execute(created.wallet.id),
      ).thenAnswer((_) async => Ok(policy));
      locator.registerFactory<WalletDetailsCubit>(
        () => WalletDetailsCubit(
          getWalletPolicyUsecase: getPolicy,
          updateWalletSignerDeviceUsecase: _MockUpdateSignerUsecase(),
        ),
      );
      when(
        () => usecase.execute(
          kind: BullVaultRestoreInputKind.descriptor,
          source: 'descriptor',
          label: 'Vault',
        ),
      ).thenAnswer(
        (_) async => Ok(
          BullVaultRestoreResult(
            wallet: created.wallet,
            record: created.record,
            mobileAccess: BullVaultMobileAccess.unavailable,
          ),
        ),
      );
      final cubit = BullVaultRestoreCubit(usecase);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const BullVaultRestoreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await cubit.restore(
        kind: BullVaultRestoreInputKind.descriptor,
        source: 'descriptor',
        label: 'Vault',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(WalletPolicyDetails), 150);
      await tester.pumpAndSettle();

      final viewer = tester.widget<WalletPolicyDetails>(
        find.byType(WalletPolicyDetails),
      );
      expect(viewer.policy, same(policy));
      expect(viewer.wallet.id, created.wallet.id);
      expect(
        find.descendant(
          of: find.byType(WalletPolicyDetails),
          matching: find.byIcon(Icons.close),
        ),
        findsNothing,
      );
      expect(
        cubit.state.result?.mobileAccess,
        BullVaultMobileAccess.unavailable,
      );
      expect(find.text('Continue'), findsOneWidget);
      verify(() => getPolicy.execute(created.wallet.id)).called(1);
    },
  );
}
