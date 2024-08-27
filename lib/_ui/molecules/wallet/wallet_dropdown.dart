import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/molecules/wallet/wallet_card.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletDropDown extends StatelessWidget {
  const WalletDropDown({
    super.key,
    required this.items,
    required this.onChanged,
    required this.value,
    this.isCentered = true,
    this.disabled = false,
  });

  final List<Wallet> items;
  final void Function(Wallet) onChanged;
  final Wallet value;
  final bool isCentered;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    final bgColour =
        darkMode ? context.colour.onPrimaryContainer : NewColours.offWhite;

    final balance = context.select(
      (CurrencyCubit x) =>
          x.state.getAmountInUnits(value.balance ?? 0, removeText: true),
    );
    final unit = context.select(
      (CurrencyCubit x) => x.state.getUnitString(isLiquid: value.isLiquid()),
    );

    final widget = DropdownButtonHideUnderline(
      child: DropdownButton<Wallet>(
        padding: EdgeInsets.zero,
        itemHeight: null,
        iconSize: 0.0,
        value: value,
        dropdownColor: context.colour.primaryContainer,
        onChanged: disabled
            ? null
            : (value) {
                if (value == null) return;
                onChanged.call(value);
              },
        selectedItemBuilder: (context) => items.map((key) {
          final widget = buildCard(key, balance, unit);
          return widget;
        }).toList(),
        items: [
          for (final w in items)
            DropdownMenuItem(
              value: w,
              child: buildMenuItem(w),
            ),
        ],
      ),
    );

    return widget;
  }
}

Widget buildCard(Wallet w, String balance, String unit) {
  return WalletCard(
    wallet: w,
    balance: balance,
    balanceUnit: unit,
  );
}

Widget buildMenuItem(Wallet w) {
  final text = w.name ?? '';

  final textWidget = BBText.body(text);

  return Center(
    child: textWidget,
  );
}
