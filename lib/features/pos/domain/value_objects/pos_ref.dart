import 'package:nostr_pos/nostr_pos.dart' as nostr;

class PosRef {
  const PosRef({required this.merchantPubkey, required this.posId});

  final String merchantPubkey;
  final String posId;

  String get nostrAddress =>
      nostr.posRef(merchantPubkey: merchantPubkey, posId: posId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosRef &&
          runtimeType == other.runtimeType &&
          merchantPubkey == other.merchantPubkey &&
          posId == other.posId;

  @override
  int get hashCode => Object.hash(merchantPubkey, posId);
}
