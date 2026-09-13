import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';

enum BullVaultKeyAccess { available, passphraseRequired, external, unavailable }

final class BullVaultInspection {
  final BullVaultRecord record;
  final Wallet wallet;
  final Map<String, BullVaultKeyAccess> keyAccess;

  BullVaultInspection(
    this.record,
    this.wallet,
    Map<String, BullVaultKeyAccess> keyAccess,
  ) : keyAccess = Map.unmodifiable(keyAccess);
}

/// Inspection does not synchronize balances or restore/change signing material.
final class InspectBullVaultUsecase {
  final BullVaultRepository _vaults;
  final GetWalletUsecase _wallets;
  final GetSettingsUsecase _settings;
  final SeedVerificationPort _seeds;

  const InspectBullVaultUsecase(
    this._vaults,
    this._wallets,
    this._settings,
    this._seeds,
  );

  Future<Result<List<BullVaultRecord>, BullVaultFailure>> list() async {
    try {
      final settings = await _settings.execute();
      final result = await _vaults.getAll();
      return result.map((records) {
        final visible =
            records
                .where(
                  (record) =>
                      record.recoveryPackage.policy.network.isTestnet ==
                          settings.environment.isTestnet &&
                      record.status != BullVaultLifecycleStatus.cancelled,
                )
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return List.unmodifiable(visible);
      });
    } on Exception {
      return const Err(BullVaultBackupStatusFailure());
    }
  }

  Future<Result<BullVaultInspection, BullVaultFailure>> execute(
    String walletId,
  ) async {
    try {
      final result = await _vaults.getByWalletId(walletId);
      if (result case Err(:final failure)) return Err(failure);
      final record = (result as Ok<BullVaultRecord?, BullVaultFailure>).value;
      final wallet = await _wallets.execute(walletId);
      if (record == null || wallet == null) {
        return const Err(BullVaultInvalidRecoveryFailure());
      }
      final access = <String, BullVaultKeyAccess>{};
      for (final signer in wallet.signers) {
        for (final key in signer.descriptorKeys) {
          final fingerprint = signer.localSeedFingerprint;
          if (signer.signer != SignerEntity.local || fingerprint == null) {
            access[key.id] = BullVaultKeyAccess.external;
          } else if (key.requiresPassphrase) {
            // A persisted ownership claim cannot prove a passphrase is loaded.
            access[key.id] = BullVaultKeyAccess.passphraseRequired;
          } else if (key.derivationPath case final path? when path.isNotEmpty) {
            try {
              final matches = await _seeds.matchesXpubs(
                fingerprint: fingerprint,
                keys: [(derivationPath: path, xpub: key.xpub)],
              );
              access[key.id] = matches
                  ? BullVaultKeyAccess.available
                  : BullVaultKeyAccess.unavailable;
            } on Exception {
              // Missing private storage must not hide the public policy or kits.
              access[key.id] = BullVaultKeyAccess.unavailable;
            }
          } else {
            access[key.id] = BullVaultKeyAccess.unavailable;
          }
        }
      }
      return Ok(BullVaultInspection(record, wallet, access));
    } on Exception {
      return const Err(BullVaultBackupStatusFailure());
    }
  }
}
