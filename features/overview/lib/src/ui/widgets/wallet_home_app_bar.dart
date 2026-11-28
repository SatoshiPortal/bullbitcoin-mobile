import 'package:bull_ui/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class WalletHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;

  const WalletHomeAppBar({super.key, required this.title});

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
      title: title,
    );
  }
}
