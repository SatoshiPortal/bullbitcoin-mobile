import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/coins/data/wallet_private_key_resolver.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:proof_of_funds/proof_of_funds.dart';

/// Builds a BIP-322 "Proof of Funds" signature proving control of the selected
/// [BitcoinWalletUtxo]s.
///
/// The first selected UTXO's address is used as the message challenge (input
/// 0); every selected UTXO is proven as an additional input. Per-UTXO private
/// keys are resolved on demand from the wallet (never cached).
class SignProofOfFundsUsecase {
  SignProofOfFundsUsecase({
    required this.walletRepository,
    this.proofOfFunds = const ProofOfFunds(),
  });

  final BitcoinWalletRepository walletRepository;
  final ProofOfFunds proofOfFunds;

  Future<String> execute({
    required String walletId,
    required Network network,
    required String message,
    required List<BitcoinWalletUtxo> utxos,
  }) async {
    if (utxos.isEmpty) {
      throw const CoinsError.proofFailed();
    }

    final resolver = WalletPrivateKeyResolver(
      walletRepository: walletRepository,
      walletId: walletId,
    );

    // The challenge address (input 0) is the first selected UTXO's address —
    // UTXO-first UX: the user picks coins, not a separate address.
    final challengeAddress = utxos.first.address;

    final proofInputs = [
      for (final u in utxos)
        ProofInput(
          outpoint: ProofOutpoint(txId: u.txId, vout: u.vout),
          amountSat: u.amountSat,
          scriptPubKey: u.scriptPubkey,
        ),
    ];

    try {
      return await proofOfFunds.prove(
        message: message,
        challengeAddress: challengeAddress,
        utxos: proofInputs,
        keys: resolver,
        network: network.isTestnet
            ? ProofNetwork.testnet
            : ProofNetwork.mainnet,
      );
    } on UnsupportedScriptError {
      throw const CoinsError.unsupportedScript();
    } on ProofError {
      throw const CoinsError.proofFailed();
    } catch (e) {
      throw CoinsError.unexpected(message: e.toString());
    }
  }
}
