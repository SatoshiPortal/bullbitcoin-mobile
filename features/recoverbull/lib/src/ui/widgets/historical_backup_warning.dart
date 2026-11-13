import 'package:bull_ui/bull_ui.dart';
import '../../l10n/context_localizations.dart';

class RecoverBullHistoricalWarning extends StatelessWidget {
  const RecoverBullHistoricalWarning({super.key});
  @override
  Widget build(BuildContext context) => BullText(
    context.loc.recoverbullHistoricalUnknown,
    style: context.bullText.bodyMedium,
  );
}
