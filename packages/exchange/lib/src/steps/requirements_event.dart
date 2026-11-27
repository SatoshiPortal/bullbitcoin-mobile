import 'package:meta/meta.dart';

import 'interac_security_event.dart';
import 'virtual_iban_event.dart';
import 'virtual_payee_event.dart';

@immutable
sealed class RequirementsEvent {
  const RequirementsEvent();
}

final class RequirementInteracEvent extends RequirementsEvent {
  final InteracSecurityEvent event;

  const RequirementInteracEvent(this.event);
}

final class RequirementVirtualIbanEvent extends RequirementsEvent {
  final VirtualIbanEvent event;

  const RequirementVirtualIbanEvent(this.event);
}

final class RequirementVirtualPayeeEvent extends RequirementsEvent {
  final VirtualPayeeEvent event;

  const RequirementVirtualPayeeEvent(this.event);
}

/// Back out of the step to the recipient list.
final class RequirementsCancelPressed extends RequirementsEvent {
  const RequirementsCancelPressed();
}
