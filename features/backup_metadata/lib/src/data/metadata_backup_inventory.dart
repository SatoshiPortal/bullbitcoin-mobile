import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart' as secrets;
import 'package:secrets/secrets.dart' show SecretFailure;

import '../domain/backup_metadata_failure.dart';
import '../domain/entities/backup_content.dart';
import '../domain/entities/backup_inventory.dart';
import '../domain/ports/backup_inventory_port.dart';
import '../domain/ports/backup_secrets_port.dart';
import 'backup_metadata_store.dart';

final class MetadataBackupInventory implements BackupInventoryPort {
  final Future<Result<List<secrets.MetadataBackupWallet>, SecretFailure>>
  Function()
  _wallets;

  /// The encrypted journal that keeps each group's installation-stable id,
  /// per view.
  final BackupMetadataStore _store;
  final BackupSecretsPort _secrets;
  final Future<bool> Function() _hasSilentPaymentsWallet;
  final String _defaultBitcoinWalletLabel;
  final String _unnamedWalletLabel;
  final Future<bool> Function(Fingerprint, BitcoinNetwork) _backupVerified;

  MetadataBackupInventory({
    required this._wallets,
    required this._store,
    required this._secrets,
    required this._hasSilentPaymentsWallet,
    required this._defaultBitcoinWalletLabel,
    required this._unnamedWalletLabel,
    required this._backupVerified,
  });

  @override
  Future<Result<BackupInventory, BackupMetadataFailure>> read() async {
    try {
      final unsupported = <UnsupportedWallet>[];
      final scope = await _secrets.viewScope();
      if (scope is! Ok<String, BackupMetadataFailure>) {
        return const Err(BackupMetadataNotReadyFailure());
      }
      final view = scope.value;
      final result = await _wallets();
      if (result is! Ok<List<secrets.MetadataBackupWallet>, SecretFailure>) {
        return const Err(BackupMetadataUnexpectedFailure());
      }
      final groups =
          <(Fingerprint, NetworkEnv), List<secrets.MetadataBackupWallet>>{};
      final watchOnly = <secrets.MetadataBackupWallet>[];
      final shared = _shared(result.value);
      bool ambiguous(Iterable<secrets.MetadataBackupWallet> wallets) => wallets
          .expand((wallet) => wallet.bitcoinPublicDescriptors)
          .any((descriptor) => shared.contains(_canonical(descriptor)));
      for (final wallet in result.value) {
        final network = wallet.network;
        final reference = wallet.secret;
        if (wallet.isWatchOnly &&
            network is BitcoinNetwork &&
            wallet.bitcoinPublicDescriptors.isNotEmpty) {
          watchOnly.add(wallet);
        } else if (network == null || reference == null) {
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
        final groupId = await _store.groupId(
          view,
          reference.hex,
          environment.name,
        );
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
            wallets: [for (final wallet in bitcoin) _account(wallet)],
            secretReference: reference.hex,
            ambiguous: ambiguous(bitcoin),
          ),
        );
      }
      for (final wallet in watchOnly) {
        final network = wallet.network;
        if (network is! BitcoinNetwork) continue;
        final label = wallet.label;
        final groupId = await _store.groupId(
          view,
          'watch:${wallet.id}',
          network.env.name,
        );
        if (groupId == null) return const Err(BackupMetadataNotReadyFailure());
        inventory.add(
          BackupGroup(
            id: groupId,
            displayName: label == null || label.trim().isEmpty
                ? _unnamedWalletLabel
                : label,
            network: network,
            bitcoinWalletIds: [wallet.id],
            liquidWalletIds: const [],
            bitcoinPublicDescriptors: wallet.bitcoinPublicDescriptors,
            // A watch-only wallet has no seed to back up (D95): it is never
            // reported as a verified seed backup.
            seedBackupVerified: false,
            wallets: [_account(wallet)],
            ambiguous: ambiguous([wallet]),
          ),
        );
      }
      return Ok(BackupInventory(groups: inventory, unsupported: unsupported));
    } on Exception {
      return const Err(BackupMetadataUnexpectedFailure());
    }
  }

  /// Descriptors that more than one wallet of the view carries. A group that
  /// owns one is still backed up, but a restore could not tell which wallet
  /// to change: it is neither offered nor applied.
  static Set<String> _shared(List<secrets.MetadataBackupWallet> wallets) {
    final owners = <String, Set<String>>{};
    for (final wallet in wallets) {
      for (final descriptor in wallet.bitcoinPublicDescriptors) {
        (owners[_canonical(descriptor)] ??= {}).add(wallet.id);
      }
    }
    return {
      for (final entry in owners.entries)
        if (entry.value.length > 1) entry.key,
    };
  }

  static String _canonical(String descriptor) =>
      descriptor.trim().split('#').first;

  static BackupWallet _account(secrets.MetadataBackupWallet wallet) {
    final network = wallet.network as BitcoinNetwork;
    return BackupWallet(
      network: network,
      scriptType: wallet.scriptType ?? ScriptType.bip84,
      externalDescriptor: wallet.bitcoinPublicDescriptors.first,
      internalDescriptor: wallet.bitcoinPublicDescriptors.last,
      label: wallet.label,
      birthday: wallet.birthday,
      watchOnly: wallet.isWatchOnly,
    );
  }
}
