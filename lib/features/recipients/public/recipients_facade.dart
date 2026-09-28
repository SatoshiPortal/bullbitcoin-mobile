export '../domain/value_objects/recipient_type.dart' show RecipientType;
export 'recipient_filter_criteria.dart' show RecipientFilterCriteria;
export 'recipient_view_model.dart';

/// Public contract of the Recipients feature.
///
/// Other features must import Recipients-owned types through this file instead
/// of depending on its internal layers directly. This surface is Flutter-free
/// so domain-layer consumers can depend on it; the feature's UI is published
/// separately through `recipients_ui.dart`.
class RecipientsFacade {
  const RecipientsFacade();
}
