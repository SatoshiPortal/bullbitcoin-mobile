import 'package:bb_mobile/features/settings/domain/usecases/get_background_activity_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/open_background_activity_settings_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum BackgroundActivityStatus {
  unknown,
  notApplicable,
  unrestricted,
  restricted,
}

class BackgroundActivityCubit extends Cubit<BackgroundActivityStatus> {
  final GetBackgroundActivityUsecase _get;
  final OpenBackgroundActivitySettingsUsecase _open;

  BackgroundActivityCubit({
    required GetBackgroundActivityUsecase getBackgroundActivityUsecase,
    required OpenBackgroundActivitySettingsUsecase
    openBackgroundActivitySettingsUsecase,
  }) : _get = getBackgroundActivityUsecase,
       _open = openBackgroundActivitySettingsUsecase,
       super(BackgroundActivityStatus.unknown);

  /// Read on entry and on resume: the user changes it in the system settings.
  Future<void> refresh() async {
    final unrestricted = await _get.execute();
    if (isClosed) return;
    emit(switch (unrestricted) {
      null => BackgroundActivityStatus.notApplicable,
      true => BackgroundActivityStatus.unrestricted,
      false => BackgroundActivityStatus.restricted,
    });
  }

  Future<void> openSettings() async {
    if (!await _open.execute()) log.warning('Opening battery settings failed');
  }
}
