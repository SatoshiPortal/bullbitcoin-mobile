import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// OR
// import 'package:bb_mobile/_ui/screens/exchange/bull_bitcoin_launcher.dart'; // For URL launcher solution

class BottomNavbar extends StatelessWidget {
  const BottomNavbar({
    super.key,
    required this.selectedPage,
    required this.onPageSelected,
  });

  final int selectedPage;
  final Function(int) onPageSelected;

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state?.isSuperuser ?? false,
    );
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 20),
      color: context.colour.onPrimary,
      height: 92,
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavButton(
            icon: Assets.icons.btc.path,
            label: 'Wallet',
            onPressed: () {
              onPageSelected(0);
            },
            selected: selectedPage == 0,
          ),
          _BottomNavButton(
            icon: Assets.icons.dollar.path,
            label: 'Exchange',
            onPressed:
                isSuperuser
                    ? () {
                      onPageSelected(1);
                    }
                    : null,
            selected: selectedPage == 1,
          ),
        ],
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.selected,
  });

  final String icon;
  final String label;
  final void Function()? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colour.primary : context.colour.outline;

    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Column(
          children: [
            Image.asset(icon, width: 24, height: 24, color: color),
            const SizedBox(height: 8),
            BBText(label, style: context.font.labelLarge, color: color),
          ],
        ),
      ),
    );
  }
}
