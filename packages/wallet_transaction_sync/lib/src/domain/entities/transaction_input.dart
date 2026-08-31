import 'transaction_chain.dart';

class TransactionInput {
  final String txid;
  final int vout;
  final int originalIndex;
  final int? value;
  final String? assetId;
  final String? script;
  final String? standardAddress;
  final String? confidentialAddress;
  final int? height;
  final bool? isSpent;
  final TransactionChain? chain;

  const TransactionInput({
    required this.txid,
    required this.vout,
    this.originalIndex = 0,
    this.value,
    this.assetId,
    this.script,
    this.standardAddress,
    this.confidentialAddress,
    this.height,
    this.isSpent,
    this.chain,
  });
}
