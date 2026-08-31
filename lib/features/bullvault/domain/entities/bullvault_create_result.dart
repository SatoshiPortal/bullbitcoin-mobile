import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';

final class BullVaultCreateResult {
  final Wallet wallet;
  final BullVaultPolicy policy;
  final BullVaultRecord record;
  final BullVaultRecoveryPackage recoveryPackage;

  const BullVaultCreateResult({
    required this.wallet,
    required this.policy,
    required this.record,
    required this.recoveryPackage,
  });
}
