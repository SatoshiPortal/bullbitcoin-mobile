import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';

final class BullVaultRenewResult {
  final BullVaultRecord previous;
  final BullVaultCreateResult replacement;

  const BullVaultRenewResult({
    required this.previous,
    required this.replacement,
  });
}
