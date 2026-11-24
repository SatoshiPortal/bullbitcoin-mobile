import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/presentation/recipient_type_l10n.dart';
import 'package:material_ui/material_ui.dart';

class RecipientTypeText extends StatelessWidget {
  const RecipientTypeText({super.key, required this.recipientType, this.style});

  final RecipientType recipientType;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(recipientType.label(context), style: style);
  }
}
