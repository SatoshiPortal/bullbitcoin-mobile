import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/mount_passphrase_candidate.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:primitives/primitives.dart' show Err, Result;

/// Loads a passphrase wallet the app already has a manifest record for
/// (spec 20.4).
///
/// It writes no manifest record and shows no creation disclaimer: nothing about
/// the user's keys is new. The match must be exact on both the wallet id and
/// the combined descriptor, so a preparation that only looks familiar is a
/// conflict rather than an unlock.
final class UnlockKnownPassphraseWalletUsecase {
  final WalletFacade _wallets;

  const UnlockKnownPassphraseWalletUsecase(this._wallets);

  Future<Result<void, PassphraseWalletFailure>> execute(
    PassphraseWalletPreparation preparation, {
    required int mountGeneration,
  }) async {
    final known = preparation.knownWallet;
    final record = preparation.candidate.record;
    if (known == null ||
        known.walletId != record.walletId ||
        known.descriptor != record.descriptor) {
      preparation.clear();
      return const Err(PassphraseWalletConflictFailure());
    }
    return mountPassphraseCandidate(
      wallets: _wallets,
      candidate: preparation.candidate,
      mountGeneration: mountGeneration,
      label: known.label,
    );
  }
}
