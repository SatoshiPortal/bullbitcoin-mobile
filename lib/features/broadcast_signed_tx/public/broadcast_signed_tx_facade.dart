import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/type.dart';

export '../type.dart' show BroadcastSignedTxRequest;

class BroadcastSignedTxFacade {
  const BroadcastSignedTxFacade();

  String get collectSignerResultRouteName =>
      BroadcastSignedTxRoute.broadcastHome.name;

  BroadcastSignedTxRequest collectSignerResultRequest({
    required String unsignedPsbt,
    required bool allowNfc,
    required bool allowBbqr,
  }) => BroadcastSignedTxRequest(
    unsignedPsbt: unsignedPsbt,
    collectSignerResult: true,
    allowSignerResultNfc: allowNfc,
    allowBbqrSignerResult: allowBbqr,
  );
}
