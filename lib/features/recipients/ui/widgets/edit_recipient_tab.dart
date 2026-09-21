import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipient_form.dart';
import 'package:flutter/widgets.dart';

class EditRecipientTab extends StatelessWidget {
  const EditRecipientTab({required this.recipient, super.key});

  final RecipientViewModel recipient;

  @override
  Widget build(BuildContext context) {
    return ScrollableColumn(
      padding: EdgeInsets.zero,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RecipientForm(recipientType: recipient.type, recipient: recipient),
      ],
    );
  }
}
