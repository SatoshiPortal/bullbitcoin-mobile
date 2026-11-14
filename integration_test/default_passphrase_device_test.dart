import 'dart:math';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/app_unlock/presentation/bloc/app_unlock_bloc.dart';
import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/show_mnemonic_screen.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_physical_recovery.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_secret_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/backup_test_success.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/features/import_mnemonic/ui/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/verify_backup_passphrase_usecase.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/init.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_file_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/delete_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/export_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/list_drive_vaults_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_backup_settings_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/read_drive_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:bull_recoverbull/src/presentation/vault_flow_cubit.dart';
import 'package:bull_recoverbull/src/presentation/vault_flow_presentation.dart';
import 'package:bull_recoverbull/src/ui/screens/vault_flow_page.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'secrets_derivation_vectors_test.dart' as vectors;

T custodyValue<T>(Result<T, SecretFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail(
    'custody operation failed: ${failure.runtimeType}',
  ),
};

// These ports are never used for custody: the vault repository below uses
// the real Secrets instance and the platform keystore on the device.
final class _DeviceFiles extends Fake implements VaultFileRepository {}

final class _DeviceDrive extends Fake implements GoogleDriveRepository {}

final class _DeviceWallets extends Fake implements rb.RecoverBullWalletPort {
  int restores = 0;
  @override
  Future<Result<rb.VaultContext, rb.RecoverBullFailure>> restoreDefaults(
    rb.VaultContext requested,
  ) async {
    restores++;
    return Ok(requested);
  }
}

// Keep the actual PIN input route open without starting automatic unlock.
// This isolates its real go_router Back callback, including on a no-PIN app.
final class _DeviceCancelUnlock extends AppUnlockFacade {
  const _DeviceCancelUnlock();

  @override
  Widget buildReauthenticationGate({
    required ValueChanged<AppUnlockGrant> onSuccess,
    bool canPop = false,
  }) => BlocProvider(
    create: (_) => locator<AppUnlockBloc>(),
    child: PinCodeUnlockInputScreen(canPop: canPop),
  );
}

VaultFlowPresentation _vaultPresentation(
  SecretsVaultRepository vaults,
  _DeviceWallets wallets,
  rb.EncryptedVault vault,
) {
  final files = _DeviceFiles();
  final drive = _DeviceDrive();
  return VaultFlowPresentation(
    VaultFlowCubit(
      const ManageBackupSettingsUsecase(
        null,
        rb.RecoverBullStorageFullFailure(),
      ),
      (
        pick: PickVaultUsecase(files),
        list: ListDriveVaultsUsecase(drive),
        select: ReadDriveVaultUsecase(drive),
        delete: DeleteDriveVaultUsecase(drive),
        export: ExportDriveVaultUsecase(files, drive),
      ),
      null,
      CompleteVaultUsecase(
        TestVaultUsecase(vaults, wallets),
        RestoreVaultUsecase(vaults, wallets),
        null,
        null,
      ),
      unavailable: const rb.RecoverBullStorageFullFailure(),
      vault: vault,
    ),
    const Ok(BitcoinNetwork.mainnet),
    null,
    defaultHasPassphrase: true,
  );
}

Future<void> _waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 300 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue);
}

Future<void> initializeDeviceTests({bool isInitialized = false}) async {
  if (!isInitialized) await Bull.init();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  Device.screen = view.physicalSize / view.devicePixelRatio;
}

