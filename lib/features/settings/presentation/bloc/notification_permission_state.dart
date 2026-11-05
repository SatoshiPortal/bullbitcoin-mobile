enum NotificationPermissionStatus { loading, allowed, off, unavailable }

class NotificationPermissionState {
  final NotificationPermissionStatus status;

  /// The OS prompt was shown and notifications stayed off: the OS may not
  /// prompt again, so the system settings become the way to allow them.
  final bool promptDeclined;

  final bool busy;

  const NotificationPermissionState({
    this.status = NotificationPermissionStatus.loading,
    this.promptDeclined = false,
    this.busy = false,
  });

  NotificationPermissionState copyWith({
    NotificationPermissionStatus? status,
    bool? promptDeclined,
    bool? busy,
  }) => NotificationPermissionState(
    status: status ?? this.status,
    promptDeclined: promptDeclined ?? this.promptDeclined,
    busy: busy ?? this.busy,
  );
}
