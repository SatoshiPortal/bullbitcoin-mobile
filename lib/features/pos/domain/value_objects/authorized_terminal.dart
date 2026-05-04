import 'package:bb_mobile/features/pos/domain/value_objects/pos_ref.dart';

class AuthorizedTerminal {
  const AuthorizedTerminal({
    required this.posRef,
    required this.terminalPubkey,
    required this.terminalId,
    required this.ctDescriptorRef,
    required this.saleBucketSecretRef,
    required this.saleBucketGeneration,
    required this.effectiveFromEpochDay,
    required this.terminalIndex,
    required this.authorizedAt,
    this.revokedAt,
  });

  final PosRef posRef;
  final String terminalPubkey;
  final String terminalId;
  final String ctDescriptorRef;
  final String saleBucketSecretRef;
  final int saleBucketGeneration;
  final int effectiveFromEpochDay;
  final int terminalIndex;
  final DateTime authorizedAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;
}
