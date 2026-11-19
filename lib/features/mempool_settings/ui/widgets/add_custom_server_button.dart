import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:bb_mobile/features/mempool_settings/ui/widgets/set_custom_server_bottom_sheet.dart';
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
      child: BullButton.big(
        label: context.loc.mempoolSettingsCustomServer,
        iconData: Icons.add,
        iconFirst: true,
        bgColor: context.appColors.primary,
        textColor: context.appColors.onPrimary,
        disabled: processing,
        onPressed: add,
      ),
    );
  }
}
