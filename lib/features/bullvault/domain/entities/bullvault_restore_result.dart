import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';

enum BullVaultMobileAccess { available, recoveryOnly, unavailable }

final class BullVaultRestoreResult {
  final Wallet wallet;
  final BullVaultRecord record;
  final BullVaultMobileAccess mobileAccess;

  const BullVaultRestoreResult({
    required this.wallet,
    required this.record,
    required this.mobileAccess,
  });
}
