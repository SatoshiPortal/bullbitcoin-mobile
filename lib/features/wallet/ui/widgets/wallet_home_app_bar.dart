import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WalletHomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      centerTitle: true,
      title: const TopBarBullLogo(enableSuperuserTapUnlocker: true),
      actionsIconTheme: IconThemeData(
        color: context.colour.onPrimary,
        size: 24,
      ),
      actionsPadding: const EdgeInsets.only(right: 16),
      actions: [
        IconButton(
          onPressed: () {
            context.pushNamed(TransactionsRoute.transactions.name);
          },
          visualDensity: VisualDensity.compact,
          color: context.colour.onPrimary,
          iconSize: 32,
          icon: const Icon(Icons.history),
        ),
        const Gap(16),
        InkWell(
          onTap: () => context.pushNamed(SettingsRoute.settings.name),
          child: Image.asset(
            Assets.icons.settingsLine.path,
            width: 32,
            height: 32,
            color: context.colour.onPrimary,
          ),
        ),
      ],
    );
  }
}
