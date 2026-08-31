import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';

final class BullVaultRecoveryPackage {
  final String? previousVaultId;
  final BullVaultPolicy policy;

  const BullVaultRecoveryPackage({this.previousVaultId, required this.policy});
}
