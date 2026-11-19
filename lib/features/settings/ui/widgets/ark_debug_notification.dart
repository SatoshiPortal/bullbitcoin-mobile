import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:bull_ark/ark_debug_notification.dart';
import 'package:bull_ark/ark_notification_setup.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

Future<void> showArkDebugNotification(BuildContext context) async {
  final locale = Localizations.localeOf(context);
  final initialized = await initializeArkNotifications(locale);
  final result = switch (initialized) {
    Err(:final failure) => Err(failure),
    Ok(:final value) => await scheduleArkDebugNotification(
      gateway: value,
      locale: locale,
      now: DateTime.now(),
    ),
  };
  if (!context.mounted) return;
  final french = locale.languageCode == 'fr';
  BullSnackBar.show(
    context,
    message: switch (result) {
      Ok() =>
        french
            ? 'Notification programmée dans environ une minute.'
            : 'Notification scheduled in about one minute.',
      Err() =>
        french
            ? 'Notification indisponible : vérifiez les autorisations.'
            : 'Notification unavailable: check notification permissions.',
    },
  );
}
