import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vault_from_bip138_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_backup_words_usecase.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/seed_recovery_completion.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'features/bullvault/bullvault_test_fixture.dart';

class _MockWalletBackupFacade extends Mock implements WalletBackupFacade {}

class _MockVaults extends Mock implements BullVaultFacade {}

class _MockIdentity extends Mock implements NostrIdentityFacade {}

class _MockFiles extends Mock implements WalletBackupFileRepository {}

final class _Parser extends Fake implements BitcoinDescriptorPort {
  @override
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) => parseTestBullVaultDescriptor(descriptor: descriptor, network: network);
}

void main() {
  final bitcoin = WalletPreferences(
    walletRef: 'bitcoin',
    label: 'Initial Bitcoin',
  );
  final liquid = WalletPreferences(
    walletRef: 'liquid',
    label: 'Initial Liquid',
  );
  late _MockWalletBackupFacade backup;

  /// The Data Backup answer the first-run wizard recorded, as the recovery
  /// path reads it. `null` is a person who never answered.
  WizardFacade wizard(bool? consent) => WizardFacade(
    applyPendingChoices:
        ({
          List<WalletPreferences> defaultCreatedWalletPreferences = const [],
        }) async => const Ok(null),
    hasPendingChoices: () async => consent != null,
    pendingMetadataBackupEnabled: () async => consent,
  );

  setUp(() {
    backup = _MockWalletBackupFacade();
  });

  for (final status in [
    WalletBackupRecoveryStatus.noBackup,
    WalletBackupRecoveryStatus.restored,
  ]) {
    test('$status completes optional Data Backup recovery', () async {
      when(
        () =>
            backup.recover(defaultCreatedWalletPreferences: [bitcoin, liquid]),
      ).thenAnswer((_) async => WalletBackupRecoveryResult(status: status));

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin, liquid],
        ),
        isTrue,
      );
    });
  }

  test(
    'reports an incomplete optional recovery without failing money recovery',
    () async {
      when(
        () =>
            backup.recover(defaultCreatedWalletPreferences: [bitcoin, liquid]),
      ).thenAnswer(
        (_) async => const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.partiallyRestored,
          restoredCount: 2,
          failedCount: 1,
        ),
      );

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin, liquid],
        ),
        isFalse,
      );
    },
  );

  test(
    'an optional backup exception cannot invalidate seed recovery',
    () async {
      when(
        () =>
            backup.recover(defaultCreatedWalletPreferences: [bitcoin, liquid]),
      ).thenThrow(const FormatException('synthetic unreadable backup'));

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin, liquid],
        ),
        isFalse,
      );
    },
  );

  for (final status in WalletBackupRecoveryStatus.values.where(
    (status) =>
        status != WalletBackupRecoveryStatus.noBackup &&
        status != WalletBackupRecoveryStatus.restored,
  )) {
    test('$status is not reported as a complete metadata recovery', () async {
      when(
        () => backup.recover(defaultCreatedWalletPreferences: [bitcoin]),
      ).thenAnswer((_) async => WalletBackupRecoveryResult(status: status));
      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin],
        ),
        isFalse,
      );
    });
  }

  group('vault descriptor discovery after seed restoration', () {
    late _MockVaults vaults;
    late _MockIdentity identity;
    late RecoverVaultsFromBackupWordsUsecase discover;
    late List<BullVaultRecord> present;
    final record = testBullVaultCreateResult().record;
    final policy = record.recoveryPackage.policy;

    setUp(() {
      vaults = _MockVaults();
      identity = _MockIdentity();
      present = [];
      when(() => vaults.listRecords()).thenAnswer((_) async => Ok(present));
      when(() => vaults.holdsSigningKey(any())).thenAnswer((_) async => false);
      when(
        () => identity.walletBackupPublicKey(),
      ).thenAnswer((_) async => Ok('a' * 64));
      discover = RecoverVaultsFromBackupWordsUsecase(
        backup,
        vaults,
        identity,
        RecoverVaultFromBip138FileUsecase(vaults, _Parser(), _MockFiles()),
      );
    });

    void relaysHold(List<NostrDescriptorRecord> descriptors) {
      when(
        () => vaults.discoverDescriptorsOnNostr(
          words: any(named: 'words'),
          session: any(named: 'session'),
        ),
      ).thenAnswer(
        (_) async => Ok((descriptors: descriptors, incomplete: false)),
      );
    }

    void restores() {
      when(
        () => vaults.restoreFromDescriptor(
          source: any(named: 'source'),
          label: any(named: 'label'),
        ),
      ).thenAnswer((_) async {
        present = [...present, record];
        return Ok(
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
      });
    }

    /// A vault the metadata recovery persisted, which the relays do not also
    /// hand back.
    void metadataRestored() {
      when(
        () => backup.recover(defaultCreatedWalletPreferences: [bitcoin]),
      ).thenAnswer((_) async {
        present = [...present, record];
        return const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.restored,
        );
      });
    }

    test('a persisted vault is announced exactly once', () async {
      when(
        () => backup.recover(defaultCreatedWalletPreferences: [bitcoin]),
      ).thenAnswer(
        (_) async => const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.restored,
        ),
      );
      relaysHold([
        NostrDescriptorRecord(
          descriptor: policy.descriptor,
          network: policy.network,
          createdAt: DateTime.utc(2027),
        ),
      ]);
      restores();

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin],
          discoverVaults: discover,
          vaults: vaults,
        ),
        isTrue,
      );

      verify(() => vaults.recordVaultRecovered()).called(1);
    });

    test('a search that found nothing announces nothing', () async {
      when(
        () => backup.recover(defaultCreatedWalletPreferences: [bitcoin]),
      ).thenAnswer(
        (_) async => const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.noBackup,
        ),
      );
      relaysHold(const []);

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin],
          discoverVaults: discover,
          vaults: vaults,
        ),
        isTrue,
      );

      verifyNever(() => vaults.recordVaultRecovered());
    });

    test('a Data Backup outage is exactly when the relays are '
        'needed', () async {
      when(
        () => backup.recover(defaultCreatedWalletPreferences: [bitcoin]),
      ).thenAnswer(
        (_) async => const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.unavailable,
        ),
      );
      relaysHold([
        NostrDescriptorRecord(
          descriptor: policy.descriptor,
          network: policy.network,
          createdAt: DateTime.utc(2027),
        ),
      ]);
      restores();

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin],
          discoverVaults: discover,
          vaults: vaults,
        ),
        isFalse,
        reason: 'the metadata half really did not finish',
      );

      verify(
        () => vaults.discoverDescriptorsOnNostr(
          words: any(named: 'words'),
          session: any(named: 'session'),
        ),
      ).called(1);
      verify(() => vaults.recordVaultRecovered()).called(1);
    });

    test('a vault only the metadata backup held is announced too', () async {
      metadataRestored();
      relaysHold(const []);

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin],
          discoverVaults: discover,
          vaults: vaults,
        ),
        isTrue,
      );

      verify(() => vaults.recordVaultRecovered()).called(1);
    });

    test('nothing is searched or announced without the vault half', () async {
      when(
        () => backup.recover(defaultCreatedWalletPreferences: [bitcoin]),
      ).thenAnswer(
        (_) async => const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.restored,
        ),
      );

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin],
        ),
        isTrue,
      );

      verifyNever(
        () => vaults.discoverDescriptorsOnNostr(
          words: any(named: 'words'),
          session: any(named: 'session'),
        ),
      );
      verifyNever(() => vaults.recordVaultRecovered());
    });

    for (final consent in [false, null]) {
      test('a Data Backup choice of $consent asks nobody anything', () async {
        metadataRestored();
        relaysHold([
          NostrDescriptorRecord(
            descriptor: policy.descriptor,
            network: policy.network,
            createdAt: DateTime.utc(2027),
          ),
        ]);
        restores();

        expect(
          await recoverWalletDataAfterSeedRestore(
            backup,
            wizard: wizard(consent),
            defaultCreatedWalletPreferences: [bitcoin],
            discoverVaults: discover,
            vaults: vaults,
          ),
          isTrue,
          reason: 'nothing was asked for, so nothing is reported unfinished',
        );

        verifyZeroInteractions(backup);
        verifyZeroInteractions(identity);
        verifyZeroInteractions(vaults);
      });
    }

    test('a Data Backup choice of true runs both halves', () async {
      metadataRestored();
      relaysHold(const []);

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin],
          discoverVaults: discover,
          vaults: vaults,
        ),
        isTrue,
      );

      verify(
        () => backup.recover(defaultCreatedWalletPreferences: [bitcoin]),
      ).called(1);
      verify(
        () => vaults.discoverDescriptorsOnNostr(
          words: any(named: 'words'),
          session: any(named: 'session'),
        ),
      ).called(1);
    });

    test('a relay failure cannot invalidate seed recovery', () async {
      when(
        () => backup.recover(defaultCreatedWalletPreferences: [bitcoin]),
      ).thenAnswer(
        (_) async => const WalletBackupRecoveryResult(
          status: WalletBackupRecoveryStatus.restored,
        ),
      );
      when(
        () => vaults.discoverDescriptorsOnNostr(
          words: any(named: 'words'),
          session: any(named: 'session'),
        ),
      ).thenAnswer((_) async => const Err(BullVaultNostrUnreachableFailure()));

      expect(
        await recoverWalletDataAfterSeedRestore(
          backup,
          wizard: wizard(true),
          defaultCreatedWalletPreferences: [bitcoin],
          discoverVaults: discover,
          vaults: vaults,
        ),
        isTrue,
      );

      verifyNever(() => vaults.recordVaultRecovered());
    });
  });
}
