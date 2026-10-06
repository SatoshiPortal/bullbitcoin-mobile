import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';

/// Max retained SP notification-log lines, shared by the repository ring buffer
/// and the settings console mirror so both cap at the same length.
const int spNotifLogCap = 200;

/// One timestamped SP notification kept for the debug console. Rendering lives
/// in the presentation layer.
class SpNotifLogLine {
  final DateTime time;
  final SpNotification notification;

  const SpNotifLogLine({required this.time, required this.notification});
}
