import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/publish_vault_descriptor_backups_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/verify_vault_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
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

  /// What this vault has agreed to publish where, and how far each got.
  final List<VaultDescriptorPublication> publications;
  const VaultBackupState({
    this.inspection,
    this.busy = false,
    this.failure,
    this.verified,
    this.checkedSource,
    this.latest = const {},
    this.publications = const [],
  });

  bool get hasOutstandingPublication =>
      publications.any((row) => row.outstanding);
}

final class VaultBackupCubit extends Cubit<VaultBackupState> {
  final VerifyVaultDescriptorBackupUsecase _verify;
  final PublishVaultDescriptorBackupsUsecase _publish;
  final String walletId;
  VaultBackupCubit(this._verify, this._publish, this.walletId)
    : super(const VaultBackupState(busy: true));

  Future<void> load() async {
    final result = await _verify.load(walletId);
    final publications = await _publish.load(walletId);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => VaultBackupState(
        inspection: value,
        publications: switch (publications) {
          Ok(value: final rows) => rows,
          // A publication row that cannot be read says nothing about the
          // recovery data this screen exists to hand out.
          Err() => const [],
        },
      ),
      Err(:final failure) => VaultBackupState(failure: failure),
    });
  }

  /// Resends exactly the bytes a destination never acknowledged.
  Future<void> retryPublications() async {
    if (state.busy) return;
    final inspection = state.inspection;
    final publications = state.publications;
    emit(
      VaultBackupState(
        inspection: inspection,
        publications: publications,
        busy: true,
      ),
    );
    final resent = await _publish.retryPendingPublications(walletId);
    if (isClosed) return;
    emit(switch (resent) {
      Ok(:final value) => VaultBackupState(
        inspection: inspection,
        publications: value,
      ),
      Err(:final failure) => VaultBackupState(
        inspection: inspection,
        publications: publications,
        failure: failure,
      ),
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
    // Checking a backup says nothing about what was published where, so the
    // rows and their Retry button stay put while it runs.
    final publications = state.publications;
    emit(
      VaultBackupState(
        inspection: inspection,
        publications: publications,
        busy: true,
      ),
    );
    final result = await _verify.checkAgain(walletId);
    if (isClosed) return;
    if (result case Err(:final failure)) {
      emit(
        VaultBackupState(
          inspection: inspection,
          publications: publications,
          failure: failure,
        ),
      );
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
        publications: publications,
        verified: latest.containsValue(VaultBackupCheckStatus.success),
      ),
      Err(:final failure) => VaultBackupState(
        inspection: inspection,
        publications: publications,
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
    final publications = state.publications;
    final latest = state.latest;
    emit(
      VaultBackupState(
        inspection: inspection,
        publications: publications,
        busy: true,
      ),
    );
    final result = await operation();
    if (isClosed) return;
    if (result case Err(:final failure)) {
      emit(
        VaultBackupState(
          inspection: inspection,
          publications: publications,
          failure: failure,
        ),
      );
      return;
    }
    final updated = await _verify.load(walletId);
    if (isClosed) return;
    emit(switch (updated) {
      Ok(:final value) => VaultBackupState(
        inspection: value,
        latest: latest,
        publications: publications,
        verified: (result as Ok<bool?, BackupSettingsFailure>).value,
        checkedSource: source,
      ),
      Err(:final failure) => VaultBackupState(
        inspection: inspection,
        publications: publications,
        failure: failure,
      ),
    });
  }
}
