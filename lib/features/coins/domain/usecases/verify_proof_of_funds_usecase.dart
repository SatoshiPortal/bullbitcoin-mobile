import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/features/coins/data/electrum_chain_lookup.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:proof_of_funds/proof_of_funds.dart';

/// Verifies a BIP-322 "Proof of Funds" signature: runs the offline
/// cryptographic check, then confirms each proven UTXO against the live
/// Electrum UTXO set (exists, matches the claimed script/amount, unspent).
///
/// Network-agnostic entry point: it resolves the current network from the
/// app environment itself, so it can be invoked from anywhere (e.g. Settings)
/// without a wallet in context.
class VerifyProofOfFundsUsecase {
  VerifyProofOfFundsUsecase({
    required this.serversPort,
    required this.transactionRepository,
    required this.electrumDatasource,
    required this.environmentPort,
    this.proofOfFunds = const ProofOfFunds(),
  });

  final ElectrumServersPort serversPort;
  final ElectrumTransactionRepository transactionRepository;
  final ElectrumRemoteDatasource electrumDatasource;
  final EnvironmentPort environmentPort;
  final ProofOfFunds proofOfFunds;

  Future<ProofResult> execute({
    required String message,
    required String challengeAddress,
    required String signature,
  }) async {
    final environment = await environmentPort.getEnvironment();
    final isTestnet = environment.isTestnet;

    final chain = ElectrumChainLookup(
      serversPort: serversPort,
      transactionRepository: transactionRepository,
      datasource: electrumDatasource,
      isTestnet: isTestnet,
    );

    try {
      return await proofOfFunds.verify(
        message: message,
        challengeAddress: challengeAddress,
        signature: signature,
        network: isTestnet ? ProofNetwork.testnet : ProofNetwork.mainnet,
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
