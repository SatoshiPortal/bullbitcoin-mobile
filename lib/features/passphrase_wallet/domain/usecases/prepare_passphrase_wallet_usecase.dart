import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_deriver.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/get_passphrase_wallets_usecase.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;

/// Turns one entered passphrase into the wallet it opens, and decides whether
/// the app has seen that wallet before (spec 20.3).
///
/// The decision is exact combined-descriptor equality. A wallet id or a
/// four-byte fingerprint that matches while the descriptor does not is a
/// conflict, never a merge (spec 6.5).
final class PreparePassphraseWalletUsecase {
  final GetDefaultSeedUsecase _getDefaultSeed;
  final GetSettingsUsecase _getSettings;
  final GetPassphraseWalletsUsecase _getWallets;
  final PassphraseWalletDeriver _deriver;

  const PreparePassphraseWalletUsecase(
    this._getDefaultSeed,
    this._getSettings,
    this._getWallets,
    this._deriver,
  );

  Future<Result<PassphraseWalletPreparation, PassphraseWalletFailure>> execute(
    String passphrase,
  ) async {
    if (passphrase.isEmpty ||
        passphrase.codeUnits.any((value) => value < 0x20 || value > 0x7e)) {
      return const Err(InvalidPassphraseFailure());
    }

    final MnemonicSeed parentSeed;
    final Network network;
    try {
      final settings = await _getSettings.execute();
      final defaultSeed = await _getDefaultSeed.execute(
        environment: settings.environment,
      );
      switch (defaultSeed) {
        case Ok(:final value):
          if (value is! MnemonicSeed) {
            return const Err(PassphraseWalletSeedFailure());
          }
          parentSeed = value;
        case Err():
          return const Err(PassphraseWalletSeedFailure());
      }
      network = Network.fromEnvironment(
        isTestnet: settings.environment.isTestnet,
        isLiquid: false,
      );
    } on Exception {
      return const Err(PassphraseWalletSeedFailure());
    }

    final PassphraseWalletDerivation derivation;
    try {
      derivation = await _deriver.derive(
        parentSeed: parentSeed,
        passphrase: passphrase,
        network: network,
      );
    } on Exception {
      return const Err(PassphraseWalletDescriptorFailure());
    }

    // From here the candidate owns private material, so every exit clears it.
    final candidate = PassphraseWalletCandidate(
      record: PassphraseWalletRecord(
        walletId: derivation.walletId,
        parentFingerprint: Fingerprint(parentSeed.masterFingerprint),
        seedFingerprint: Fingerprint(derivation.seed.masterFingerprint),
        network: network,
        descriptor: derivation.combinedPublicDescriptor,
        createdAt: DateTime.now().toUtc(),
      ),
      seed: derivation.seed,
    );

    final walletsResult = await _getWallets.execute();
    final List<PassphraseWalletRecord> wallets;
    switch (walletsResult) {
      case Ok(value: final value):
        wallets = value;
      case Err(:final failure):
        candidate.clear();
        return Err(failure);
    }

    final sameId = wallets
        .where((wallet) => wallet.walletId == candidate.record.walletId)
        .firstOrNull;
    if (sameId != null && sameId.descriptor != candidate.record.descriptor) {
      candidate.clear();
      return const Err(PassphraseWalletConflictFailure());
    }
    final known = wallets
        .where(
          (wallet) =>
              wallet.network == candidate.record.network &&
              wallet.descriptor == candidate.record.descriptor,
        )
        .firstOrNull;
    if (known != null && known.walletId != candidate.record.walletId) {
      candidate.clear();
      return const Err(PassphraseWalletConflictFailure());
    }
    return Ok(
      PassphraseWalletPreparation(
        candidate: candidate,
        knownWallet: known,
        hasHistory: wallets.isNotEmpty,
      ),
    );
  }
}
