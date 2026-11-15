export '../router.dart' show BroadcastSignedTxRoute;

final class BroadcastSignedTxArgs {
  final String signedPayload;

  const BroadcastSignedTxArgs.signed(this.signedPayload);
}
