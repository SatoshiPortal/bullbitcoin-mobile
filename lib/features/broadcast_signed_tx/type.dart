import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Network;
import 'package:bb_mobile/core/bbqr/bbqr.dart';

typedef ParsedTx = ScannedTransaction;

final class BroadcastSignedTxRequest {
  final String? unsignedPsbt;
  final Network? network;
  final bool collectSignerResult;
  final bool allowSignerResultNfc;
  final bool allowBbqrSignerResult;

  const BroadcastSignedTxRequest({
    this.unsignedPsbt,
    this.network,
    this.collectSignerResult = false,
    this.allowSignerResultNfc = false,
    this.allowBbqrSignerResult = false,
  });
}
