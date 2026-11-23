import 'package:bull_ui/bull_ui.dart' show BullSettingsEntryItem, BullSwitch;
import 'package:material_ui/material_ui.dart';

import '../../exchange_l10n.dart';

/// The pre-init wizard exposure of Exchange. It does not resolve a session.
final class WizardExchangeOption extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const WizardExchangeOption({
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: BullSettingsEntryItem(
      icon: Icons.currency_exchange,
      title: context.loc.wizardExchangeTitle,
      subtitle: context.loc.wizardExchangeDescription,
      contentPadding: EdgeInsets.zero,
      trailing: BullSwitch(value: enabled, onChanged: onChanged),
    ),
  );
}
