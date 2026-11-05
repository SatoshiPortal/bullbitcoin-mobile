import 'package:bb_mobile/features/wizard/domain/usecase/open_battery_settings_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/read_background_activity_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// State: whether Android restricts the app in the background.
class BackgroundActivityCubit extends Cubit<bool> {
  BackgroundActivityCubit({required this._read, required this._open})
    : super(false);

  final ReadBackgroundActivityUsecase _read;
  final OpenBatterySettingsUsecase _open;

  Future<void> refresh() async {
    final unrestricted = await _read.execute();
    if (!isClosed) emit(unrestricted == false);
  }

  Future<void> openSettings() => _open.execute();
}
