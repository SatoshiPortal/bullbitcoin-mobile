import 'package:bb_mobile/core/bbqr/bbqr.dart';

typedef ParsedTx = ScannedTransaction;

final class BroadcastSignedTxRequest {
  final String? unsignedPsbt;
  final bool collectSignerResult;
  final bool allowSignerResultNfc;
  final bool allowBbqrSignerResult;

  const BroadcastSignedTxRequest({
    this.unsignedPsbt,
    this.collectSignerResult = false,
    this.allowSignerResultNfc = false,
    this.allowBbqrSignerResult = false,
  });
}
