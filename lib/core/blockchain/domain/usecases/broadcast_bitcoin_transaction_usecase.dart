import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:convert/convert.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;
  final SettingsRepository _settingsRepository;
  final WalletUtxoRepository _walletUtxoRepository;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required this._settingsRepository,
    required this._walletUtxoRepository,
  }) : _bitcoinBlockchain = bitcoinBlockchainRepository;

  Future<String> execute(String transaction, {required bool isPsbt}) async {
    try {
      // A frozen coin must never be spent, whoever built or signed the
      // transaction: before broadcasting for its callers (send, broadcast
      // signed tx, pay, sell, transfer, RBF), check the outpoints this
      // transaction actually spends against the frozen store, read now. A
      // failure to read either refuses the broadcast. Payjoin broadcasts
      // through its own port (AppPayjoinBlockchainAdapter), not through here.
      await _requireNoFrozenInput(transaction, isPsbt: isPsbt);

      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      if (isPsbt) {
        return await _bitcoinBlockchain.broadcastPsbt(
          transaction,
          isTestnet: isTestnet,
        );
      }
      return await _bitcoinBlockchain.broadcastTransaction(
        hex.decode(transaction),
        isTestnet: isTestnet,
      );
    } catch (e) {
      throw BroadcastTransactionException(e.toString());
    }
  }

  Future<void> _requireNoFrozenInput(
    String transaction, {
    required bool isPsbt,
  }) async {
    final tx = isPsbt
        ? await BitcoinTx.fromPsbt(transaction)
        : await BitcoinTx.fromBytes(hex.decode(transaction));
    final frozen = (await _walletUtxoRepository.getAllFrozenOutpoints())
        .map((outpoint) => '${outpoint.txId}:${outpoint.vout}')
        .toSet();
    if (tx.inputs.any(
      (input) => frozen.contains('${input.txid}:${input.vout}'),
    )) {
      throw const FrozenInputBroadcastException();
    }
  }
}

/// The transaction spends a coin the user froze; it is not broadcast.
class FrozenInputBroadcastException implements Exception {
  const FrozenInputBroadcastException();

  @override
  String toString() => 'The transaction spends a frozen coin';
}
