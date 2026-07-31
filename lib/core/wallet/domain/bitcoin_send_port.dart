import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/tx_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:meta/meta.dart';

abstract interface class BitcoinSendPort {
  Future<String> buildPsbt({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxo>? selected,
    bool? replaceByFee,
  });

  /// Builds an unsigned PSBT that spends **exactly** [inputs] to [recipients],
  /// which may hold several outputs — the coin-sweep contract.
  ///
  /// The wallet is forbidden from adding any input beyond [inputs], so the
  /// coins the user picked are the coins that get spent. A [DrainTxRecipient]
  /// in [recipients] (at most one) absorbs the remainder and suppresses the
  /// change output; with none, the leftover returns to this wallet's own
  /// change output.
  ///
  /// Callers MUST have already rejected any frozen or otherwise reserved
  /// outpoint: pinned inputs outrank the unspendable list inside BDK, so this
  /// method cannot enforce that invariant on their behalf.
  @useResult
  Future<String> buildSweepPsbt({
    required String walletId,
    required List<TxRecipient> recipients,
    required List<WalletUtxo> inputs,
    required NetworkFee networkFee,
    bool? replaceByFee,
  });

  Future<int> getTxSize({required String psbt});

  /// The absolute fee of [psbt], read from the PSBT itself rather than
  /// re-derived from a rate — the real number the user will pay.
  Future<int> getTxFeeAmount({required String psbt});

  Future<String> signPsbt(String psbt, {required String walletId});

  Future<bool> isAddressOfWallet(String address, {required String walletId});
}
