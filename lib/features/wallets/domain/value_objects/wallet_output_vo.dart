import 'package:meta/meta.dart';

import '../errors/wallet_errors.dart';

@immutable
class WalletOutputVO {
  const WalletOutputVO({
    required this.txId,
    required this.vout,
    required this.amountSat,
    this.isChangeOutput,
  }) {
    if (txId.isEmpty) {
      throw InvalidOutputError(field: 'txId', value: txId);
    }
    if (txId.length != 64) {
      throw InvalidOutputError(field: 'txId', value: 'Transaction ID must be 64 characters (got ${txId.length})');
    }
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(txId)) {
      throw InvalidOutputError(field: 'txId', value: 'Transaction ID must be hexadecimal');
    }
    if (vout < 0) {
      throw InvalidOutputError(field: 'vout', value: vout);
    }
    if (amountSat < 0) {
      throw InvalidOutputError(field: 'amountSat', value: amountSat);
    }
  }

  final String txId;
  final int vout;
  final int amountSat;
  final bool? isChangeOutput;
}
