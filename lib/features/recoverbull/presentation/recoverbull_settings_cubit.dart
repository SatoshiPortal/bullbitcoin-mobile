import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/has_current_encrypted_backup_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverBullSettingsCubit extends Cubit<bool?> {
  final HasCurrentEncryptedBackupUsecase _hasCurrentEncryptedBackupUsecase;

  RecoverBullSettingsCubit(this._hasCurrentEncryptedBackupUsecase)
    : super(null);

  Future<void> load() async {
    try {
      emit(await _hasCurrentEncryptedBackupUsecase.execute());
    } catch (error, stackTrace) {
      log.warning(
        'Failed to check RecoverBull encrypted backup status',
        error: error,
        trace: stackTrace,
      );
      emit(false);
    }
  }
}
