import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/coins/data/electrum_chain_lookup.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:proof_of_funds/proof_of_funds.dart';

/// Verifies a BIP-322 "Proof of Funds" signature: runs the offline
/// cryptographic check, then confirms each proven UTXO against the live
/// Electrum UTXO set (exists, matches the claimed script/amount, unspent).
class VerifyProofOfFundsUsecase {
  VerifyProofOfFundsUsecase({
    required this.serversPort,
    required this.transactionRepository,
    required this.electrumDatasource,
    this.proofOfFunds = const ProofOfFunds(),
  });

  final ElectrumServersPort serversPort;
  final ElectrumTransactionRepository transactionRepository;
  final ElectrumRemoteDatasource electrumDatasource;
  final ProofOfFunds proofOfFunds;

  Future<ProofResult> execute({
    required String message,
    required String challengeAddress,
    required String signature,
    required Network network,
  }) async {
    final chain = ElectrumChainLookup(
      serversPort: serversPort,
      transactionRepository: transactionRepository,
      datasource: electrumDatasource,
      isTestnet: network.isTestnet,
    );

    try {
      return await proofOfFunds.verify(
        message: message,
        challengeAddress: challengeAddress,
        signature: signature,
        network: network.isTestnet
            ? ProofNetwork.testnet
            : ProofNetwork.mainnet,
        chain: chain,
      );
    } on UnsupportedScriptError {
      throw const CoinsError.unsupportedScript();
    } on ProofError {
      throw const CoinsError.verifyFailed();
    } catch (e) {
      throw CoinsError.unexpected(message: e.toString());
    }
  }
}
