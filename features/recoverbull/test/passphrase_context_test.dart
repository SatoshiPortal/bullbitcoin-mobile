import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/domain/repositories/attempt_monitoring_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/backup_metadata_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final server = Uri.parse('http://backup.onion');
  final captured = BackupSettings(
    server: server,
    permissionGranted: true,
    monitoringEnabled: false,
    generation: 3,
  );
  final vault = EncryptedVault(
    id: '11' * 32,
    salt: '22' * 16,
    ciphertext: List.filled(64, 0),
    createdAt: DateTime.utc(2026),
  );
  final key = VaultKey('33' * 32);

  final changed = <String, BackupSettings>{
    'permission revoked': BackupSettings(
      server: server,
      permissionGranted: false,
      monitoringEnabled: false,
      generation: 3,
    ),
    'server changed': BackupSettings(
      server: Uri.parse('http://other.onion'),
      permissionGranted: true,
      monitoringEnabled: false,
      generation: 3,
    ),
    'generation changed': BackupSettings(
      server: server,
      permissionGranted: true,
      monitoringEnabled: false,
      generation: 4,
    ),
  };
  for (final entry in changed.entries) {
    test('${entry.key} refuses before import', () async {
      final vaults = _Vaults();
      final wallets = _Wallets();
      final complete = CompleteVaultUsecase(
        TestVaultUsecase(vaults, wallets),
        RestoreVaultUsecase(vaults, wallets),
        _Metadata(entry.value),
        _Monitoring(),
      );
      final result = await complete.execute(
        vault: vault,
        key: key,
        recoveryNetwork: BitcoinNetwork.testnet,
        cancelled: () => false,
        capturedSettings: captured,
        passphrase: 'synthetic phrase',
      );
      expect(result, isA<Err<VaultCompletion, RecoverBullFailure>>());
      expect(
        (result as Err<VaultCompletion, RecoverBullFailure>).failure,
        isA<VaultContextChangedFailure>(),
      );
      expect(vaults.restores, 0);
      expect(wallets.restores, 0);
    });
  }

  test('unchanged captured settings permit recovery', () async {
    final vaults = _Vaults();
    final wallets = _Wallets();
    final complete = CompleteVaultUsecase(
      TestVaultUsecase(vaults, wallets),
      RestoreVaultUsecase(vaults, wallets),
      _Metadata(captured),
      _Monitoring(),
    );
    final result = await complete.execute(
      vault: vault,
      key: key,
      recoveryNetwork: BitcoinNetwork.testnet,
      cancelled: () => false,
      capturedSettings: captured,
      passphrase: 'synthetic phrase',
    );
    expect(result, isA<Ok<VaultCompletion, RecoverBullFailure>>());
    expect(vaults.restores, 1);
    expect(wallets.restores, 1);
  });
}

final class _Vaults extends Fake implements VaultRepository {
  int restores = 0;

  @override
  Future<Result<Fingerprint, RecoverBullFailure>> restore(
    EncryptedVault vault,
    VaultKey key, {
    String passphrase = '',
    bool allowUnverified = false,
  }) async {
    restores++;
    return Ok(Fingerprint('73c5da0a'));
  }

  @override
  Future<Result<VaultBackup, RecoverBullFailure>> create(
    VaultContext context,
  ) => throw UnimplementedError();
}

final class _Wallets extends Fake implements RecoverBullWalletPort {
  int restores = 0;
  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) async {
    restores++;
    return Ok(requested);
  }
}

final class _Metadata extends Fake implements BackupMetadataRepository {
  final BackupSettings current;
  _Metadata(this.current);
  @override
  Future<Result<BackupSettings, RecoverBullFailure>> settings() async =>
      Ok(current);
  @override
  Future<Result<void, RecoverBullFailure>> markVerified(
    VaultContext context,
    EncryptedVault vault,
  ) async => const Ok(null);
}

final class _Monitoring extends Fake implements AttemptMonitoringRepository {
  @override
  Future<Result<void, RecoverBullFailure>> register(
    BackupSettings settings,
    EncryptedVault vault,
  ) async => const Ok(null);
}
