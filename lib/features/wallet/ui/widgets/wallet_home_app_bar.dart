import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class WalletHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WalletHomeAppBar({super.key});

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
      title: Semantics(
        container: true,
        label: context.loc.onboardingBullBitcoin,
        button: true,
        child: SizedBox.square(
          dimension: 48,
          child: Transform.scale(
            scale: 40 / 48,
            transformHitTests: false,
            child: const TopBarBullLogo(enableSuperuserTapUnlocker: true),
          ),
        ),
      ),
    );
  }
}
