import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/buttons/bottom_button.dart';
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
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    return Container(
      padding: const EdgeInsets.only(bottom: 20, top: 20),
      color: context.colour.onPrimary,
      height: 92,
      child: Row(
        // mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          BottomButton(
            icon: Assets.icons.btc.path,
            label: 'Wallet',
            onPressed: () {
              onPageSelected(0);
            },
            selected: selectedPage == 0,
          ),
          BottomButton(
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
