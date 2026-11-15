import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as app;
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// The secret a Silent Payments account is opened from: the one behind the
/// default Bitcoin wallet of the account's own network.
///
/// A handle, never the words: `Secret.silentPaymentsAccount` hands the BIP39 seed to bwk
/// inside the package. Every failure carries fixed text, since this is the
/// seed path.
class GetSpSecretUsecase {
  final WalletRepository _walletRepository;
  final Secrets _secrets;

  GetSpSecretUsecase({required this._walletRepository, required this._secrets});

  @useResult
  Future<Result<Secret, SpFailure>> execute(BitcoinNetwork network) async {
    final walletNetwork = switch (network) {
      BitcoinNetwork.mainnet => app.Network.bitcoinMainnet,
      BitcoinNetwork.testnet => app.Network.bitcoinTestnet,
      BitcoinNetwork.signet || BitcoinNetwork.regtest => null,
    };
    if (walletNetwork == null ||
        !NetworkCapabilities.supports(
          network,
          NetworkCapability.silentPayments,
        )) {
      return const Err(SpUnsupportedNetwork());
    }
    final List<app.Wallet> wallets;
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
    final wallet = wallets.where((w) => w.network == walletNetwork).firstOrNull;
    if (wallet == null) {
      return const Err(SpUnexpected('SP secret lookup failed'));
    }

    switch (await _secrets.fetch(Fingerprint(wallet.masterFingerprint))) {
      case Ok(:final value):
        return Ok(value);
      case Err():
        return const Err(SpUnexpected('SP secret lookup failed'));
    }
  }
}
