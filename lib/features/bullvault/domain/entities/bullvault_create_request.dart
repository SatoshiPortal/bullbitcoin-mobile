import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';

final class BullVaultSignerRequest {
  final String input;
  final SignerDeviceEntity? device;
  final bool genericExternal;

  const BullVaultSignerRequest({
    required this.input,
    required this.device,
    this.genericExternal = false,
  });
}

final class BullVaultCreateRequest {
  final String label;
  final BullVaultProtection protection;
  final BullVaultSignerRequest cold;
  final BullVaultSignerRequest? secondCold;
  final BullVaultSignerRequest? inheritance;
  final BullVaultSchedule schedule;
  final BullVaultTimeReference timeReference;

  const BullVaultCreateRequest({
    required this.label,
    required this.protection,
    required this.cold,
    required this.secondCold,
    required this.inheritance,
    required this.schedule,
    required this.timeReference,
  });
}
