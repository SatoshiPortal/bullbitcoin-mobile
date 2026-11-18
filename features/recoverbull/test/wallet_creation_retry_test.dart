import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/backup_metadata_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/attempt_monitoring_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final secret = Fingerprint('73c5da0a');
  final vault = EncryptedVault(
    id: '11' * 32,
    salt: '22' * 16,
    ciphertext: List.filled(64, 0),
    createdAt: DateTime.utc(2026),
  );

  for (final unverified in [false, true]) {
    for (final metadataFails in [false, true]) {
      test(
        'retry accounts for verified identity: sibling=$unverified, metadataFailure=$metadataFails',
        () async {
          final vaults = _ImportedVaults();
          final wallets = _Wallets()..failures = 2;
          final metadata = _Metadata()..fails = metadataFails;
          final complete = CompleteVaultUsecase(
            TestVaultUsecase(vaults, wallets),
            RestoreVaultUsecase(vaults, wallets),
            metadata,
            _Monitoring(),
          );
          final result = await complete.execute(
            vault: vault,
            key: VaultKey('33' * 32),
            recoveryNetwork: BitcoinNetwork.testnet,
            cancelled: () => false,
            passphrase: unverified ? '' : 'correct',
            allowUnverified: unverified,
          );
          final initial =
              (result as Ok<VaultCompletion, RecoverBullFailure>).value;
          expect(initial.recovery, isA<VaultRecoveryNeedsWallets>());
          expect(initial.verifiedContext, isNull);
          expect(metadata.writes, isEmpty);
          final stillMissing = await complete.retryWallets(initial);
          expect(stillMissing.recovery, isA<VaultRecoveryNeedsWallets>());
          expect(metadata.writes, isEmpty);
          final completed = await complete.retryWallets(stillMissing);
          final recovery = completed.recovery;
          expect(recovery, isA<VaultRecovered>());
          if (recovery is! VaultRecovered) return;
          expect(vaults.imports, 1);
          expect(vaults.unverified, unverified);
          expect(wallets.requested, hasLength(3));
          if (unverified) {
            expect(metadata.writes, isEmpty);
            expect(completed.verifiedContext, isNull);
            expect(completed.warning, isNull);
          } else {
            expect(metadata.writes, hasLength(1));
            expect(identical(metadata.writes.single, recovery.context), isTrue);
            expect(metadata.vaults, [vault]);
            expect(completed.verifiedContext, same(recovery.context));
            expect(recovery.context.hasPassphrase, isTrue);
            expect(recovery.context.network, BitcoinNetwork.testnet);
            expect(recovery.context.fingerprint.hex, secret.hex);
            if (metadataFails) {
              expect(completed.warning, isA<RecoverBullStorageFullFailure>());
            } else {
              expect(completed.warning, isNull);
            }
          }
          expect(await complete.retryWallets(completed), same(completed));
          expect(metadata.writes.length, unverified ? 0 : 1);
        },
      );
    }
  }

  test('retry without metadata preserves import success and warning', () async {
    final vaults = _ImportedVaults();
    final wallets = _Wallets()..failures = 1;
    final complete = CompleteVaultUsecase(
      TestVaultUsecase(vaults, wallets),
      RestoreVaultUsecase(vaults, wallets),
      null,
      null,
    );
    final result = await complete.execute(
      vault: vault,
      key: VaultKey('33' * 32),
      recoveryNetwork: BitcoinNetwork.testnet,
      cancelled: () => false,
      passphrase: 'correct',
    );
    final initial = (result as Ok<VaultCompletion, RecoverBullFailure>).value;
    final completed = await complete.retryWallets(initial);
    expect(completed.recovery, isA<VaultRecovered>());
    expect(completed.verifiedContext?.fingerprint.hex, secret.hex);
    expect(completed.warning, isA<RecoverBullJournalFailure>());
    expect(vaults.imports, 1);
  });

  test(
    'a legacy completion without identity evidence never certifies',
    () async {
      final wallets = _Wallets();
      final metadata = _Metadata();
      final complete = CompleteVaultUsecase(
        TestVaultUsecase(_Vaults(), wallets),
        RestoreVaultUsecase(_Vaults(), wallets),
        metadata,
        _Monitoring(),
      );
      final completed = await complete.retryWallets(
        VaultCompletion(
          vault: vault,
          recovery: VaultRecoveryNeedsWallets(
            secret,
            const VaultStorageFailure(),
            network: BitcoinNetwork.testnet,
          ),
        ),
      );
      expect(completed.recovery, isA<VaultRecovered>());
      expect(completed.verifiedContext, isNull);
      expect(metadata.writes, isEmpty);
    },
  );

  test('a retry creates the wallets an import left missing', () async {
    final wallets = _Wallets()..failures = 1;
    final complete = CompleteVaultUsecase(
      TestVaultUsecase(_Vaults(), wallets),
      RestoreVaultUsecase(_Vaults(), wallets),
      null,
      null,
    );
    final incomplete = VaultCompletion(
      vault: vault,
      recovery: VaultRecoveryNeedsWallets(
        secret,
        const VaultStorageFailure(),
        network: BitcoinNetwork.testnet,
      ),
    );

    final stillMissing = await complete.retryWallets(incomplete);
    expect(stillMissing.recovery, isA<VaultRecoveryNeedsWallets>());

    final recovered = await complete.retryWallets(stillMissing);
    expect(recovered.vault, vault);
    final recovery = recovered.recovery;
    expect(recovery, isA<VaultRecovered>());
    expect(wallets.requested.last.fingerprint.hex, secret.hex);
    expect(wallets.requested.last.network, BitcoinNetwork.testnet);
  });
}

