import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/add_custom_server_bottom_sheet.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

class AddCustomServerButton extends StatelessWidget {
  const AddCustomServerButton({super.key});

  @override
  Widget build(BuildContext context) {
    // The visible label is short; the accessible name stays explicit.
    return Semantics(
      label: context.loc.electrumAddCustomServer,
      button: true,
      excludeSemantics: true,
      child: BullButton.big(
        label: context.loc.mempoolSettingsCustomServer,
        iconData: Icons.add,
        iconFirst: true,
        bgColor: context.appColors.primary,
        textColor: context.appColors.onPrimary,
        onPressed: () async {
          final result = await AddCustomServerBottomSheet.show(context);
          if (result != null && context.mounted) {
            context.read<ElectrumSettingsBloc>().add(
              ElectrumCustomServerAdded(
                url: result.url,
                enableSsl: result.enableSsl,
              ),
            );
          }
        },
      ),
    );
  }
}
