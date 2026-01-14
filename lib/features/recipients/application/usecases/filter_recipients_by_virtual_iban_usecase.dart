import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';

/// Usecase to filter recipients for Virtual IBAN (Confidential SEPA) mode.
///
/// This usecase applies the following filters:
/// - Only show recipients with isOwner=true
/// - Group by IBAN
/// - If both cjPayee and frPayee exist for the same IBAN, keep only frPayee
class FilterRecipientsByVirtualIbanUsecase {
  const FilterRecipientsByVirtualIbanUsecase();

  /// Filters and deduplicates recipients for Virtual IBAN mode.
  ///
  /// Returns a list of recipients where:
  /// - All recipients have isOwner=true
  /// - For recipients with the same IBAN, frPayee is preferred over cjPayee
  List<RecipientViewModel> execute(List<RecipientViewModel> recipients) {
    // Filter to only show recipients with isOwner=true
    final ownerRecipients =
        recipients.where((r) => r.isOwner == true).toList();

    // Group recipients by IBAN
    final ibanGroups = <String, List<RecipientViewModel>>{};
    final recipientsWithoutIban = <RecipientViewModel>[];

    for (final recipient in ownerRecipients) {
      final iban = recipient.iban;
      if (iban != null && iban.isNotEmpty) {
        ibanGroups.putIfAbsent(iban, () => []).add(recipient);
      } else {
        // Keep track of recipients without IBAN separately
        recipientsWithoutIban.add(recipient);
      }
    }

    // For each IBAN group, if there are both cjPayee and frPayee,
    // keep only the frPayee recipient
    final result = <RecipientViewModel>[];
    for (final group in ibanGroups.values) {
      final frPayees =
          group.where((r) => r.type == RecipientType.frPayee).toList();
      final cjPayees =
          group.where((r) => r.type == RecipientType.cjPayee).toList();

      if (frPayees.isNotEmpty && cjPayees.isNotEmpty) {
        // If both exist, only add frPayee recipients (prefer VIBAN)
        result.addAll(frPayees);
      } else {
        // Otherwise, add all recipients in the group
        result.addAll(group);
      }
    }

    // Add recipients without IBAN (shouldn't happen for cjPayee/frPayee, but just in case)
    result.addAll(recipientsWithoutIban);

    return result;
  }
}
