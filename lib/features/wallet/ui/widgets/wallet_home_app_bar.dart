import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullSpacing;
import 'package:settings/settings.dart' show SuperuserTapUnlocker;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
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
      title: SuperuserTapUnlocker(
        child: SizedBox.square(
          dimension: BullSpacing.xxl,
          child: Center(
            child: Assets.logos.bbLogoSmall.image(width: 40, height: 40),
          ),
        ),
      ),
    );
  }
}
