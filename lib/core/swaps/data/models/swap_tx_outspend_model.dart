import 'package:bb_mobile/core/swaps/domain/entity/swap_tx_outspend.dart';

class SwapTxOutspendModel {
  final String? txid;
  final DateTime? timestamp;

  const SwapTxOutspendModel({this.txid, this.timestamp});

  SwapTxOutspend toEntity() {
    return SwapTxOutspend(txid: txid, timestamp: timestamp);
  }

  factory SwapTxOutspendModel.fromEntity(SwapTxOutspend entity) {
    return SwapTxOutspendModel(txid: entity.txid, timestamp: entity.timestamp);
  }
}
