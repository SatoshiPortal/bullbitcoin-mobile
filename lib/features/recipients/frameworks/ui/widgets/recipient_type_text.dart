import 'package:bb_mobile/features/recipients/public/recipient_type_label.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:material_ui/material_ui.dart';

// Helper widget to avoid needing to repeat the mapping of the type with its
// translation label per recipient type in multiple places.
class RecipientTypeText extends StatelessWidget {
  const RecipientTypeText({super.key, required this.recipientType, this.style});

  final RecipientType recipientType;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(recipientTypeLabel(context, recipientType), style: style);
  }
}
