import '../../../network_l10n.dart';
import '../../presentation/mempool_settings_cubit.dart';
import 'set_custom_server_bottom_sheet.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:material_ui/material_ui.dart';

class AddCustomServerButton extends StatelessWidget {
  const AddCustomServerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final processing = context.select(
      (MempoolSettingsCubit cubit) => cubit.state.isProcessing,
    );
    void add() => SetCustomServerBottomSheet.show(context);
    // The visible label is short; the accessible name stays explicit and
    // keeps the tap action the excluded button would otherwise carry.
    return Semantics(
      label: context.loc.mempoolCustomServerAdd,
      button: true,
      enabled: !processing,
      onTap: processing ? null : add,
      excludeSemantics: true,
      child: BullButton.primary(
        label: context.loc.mempoolSettingsCustomServer,
        iconData: Icons.add,
        iconFirst: true,
        onPressed: (processing) ? null : add,
      ),
    );
  }
}
