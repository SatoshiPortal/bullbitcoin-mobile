import 'package:primitives/primitives.dart' show Network;

/// The original payment details needed to review and submit a replacement.
typedef ReplacementTarget = ({
  String walletId,
  String txId,
  Network network,
  int feeSat,
  int vsize,
});
