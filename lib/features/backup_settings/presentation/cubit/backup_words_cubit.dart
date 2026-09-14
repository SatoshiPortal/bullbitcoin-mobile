import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/reveal_backup_words_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether a reveal is running and why the last one did not produce words.
///
/// The words themselves are deliberately absent: [BackupWordsCubit.reveal]
/// hands them straight back to the widget that displays them, so a secret never
/// sits in bloc state, in a state `toString`, or in an observer's log.
final class BackupWordsState {
  final bool loading;
  final BackupSettingsFailure? failure;

  const BackupWordsState({this.loading = false, this.failure});
}

final class BackupWordsCubit extends Cubit<BackupWordsState> {
  final RevealBackupWordsUsecase _reveal;

  BackupWordsCubit(this._reveal) : super(const BackupWordsState());

  /// The twelve words, or null when they could not be derived.
  ///
  /// [originFingerprint] names the wallet a selected vault belongs to, so this
  /// device's words are never shown as that vault's credential.
  ///
  /// Each emitted state is a fresh object: a canonicalised `const` state would
  /// compare equal to the initial one and the finished emit would be dropped.
  Future<List<String>?> reveal({String? originFingerprint}) async {
    emit(BackupWordsState(loading: true));
    final result = await _reveal.execute(originFingerprint: originFingerprint);
    if (isClosed) return null;
    switch (result) {
      case Ok(:final value):
        emit(BackupWordsState());
        return value;
      case Err(:final failure):
        emit(BackupWordsState(failure: failure));
        return null;
    }
  }
}
