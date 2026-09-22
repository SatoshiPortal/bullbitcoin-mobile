export '../domain/value_objects/recipient_type.dart' show RecipientType;
export '../domain/value_objects/sepa_payment_option.dart'
    show SepaPaymentOption;
export '../domain/value_objects/sepa_virtual_payee_status.dart'
    show SepaVirtualPayeeStatus;
export '../frameworks/ui/screens/recipients_screen.dart' show RecipientsScreen;
export '../ui/screens/fr_payee_activation_screen.dart'
    show FrPayeeActivationArgs, FrPayeeActivationScreen;
export 'recipient_filter_criteria.dart' show RecipientFilterCriteria;
export 'recipient_view_model.dart';

/// Public contract of the Recipients feature.
///
/// Other features must import Recipients-owned types and UI through this file
/// instead of depending on its internal layers directly.
class RecipientsFacade {
  const RecipientsFacade();
}
