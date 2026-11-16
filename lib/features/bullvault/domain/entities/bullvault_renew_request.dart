import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';

final class BullVaultRenewRequest {
  final String walletId;
  final String label;
  final BullVaultSchedule schedule;
  final BullVaultTimeReference timeReference;

  const BullVaultRenewRequest({
    required this.walletId,
    required this.label,
    required this.schedule,
    required this.timeReference,
  });
}
