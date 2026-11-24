import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart' as secrets;
import 'package:secrets/secrets.dart' show SecretFailure;

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_inventory.dart';
import '../domain/ports/backup_inventory_port.dart';
import 'backup_metadata_store.dart';

final class MetadataBackupInventory implements BackupInventoryPort {
  final Future<Result<List<secrets.MetadataBackupWallet>, SecretFailure>>
  Function()
  _wallets;

  /// The owner database that keeps each group's installation-stable id.
  final BackupMetadataStore _store;
  final Future<bool> Function() _hasSilentPaymentsWallet;
  final String _defaultBitcoinWalletLabel;
  final String _unnamedWalletLabel;
  final Future<bool> Function(Fingerprint, BitcoinNetwork) _backupVerified;

  MetadataBackupInventory({
    required this._wallets,
    required String statePath,
    required this._hasSilentPaymentsWallet,
    required this._defaultBitcoinWalletLabel,
    required this._unnamedWalletLabel,
    required this._backupVerified,
  }) : _store = BackupMetadataStore(path: statePath);

  @override
  Future<Result<BackupInventory, BackupMetadataFailure>> read() async {
    try {
      final result = await _wallets();
      if (result is! Ok<List<secrets.MetadataBackupWallet>, SecretFailure>) {
        return const Err(BackupMetadataUnexpectedFailure());
      }
      final unsupported = <UnsupportedWallet>[];
      final groups =
          <(Fingerprint, NetworkEnv), List<secrets.MetadataBackupWallet>>{};
      for (final wallet in result.value) {
        final network = wallet.network;
        final reference = wallet.secret;
        if (network == null || reference == null) {
          unsupported.add(
            UnsupportedWallet(
              walletId: wallet.id,
              reason: UnsupportedReason.other,
            ),
          );
        } else {
          (groups[(reference, network.env)] ??= []).add(wallet);
        }
      }
      if (await _hasSilentPaymentsWallet()) {
        unsupported.add(
          const UnsupportedWallet(
            walletId: 'silent-payments',
            reason: UnsupportedReason.silentPayments,
          ),
        );
      }
      final inventory = <BackupGroup>[];
      for (final entry in groups.entries) {
        final bitcoin = entry.value
            .where(
              (wallet) =>
                  wallet.network is BitcoinNetwork &&
                  wallet.bitcoinPublicDescriptors.isNotEmpty,
            )
            .toList();
        final liquid = entry.value.where(
          (wallet) => wallet.network is LiquidNetwork,
        );
        final primary =
            bitcoin.where((wallet) => wallet.isDefault).firstOrNull ??
            bitcoin.firstOrNull;
        final network = primary?.network;
        if (primary == null || network is! BitcoinNetwork) {
          unsupported.addAll(
            liquid.map(
              (wallet) => UnsupportedWallet(
                walletId: wallet.id,
                reason: UnsupportedReason.noBitcoinAccount,
              ),
            ),
          );
          continue;
        }
        final (reference, environment) = entry.key;
        final label = primary.label;
        final groupId = await _store.groupId(reference.hex, environment.name);
        if (groupId == null) {
          // The foreground owner database has not been prepared yet; never
          // create a second, unowned file for the identity mapping.
          return const Err(BackupMetadataNotReadyFailure());
        }
        inventory.add(
          BackupGroup(
            id: groupId,
            displayName: primary.isDefault
                ? _defaultBitcoinWalletLabel
                : label == null || label.trim().isEmpty
                ? _unnamedWalletLabel
                : label,
            network: network,
            bitcoinWalletIds: [for (final wallet in bitcoin) wallet.id],
            liquidWalletIds: [for (final wallet in liquid) wallet.id],
            bitcoinPublicDescriptors: [
              for (final wallet in bitcoin) ...wallet.bitcoinPublicDescriptors,
            ],
            seedBackupVerified: await _backupVerified(reference, network),
          ),
        );
      }
      return Ok(BackupInventory(groups: inventory, unsupported: unsupported));
    } on Exception {
      return const Err(BackupMetadataUnexpectedFailure());
    }
  }
}
