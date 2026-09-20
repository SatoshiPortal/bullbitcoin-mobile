import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/screens/recipients_screen.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/public/recipient_selection.dart';
import 'package:flutter/widgets.dart';

/// Public recipients picker that does not expose recipients feature internals.
class RecipientSelectionScreen extends StatelessWidget {
  const RecipientSelectionScreen({
    required this.types,
    required this.onRecipientSelected,
    this.isOwner,
    this.isHookRunning,
    this.onRecipientAddedHookError,
    this.onRecipientSelectedHookError,
    super.key,
  });

  final List<RecipientType> types;
  final bool? isOwner;
  final Future<void>? Function(RecipientSelection, {required bool isNew})
  onRecipientSelected;
  final bool? isHookRunning;
  final String? onRecipientAddedHookError;
  final String? onRecipientSelectedHookError;

  @override
  Widget build(BuildContext context) {
    return RecipientsScreen(
      filter: RecipientFilterCriteria(types: types, isOwner: isOwner),
      onRecipientSelected: (recipient, {required isNew}) =>
          onRecipientSelected(_toSelection(recipient), isNew: isNew),
      isHookRunning: isHookRunning,
      onRecipientAddedHookError: onRecipientAddedHookError,
      onRecipientSelectedHookError: onRecipientSelectedHookError,
    );
  }

  RecipientSelection _toSelection(RecipientViewModel recipient) {
    return RecipientSelection(
      id: recipient.id,
      type: recipient.type,
      displayName: recipient.displayName,
      email: recipient.email,
      securityQuestion: recipient.securityQuestion,
      securityAnswer: recipient.securityAnswer,
      payeeName: recipient.payeeName,
      payeeCode: recipient.payeeCode,
      payeeAccountNumber: recipient.payeeAccountNumber,
      institutionNumber: recipient.institutionNumber,
      transitNumber: recipient.transitNumber,
      accountNumber: recipient.accountNumber,
      iban: recipient.iban,
      clabe: recipient.clabe,
      phoneNumber: recipient.phoneNumber,
      debitcard: recipient.debitcard,
      bankAccount: recipient.bankAccount,
    );
  }
}
