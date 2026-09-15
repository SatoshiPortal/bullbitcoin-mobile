import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vault_from_bip138_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_backup_words_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_cosigner_key_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_words_recovery_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_cosigner_key_recovery_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/vault_recovery_screen.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:screen_privacy/screen_privacy.dart';

import '../../bullvault/bullvault_test_fixture.dart';

class _Vaults extends Mock implements BullVaultFacade {}

class _Metadata extends Mock implements WalletBackupFacade {}

class _Identity extends Mock implements NostrIdentityFacade {}

class _Files extends Mock implements WalletBackupFileRepository {}

final class _Parser extends Fake implements BitcoinDescriptorPort {
  @override
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) => parseTestBullVaultDescriptor(descriptor: descriptor, network: network);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const privacyChannel = MethodChannel(
    'com.flutterplaza.no_screenshot_methods',
  );
  final loc = AppLocalizationsEn();
  final record = testBullVaultCreateResult().record;
  final policy = record.recoveryPackage.policy;

  late _Vaults vaults;
  late _Metadata metadata;
  late _Identity identity;
  late VaultRecoveryCubit cubit;

  setUp(() {
    Device.screen = const Size(411, 890);
    ScreenCaptureProtection.instance.enabledByUser = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, (_) async => true);
    vaults = _Vaults();
    metadata = _Metadata();
    identity = _Identity();
    when(() => vaults.listRecords()).thenAnswer((_) async => const Ok([]));
    when(() => vaults.holdsSigningKey(any())).thenAnswer((_) async => false);
    when(
      () => identity.walletBackupPublicKey(),
    ).thenAnswer((_) async => Ok('a' * 64));
    when(
      () => vaults.restoreFromDescriptor(
        source: any(named: 'source'),
        label: any(named: 'label'),
      ),
    ).thenAnswer(
      (_) async => Ok(
        BullVaultRestoreResult(
          wallet: Wallet(
            origin: record.walletId,
            network: policy.network,
            signers: const [],
            scriptType: null,
            publicDescriptor: policy.descriptor,
            balanceSat: BigInt.zero,
            isHidden: true,
          ),
          record: record,
          mobileAccess: BullVaultMobileAccess.unavailable,
        ),
      ),
    );
    final artifact = RecoverVaultFromBip138FileUsecase(
      vaults,
      _Parser(),
      _Files(),
    );
    cubit = VaultRecoveryCubit(
      RecoverVaultsFromBackupWordsUsecase(metadata, vaults, identity, artifact),
      RecoverVaultsFromCosignerKeyUsecase(metadata, artifact),
      artifact,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, null);
  });

  // A tall surface so the landing's four entries are all built: a ListView
  // only builds what fits, and an entry off the bottom is not a missing one.
  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: BlocProvider.value(value: cubit, child: screen),
      ),
    );
  }

  void noVaultsFound() {
    when(
      () => metadata.fetchRemoteContents(),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => metadata.fetchVaultsWithBackupWords(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer(
      (_) async =>
          const Ok((descriptors: <NostrDescriptorRecord>[], incomplete: false)),
    );
  }

  testWidgets('the landing keeps every manual entry without a seed', (
    tester,
  ) async {
    when(
      () => identity.walletBackupPublicKey(),
    ).thenAnswer((_) async => const Err(NostrIdentityUnavailableFailure()));

    await open(tester, const VaultRecoveryScreen());
    await cubit.discover();
    await tester.pumpAndSettle();

    expect(find.text(loc.vaultRecoveryNoCredential), findsOneWidget);
    expect(find.text(loc.vaultRecoveryImportDescriptor), findsOneWidget);
    expect(find.text(loc.vaultRecoveryImportCosignerKey), findsOneWidget);
    expect(find.text(loc.vaultRecoveryImportBackupWords), findsOneWidget);
    expect(find.text(loc.vaultRecoveryImportMobileKey), findsOneWidget);
  });

  testWidgets('the landing shows bitcoin as coming soon, never pending', (
    tester,
  ) async {
    noVaultsFound();

    await open(tester, const VaultRecoveryScreen());
    await cubit.discover();
    await tester.pumpAndSettle();

    expect(find.text(loc.backupSettingsComingSoon), findsOneWidget);
    expect(find.text(loc.vaultRecoveryNone), findsNWidgets(2));
  });

  testWidgets('one vault found twice is one card, named by its keys', (
    tester,
  ) async {
    final restored = Ok<BullVaultRestoreResult, BullVaultFailure>(
      BullVaultRestoreResult(
        wallet: Wallet(
          origin: record.walletId,
          network: policy.network,
          signers: const [],
          scriptType: null,
          publicDescriptor: policy.descriptor,
          balanceSat: BigInt.zero,
          isHidden: true,
        ),
        record: record,
        mobileAccess: BullVaultMobileAccess.unavailable,
      ),
    );
    when(
      () => vaults.restoreFromRecoveryPackage(
        source: any(named: 'source'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => restored);
    when(() => metadata.fetchRemoteContents()).thenAnswer(
      (_) async => Ok(
        WalletBackupContents(
          vaults: [
            WalletBackupVaultSummary(
              walletRef: record.walletId,
              status: 'active',
              network: policy.network,
              lineageId: policy.lineageId,
              vaultGeneration: 0,
              descriptor: policy.descriptor,
              birthHeight: null,
              recoveryPackage: '{}',
            ),
          ],
          labelCount: 0,
          frozenCoinCount: 0,
          walletPreferenceCount: 0,
        ),
      ),
    );
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer(
      (_) async => Ok((
        descriptors: [
          NostrDescriptorRecord(
            descriptor: policy.descriptor,
            network: policy.network,
            createdAt: DateTime.utc(2027),
          ),
        ],
        incomplete: false,
      )),
    );
    when(
      () => vaults.holdsSigningKey(record.walletId),
    ).thenAnswer((_) async => true);

    await open(tester, const VaultRecoveryScreen());
    await cubit.discover();
    await tester.pumpAndSettle();

    // One card, not one per source: "Vault recovered" also labels the two
    // source rows above the cards, so the card is counted by its own action.
    expect(find.text(loc.vaultRecoveryOpenVault), findsOneWidget);
    expect(find.text(loc.vaultRecoveryAlreadyPresent), findsNothing);
    expect(find.text(loc.vaultRecoverySigningKeyOnThisDevice), findsOneWidget);
    expect(find.text(loc.vaultRecoveryAttachSigningKey), findsNothing);
  });

  testWidgets('a cosigner key recovers a vault and shows what it did', (
    tester,
  ) async {
    when(() => metadata.lookupPrivateDescriptors(any())).thenAnswer(
      (_) async =>
          Ok(PrivateDescriptorLookup(records: const [], incomplete: false)),
    );

    await open(tester, const VaultCosignerKeyRecoveryScreen());
    await tester.enterText(find.byType(TextField).first, 'xpubFixture');
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.vaultRecoverySearch));
    await tester.pumpAndSettle();

    expect(find.text(loc.vaultRecoveryNothingYet), findsOneWidget);
    verify(() => metadata.lookupPrivateDescriptors('xpubFixture')).called(1);
  });

  testWidgets('a cosigner key the server refuses reaches the user', (
    tester,
  ) async {
    when(() => metadata.lookupPrivateDescriptors(any())).thenAnswer(
      (_) async => const Err(WalletBackupInvalidAccountKeyFailure()),
    );

    await open(tester, const VaultCosignerKeyRecoveryScreen());
    await tester.enterText(find.byType(TextField).first, 'not a key');
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.vaultRecoverySearch));
    await tester.pumpAndSettle();

    expect(find.text(loc.vaultRecoveryInvalidAccountKey), findsOneWidget);
  });

  testWidgets('a chosen encrypted file asks for the cosigner key', (
    tester,
  ) async {
    await open(
      tester,
      VaultCosignerKeyRecoveryScreen(
        initialArtifact: Uint8List.fromList(const [1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(loc.vaultRecoveryEncryptedFileDetected), findsOneWidget);
    expect(find.text(loc.vaultRecoveryArtifactChosen), findsOneWidget);
    expect(find.text(loc.vaultRecoveryChooseArtifact), findsNothing);
  });

  testWidgets('twelve backup words search both sources', (tester) async {
    noVaultsFound();

    await open(tester, const VaultWordsRecoveryScreen.backupWords());
    await tester.pumpAndSettle();
    expect(find.text(loc.vaultRecoveryBackupWordsHelp), findsOneWidget);

    tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
      label: '',
      passphrase: '',
      words: List.filled(11, 'abandon') + ['about'],
      language: bip39.Language.english,
    ));
    await tester.pumpAndSettle();

    verify(() => metadata.fetchVaultsWithBackupWords(any())).called(1);
    verify(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).called(1);
    expect(find.text(loc.vaultRecoveryNone), findsNWidgets(2));
  });

  testWidgets('words the server refuses are reported on the entry screen', (
    tester,
  ) async {
    when(() => metadata.fetchVaultsWithBackupWords(any())).thenAnswer(
      (_) async => const Err(WalletBackupInvalidBackupWordsFailure()),
    );
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer((_) async => const Err(BullVaultBackupWordsFailure()));

    await open(tester, const VaultWordsRecoveryScreen.backupWords());
    await cubit.searchWithWords('not the words');
    await tester.pumpAndSettle();

    expect(find.text(loc.vaultRecoveryInvalidWords), findsOneWidget);
  });

  testWidgets('the mobile key entry warns before it takes a seed', (
    tester,
  ) async {
    noVaultsFound();

    await open(tester, const VaultWordsRecoveryScreen.mobileKey());
    await tester.pumpAndSettle();
    expect(find.text(loc.vaultRecoveryMobileKeyWarning), findsOneWidget);

    tester.widget<MnemonicWidget>(find.byType(MnemonicWidget)).onSubmit((
      label: '',
      passphrase: '',
      words: List.filled(11, 'abandon') + ['about'],
      language: bip39.Language.english,
    ));
    await tester.pumpAndSettle();

    verify(() => metadata.fetchVaultsWithBackupWords(any())).called(1);
    expect(find.text(loc.vaultRecoveryNone), findsNWidgets(2));
  });
}
