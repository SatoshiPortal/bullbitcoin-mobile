import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';

final class BullVaultPreviousVault {
  final BullVaultRecord record;
  final Wallet wallet;

  const BullVaultPreviousVault({required this.record, required this.wallet});

  bool get hasFunds => switch (wallet.balanceSat) {
    final balance? => balance > BigInt.zero,
    null => false,
  };
}
