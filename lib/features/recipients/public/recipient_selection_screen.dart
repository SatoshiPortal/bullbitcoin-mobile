import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/screens/recipients_screen.dart';
import 'package:bb_mobile/features/recipients/public/recipient_filter_criteria.dart';
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
      onRecipientSelected: (recipient, {required isNew}) => onRecipientSelected(
        RecipientSelection.fromViewModel(recipient),
        isNew: isNew,
      ),
      isHookRunning: isHookRunning,
      onRecipientAddedHookError: onRecipientAddedHookError,
      onRecipientSelectedHookError: onRecipientSelectedHookError,
    );
  }
}
