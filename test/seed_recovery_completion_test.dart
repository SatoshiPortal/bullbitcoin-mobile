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
    final record = testBullVaultCreateResult().record;
    final policy = record.recoveryPackage.policy;

    setUp(() {
      vaults = _MockVaults();
      identity = _MockIdentity();
      when(() => vaults.listRecords()).thenAnswer((_) async => const Ok([]));
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
          defaultCreatedWalletPreferences: [bitcoin],
          discoverVaults: discover,
          vaults: vaults,
        ),
        isTrue,
      );

      verifyNever(() => vaults.recordVaultRecovered());
    });

    test(
      'an incomplete Data Backup recovery never reaches the relays',
      () async {
        when(
          () => backup.recover(defaultCreatedWalletPreferences: [bitcoin]),
        ).thenAnswer(
          (_) async => const WalletBackupRecoveryResult(
            status: WalletBackupRecoveryStatus.unavailable,
          ),
        );

        expect(
          await recoverWalletDataAfterSeedRestore(
            backup,
            defaultCreatedWalletPreferences: [bitcoin],
            discoverVaults: discover,
            vaults: vaults,
          ),
          isFalse,
        );

        verifyNever(
          () => vaults.discoverDescriptorsOnNostr(
            words: any(named: 'words'),
            session: any(named: 'session'),
          ),
        );
        verifyNever(() => vaults.recordVaultRecovered());
      },
    );

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
