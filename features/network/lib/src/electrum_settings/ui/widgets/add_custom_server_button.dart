import '../../../network_l10n.dart';
import 'add_custom_server_bottom_sheet.dart';
import '../../presentation/electrum_settings_bloc.dart';

import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

class AddCustomServerButton extends StatelessWidget {
  const AddCustomServerButton({super.key});

  Future<void> _add(BuildContext context) async {
    final result = await AddCustomServerBottomSheet.show(context);
    if (result != null && context.mounted) {
      context.read<ElectrumSettingsBloc>().add(
        ElectrumCustomServerAdded(url: result.url, enableSsl: result.enableSsl),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The visible label is short; the accessible name stays explicit and
    // keeps the tap action the excluded button would otherwise carry.
    return Semantics(
      label: context.loc.electrumAddCustomServer,
      button: true,
      onTap: () => _add(context),
      excludeSemantics: true,
      child: BullButton.primary(
        label: context.loc.mempoolSettingsCustomServer,
        iconData: Icons.add,
        iconFirst: true,
        onPressed: () => _add(context),
      ),
    );
  }
}
