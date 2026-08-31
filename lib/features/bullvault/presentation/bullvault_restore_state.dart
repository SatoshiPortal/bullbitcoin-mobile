import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';

final class BullVaultRestoreState {
  final bool isRestoring;
  final BullVaultFailure? failure;
  final BullVaultRestoreResult? result;

  const BullVaultRestoreState({
    this.isRestoring = false,
    this.failure,
    this.result,
  });

  BullVaultRestoreState copyWith({
    bool? isRestoring,
    BullVaultFailure? failure,
    bool clearFailure = false,
    BullVaultRestoreResult? result,
  }) => BullVaultRestoreState(
    isRestoring: isRestoring ?? this.isRestoring,
    failure: clearFailure ? null : failure ?? this.failure,
    result: result ?? this.result,
  );
}
