import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';

final class BullVaultPreviousVault {
  final BullVaultRecord record;
  final Wallet wallet;

  const BullVaultPreviousVault({required this.record, required this.wallet});

  bool get hasFunds => wallet.balanceSat > BigInt.zero;
}
