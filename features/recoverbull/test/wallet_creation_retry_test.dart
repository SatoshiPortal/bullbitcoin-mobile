import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
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
    return Ok(context);
  }
}

final class _Vaults extends Fake implements VaultRepository {}
