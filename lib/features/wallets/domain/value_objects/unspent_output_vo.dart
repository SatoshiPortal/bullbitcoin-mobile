import 'package:meta/meta.dart';

@immutable
class UnspentOutputVO {
  const UnspentOutputVO({
    required this.txId,
    required this.vout,
    required this.amountSat,
    this.isChangeOutput,
  });

  final String txId;
  final int vout;
  final int amountSat;
  final bool? isChangeOutput;
}
