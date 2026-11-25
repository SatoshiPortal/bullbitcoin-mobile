import 'package:preferences/preferences.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../entities/backup_status.dart';
import '../entities/vault_context.dart';
import '../recoverbull_failure.dart';
import '../wallet_backup_usage.dart';

final class BackupWarningNeededUsecase {
  final WalletInventory inventory;
  final ActiveEnvironmentReader environment;
  final bool certificateRegtest;
  final Future<Result<WalletBackupUsage?, RecoverBullFailure>> Function(
    String, {
    required bool regtest,
  })
  readBackup;
  final Future<Result<BackupStatus, RecoverBullFailure>> Function(VaultContext)
  status;

  const BackupWarningNeededUsecase({
    required this.inventory,
    required this.environment,
    required this.certificateRegtest,
    required this.readBackup,
    required this.status,
  });

  @useResult
  Future<Result<bool, RecoverBullFailure>> execute() async {
    try {
      final selected = await environment.readActiveEnvironment();
      if (selected case Err()) return const Err(VaultStorageFailure());
      final env = (selected as Ok<Environment, PreferencesFailure>).value;
      final (bitcoin, liquid) = switch (env) {
        Environment.mainnet => (BitcoinNetwork.mainnet, LiquidNetwork.mainnet),
        Environment.testnet => (BitcoinNetwork.testnet, LiquidNetwork.testnet),
        Environment.regtest => (BitcoinNetwork.regtest, LiquidNetwork.regtest),
      };
      final defaults = <WalletRegistration>[];
      for (final network in <Network>[bitcoin, liquid]) {
        final result = await inventory.walletsForNetwork(network);
        if (result case Err()) return const Err(VaultStorageFailure());
        final selection = (result as Ok<WalletSelection, SecretFailure>).value;
        if (!selection.isComplete) return const Err(VaultStorageFailure());
        defaults.addAll(selection.defaults);
      }
      var allVerified = true;
      for (final wallet in defaults) {
        final result = await readBackup(
          wallet.id,
          regtest: env == Environment.regtest,
        );
        if (result case Err(:final failure)) return Err(failure);
        if ((result as Ok<WalletBackupUsage?, RecoverBullFailure>)
                .value
                ?.physicalBackupTested !=
            true) {
          allVerified = false;
        }
      }
      if (allVerified) return const Ok(false);
      final bitcoinWallet = defaults
          .where((wallet) => wallet.network is BitcoinNetwork)
          .firstOrNull;
      if (bitcoinWallet == null) return const Ok(true);
      final fingerprint = bitcoinWallet.masterFingerprint;
      if (fingerprint == null) return const Err(VaultStorageFailure());
      if ((env == Environment.regtest) != certificateRegtest) {
        return const Err(VaultStorageFailure());
      }
      try {
        final certificate = await status(
          VaultContext(fingerprint: fingerprint, network: bitcoin),
        );
        return Ok(switch (certificate) {
          Ok(:final value) => !value.isVerified,
          Err() => true,
        });
      } on Exception {
        return const Ok(true);
      }
    } on Exception {
      return const Err(VaultStorageFailure());
    }
  }
}
