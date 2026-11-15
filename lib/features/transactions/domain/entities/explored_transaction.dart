import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;

final class ExploredTransactionOutput {
  final int index;
  final int amountSat;
  final String? address;

  const ExploredTransactionOutput({
    required this.index,
    required this.amountSat,
    this.address,
  });
}

final class ExploredTransaction {
  static final _txidPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  final String txid;
  final Network network;
  final int version;
  final int sizeBytes;
  final int virtualSizeBytes;
  final int locktime;
  final int inputCount;
  final List<ExploredTransactionOutput> outputs;

  ExploredTransaction({
    required this.txid,
    required this.network,
    required this.version,
    required this.sizeBytes,
    required this.virtualSizeBytes,
    required this.locktime,
    required this.inputCount,
    required List<ExploredTransactionOutput> outputs,
  }) : outputs = List.unmodifiable(outputs) {
    if (!isValidTxid(txid)) {
      throw ArgumentError('txid is not 64 hex characters');
    }
  }

  static bool isValidTxid(String txid) => _txidPattern.hasMatch(txid);

  int get totalOutputSat =>
      outputs.fold(0, (total, output) => total + output.amountSat);
}
