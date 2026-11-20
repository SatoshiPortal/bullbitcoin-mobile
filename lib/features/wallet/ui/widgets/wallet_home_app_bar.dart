import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show BullIcon, BullIcons;
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class WalletHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WalletHomeAppBar({super.key, required this.onSettings});

  final VoidCallback onSettings;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.appColors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: const TopBarBullLogo(enableSuperuserTapUnlocker: true),
      actions: [
        IconButton(
          tooltip: context.loc.settingsScreenTitle,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          visualDensity: VisualDensity.standard,
          onPressed: onSettings,
          icon: BullIcon(
            BullIcons.settings,
            size: 32,
            color: context.appColors.onPrimary,
          ),
        ),
      ],
    );
  }
}
