import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_transaction_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:primitives/primitives.dart' show Sats;

abstract interface class BitcoinSendPort {
  Future<String> buildPsbt({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxo>? selected,
    bool selectedOnly = false,
    bool? replaceByFee,
  });

  Future<int> getTxSize({required String psbt});

  Future<List<Sats>> getRecipientAmounts({
    required String psbt,
    required List<BitcoinTransactionRecipient> recipients,
    required String walletId,
  });

  Future<bool> areAddressesOfWallet(
    List<String> addresses, {
    required String walletId,
  });
}
