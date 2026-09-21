export '../domain/value_objects/recipient_type.dart' show RecipientType;
export '../frameworks/ui/screens/recipients_screen.dart' show RecipientsScreen;
export 'recipient_filter_criteria.dart' show RecipientFilterCriteria;
export 'recipient_view_model.dart';

/// Public contract of the Recipients feature.
///
/// Other features must import Recipients-owned types and UI through this file
/// instead of depending on its internal layers directly.
class RecipientsFacade {
  const RecipientsFacade();
}
