import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar_bull_logo.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
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
      centerTitle: true,
      title: const TopBarBullLogo(enableSuperuserTapUnlocker: true),
      actionsIconTheme: IconThemeData(
        color: context.colour.onPrimary,
        size: 24,
      ),
      actionsPadding: const EdgeInsets.only(right: 16),
      actions: [
        IconButton(
          padding: const EdgeInsets.only(right: 16),
          onPressed: () {
            context.pushNamed(TransactionsRoute.transactions.name);
          },
          visualDensity: VisualDensity.compact,
          color: context.colour.onPrimary,
          iconSize: 24,
          icon: const Icon(Icons.history),
        ),
        InkWell(
          onTap: () => context.pushNamed(SettingsRoute.settings.name),
          child: Image.asset(
            Assets.icons.settingsLine.path,
            width: 24,
            height: 24,
            color: context.colour.onPrimary,
          ),
        ),
      ],
    );
  }
}
