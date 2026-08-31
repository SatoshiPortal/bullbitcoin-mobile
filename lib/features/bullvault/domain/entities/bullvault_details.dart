import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_previous_vault.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';

final class BullVaultDetails {
  final BullVaultRecord record;
  final BullVaultPolicy policy;
  final Duration? timeUntilFirstRecovery;
  final bool showEarlyRenewalWarning;
  final String? migrationAddress;
  final List<BullVaultPreviousVault> previousVaults;

  BullVaultDetails({
    required this.record,
    required this.policy,
    required this.timeUntilFirstRecovery,
    required this.showEarlyRenewalWarning,
    required this.migrationAddress,
    this.previousVaults = const [],
  }) {
    if (previousVaults.isNotEmpty && migrationAddress == null) {
      throw ArgumentError(
        'BullVaults with previous generations require a migration address',
      );
    }
  }

  bool get hasPreviousFunds => previousVaults.any((vault) => vault.hasFunds);
}
