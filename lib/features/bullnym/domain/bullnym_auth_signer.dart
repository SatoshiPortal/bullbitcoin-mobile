import 'dart:async';

typedef BullnymSignHash = FutureOr<String> Function(String messageHashHex);

class BullnymAuthSigner {
  final String npubHex;
  final BullnymSignHash signHashHex;

  const BullnymAuthSigner({required this.npubHex, required this.signHashHex});
}
