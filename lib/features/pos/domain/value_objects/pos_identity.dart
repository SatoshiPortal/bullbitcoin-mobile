import 'package:bb_mobile/features/pos/domain/value_objects/pos_network.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

class PosIdentity {
  const PosIdentity({
    required this.ref,
    required this.walletId,
    required this.masterFingerprint,
    required this.recoveryPubkey,
    required this.relays,
    required this.network,
    required this.name,
    required this.currency,
    required this.createdAt,
    this.paymentMethods = nostr.PosPaymentMethods.all,
  });

  final PosRef ref;
  final String walletId;
  final String masterFingerprint;
  final String recoveryPubkey;
  final List<String> relays;
  final PosNetwork network;
  final String name;
  final String currency;
  final DateTime createdAt;
  final nostr.PosPaymentMethods paymentMethods;
}
