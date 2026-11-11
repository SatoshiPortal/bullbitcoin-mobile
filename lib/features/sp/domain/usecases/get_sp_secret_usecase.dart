import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// The secret a Silent Payments account is opened from: the one behind the
/// default Bitcoin wallet of the account's own network.
///
/// A handle, never the words: `Secret.silentPaymentsAccount` hands them to bwk
/// inside the package. Every failure carries fixed text, since this is the
/// seed path.
class GetSpSecretUsecase {
  final WalletRepository _walletRepository;
  final Secrets _secrets;

  GetSpSecretUsecase({required this._walletRepository, required this._secrets});

  @useResult
  Future<Result<Secret, SpFailure>> execute(BitcoinNetwork network) async {
    final List<Wallet> wallets;
    switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
    )) {
      case Ok(:final value):
        wallets = value;
      case Err():
        return const Err(SpUnexpected('SP secret lookup failed'));
    }

    // Mainnet and testnet defaults need not share a seed: the account must be
    // the one of the network it scans.
    final isMainnet = network == BitcoinNetwork.mainnet;
    final wallet = wallets
        .where((w) => w.network.isMainnet == isMainnet)
        .firstOrNull;
    if (wallet == null) {
      return const Err(SpUnexpected('SP secret lookup failed'));
    }

    switch (await _secrets.fetch(Fingerprint(wallet.masterFingerprint))) {
      case Ok(:final value):
        // bwk derives from the words alone: opening the account would give the
        // passphrase-less sibling's wallet, not this seed's.
        if (value.info.hasPassphrase) {
          return const Err(SpPassphraseUnsupported());
        }
        return Ok(value);
      case Err():
        return const Err(SpUnexpected('SP secret lookup failed'));
    }
  }
}