final class _Wallets implements RecoverBullWalletPort {
  int failures = 0;
  final requested = <VaultContext>[];

  @override
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault() async =>
      const Ok(null);

  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext context,
  ) async {
    requested.add(context);
    if (failures > 0) {
      failures--;
      return const Err(VaultStorageFailure());
    }
    return Ok(
      VaultContext(
        fingerprint: context.fingerprint,
        network: context.network,
        hasPassphrase: true,
      ),
    );
  }
}

final class _Vaults extends Fake implements VaultRepository {}

final class _ImportedVaults extends Fake implements VaultRepository {
  int imports = 0;
  bool unverified = false;

  @override
  Future<Result<Fingerprint, RecoverBullFailure>> restore(
    EncryptedVault vault,
    VaultKey key, {
    String passphrase = '',
    bool allowUnverified = false,
  }) async {
    if (!allowUnverified && passphrase != 'correct') {
      return const Err(VaultPassphraseRequiredFailure());
    }
    imports++;
    unverified = allowUnverified;
    return Ok(Fingerprint('73c5da0a'));
  }
}

final class _Metadata extends Fake implements BackupMetadataRepository {
  bool fails = false;
  final writes = <VaultContext>[];
  final vaults = <EncryptedVault>[];

  @override
  Future<Result<BackupSettings, RecoverBullFailure>> settings() async => Ok(
    BackupSettings(
      server: Uri.parse('http://backup.onion'),
      permissionGranted: true,
      monitoringEnabled: true,
      generation: 0,
    ),
  );

  @override
  Future<Result<void, RecoverBullFailure>> markVerified(
    VaultContext context,
    EncryptedVault vault,
  ) async {
    writes.add(context);
    vaults.add(vault);
    return fails ? const Err(RecoverBullStorageFullFailure()) : const Ok(null);
  }
}

final class _Monitoring extends Fake implements AttemptMonitoringRepository {
  @override
  Future<Result<void, RecoverBullFailure>> register(
    BackupSettings settings,
    EncryptedVault vault,
  ) async => const Ok(null);
}
