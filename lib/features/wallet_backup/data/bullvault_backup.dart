import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_vaults_section.dart';
import 'package:bull_logger/bull_logger.dart';

typedef ListBullVaultRecords =
    Future<Result<List<BullVaultRecord>, BullVaultFailure>> Function();
typedef EncodeBullVaultPackage = String Function(BullVaultRecoveryPackage);
typedef LookupBackedUpWallet = Future<Wallet?> Function(String walletId);

/// The two Keys-screen writes, as the wallet owner already exposes them.
typedef SetVaultSignerDevice =
    Future<void> Function({
      required String walletId,
      required String signerId,
      required SignerDeviceEntity? signerDevice,
    });
typedef SetVaultSignerRegistrationName =
    Future<void> Function({
      required String walletId,
      required String signerId,
      required String registrationName,
    });
typedef CurrentBitcoinNetwork = Future<Network> Function();
typedef WalletExists = Future<bool> Function(String walletId);
typedef RestoreBullVault =
    Future<Result<BullVaultRestoreResult, BullVaultFailure>> Function({
      required String source,
      required String label,
      required BullVaultLifecycleStatus status,
    });

/// The vaults section over the BullVault feature's public surface.
///
/// Reading takes every record as it is; recovery replays each package through
/// the feature's own atomic restore, under the lifecycle status the record was
/// backed up with, so a lineage keeps exactly the one vault it had in force.
/// Descriptor restoration does not establish local ownership of any signing
/// key.
final class BullVaultBackupImpl implements BullVaultBackupSection {
  static const fallbackLabel = 'BullVault';

  final ListBullVaultRecords _listRecords;
  final EncodeBullVaultPackage _encodePackage;
  final LookupBackedUpWallet _wallet;
  final CurrentBitcoinNetwork _currentNetwork;
  final WalletExists _walletExists;
  final RestoreBullVault _restore;
  final SetVaultSignerDevice _setSignerDevice;
  final SetVaultSignerRegistrationName _setSignerRegistrationName;
  final DateTime Function() _nowUtc;

  const BullVaultBackupImpl({
    required this._listRecords,
    required this._encodePackage,
    required this._wallet,
    required this._currentNetwork,
    required this._walletExists,
    required this._restore,
    required this._setSignerDevice,
    required this._setSignerRegistrationName,
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
        final wallet = await _wallet(record.walletId);
        entries.add(
          WalletBackupVaultEntry(
            walletRef: record.walletId,
            label: wallet?.label,
            status: record.status.name,
            network: policy.network,
            lineageId: record.lineageId,
            vaultGeneration: record.vaultGeneration,
            recoveryPackage: _encodePackage(record.recoveryPackage),
            signers: _annotationsOf(wallet),
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
      // A status this build cannot read was written by a newer version. It is
      // left alone rather than replayed as the vault in force.
      final status = BullVaultLifecycleStatus.values
          .where((value) => value.name == entry.status)
          .firstOrNull;
      if (status == null) {
        failed++;
        log.warning('BullVault recovery entry has an unreadable status');
        continue;
      }
      try {
        final existed = await _walletExists(entry.walletRef);
        switch (await _restore(
          source: entry.recoveryPackage,
          label: entry.label ?? fallbackLabel,
          status: status,
        )) {
          case Ok(:final value):
            restored++;
            await _restoreAnnotations(value.wallet, entry.signers);
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

  /// The Keys-screen facts a vault's wallet holds, one per annotated signer.
  ///
  /// A signer is named by its account key rather than by its id, because the
  /// wallet a recovery creates assigns ids of its own.
  List<WalletBackupVaultSigner> _annotationsOf(Wallet? wallet) => [
    for (final signer in wallet?.signers ?? const <WalletSigner>[])
      if (signer.signerDevice != null || signer.registrationName != null)
        if (signer.descriptorKeys.firstOrNull?.xpub case final xpub?)
          WalletBackupVaultSigner(
            accountXpub: xpub,
            signerDevice: signer.signerDevice,
            registrationName: signer.registrationName,
          ),
  ];

  /// Puts each backed-up annotation back on the signer that holds its account
  /// key.
  ///
  /// An annotation that will not apply is logged and left: the descriptor, the
  /// policy and the funds are recovered either way, and failing the whole
  /// vault over a device label would raise the publication fence for a hint.
  Future<void> _restoreAnnotations(
    Wallet wallet,
    List<WalletBackupVaultSigner> signers,
  ) async {
    for (final annotation in signers) {
      if (!annotation.isAnnotated) continue;
      final signer = wallet.signers
          .where(
            (candidate) => candidate.descriptorKeys.any(
              (key) => key.xpub == annotation.accountXpub,
            ),
          )
          .firstOrNull;
      if (signer == null) {
        log.warning('Backed-up vault signer is not in the restored wallet');
        continue;
      }
      try {
        if (annotation.signerDevice case final device?) {
          await _setSignerDevice(
            walletId: wallet.id,
            signerId: signer.id,
            signerDevice: device,
          );
        }
        if (annotation.registrationName case final name?) {
          await _setSignerRegistrationName(
            walletId: wallet.id,
            signerId: signer.id,
            registrationName: name,
          );
        }
      } on Exception catch (error) {
        log.warning(
          'Backed-up vault signer annotation was refused',
          error: error.runtimeType,
        );
      }
    }
  }
}

DateTime _systemNowUtc() => DateTime.now().toUtc();
