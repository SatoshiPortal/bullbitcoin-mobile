import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:flutter/material.dart';
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
      title: const TopBarBullLogo(enableSuperuserTapUnlocker: true),
    );
  }
}
