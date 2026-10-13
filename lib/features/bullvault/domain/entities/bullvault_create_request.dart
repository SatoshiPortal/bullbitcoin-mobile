import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_key_source.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';

final class BullVaultSignerRequest {
  final String input;
  final SignerDeviceEntity? device;
  final bool genericExternal;
  final bool requiresHardwareSetup;

  const BullVaultSignerRequest({
    required this.input,
    required this.device,
    this.genericExternal = false,
    this.requiresHardwareSetup = true,
  });
}

final class BullVaultCreateRequest {
  final String label;
  final BullVaultProtection protection;
  final BullVaultEverydayKeySource everydayKeySource;
  final BullVaultSignerRequest? everydayHardware;
  final String? mobilePassphrase;
  final bool passphraseFreeRecovery;
  final BullVaultSignerRequest cold;
  final BullVaultSignerRequest? secondCold;
  final BullVaultSignerRequest? inheritance;
  final BullVaultSchedule schedule;
  final BullVaultTimeReference timeReference;

  const BullVaultCreateRequest({
    required this.label,
    required this.protection,
    this.everydayKeySource = BullVaultEverydayKeySource.bullMobile,
    this.everydayHardware,
    this.mobilePassphrase,
    this.passphraseFreeRecovery = false,
    required this.cold,
    required this.secondCold,
    required this.inheritance,
    required this.schedule,
    required this.timeReference,
  });
}