void main({bool isInitialized = false}) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Register every test synchronously; native initialization runs once before
  // either this file or the imported vector suite uses the platform plugins.
  setUpAll(() => initializeDeviceTests(isInitialized: isInitialized));
  vectors.main(isInitialized: true);

  testWidgets('real custody restores a protected synthetic wallet', (
    tester,
  ) async {
    final scratch = await getTemporaryDirectory();
    final secrets = Secrets(scratchDirectory: () async => scratch.path);
    final random = Random.secure();
    final entropy = List<int>.generate(16, (_) => random.nextInt(256));
    final words = bip39.Mnemonic(entropy, bip39.Language.english).words;
    const phrase = 'synthetic passphrase é';
    Fingerprint? owned;
    try {
      final secret = custodyValue(
        await secrets.import(words: words, passphrase: phrase),
      );
      owned = secret.id;
      expect(secret.info.hasPassphrase, isTrue);

      // Exercise the real native engines using the same stored secret.
      final bitcoin = custodyValue(
        await secret.derive.descriptors.bitcoin(
          network: BitcoinNetwork.mainnet,
          scriptType: ScriptType.bip84,
        ),
      );
      final liquid = custodyValue(
        await secret.derive.descriptors.liquid(network: LiquidNetwork.mainnet),
      );
      expect(bitcoin.external, contains(secret.id.hex));
      expect(liquid, contains(secret.id.hex));

      final verification = const VerifyBackupPassphraseUsecase();
      expect(
        (await verification.execute(secret, 'wrong') as Ok).value,
        isFalse,
      );
      expect((await verification.execute(secret, phrase) as Ok).value, isTrue);

      final backup = custodyValue(await secret.backup.recoverbull());
      expect(
        (await secrets.recoverbull.fingerprint(
                  vault: backup.vault,
                  key: backup.key,
                )
                as Err)
            .failure,
        isA<VaultIdentityMismatchFailure>(),
      );
      expect(
        (await secrets.recoverbull.fingerprint(
                  vault: backup.vault,
                  key: backup.key,
                  passphrase: 'wrong',
                )
                as Err)
            .failure,
        isA<VaultIdentityMismatchFailure>(),
      );
      expect(
        custodyValue(
          await secrets.recoverbull.fingerprint(
            vault: backup.vault,
            key: backup.key,
            passphrase: phrase,
          ),
        ),
        secret.id,
      );

      // Remove only this test's fresh secret, so a successful restore must
      // actually write it again. A failed candidate must leave storage intact.
      custodyValue(await secrets.trash(secret.id));
      final before = custodyValue(
        await secrets.list(),
      ).map((entry) => entry.id).toSet();
      final wrong = await secrets.recoverbull.restore(
        vault: backup.vault,
        key: backup.key,
        passphrase: 'wrong',
      );
      expect((wrong as Err).failure, isA<VaultIdentityMismatchFailure>());
      final after = custodyValue(
        await secrets.list(),
      ).map((entry) => entry.id).toSet();
      expect(after, before);
      expect(custodyValue(await secrets.exists(secret.id)), isFalse);
      final restored = custodyValue(
        await secrets.recoverbull.restore(
          vault: backup.vault,
          key: backup.key,
          passphrase: phrase,
        ),
      );
      expect(restored.secret.id, secret.id);
      expect(custodyValue(await secrets.exists(secret.id)), isTrue);
    } finally {
      if (owned != null) custodyValue(await secrets.trash(owned));
    }
  });

  testWidgets('RecoverBull page retries against native custody', (
    tester,
  ) async {
    final scratch = await getTemporaryDirectory();
    final secrets = Secrets(scratchDirectory: () async => scratch.path);
    final random = Random.secure();
    final words = bip39.Mnemonic(
      List<int>.generate(16, (_) => random.nextInt(256)),
      bip39.Language.english,
    ).words;
    const phrase = 'synthetic passphrase é';
    Fingerprint? owned;
    try {
      final secret = custodyValue(
        await secrets.import(words: words, passphrase: phrase),
      );
      owned = secret.id;
      final vaults = SecretsVaultRepository(secrets);
      final context = rb.VaultContext(
        fingerprint: secret.id,
        network: BitcoinNetwork.mainnet,
        hasPassphrase: true,
      );
      final created = await vaults.create(context);
      final backup = switch (created) {
        Ok(:final value) => value,
        Err(:final failure) => fail(
          'vault creation failed: ${failure.runtimeType}',
        ),
      };
      final wallets = _DeviceWallets();
      Widget page(
        rb.RecoverBullFlow flow,
        VaultFlowPresentation presentation,
      ) => MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: VaultFlowPage(
          flow: flow,
          presentation: () async => presentation,
          copiedMessage: 'Copied',
        ),
      );

      // The save screen warns before any external storage or server operation.
      final save = _vaultPresentation(vaults, wallets, backup.vault);
      await tester.pumpWidget(page(rb.RecoverBullFlow.secureVault, save));
      await _waitFor(
        tester,
        () => find.byType(BullCheckbox).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<BullCheckbox>(find.byType(BullCheckbox)).checked,
        isFalse,
      );
      expect(
        find.text('I wrote it down and keep it separately'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(BullCheckbox));
      await tester.tap(find.byType(BullCheckbox));
      await tester.pump();
      expect(
        tester.widget<BullCheckbox>(find.byType(BullCheckbox)).checked,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      custodyValue(await secrets.trash(secret.id));
      final before = custodyValue(
        await secrets.list(),
      ).map((entry) => entry.id).toSet();
      final recover = _vaultPresentation(vaults, wallets, backup.vault);
      await tester.pumpWidget(page(rb.RecoverBullFlow.recoverVault, recover));
      await _waitFor(
        tester,
        () => find.text('Enter a vault key instead').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Enter a vault key instead'));
      await tester.pumpAndSettle();
      await _waitFor(
        tester,
        () => find.byType(TextField).evaluate().isNotEmpty,
      );
      await tester.enterText(find.byType(TextField), backup.key.hex);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await _waitFor(
        tester,
        () => find.text('Passphrase required').evaluate().isNotEmpty,
      );
      expect(wallets.restores, 0);
      expect(
        custodyValue(await secrets.list()).map((entry) => entry.id).toSet(),
        before,
      );

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.ensureVisible(find.text('Verify'));
      await tester.tap(find.text('Verify'));
      await _waitFor(
        tester,
        () => find
            .textContaining('does not match your backup')
            .evaluate()
            .isNotEmpty,
      );
      expect(wallets.restores, 0);
      expect(
        custodyValue(await secrets.list()).map((entry) => entry.id).toSet(),
        before,
      );

      await tester.enterText(find.byType(TextField), phrase);
      await tester.ensureVisible(find.text('Verify'));
      await tester.tap(find.text('Verify'));
      await _waitFor(tester, () => recover.cubit.state.completion != null);
      expect(wallets.restores, 1);
      expect(
        recover.cubit.state.completion?.verifiedContext?.fingerprint,
        secret.id,
      );
      expect(custodyValue(await secrets.exists(secret.id)), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      if (owned != null) custodyValue(await secrets.trash(owned));
    }
  });

  testWidgets('recovery passphrase input starts collapsed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MnemonicWidget(
            initialLength: bip39.MnemonicLength.words12,
            allowPassphrase: true,
            allowLabel: false,
            allowAutoFillWords: false,
            onSubmit: (_) {},
          ),
        ),
      ),
    );
    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Optional Passphrase',
    );
    expect(field, findsNothing);
    final option = find.text('I have a passphrase');
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(field, findsOneWidget);
    await tester.enterText(field, 'synthetic passphrase');
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller?.text ==
          'synthetic passphrase',
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  registerPhysicalRecoveryTests();
  registerReturnNavigationTest();
}

