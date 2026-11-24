import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:settings/settings.dart' show Settings;
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EyeToggle extends StatelessWidget {
  const EyeToggle();

  @override
  Widget build(BuildContext context) {
    final hide = context.select(
      (WalletBloc bloc) => bloc.state.amountDisplay?.hideAmounts ?? true,
    );
    return IconButton(
      tooltip: hide
          ? context.loc.walletShowAmountsTooltip
          : context.loc.walletHideAmountsTooltip,
      // 9 + 30 + 9 keeps a 48 dp target around the unchanged 30 dp badge.
      padding: const EdgeInsets.all(9),
      onPressed: () {
        Settings.setAmountsHidden(context, !hide);
      },
      icon: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.bullShapes.key),
          border: Border.all(color: context.appColors.surfaceBright),
          color: context.appColors.scrim,
        ),
        child: Icon(
          !hide ? Icons.visibility : Icons.visibility_off,
          color: context.appColors.onPrimary,
          size: 20,
        ),
      ),
    );
  }
}
