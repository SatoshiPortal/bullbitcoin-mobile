import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_vaults_section.dart';
import 'package:bull_logger/bull_logger.dart';

typedef ListBullVaultRecords =
    Future<Result<List<BullVaultRecord>, BullVaultFailure>> Function();
typedef EncodeBullVaultPackage = String Function(BullVaultRecoveryPackage);
typedef LookupWalletLabel = Future<String?> Function(String walletId);
typedef CurrentBitcoinNetwork = Future<Network> Function();
typedef WalletExists = Future<bool> Function(String walletId);
typedef RestoreBullVault =
    Future<Result<BullVaultRestoreResult, BullVaultFailure>> Function({
      required String source,
      required String label,
    });

/// The vaults section over the BullVault feature's public surface.
///
/// Reading takes every record as it is; recovery replays each package through
/// the feature's own atomic restore. Descriptor restoration does not establish
/// local ownership of any signing key.
final class BullVaultBackupImpl implements BullVaultBackupSection {
  static const fallbackLabel = 'BullVault';

  final ListBullVaultRecords _listRecords;
  final EncodeBullVaultPackage _encodePackage;
  final LookupWalletLabel _walletLabel;
  final CurrentBitcoinNetwork _currentNetwork;
  final WalletExists _walletExists;
  final RestoreBullVault _restore;
  final DateTime Function() _nowUtc;

  const BullVaultBackupImpl({
    required this._listRecords,
    required this._encodePackage,
    required this._walletLabel,
    required this._currentNetwork,
    required this._walletExists,
    required this._restore,
    this._nowUtc = _systemNowUtc,
  });

  @override
  Future<Result<List<WalletBackupVaultEntry>, WalletBackupFailure>>
  read() async {
    try {
      final List<BullVaultRecord> records;
      switch (await _listRecords()) {
        case Ok(:final value):
          records = value;
        case Err(:final failure):
          return Err(WalletBackupVaultsFailure(failure.runtimeType.toString()));
      }
      final entries = <WalletBackupVaultEntry>[];
      for (final record in records) {
        final policy = record.recoveryPackage.policy;
        entries.add(
          WalletBackupVaultEntry(
            walletRef: record.walletId,
            label: await _walletLabel(record.walletId),
            status: record.status.name,
            network: policy.network,
            lineageId: record.lineageId,
            vaultGeneration: record.vaultGeneration,
            recoveryPackage: _encodePackage(record.recoveryPackage),
          ),
        );
      }
      entries.sort(WalletBackupVaultEntry.compare);
      return Ok(List.unmodifiable(entries));
    } on Exception catch (error) {
      return Err(WalletBackupVaultsFailure(error.runtimeType.toString()));
    }
  }

  @override
  Future<Result<WalletVaultsRecoveryResult, WalletBackupFailure>> recover(
    List<WalletBackupVaultEntry> entries, {
    DateTime? deadline,
  }) async {
    final Network network;
    try {
      network = await _currentNetwork();
    } on Exception catch (error) {
      return Err(WalletBackupVaultsFailure(error.runtimeType.toString()));
    }
    var restored = 0;
    var skipped = 0;
    var failed = 0;
    final created = <WalletPreferences>[];
    final ordered = [...entries]..sort(WalletBackupVaultEntry.compare);
    for (var index = 0; index < ordered.length; index++) {
      final entry = ordered[index];
      if (entry.network != network) {
        skipped++;
        continue;
      }
      if (deadline != null && !_nowUtc().isBefore(deadline)) {
        failed += ordered.length - index;
        break;
      }
      try {
        final existed = await _walletExists(entry.walletRef);
        switch (await _restore(
          source: entry.recoveryPackage,
          label: entry.label ?? fallbackLabel,
        )) {
          case Ok(:final value):
            restored++;
            if (!existed) {
              created.add(
                WalletPreferences(
                  walletRef: value.wallet.id,
                  label: value.wallet.label,
                ),
              );
            }
          case Err(:final failure):
            failed++;
            log.warning(
              'BullVault recovery package was not restored',
              error: failure.runtimeType,
            );
        }
      } on Exception catch (error) {
        failed++;
        log.warning(
          'BullVault recovery package restore threw',
          error: error.runtimeType,
        );
      }
    }
    return Ok(
      WalletVaultsRecoveryResult(
        restoredCount: restored,
        skippedCount: skipped,
        failedCount: failed,
        createdWalletPreferences: created,
      ),
    );
  }
}

DateTime _systemNowUtc() => DateTime.now().toUtc();
