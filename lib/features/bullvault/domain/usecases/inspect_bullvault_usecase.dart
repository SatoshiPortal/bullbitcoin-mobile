import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class InspectBullVaultUsecase {
  final BullVaultRepository _records;
  final GetWalletUsecase _getWallet;
  final SeedVerificationPort _seeds;
  const InspectBullVaultUsecase(this._records, this._getWallet, this._seeds);

  @useResult
  Future<Result<BullVaultInspection, BullVaultFailure>> execute(
    String walletId,
  ) async {
    try {
      final loaded = await _records.getByWalletId(walletId);
      switch (loaded) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: null):
          return const Err(BullVaultInvalidRecoveryFailure());
        case Ok(value: final record?):
          final wallet = await _getWallet.execute(walletId);
          if (wallet == null) {
            return const Err(BullVaultInvalidRecoveryFailure());
          }
          final access = <String, BullVaultKeyAccess>{};
          for (final signer in wallet.signers) {
            final fingerprint = signer.localSeedFingerprint;
            for (final key in signer.descriptorKeys) {
              if (signer.signer != SignerEntity.local || fingerprint == null) {
                access[key.id] = BullVaultKeyAccess.external;
              } else if (key.requiresPassphrase) {
                access[key.id] = BullVaultKeyAccess.passphraseRequired;
              } else {
                final path = key.derivationPath;
                var verified = false;
                if (path != null && path.isNotEmpty) {
                  try {
                    verified = await _seeds.matchesXpubs(
                      fingerprint: fingerprint,
                      keys: [(derivationPath: path, xpub: key.xpub)],
                    );
                  } on Exception {
                    // Private storage failure must not hide public inspection.
                    verified = false;
                  }
                }
                access[key.id] = verified
                    ? BullVaultKeyAccess.available
                    : BullVaultKeyAccess.unavailable;
              }
            }
          }
          return Ok(BullVaultInspection(record, wallet, access));
      }
    } on Exception {
      return const Err(BullVaultBackupStatusFailure());
    }
  }
}
