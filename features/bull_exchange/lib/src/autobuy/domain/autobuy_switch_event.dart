import 'package:meta/meta.dart';

import 'autobuy_event.dart';

@immutable
sealed class AutoBuySwitchEvent {
  const AutoBuySwitchEvent();
}

/// The dashboard's summary changed (a refresh, the activation flow).
final class SwitchSummaryChanged extends AutoBuySwitchEvent {
  final bool active;
  final bool restricted;

  const SwitchSummaryChanged({required this.active, required this.restricted});
}

/// The user confirmed the deactivate dialog.
final class SwitchDeactivatePressed extends AutoBuySwitchEvent {
  const SwitchDeactivatePressed();
}

final class SwitchRetryPressed extends AutoBuySwitchEvent {
  const SwitchRetryPressed();
}

final class SwitchConfirmChanged extends AutoBuySwitchEvent {
  final AutoBuyConfirmEvent event;

  const SwitchConfirmChanged(this.event);
}
