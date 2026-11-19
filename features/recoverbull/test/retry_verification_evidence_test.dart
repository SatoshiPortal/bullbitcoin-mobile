import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/domain/repositories/backup_metadata_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fingerprint = Fingerprint('73c5da0a');
  final vault = EncryptedVault(
    id: '11' * 32,
    salt: '22' * 16,
    ciphertext: List.filled(64, 0),
    createdAt: DateTime.utc(2026),
  );
  for (final mismatch in ['fingerprint', 'network', 'none']) {
    test(
      'mismatched pending evidence cannot certify: kind=$mismatch',
      () async {
        final wallets = _Wallets();
        final metadata = _Metadata();
        final complete = CompleteVaultUsecase(
          TestVaultUsecase(_Vaults(), wallets),
          RestoreVaultUsecase(_Vaults(), wallets),
          metadata,
          null,
        );
        final completed = await complete.retryWallets(
          VaultCompletion(
            vault: vault,
            pendingVerificationContext: VaultContext(
              fingerprint: mismatch == 'fingerprint'
                  ? Fingerprint('12345678')
                  : fingerprint,
              network: mismatch == 'network'
                  ? BitcoinNetwork.mainnet
                  : BitcoinNetwork.testnet,
            ),
            recovery: VaultRecoveryNeedsWallets(
              fingerprint,
              const VaultStorageFailure(),
              network: BitcoinNetwork.testnet,
            ),
            warning: const RecoverBullJournalFailure(),
          ),
        );
        expect(completed.recovery, isA<VaultRecovered>());
        if (mismatch == 'none') {
          expect(completed.verifiedContext, isNotNull);
        } else {
          expect(completed.verifiedContext, isNull);
        }
        expect(completed.pendingVerificationContext, isNull);
        expect(completed.warning, isA<RecoverBullJournalFailure>());
        expect(metadata.writes, mismatch == 'none' ? 1 : 0);
        expect(await complete.retryWallets(completed), same(completed));
        expect(wallets.restores, 1);
      },
    );
  }
}

final class _Vaults extends Fake implements VaultRepository {}

final class _Wallets extends Fake implements RecoverBullWalletPort {
  int restores = 0;

  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext context,
  ) async {
    restores++;
    return Ok(context);
  }
}

final class _Metadata extends Fake implements BackupMetadataRepository {
  int writes = 0;

  @override
  Future<Result<void, RecoverBullFailure>> markVerified(
    VaultContext context,
    EncryptedVault vault,
  ) async {
    writes++;
    return const Err(RecoverBullStorageFullFailure());
  }
}