void registerPhysicalRecoveryTests() {
  testWidgets(
    'physical default recovery and backup passphrase on device',
    (tester) async {
      final wallets = locator<WalletRepository>();
      final existing = await wallets.getWallets(onlyDefaults: true);
      final prior = switch (existing) {
        Ok(:final value) => value,
        Err(:final failure) => fail(
          'default wallet read failed: ${failure.runtimeType}',
        ),
      };
      // This test creates persistent defaults; never touch a populated app.
      expect(prior.isEmpty, isTrue, reason: 'requires a dedicated empty app');

      final random = Random.secure();
      final words = bip39.Mnemonic(
        List<int>.generate(16, (_) => random.nextInt(256)),
        bip39.Language.english,
      ).words;
      const phrase = 'synthetic passphrase é';
      final onboarding = locator<OnboardingBloc>();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider.value(
              value: onboarding,
              child: const OnboardingPhysicalRecovery(),
            ),
          ),
          GoRoute(
            name: WalletRoute.walletHome.name,
            path: WalletRoute.walletHome.path,
            builder: (_, _) =>
                const Scaffold(body: Text('DEVICE_WALLET_READY')),
          ),
        ],
      );
      TestWalletBackupBloc? backupBloc;
      try {
        await tester.pumpWidget(
          MaterialApp.router(
            locale: const Locale('en'),
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        await _waitFor(
          tester,
          () => find.byType(MnemonicWidget).evaluate().isNotEmpty,
        );
        // The independent widget test types the field. Here invoke the actual
        // widget's submit callback with a fresh synthetic recovery record.
        tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
          words: words,
          passphrase: phrase,
          label: '',
          language: bip39.Language.english,
        ));
        // Electrum may answer empty or fail. Both require explicit consent;
        // no server setting or network policy is changed by this test.
        for (var i = 0; i < 1200; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.text('Continue without checking').evaluate().isNotEmpty ||
              find.text('This wallet looks empty').evaluate().isNotEmpty ||
              find.text('DEVICE_WALLET_READY').evaluate().isNotEmpty) {
            break;
          }
        }
        final unavailable = find.text('Continue without checking');
        final empty = find.text('This wallet looks empty');
        if (unavailable.evaluate().isNotEmpty) {
          await tester.tap(unavailable);
        } else if (empty.evaluate().isNotEmpty) {
          await tester.tap(find.widgetWithText(TextButton, 'Continue'));
        } else {
          expect(
            find.text('DEVICE_WALLET_READY'),
            findsOneWidget,
            reason: 'scan must finish or offer an explicit continuation',
          );
        }
        await _waitFor(
          tester,
          () => find.text('DEVICE_WALLET_READY').evaluate().isNotEmpty,
        );
        final read = await wallets.getWallets(onlyDefaults: true);
        final created = switch (read) {
          Ok(:final value) => value,
          Err(:final failure) => fail(
            'wallet read failed: ${failure.runtimeType}',
          ),
        };
        expect(created.length, 2);
        expect(created.where((wallet) => wallet.network.isBitcoin).length, 1);
        expect(created.where((wallet) => wallet.network.isLiquid).length, 1);
        expect(
          created.map((wallet) => wallet.masterFingerprint).toSet().length,
          1,
        );
        final secrets = locator<Secrets>();
        final secret = custodyValue(
          await secrets.fetch(Fingerprint(created.first.masterFingerprint)),
        );
        expect(secret.info.hasPassphrase, isTrue);
        expect(custodyValue(await secret.verify.passphrase(phrase)), isTrue);

        backupBloc = TestWalletBackupBloc(
          completeBackupVerificationUsecase:
              locator<CompleteBackupVerificationUsecase>(),
          loadWalletsForNetworkUsecase: locator<LoadWalletsForNetworkUsecase>(),
          getSecretFromFingerprintUsecase:
              locator<GetSecretFromFingerprintUsecase>(),
          verifyBackupPassphraseUsecase:
              locator<VerifyBackupPassphraseUsecase>(),
        )..add(const LoadWallets());
        final selectedBloc = backupBloc;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider.value(
              value: selectedBloc,
              child: const VerifyMnemonicScreen(),
            ),
          ),
        );
        await _waitFor(
          tester,
          () => find.byType(MnemonicChallenge).evaluate().isNotEmpty,
        );
        // Challenge tiles are painted and deliberately unreadable to the
        // widget tree. Invoke the real widget's onSolved callback; this does
        // not test entering the words and must not certify that part of UX.
        tester
            .widget<MnemonicChallenge>(find.byType(MnemonicChallenge))
            .onSolved();
        await _waitFor(
          tester,
          () => find
              .text('Enter your passphrase to verify your backup.')
              .evaluate()
              .isNotEmpty,
        );
        final input = find.byType(TextField);
        await tester.enterText(input, 'wrong');
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await _waitFor(
          tester,
          () => find.text('Incorrect passphrase.').evaluate().isNotEmpty,
        );
        expect(find.byType(BackupTestSuccessScreen), findsNothing);
        await tester.enterText(input, phrase);
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await _waitFor(
          tester,
          () => find.byType(BackupTestSuccessScreen).evaluate().isNotEmpty,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        await onboarding.close();
        await backupBloc?.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

void registerReturnNavigationTest() {
  testWidgets('reauthentication Back only closes the Navigator gate', (
    tester,
  ) async {
    final bloc = TestWalletBackupBloc(
      completeBackupVerificationUsecase:
          locator<CompleteBackupVerificationUsecase>(),
      loadWalletsForNetworkUsecase: locator<LoadWalletsForNetworkUsecase>(),
      getSecretFromFingerprintUsecase:
          locator<GetSecretFromFingerprintUsecase>(),
    )..add(const LoadWallets());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider.value(
            value: bloc,
            child: const ShowMnemonicScreen(
              appUnlockFacade: _DeviceCancelUnlock(),
            ),
          ),
        ),
      ],
    );
    try {
      await tester.pumpWidget(
        MaterialApp.router(
          locale: const Locale('en'),
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await _waitFor(
        tester,
        () => find.text('Show passphrase').evaluate().isNotEmpty,
      );
      await tester.ensureVisible(find.text('Show passphrase'));
      await tester.tap(find.text('Show passphrase'));
      await tester.pumpAndSettle();
      expect(find.byType(PinCodeUnlockInputScreen), findsOneWidget);
      // Invoke the actual top bar callback, which calls context.pop().
      tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack?.call();
      await tester.pumpAndSettle();
      expect(find.byType(PinCodeUnlockInputScreen), findsNothing);
      expect(find.byType(ShowMnemonicScreen), findsOneWidget);
      expect(
        tester.widget<MnemonicView>(find.byType(MnemonicView)).showPassphrase,
        isFalse,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await bloc.close();
    }
  });
}
