import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/verify_vault_descriptor_backup_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';

final class VaultBackupState {
  final VaultBackupInspection? inspection;
  final bool busy;
  final BackupSettingsFailure? failure;
  final bool? verified;

  /// The source a single check tested, or null when every remote source was.
  final VaultBackupSource? checkedSource;

  /// What the last check made of each source, beside its historical date. A
  /// failed attempt appears here and never in [VaultBackupInspection.testedAt].
  final VaultBackupCheckResults latest;
  const VaultBackupState({
    this.inspection,
    this.busy = false,
    this.failure,
    this.verified,
    this.checkedSource,
    this.latest = const {},
  });
}

final class VaultBackupCubit extends Cubit<VaultBackupState> {
  final VerifyVaultDescriptorBackupUsecase _verify;
  final String walletId;
  VaultBackupCubit(this._verify, this.walletId)
    : super(const VaultBackupState(busy: true));

  Future<void> load() async {
    final result = await _verify.load(walletId);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => VaultBackupState(inspection: value),
      Err(:final failure) => VaultBackupState(failure: failure),
    });
  }

  String export() => _verify.export(state.inspection!);
  Future<void> verifyManual(String text) => _check(
    VaultBackupSource.manual,
    () => _verify.verifyManual(walletId, text),
  );
  Future<void> importFile() =>
      _check(VaultBackupSource.manual, () => _verify.importFile(walletId));

  /// Tests every remote source independently and keeps each result.
  Future<void> checkAgain() async {
    if (state.busy) return;
    final inspection = state.inspection;
    emit(VaultBackupState(inspection: inspection, busy: true));
    final result = await _verify.checkAgain(walletId);
    if (isClosed) return;
    if (result case Err(:final failure)) {
      emit(VaultBackupState(inspection: inspection, failure: failure));
      return;
    }
    final latest =
        (result as Ok<VaultBackupCheckResults, BackupSettingsFailure>).value;
    final updated = await _verify.load(walletId);
    if (isClosed) return;
    emit(switch (updated) {
      Ok(:final value) => VaultBackupState(
        inspection: value,
        latest: latest,
        verified: latest.containsValue(VaultBackupCheckStatus.success),
      ),
      Err(:final failure) => VaultBackupState(
        inspection: inspection,
        failure: failure,
      ),
    });
  }

  Future<void> _check(
    VaultBackupSource source,
    Future<Result<bool?, BackupSettingsFailure>> Function() operation,
  ) async {
    if (state.busy) return;
    final inspection = state.inspection;
    emit(VaultBackupState(inspection: inspection, busy: true));
    final result = await operation();
    if (isClosed) return;
    if (result case Err(:final failure)) {
      emit(VaultBackupState(inspection: inspection, failure: failure));
      return;
    }
    final updated = await _verify.load(walletId);
    if (isClosed) return;
    emit(switch (updated) {
      Ok(:final value) => VaultBackupState(
        inspection: value,
        latest: state.latest,
        verified: (result as Ok<bool?, BackupSettingsFailure>).value,
        checkedSource: source,
      ),
      Err(:final failure) => VaultBackupState(
        inspection: inspection,
        failure: failure,
      ),
    });
  }
}
