import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_notification_permission_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/open_notification_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/request_notification_permission_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/notification_permission_state.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'notification_permission_state.dart';

class NotificationPermissionCubit extends Cubit<NotificationPermissionState> {
  final GetNotificationPermissionUsecase _get;
  final RequestNotificationPermissionUsecase _request;
  final OpenNotificationSettingsUsecase _openSettings;

  NotificationPermissionCubit({
    required GetNotificationPermissionUsecase getNotificationPermissionUsecase,
    required RequestNotificationPermissionUsecase
    requestNotificationPermissionUsecase,
    required OpenNotificationSettingsUsecase openNotificationSettingsUsecase,
  }) : _get = getNotificationPermissionUsecase,
       _request = requestNotificationPermissionUsecase,
       _openSettings = openNotificationSettingsUsecase,
       super(const NotificationPermissionState());

  /// Reads the OS state; called on entry and whenever the app resumes, since
  /// the user can change it in the system settings at any time.
  Future<void> refresh() async {
    final result = await _get.execute();
    if (isClosed) return;
    emit(state.copyWith(status: _statusOf(result)));
  }

  Future<void> request() async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    final requested = await _request.execute();
    if (isClosed) return;
    // The prompt reports the app-level grant only; the effective state also
    // needs the payment channel, which the user may have blocked.
    final result = requested is Ok ? await _get.execute() : requested;
    if (isClosed) return;
    final status = _statusOf(result);
    if (result case Ok()) {
      log.config('Notification permission requested status=${status.name}');
    }
    emit(
      state.copyWith(
        status: status,
        promptDeclined: status == NotificationPermissionStatus.off,
        busy: false,
      ),
    );
  }

  Future<void> openSystemSettings() async {
    if (await _openSettings.execute() case Err(:final failure)) {
      log.warning(
        'Opening notification settings failed: ${failure.runtimeType}',
      );
    }
  }

  static NotificationPermissionStatus _statusOf(
    Result<bool, SettingsFailure> result,
  ) => switch (result) {
    Ok(value: true) => NotificationPermissionStatus.allowed,
    Ok() => NotificationPermissionStatus.off,
    Err() => NotificationPermissionStatus.unavailable,
  };
}
