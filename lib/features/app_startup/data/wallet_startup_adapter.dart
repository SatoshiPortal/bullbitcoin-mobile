import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:meta/meta.dart';

final class WalletStartupAdapter implements AppStartupWalletPort {
  final WalletRepository _walletRepository;

  final Future<rb.Result<rb.BackupStatus, rb.RecoverBullFailure>> Function(
    rb.VaultContext,
  )
  _backupStatus;
  const WalletStartupAdapter(this._walletRepository, this._backupStatus);

  @override
  @useResult
  Future<Result<bool, AppStartupFailure>>
  hasMainnetBitcoinEncryptedBackup() async {
    return switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
      environment: Environment.mainnet,
    )) {
      Ok(:final value) =>
        value.isEmpty
            ? const Ok(false)
            : switch (await _backupStatus(
                rb.VaultContext(
                  fingerprint: rb.Fingerprint(value.first.masterFingerprint),
                  network: rb.BitcoinNetwork.mainnet,
                ),
              )) {
                rb.Ok(value: final status) => Ok(
                  status.storedAt != null ||
                      status.verifiedAt != null ||
                      value.first.latestEncryptedBackup != null,
                ),
                rb.Err() => Ok(value.first.latestEncryptedBackup != null),
              },
      // The wallet repository already logged the raw reason.
      Err(:final failure) => Err(
        AppStartupWalletCheckFailure(
          'encrypted backup check failed: ${failure.runtimeType}',
        ),
      ),
    };
  }
}
