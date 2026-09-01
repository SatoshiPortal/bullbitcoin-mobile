import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_metadata_rules.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/mount_passphrase_candidate.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

/// Creates a passphrase wallet the app has never seen (spec 20.5).
///
/// The manifest record is written before the mount, so an interrupted creation
/// leaves a locked card the user can unlock again rather than a wallet with no
/// public record of how to recover it.
final class CreatePassphraseWalletUsecase {
  final KeychainManifestFacade _manifest;
  final WalletFacade _wallets;

  const CreatePassphraseWalletUsecase(this._manifest, this._wallets);

  Future<Result<PassphraseWalletOpenStatus, PassphraseWalletFailure>> execute(
    PassphraseWalletPreparation preparation, {
    required int mountGeneration,
    String? label,
    String? hint,
  }) async {
    if (preparation.isKnown) {
      preparation.clear();
      return const Err(PassphraseWalletConflictFailure());
    }
    final record = preparation.candidate.record;
    final walletLabel = PassphraseWalletMetadataRules.normalize(label);
    final walletHint = PassphraseWalletMetadataRules.normalize(hint);
    if (PassphraseWalletMetadataRules.rejectsLabel(walletLabel) ||
        PassphraseWalletMetadataRules.rejectsHint(walletHint)) {
      preparation.clear();
      return const Err(PassphraseWalletStorageFailure());
    }

    final saved = await _manifest.recordWallet(
      parentFingerprint: record.parentFingerprint,
      wallet: KeychainManifestWalletInventoryBinding(
        walletId: record.walletId,
        seedFingerprint: record.seedFingerprint,
        network: record.network,
        scriptType: ScriptType.bip84,
        provenance: WalletProvenance.defaultSeedPassphrase,
        derivationPath: "m/84'/${record.network.coinType}'/0'",
        seedPassphraseUsed: true,
        descriptor: record.descriptor,
        label: walletLabel,
        description: walletHint,
        createdAt: record.createdAt.millisecondsSinceEpoch ~/ 1000,
        updatedAt: record.createdAt.millisecondsSinceEpoch ~/ 1000,
      ),
    );
    if (saved case Err()) {
      preparation.clear();
      return const Err(PassphraseWalletManifestFailure());
    }

    return switch (await mountPassphraseCandidate(
      wallets: _wallets,
      candidate: preparation.candidate,
      mountGeneration: mountGeneration,
      label: walletLabel,
    )) {
      Ok() => const Ok(PassphraseWalletOpenStatus.opened),
      // The record is valid and stays: the user unlocks it from its locked card.
      Err() => const Ok(PassphraseWalletOpenStatus.savedButNotOpened),
    };
  }
}
