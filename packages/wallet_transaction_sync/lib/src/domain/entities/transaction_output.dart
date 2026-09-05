import 'transaction_chain.dart';

class TransactionOutput {
  final int valueSats;
  final String? txid;
  final int? vout;
  final String? script;
  final int originalIndex;
  final String? assetId;
  final String? standardAddress;
  final String? confidentialAddress;
  final int? height;
  final bool? isSpent;
  final TransactionChain? chain;

  const TransactionOutput({
    required this.valueSats,
    this.txid,
    this.vout,
    this.script,
    this.originalIndex = 0,
    this.assetId,
    this.standardAddress,
    this.confidentialAddress,
    this.height,
    this.isSpent,
    this.chain,
  });
}
