import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';

final class BullVaultCreateResult {
  final Wallet wallet;
  final BullVaultRecord record;

  const BullVaultCreateResult({required this.wallet, required this.record});

  BullVaultPolicy get policy => record.recoveryPackage.policy;

  BullVaultRecoveryPackage get recoveryPackage => record.recoveryPackage;

  BullVaultCreateResult copyWith({Wallet? wallet, BullVaultRecord? record}) =>
      BullVaultCreateResult(
        wallet: wallet ?? this.wallet,
        record: record ?? this.record,
      );
}
